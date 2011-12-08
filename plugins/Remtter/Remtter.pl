package MT::Plugin::Remtter;
use strict;
use MT;
use MT::Plugin;
use base qw( MT::Plugin );

use MT::AtomServer;
use MT::Util qw( offset_time_list );

use XML::Simple;

our $CONSUMER_KEY = 'gmoaaG9a5nc7wQ3g4a2qQ';
our $CONSUMER_SECRET = 'PWPS20AKZNcJqph3z1hEo1cOqnVVScViG7mQTeih0';

our $PLUGIN_NAME = 'Remtter';
our $PLUGIN_VERSION = '1.0';

my $plugin = new MT::Plugin::Remtter( {
    id => $PLUGIN_NAME,
    key => lc $PLUGIN_NAME,
    name => $PLUGIN_NAME,
    version => $PLUGIN_VERSION,
    description => '<MT_TRANS phrase=\'Available Remtter.\'>',
    author_name => 'okayama',
    author_link => 'http://weeeblog.net/',
	blog_config_template => \&_blog_config_template,
    settings => new MT::PluginSettings( [
		[ 'access_token', { Scope => 'blog' } ],
		[ 'access_token_secret', { Scope => 'blog' } ],
        [ 'last_modified', { Scope => 'blog' } ],
        [ 'last_follower_ids', { Scope => 'blog' } ],
        [ 'mail_subject', { Scope => 'blog', Default => &_default_mail_subject } ],
        [ 'mail_body', { Scope => 'blog', Default => &_default_mail_body } ],
        [ 'mail_to', { Scope => 'blog', Default => &_default_mail_to } ],
        [ 'mail_from', { Scope => 'blog', Default => &_default_mail_from } ],
        [ 'message_body', { Scope => 'blog', Default => &_default_message_body } ],
        [ 'result_log', { Scope => 'blog', Default => 0 } ],
        [ 'notification_by_direct_message', { Scope => 'blog', Default => 1 } ],
        [ 'notification_by_mail', { Scope => 'blog', Default => 1 } ],
    ] ),
    l10n_class => 'MT::Remtter::L10N',
} );
MT->add_plugin( $plugin );

sub init_registry {
    my $plugin = shift;
    $plugin->registry( {
        applications => {
            cms => {
				methods => {
					remtter_oauth => \&_mode_remtter_oauth,
					remtter_get_access_token => \&_mode_remtter_get_access_token,
				},
            },
        },
        tasks => {
            remtter => {
                label => 'Remtter Task',
                frequency => 5,
                code => \&remtter,
            },
        },
   } );
}

sub _blog_config_template {
	my $plugin = shift;
	my ( $param,  $scope ) = @_;
	my $tmpl = $plugin->load_tmpl( lc $PLUGIN_NAME . '_config_blog.tmpl' );
	my $blog_id = $scope;
	$blog_id =~ s/blog://;
	$tmpl->param( 'blog_id' => $blog_id );
    if ( my $text = $tmpl->text ) {
        $scope = 'blog:' . $blog_id;
        my $last_follower_ids = $plugin->get_config_value( 'last_follower_ids', $scope );
        my @last_follower_ids = split( ',', $last_follower_ids );
	    $tmpl->param( 'follower_num' => scalar @last_follower_ids );
    }
	return $tmpl; 
}

