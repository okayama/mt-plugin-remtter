package Remtter::Util;
use strict;

use Digest::SHA1 qw( sha1_base64 );
use Net::OAuth;
use JSON;
use MT::Util qw( offset_time_list );
use MT::Mail;

sub get_screen_name {
    my ( $blog_id, $user_id ) = @_;
    my $plugin = MT->component( 'Remtter' );
    my $request_url = 'https://api.twitter.com/1.1/users/show.json?id=' . $user_id;
    my $request_method = 'GET';
    if ( my $response = oauth_request( $blog_id, $request_url, $request_method ) ) {
        unless ( $response->is_success ) {
            my $log = $plugin->translate( 'Error get screen name of user [_1]: [_2]', $user_id, $response->status_line );
            error_log( $log, $blog_id );
            return 0;
        }
        if ( my $json = $response->content ) {
            my $data = decode_json( $json );
            if ( my $screen_name = $data->{ screen_name } ) {
                return $screen_name;
            }
        }
    }
    return 0;
}

sub get_follower_ids {
    my ( $blog_id ) = @_;
    my $plugin = MT->component( 'Remtter' );
    my $request_url = 'https://api.twitter.com/1.1/followers/ids.json';
    my $request_method = 'GET';
    if ( my $response = oauth_request( $blog_id, $request_url, $request_method ) ) {
        unless ( $response->is_success ) {
            my $log = $plugin->translate( 'Error get followers ids: [_1]', $response->status_line );
            error_log( $log, $blog_id );
            return 0;
        }
        if ( my $json = $response->content ) {
            my $data = decode_json( $json );
            if ( my $ids = $data->{ ids } ) {
                return $ids;
            }
        }
    }
    return 0;
}

sub get_account_information {
    my ( $name, $blog_id ) = @_;
    my $plugin = MT->component( 'Remtter' );
    my $request_url = 'https://api.twitter.com/1.1/account/verify_credentials.json';
    my $request_method = 'GET';
    if ( my $response = oauth_request( $blog_id, $request_url, $request_method ) ) {
        unless ( $response->is_success ) {
            my $log = $plugin->translate( 'Error get followers ids: [_1]', $response->status_line );
            error_log( $log, $blog_id );
            return 0;
        }
        if ( my $json = $response->content ) {
            my $data = decode_json( $json );
            if ( ref( $name ) eq 'ARRAY' ) {
                return map { $data->{ $_ } } @$name;
            } else {
                return $data->{ $name };
            }
        }
    }
    return 0;
}

sub send_direct_message_to_me {
    my ( $message, $blog_id ) = @_;
    return unless $message;
    my $plugin = MT->component( 'Remtter' );
    my ( $user_id, $screen_name ) = get_account_information( [ 'id', 'screen_name' ], $blog_id ) or return;
    my $request_url = 'https://api.twitter.com/1.1/direct_messages/new.json';
    my $request_method = 'POST';
    my %extra_params = (
        user_id => $user_id,
        screen_name => $screen_name,
        text => $message,
    );
    if ( my $response = oauth_request( $blog_id, $request_url, $request_method, \%extra_params ) ) {
        unless ( $response->is_success ) {
            my $log = $plugin->translate( 'Error get followers ids: [_1]', $response->status_line );
            error_log( $log, $blog_id );
            return 0;
        }
        success_log( $plugin->translate( 'Send direct message success: [_1]', $message ), $blog_id );
        return 1;
    }
    return 0;
}

