package Remtter::Tasks;
use strict;

use Remtter::Util;

sub remtter {
    my $plugin = MT->component( 'Remtter' );
    my @blogs = MT->model( 'blog' )->load( undef, { no_class => 1 } );
    for my $blog ( @blogs ) {
        my $blog_id = $blog->id;
        my $scope = 'blog:' . $blog_id;
        next unless $plugin->get_config_value( 'access_token', $scope );
        my @last_follower_ids;
        if ( my $last_follower_ids = $plugin->get_config_value( 'last_follower_ids', $scope ) ) {
            @last_follower_ids = split( /,/, $last_follower_ids );
        }
        if ( my $follower_ids = Remtter::Util::get_follower_ids( $blog_id ) ) {
            push( my @follower_ids, ( ref( $follower_ids ) eq 'ARRAY' ? @$follower_ids : $follower_ids ) );
            my ( @removed_ids, @suspended_ids );
            for my $last_follower_id ( @last_follower_ids ) {
                unless ( grep { $_ eq $last_follower_id } @follower_ids ) {
                    if ( my $screen_name = Remtter::Util::get_screen_name( $blog_id, $last_follower_id ) ) {
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
                        Remtter::Util::success_log( $message, $blog_id );
                    } else {
                        my $message = $plugin->translate( '[_1] was(were) suspended', join( ', ', @suspended_ids ) );
                        Remtter::Util::success_log( $message, $blog_id );
                    }
                }
                my %params = (
                    removed_ids => \@removed_ids,
                    suspended_ids => \@suspended_ids,
                    followers_count => scalar @follower_ids,
                );
                if ( $plugin->get_config_value( 'notification_by_mail', $scope ) ) {
                    if ( my $mail_to = $plugin->get_config_value( 'mail_to', $scope ) ) {
                        my $mail_subject = $plugin->get_config_value( 'mail_subject', $scope );
                        my $mail_body = $plugin->get_config_value( 'mail_body', $scope );
                        my $mail_from = $plugin->get_config_value( 'mail_from', $scope );
                        unless ( $mail_from ) {
                            $mail_from = MT->config->EmailAddressMain;
                        }
                        $mail_subject = Remtter::Util::build_tmpl( $mail_subject, $blog_id, \%params );
                        $mail_body = Remtter::Util::build_tmpl( $mail_body, $blog_id, \%params );
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
                        $message_body = Remtter::Util::build_tmpl( $message_body, $blog_id, \%params );
                        Remtter::Util::send_direct_message_to_me( $message_body, $blog_id );
                    }
                }
            } else {
                if ( $result_log ) {
                    my $message = $plugin->translate( 'No remover. Follower: [_1]', scalar @follower_ids );
                    Remtter::Util::success_log( $message, $blog_id );
                }
            }
            $plugin->set_config_value( 'last_updated', time, $scope );
            $plugin->set_config_value( 'last_follower_ids', join( ',', @follower_ids ), $scope );
        }
    }
}

1;