sub remtter {
    my @blogs = MT->model( 'blog' )->load( undef, { no_class => 1 } );
    for my $blog ( @blogs ) {
        my $blog_id = $blog->id;
        my $scope = 'blog:' . $blog_id;
        my @last_follower_ids;
        if ( my $last_follower_ids = $plugin->get_config_value( 'last_follower_ids', $scope ) ) {
            @last_follower_ids = split( /,/, $last_follower_ids );
        }
        if ( my $follower_ids = _get_follower_ids( $blog_id ) ) {
            push( my @follower_ids, ( ref $follower_ids eq 'ARRAY' ? @$follower_ids : $follower_ids ) );
            my ( @removed_ids, @suspended_ids );
            for my $last_follower_id ( @last_follower_ids ) {
                unless ( grep { $_ eq $last_follower_id } @follower_ids ) {
                    if ( my $screen_name = _get_screen_name( $blog_id, $last_follower_id ) ) {
                        push( @removed_ids, $screen_name );
                    } else {
                        push( @suspended_ids, $last_follower_id );
                    }
                }
            }
            my $result_log = $plugin->get_config_value( 'result_log', $scope );
            if ( @removed_ids || @suspended_ids ) {
                if ( $result_log ) {
                    if ( @removed_ids ) {
                        my $message = $plugin->translate( 'Removed by [_1]', join( ', ', @removed_ids ) );
                        _save_success_log( $message, $blog_id );
                    } else {
                        my $message = $plugin->translate( '[_1] was(were) suspended', join( ', ', @suspended_ids ) );
                        _save_success_log( $message, $blog_id );
                    }
                }
                my %params = (
                    removed_ids => \@removed_ids,
                    suspended_ids => \@suspended_ids,
                );
                if ( $plugin->get_config_value( 'notification_by_mail', $scope ) ) {
                    if ( my $mail_to = $plugin->get_config_value( 'mail_to', $scope ) ) {
                        my $mail_subject = $plugin->get_config_value( 'mail_subject', $scope );
                        my $mail_body = $plugin->get_config_value( 'mail_body', $scope );
                        my $mail_from = $plugin->get_config_value( 'mail_from', $scope );
                        unless ( $mail_from ) {
                            $mail_from = MT->config->EmailAddressMain;
                        }
                        $mail_subject = _build_tmpl( $mail_subject, $blog_id, \%params );
                        $mail_body = _build_tmpl( $mail_body, $blog_id, \%params );
                        my @mail_to = split( /\n/, $mail_to );
                        my $to = join( ',', @mail_to );
                        my %head = (   
                            To => $to,
                            From => $mail_from,
                            Subject => $mail_subject,
                        );
                        MT::Mail->send( \%head, $mail_body );
                    }
                }
                if ( $plugin->get_config_value( 'notification_by_direct_message', $scope ) ) {
                    if ( my $message_body = $plugin->get_config_value( 'message_body', $scope ) ) {
                        $message_body = _build_tmpl( $message_body, $blog_id, \%params );
                        _send_direct_message_to_me( $message_body, $blog_id );
                    }
                }
            } else {
                if ( $result_log ) {
                    my $message = $plugin->translate( 'No remover. Follower: [_1]', scalar @follower_ids );
                    _save_success_log( $message, $blog_id );
                }
            }
            $plugin->set_config_value( 'last_modified', time, $scope );
            $plugin->set_config_value( 'last_follower_ids', join( ',', @follower_ids ), $scope );
        }
    }
}

sub _build_tmpl {
    my ( $text, $blog_id, $param ) = @_;
    return unless $text;
    return unless $blog_id;
    my $blog = MT->model( 'blog' )->load( { id => $blog_id } );
    return unless $blog;
    require MT::Template;
    require MT::Template::Context;
    my $tmpl = MT::Template->new;
    $tmpl->name( 'Remtter' );
    $tmpl->text( $text );
    $tmpl->blog_id( $blog_id );
    my $ctx = MT::Template::Context->new;
    $ctx->stash( 'blog', $blog );
    $ctx->stash( 'blog_id', $blog_id );
    my @tl = &offset_time_list( time, undef );
    my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $tl[ 5 ] + 1900, $tl[ 4 ] + 1, @tl[ 3, 2, 1, 0 ];
    $ctx->{ current_timestamp } = $ts;
    for my $key ( keys %$param ) {
        $ctx->{ __stash }->{ vars }->{ $key } = $$param{ $key };
    }
    my $res = $tmpl->build( $ctx )
        or return MT->instance->error( MT->translate( $tmpl->errstr ) );
    return $res;
}