sub oauth_request {
    my ( $blog_id, $url, $request_method, $extra_params ) = @_;
    my $plugin = MT->component( 'Remtter' );
    my $request  = Net::OAuth->request( "protected resource" )->new(
        consumer_key => $plugin->get_config_value( 'consumer_key' ),
        consumer_secret => $plugin->get_config_value( 'consumer_secret' ),
        request_url => $url,
        request_method => $request_method,
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => sha1_base64( time() . $$ . rand() ),
        token => $plugin->get_config_value( 'access_token', 'blog:' . $blog_id ),
        token_secret => $plugin->get_config_value( 'access_token_secret', 'blog:' . $blog_id ),
        extra_params => $extra_params,
    );
    $request->sign;
    $request->verify;

    my $ua = MT->new_ua;
    my ( $http_header, $http_request );
    if ( lc( $request_method ) eq 'get' ) {
        $http_header = HTTP::Headers->new( 'User-Agent' => $plugin->name,
                                           'Authorization' => $request->to_authorization_header,
                                         );
        $http_request = HTTP::Request->new( $request_method, $url, $http_header );
    } else {
        $http_header = HTTP::Headers->new( 'User-Agent' => $plugin->name, );
        $http_request = HTTP::Request->new( $request_method, $url, $http_header, $request->to_post_body, );
    }
    $http_request->content_type( 'application/x-www-form-urlencoded' ); # Required in API version 1.1
    my $response = $ua->request( $http_request );

	unless ( $response->is_success ) {
	    return $plugin->trans_error( "Failed to get response from [_1], ([_2])", "twitter", $response->status_line );
	}
	return $response;
}

sub build_tmpl {
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
    my @tl = offset_time_list( time, undef );
    my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $tl[ 5 ] + 1900, $tl[ 4 ] + 1, @tl[ 3, 2, 1, 0 ];
    $ctx->{ current_timestamp } = $ts;
    for my $key ( keys %$param ) {
        $ctx->{ __stash }->{ vars }->{ $key } = $$param{ $key };
    }
    my $res = $tmpl->build( $ctx )
        or return MT->instance->error( MT->translate( $tmpl->errstr ) );
    return $res;
}

sub update_twitter {
	my ( $msg, $blog_id ) = @_;
	my $plugin = MT->component( 'Remtter' );
    $msg = MT::I18N::decode_utf8( $msg );

	my $url  = 'https://api.twitter.com/1.1/statuses/update.json';
    my $request_method = 'POST';

    my $request  = Net::OAuth->request( "protected resource" )->new(
        consumer_key => $plugin->get_config_value( 'consumer_key' ),
        consumer_secret => $plugin->get_config_value( 'consumer_secret' ),
        request_url => $url,
        request_method => $request_method,
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => sha1_base64( time() . $$ . rand() ),
        token => $plugin->get_config_value( 'access_token', 'blog:' . $blog_id ),
        token_secret => $plugin->get_config_value( 'access_token_secret', 'blog:' . $blog_id ),
        extra_params => {
            status => $msg,
        },
    );
    $request->sign;
    $request->verify;

    my $ua = MT->new_ua;
    my $http_header = HTTP::Headers->new( 'User-Agent' => $plugin->name );
    my $http_request = HTTP::Request->new( $request_method, $url, $http_header, $request->to_post_body );
    $http_request->content_type( 'application/x-www-form-urlencoded' ); # Required in API version 1.1
    my $response = $ua->request( $http_request );

	unless ( $response->is_success ) {
	    return $plugin->trans_error( "Failed to get response from [_1], ([_2])", "twitter", $response->status_line );
	}
	return $msg;
}

sub success_log {
    my ( $message, $blog_id ) = @_;
    return save_log( $message, $blog_id, MT::Log::INFO() );
}

sub error_log {
    my ( $message, $blog_id ) = @_;
    return save_log( $message, $blog_id, MT::Log::ERROR() );
}

sub save_log {
    my ( $message, $blog_id, $log_level ) = @_;
    if ( $message ) {
        my $plugin = MT->component( 'Remtter' );
        my $log = MT::Log->new;
        $log->message( $message );
        $log->class( lc( $plugin->id ) );
        $log->blog_id( $blog_id );
        $log->level( $log_level );
        $log->save or die $log->errstr;
        return $log;
    }
}

1;
