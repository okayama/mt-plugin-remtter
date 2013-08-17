package Remtter::Plugin;
use strict;

sub default_mail_subject {
    return '[Remtter] remove notification';
}

sub default_mail_body {
    return <<'MTML';
<mt:if name="removed_ids">
Removed following ids...

<mt:loop name="removed_ids">
http://twitter.com/<mt:var name="__value__"></mt:loop>

</mt:if>
<mt:if name="suspended_ids">
Following user ID was suspended...

<mt:loop name="suspended_ids" glue=", "><mt:var name="__value__"></mt:loop>

</mt:if>
Followers: <mt:var name="followers_count">

-- 
Remtter - Movable Type Plugin
MTML
}

sub default_mail_to {
    return <<'MTML';
sample@example.com
sample2@example.com
MTML
}

sub default_mail_from {
    return 'sample@example.com';
}

sub default_message_body {
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
Followers: <mt:var name="followers_count">
MTML
}

1;
