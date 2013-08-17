package Remtter::Callbacks;
use strict;

use Remtter::Plugin;

sub _cb_ts_remtter_config_blog {
    my ( $cb, $app, $tmpl ) = @_;
    return unless $app->blog;
    my $plugin = MT->component( 'Remtter' );
    my $last_follower_ids = $plugin->get_config_value( 'last_follower_ids', 'blog:' . $app->blog->id );
    my @last_follower_ids = split( ',', $last_follower_ids );
    my $follower_num = scalar @last_follower_ids;
    $$tmpl =~ s/\*follower_num\*/$follower_num/;
    my $default_mail_subject = Remtter::Plugin::default_mail_subject;
    my $default_mail_body = Remtter::Plugin::default_mail_body;
    my $default_mail_to = Remtter::Plugin::default_mail_to;
    my $default_mail_from = Remtter::Plugin::default_mail_from;
    my $default_message_body = Remtter::Plugin::default_message_body;
    $$tmpl =~ s/\*default_mail_subject\*/$default_mail_subject/;
    $$tmpl =~ s/\*default_mail_body\*/$default_mail_body/;
    $$tmpl =~ s/\*default_mail_to\*/$default_mail_to/;
    $$tmpl =~ s/\*default_mail_from\*/$default_mail_from/;
    $$tmpl =~ s/\*default_message_body\*/$default_message_body/;
}

1;