sub _get_screen_name {
    my ( $blog_id, $user_id ) = @_;
    my $request_url = 'http://api.twitter.com/users/show.xml?id=' . $user_id;
    my $request_method = 'GET';
    my $ua = MT->new_ua( { timeout => 10 } );
    my $request = new HTTP::Request( $request_method => $request_url );
    my $response = $ua->request( $request );
    unless ( $response->is_success ) {
        my $log = $plugin->translate( 'Error get screen name of user [_1]: [_2]', $user_id, $response->status_line );
        _save_error_log( $log, $blog_id );
        return 0;
    }
    if ( my $xml = $response->content ) {
        my $data = XMLin( $xml );
        if ( my $screen_name = $data->{ screen_name } ) {
            return $screen_name;
        }
    }
    return 0;
}

sub _get_follower_ids {
    my ( $blog_id ) = @_;
    my $request_url = 'http://api.twitter.com/1/followers/ids.xml';
    my $request_method = 'GET';
    if ( my $response = _oauth_request( $blog_id, $request_url, $request_method ) ) {
        unless ( $response->is_success ) {
            my $log = $plugin->translate( 'Error get followers ids: [_1]', $response->status_line );
            _save_error_log( $log, $blog_id );
            return 0;
        }
        if ( my $xml = $response->content ) {
            my $data = XMLin( $xml );
            if ( my $ids = $data->{ ids }->{ id } ) {
                return $ids;
            }
        }
    }
    return 0;
}

sub _get_account_information {
    my ( $name, $blog_id ) = @_;
    my $request_url = 'http://api.twitter.com/1/account/verify_credentials.xml';
    my $request_method = 'GET';
    if ( my $response = _oauth_request( $blog_id, $request_url, $request_method ) ) {
        unless ( $response->is_success ) {
            my $log = $plugin->translate( 'Error get followers ids: [_1]', $response->status_line );
            _save_error_log( $log, $blog_id );
            return 0;
        }
        if ( my $xml = $response->content ) {
            my $data = XMLin( $xml );
            if ( my $value = $data->{ $name } ) {
                return $value;
            }
        }
    }
    return 0;
}

sub _send_direct_message_to_me {
    my ( $message, $blog_id ) = @_;
    return unless $message;
    my $user_id = _get_account_information( 'id', $blog_id ) or return;
    my $screen_name = _get_account_information( 'screen_name', $blog_id ) or return;
    my $request_url = 'http://api.twitter.com/1/direct_messages/new.xml';
    my $request_method = 'POST';
    my %extra_params = (
        user_id => $user_id,
        screen_name => $screen_name,
        text => $message,
    );
    if ( my $response = _oauth_request( $blog_id, $request_url, $request_method, \%extra_params ) ) {
        unless ( $response->is_success ) {
            my $log = $plugin->translate( 'Error get followers ids: [_1]', $response->status_line );
            _save_error_log( $log, $blog_id );
            return 0;
        }
        _save_success_log( $plugin->translate( 'Send direct message success: [_1]', $message ), $blog_id );
        return 1;
    }
    return 0;
}

