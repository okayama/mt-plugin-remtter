package MT::Plugin::Remtter;
use strict;
use MT;
use MT::Plugin;
use base qw( MT::Plugin );

use Encode;
use HTTP::Request::Common;
use LWP::UserAgent;
use Digest::SHA1;
use Net::OAuth;
use XML::Simple;
$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A; 

use MT::AtomServer;
use MT::Util qw( offset_time_list );

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
    blog_config_template => 'remtter_config_blog.tmpl',
    settings => new MT::PluginSettings( [
        [ 'consumer_key' ],
        [ 'consumer_secret' ],
        [ 'callback_url' ],
        [ 'access_token' ],
        [ 'access_secret' ],
        [ 'last_follower_ids' ],
        [ 'last_modified' ],
        [ 'mail_subject' ],
        [ 'mail_body' ],
        [ 'mail_to' ],
        [ 'mail_from' ],
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
                    remtter_oauth_callback => \&_mode_remtter_oauth_callback,
                    remtter_oauth_request => \&_mode_remtter_oauth_request,
                },
            },
        },
        callbacks => {
            'MT::App::CMS::template_source.remtter_config_blog' => \&_cb_tp_remtter_config,
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

sub remtter {
    my @blogs = MT->model( 'blog' )->load( { class => '*' } );
    for my $blog ( @blogs ) {
        my $blog_id = $blog->id;
        my $scope = 'blog:' . $blog_id;
        my @last_follower_ids;
        if ( my $last_follower_ids = $plugin->get_config_value( 'last_follower_ids', $scope ) ) {
            @last_follower_ids = split( /,/, $last_follower_ids );
        }
        if ( my $follower_ids = _get_follower_ids( $blog_id ) ) {
            push( my @follower_ids, ( ref $follower_ids eq 'ARRAY' ? @$follower_ids : $follower_ids ) );
            my @removed_ids;
            for my $last_follower_id ( @last_follower_ids ) {
                unless ( grep { $_ eq $last_follower_id } @follower_ids ) {
                    my $screen_name = _get_screen_name( $blog_id, $last_follower_id );
                    push( @removed_ids, $screen_name );
                }
            }
            if ( @removed_ids ) {          
                my $message = $plugin->translate( 'Removed by [_1]', join( ', ', @removed_ids ) );
                _save_success_log( $message, $blog_id );  
                if ( my $mail_to = $plugin->get_config_value( 'mail_to', $scope ) ) {
                    my $mail_subject = $plugin->get_config_value( 'mail_subject', $scope );
                    my $mail_body = $plugin->get_config_value( 'mail_body', $scope );
                    my $mail_from = $plugin->get_config_value( 'mail_from', $scope );
                    unless ( $mail_from ) {
                        $mail_from = MT->config->EmailAddressMain;
                    }
                    my %params = (
                        removed_ids => \@removed_ids,
                    );
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
            } else {
                my $message = $plugin->translate( 'No remover. Follower: [_1]', scalar @follower_ids );
                _save_success_log( $message, $blog_id );
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
    if ( my $response = _oauth_request( $blog_id, $request_url, $request_method ) ) {
        unless ( $response->is_success ) {
            my $log = $plugin->translate( 'Error get followers ids: [_1]', $response->status_line );
            _save_error_log( $log, $blog_id );
            return 0;
        }
        if ( my $xml = $response->content ) {
            my $data = XMLin( $xml );
            if ( my $screen_name = $data->{ screen_name } ) {
                return $screen_name;
            }
        }
    }
    return 0;
}

sub _get_follower_ids {
    my ( $blog_id ) = @_;
    my $request_url = 'http://api.twitter.com/followers/ids.xml';
    my $request_method = 'GET';
    if ( my $response = _oauth_request( $blog_id, $request_url, $request_method ) ) {
        unless ( $response->is_success ) {
            my $log = $plugin->translate( 'Error get followers ids: [_1]', $response->status_line );
            _save_error_log( $log, $blog_id );
            return 0;
        }
        if ( my $xml = $response->content ) {
            my $data = XMLin( $xml );
            if ( my $ids = $data->{ id } ) {
                return $ids;
            }
        }
    }
    return 0;
}

sub _oauth_request {
    my ( $blog_id, $request_url, $request_method, $extra_params ) = @_;
    if ( $blog_id && $request_url && $request_method ) {
        my $oauth_params = _get_oauth_params( $blog_id );
        my $consumer_key = $oauth_params->{ 'consumer_key' } or return 0;
        my $consumer_secret = $oauth_params->{ 'consumer_secret' } or return 0;
        my $access_token = $oauth_params->{ 'access_token' } or return 0;
        my $access_secret = $oauth_params->{ 'access_secret' } or return 0;
        my $request = Net::OAuth->request( 'protected resource' )->new(
           consumer_key => $consumer_key,
           consumer_secret => $consumer_secret,
           request_url => $request_url,
           request_method => $request_method,
           signature_method => 'HMAC-SHA1',
           timestamp => time,
           nonce => Digest::SHA1::sha1_base64( time . $$ . rand ),
           token => $access_token,
           token_secret => $access_secret,
           ( $extra_params ? ( extra_params => $extra_params ) : () ),
        );
        $request->sign;
        my $ua = LWP::UserAgent->new;
        if ( my $response = ( $request_method =~ /^get$/i ? $ua->get( $request->to_url ) : $ua->post( $request->to_url ) ) ) {
            return $response;
        }
    }
    return 0;
}

sub _mode_remtter_oauth_request {
    my $app = shift;
    if ( my $blog_id = $app->param( 'blog_id' ) ) {
        my $scope = 'blog:' . $blog_id;
        my $consumer_key = $plugin->get_config_value( 'consumer_key', $scope );
        my $consumer_secret = $plugin->get_config_value( 'consumer_secret', $scope );
        my $callback_url = $plugin->get_config_value( 'callback_url', $scope );
        
        my $request_token_url = 'http://api.twitter.com/oauth/request_token';
        my $request_method = 'GET';
        my $request = Net::OAuth->request( "request token" )->new(
            consumer_key => $consumer_key,
            consumer_secret => $consumer_secret,
            request_url => $request_token_url,
            request_method => $request_method,
            signature_method => 'HMAC-SHA1',
            timestamp => time,
            nonce => Digest::SHA1::sha1_base64( time . $$ . rand ),
            callback => $callback_url,
        );    
        $request->sign;
    
        my $ua = LWP::UserAgent->new;
        my $http_header = HTTP::Headers->new( 'Authorization' => $request->to_authorization_header );
        my $http_request = HTTP::Request->new( $request_method, $request_token_url, $http_header );
        my $res = $ua->request( $http_request );
        if ( $res->is_success ) {
            my $response = Net::OAuth->response( 'request token' )->from_post_body( $res->content );
            my $request_token = $response->token;
            my $request_token_secret = $response->token_secret;
            my $authorize_url = 'http://api.twitter.com/oauth/authorize?oauth_token=' . $request_token;
            my $cookie = $app->bake_cookie( -name=>'remtter',
                                            -value => { blog_id => $blog_id,
                                                        token => $request_token,
                                                        token_secret => $request_token_secret,
                                                      },
                                            -path => '/',
                                          );
            return $app->redirect( $authorize_url, UseMeta => 1, -cookie => $cookie );
        }
    }
    my %param;
    $param{ 'page_title' } = $plugin->translate( 'OAuth failed!' );
    $param{ 'msg' } = $plugin->translate( 'OAuth failed. Please check your settings' );
    $app->{ plugin_template_path } = File::Spec->catdir( $plugin->path,'tmpl' );
    my $tmpl = 'remtter_authorized.tmpl';
    return $app->build_page( $tmpl, \%param );
}

sub _mode_remtter_oauth_callback {
    my $app = shift;
    my $cookies = $app->cookies();
    my %param;
    if ( my %cookies = $cookies->{ 'remtter' }->value ) {
        my $blog_id = $cookies{ 'blog_id' };
        my $request_token = $cookies{ 'token' };
        my $request_token_secret = $cookies{ 'token_secret' };
        my $oauth_token = $app->param( 'oauth_token' );
        my $verifier = $app->param( 'oauth_verifier' );
        my $scope = 'blog:' . $blog_id;
        my $consumer_key = $plugin->get_config_value( 'consumer_key', $scope );
        my $consumer_secret = $plugin->get_config_value( 'consumer_secret', $scope );
        my $access_token_url = 'http://api.twitter.com/oauth/access_token';
        my $request_method = 'POST';
        my $request = Net::OAuth->request( "access token" )->new(
            consumer_key => $consumer_key,
            consumer_secret => $consumer_secret,
            request_url => $access_token_url,
            request_method => $request_method,
            signature_method => 'HMAC-SHA1',
            timestamp => time,
            nonce => Digest::SHA1::sha1_base64( time . $$ . rand ),
            token => $oauth_token,
            verifier => $verifier,
            token_secret => $request_token_secret,
        );
        my $ua = LWP::UserAgent->new;
        my $http_header = HTTP::Headers->new( 'User-Agent' => $PLUGIN_NAME );
        my $http_request = HTTP::Request->new( $request_method, $access_token_url, $http_header, $request->to_post_body );
        my $res = $ua->request( $http_request );
        if ( $res->is_success ) {
            $param{ 'page_title' } = $plugin->translate( 'Get Access Token Success!' );
#             $param{ 'msg' } = $plugin->translate( 'Get Access Token Success!' );
            my $uri_cfg_plugins = $app->base . $app->uri( mode => 'cfg_plugins', args => { blog_id => $blog_id } );
            $param{ 'msg' } = $plugin->translate( 'Get Access Token Success! <a href="[_1]">The setting is completed a little more.</a>.', $uri_cfg_plugins );
            $param{ 'is_success' } = 1;
            $param{ 'show_table' } = 1;
            my $response = Net::OAuth->response( 'access token' )->from_post_body( $res->content );
            if ( my $access_token = $response->token ) {
                $plugin->set_config_value( 'access_token', $access_token, $scope );
                $param{ 'access_token' } = $access_token;
            }
            if ( my $access_secret = $response->token_secret ) {
                $plugin->set_config_value( 'access_secret', $access_secret, $scope );
                $param{ 'access_secret' } = $access_secret;
            }
        }
    }
    unless ( $param{ 'is_success' } ) {
        $param{ 'page_title' } = $plugin->translate( 'Get Access Token failed!' );
        $param{ 'msg' } = $plugin->translate( 'Get Access Token failed!' );
    }
    $app->{ plugin_template_path } = File::Spec->catdir( $plugin->path,'tmpl' );
    my $tmpl = 'remtter_authorized.tmpl';
    return $app->build_page( $tmpl, \%param );
}

sub _get_oauth_params {
    my ( $blog_id ) = @_;
    my $scope = 'blog:' . $blog_id;
    my %settings = (
        consumer_key => $plugin->get_config_value( 'consumer_key', $scope ),
        consumer_secret => $plugin->get_config_value( 'consumer_secret', $scope ),
        access_token => $plugin->get_config_value( 'access_token', $scope ),
        access_secret => $plugin->get_config_value( 'access_secret', $scope ),
    );
    return \%settings;
}

sub _cb_tp_remtter_config {
    my ( $cb, $app, $tmpl ) = @_;
    my ( $search, $replace, $scope );
    $search = quotemeta( '<[*mt_dir_uri*]>' );
    $replace = $app->base . $app->mt_path;
    $$tmpl =~ s/$search/$replace/g;
    $search = quotemeta( '<[*this_blog_id*]>' );
    my $blog_id = $app->param( 'blog_id' );
    $replace = $blog_id;
    $$tmpl =~ s/$search/$replace/g;
    $scope = 'blog:' . $blog_id;
    my $last_follower_ids = $plugin->get_config_value( 'last_follower_ids', $scope );
    my @last_follower_ids = split( ',', $last_follower_ids );
    $replace = scalar @last_follower_ids;
    $search = quotemeta( '<[*follower_num*]>' );
    $$tmpl =~ s/$search/$replace/g;
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
        $log->class( 'remtter' );
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

1;