sub _oauth_request {
    my ( $blog_id, $request_url, $request_method, $extra_params ) = @_;
	require Net::OAuth::Simple;
	my %tokens  = (
		'access_token' => $plugin->access_token( $blog_id ),
		'access_token_secret' => $plugin->access_token_secret( $blog_id ),
		'consumer_key' => $plugin->consumer_key( $blog_id ) ,
		'consumer_secret' => $plugin->consumer_secret( $blog_id ),
	);
	my $nos = Net::OAuth::Simple->new(
		tokens => \%tokens,
		protocol_version => '1.0a',
		urls => {
			authorization_url => 'https://twitter.com/oauth/authorize',
			request_token_url => 'https://twitter.com/oauth/request_token',
			access_token_url => 'https://twitter.com/oauth/access_token',
		}
	);
	return $plugin->trans_error( "Authorize error" ) unless $nos->authorized;
	my $response;
	eval { $response = $nos->make_restricted_request( $request_url, $request_method, %$extra_params ); };
	if ( $@ ) {
		_save_error_log( $plugin->trans_error( "Failed to get response from [_1], ([_2])", "twitter", $@ ) );
		return 0;
	}
	unless ( $response->is_success ) {
	    return $plugin->trans_error( "Failed to get response from [_1], ([_2])", "twitter", $response->status_line );
	}
	return $response;
}

sub get_setting {
	my ( $plugin, $key, $blog_id ) = @_;
	my $scope = $blog_id  ? 'blog:' . $blog_id : 'system';
	return $plugin->get_config_value( $key, $scope );
}

sub access_token {
	my $plugin = shift;
	return $plugin->get_setting( 'access_token', @_ );
}

sub access_token_secret {
	my $plugin = shift;
	return $plugin->get_setting( 'access_token_secret', @_ );
}

sub consumer_key {
	my $plugin = shift;
	return $CONSUMER_KEY;
}

sub consumer_secret {
	my $plugin = shift;
	return $CONSUMER_SECRET;
}

sub _update_twitter {
	my ( $plugin, $msg, $blog_id ) = @_;
	require Net::OAuth::Simple;
	my %tokens  = (
		'access_token' => $plugin->access_token( $blog_id ),
		'access_token_secret' => $plugin->access_token_secret( $blog_id ),
		'consumer_key' => $plugin->consumer_key( $blog_id ) ,
		'consumer_secret' => $plugin->consumer_secret( $blog_id ),
	);
	my $nos = Net::OAuth::Simple->new(
		tokens => \%tokens,
		protocol_version => '1.0a',
		urls => {
			authorization_url => 'https://twitter.com/oauth/authorize',
			request_token_url => 'https://twitter.com/oauth/request_token',
			access_token_url => 'https://twitter.com/oauth/access_token',
		}
	);
	return $plugin->trans_error( "Authorize error" ) unless $nos->authorized;
	my $url  = "http://api.twitter.com/1/statuses/update.xml";
	my %params = ( 'status' => $msg );
	my $response;
	eval { $response = $nos->make_restricted_request( $url, 'POST', %params ); };
	if ( $@ ) {
		my $err = $@;
		return $plugin->trans_error( "Failed to get response from [_1], ([_2])", "twitter", $err );
	}
	unless ( $response->is_success ) {
	    return $plugin->trans_error( "Failed to get response from [_1], ([_2])", "twitter", $response->status_line );
	}
	return $msg;
1;
}

sub _mode_remtter_oauth {
	my $app = shift;
	my $q = $app->{ query };
	my $blog_id = $q->param( 'blog_id' );
	
	my $tmpl = $plugin->load_tmpl( 'oauth_start.tmpl' );
	
	require Net::OAuth::Simple;
	my %tokens = (
		'consumer_key' => $plugin->consumer_key( $blog_id ),
		'consumer_secret' => $plugin->consumer_secret( $blog_id ),
	);
	my $nos = Net::OAuth::Simple->new(
		tokens => \%tokens,
		protocol_version => '1.0',
		urls => {
			authorization_url => 'https://twitter.com/oauth/authorize',
			request_token_url => 'https://twitter.com/oauth/request_token',
			access_token_url  => 'https://twitter.com/oauth/access_token',
		}
	);

	my $url;
	eval { $url = $nos->get_authorization_url(); };
	if ( $@ ) {
		my $err = $@;
		$tmpl->param( 'error_authorization' => 1 );
	} else {
		my $request_token = $nos->request_token;
		my $request_token_secret = $nos->request_token_secret;
		$tmpl->param( 'access_url' => $url );
		$tmpl->param( 'request_token' => $request_token );
		$tmpl->param( 'request_token_secret' => $request_token_secret );
	}
	return $tmpl; 
}

sub _mode_remtter_get_access_token {
	my $app = shift;
	my $q = $app->{ query };
	my $blog_id = $q->param( 'blog_id' );

	my $new_pin = $q->param( 'remtter_pin' ) || q{};
	my $tmpl = $plugin->load_tmpl( 'oauth_finished.tmpl' );

	my %tokens  = (
		'consumer_key' => $plugin->consumer_key( $blog_id ) ,
		'consumer_secret' => $plugin->consumer_secret( $blog_id ),
		'request_token' => $q->param( 'request_token' ),
		'request_token_secret' => $q->param( 'request_token_secret' ),
	);
	require Net::OAuth::Simple;
	my $nos = Net::OAuth::Simple->new(
		tokens => \%tokens,
		protocol_version => '1.0a',
		urls => {
			authorization_url => 'https://twitter.com/oauth/authorize',
			request_token_url => 'https://twitter.com/oauth/request_token',
			access_token_url  => 'https://twitter.com/oauth/access_token',
		}
	);
	$nos->verifier( $new_pin );
	my ( $access_token, $access_token_secret, $user_id, $screen_name );
	eval { ( $access_token, $access_token_secret, $user_id, $screen_name ) =  $nos->request_access_token(); };
	if ( $@ ) {
		my $err = $@;
		$tmpl->param( 'error_verification' => 1 );
	} else {
		$tmpl->param( 'verified_screen_name' => $screen_name );
		$tmpl->param( 'verified_user_id' => $user_id );
		my $scope = 'blog:' . $blog_id;
		$plugin->set_config_value( 'access_token', $access_token, $scope );
		$plugin->set_config_value( 'access_token_secret', $access_token_secret, $scope );
	}
	$tmpl;
}

sub _save_success_log {
    my ( $message, $blog_id ) = @_;
    _save_log( $message, $blog_id, MT::Log::INFO() );
}

sub _save_error_log {
    my ( $message, $blog_id ) = @_;
    _save_log( $message, $blog_id, MT::Log::ERROR() );
}

sub _save_log {
    my ( $message, $blog_id, $log_level ) = @_;
    if ( $message ) {
        my $log = MT::Log->new;
        $log->message( $message );
        $log->class( lc $PLUGIN_NAME );
        $log->blog_id( $blog_id );
        $log->level( $log_level );
        $log->save or die $log->errstr;
    }
}

sub _debug {
    my ( $data ) = @_;
    use Data::Dumper;
    MT->log( Dumper( $data ) );
}

sub _default_mail_subject {
    return '[Remtter] remove notification';
}

sub _default_mail_body {
    return <<'MTML';
<mt:if name="removed_ids">
Removed following ids...

<mt:loop name="removed_ids">
http://twitter.com/<mt:var name="__value__">
</mt:loop>

</mt:if>
<mt:if name="suspended_ids">
Following user ID was suspended...

<mt:loop name="suspended_ids" glue=", "><mt:var name="__value__"></mt:loop>

</mt:if>
-- 
Remtter - Movable Type Plugin
MTML
}

sub _default_mail_to {
    return <<'MTML';
sample@example.com
sample2@example.com
MTML
}

sub _default_mail_from {
    return 'sample@example.com';
}

sub _default_message_body {
    return <<'MTML';
[Remtter]
<mt:if name="removed_ids">
following is remove from your friends.

Removed by <mt:loop name="removed_ids" glue=", ">@<mt:var name="__value__"></mt:loop>
</mt:if>
<mt:if name="suspended_ids">
Following user ID was suspended...

<mt:loop name="suspended_ids" glue=", "><mt:var name="__value__"></mt:loop>
</mt:if>
MTML
}

1;
