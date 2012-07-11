#!/usr/bin/perl
use strict;
use warnings;

use RT::Test::SMIME tests => 10;

use RT::Tickets;

RT::Test->import_smime_key('sender@example.com');
my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'sender@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

{
    my ($status, $msg) = $queue->SetEncrypt(1);
    ok $status, "turn on encyption by default"
        or diag "error: $msg";
}

{
    my $cf = RT::CustomField->new( $RT::SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name       => 'SMIME Key',
        LookupType => RT::User->new( $RT::SystemUser )->CustomFieldLookupType,
        Type       => 'TextSingle',
    );
    ok($ret, "Custom Field created");

    my $OCF = RT::ObjectCustomField->new( $RT::SystemUser );
    $OCF->Create(
        CustomField => $cf->id,
        ObjectId    => 0,
    );
}

my $root;
{
    $root = RT::User->new($RT::SystemUser);
    ok($root->LoadByEmail('root@localhost'), "Loaded user 'root'");
    ok($root->Load('root'), "Loaded user 'root'");
    is($root->EmailAddress, 'root@localhost');

    RT::Test->import_smime_key( 'root@example.com.crt' => $root );
}

my $bad_user;
{
    $bad_user = RT::Test->load_or_create_user(
        Name => 'bad_user',
        EmailAddress => 'baduser@example.com',
    );
    ok $bad_user && $bad_user->id, 'created a user without key';
}

RT::Test->clean_caught_mails;

{
    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($status, undef, $msg) = $ticket->Create( Queue => $queue->id, Requestor => [$root->id, $bad_user->id] );
    ok $status, "created a ticket" or "error: $msg";

    my @mails = RT::Test->fetch_caught_mails;
    is scalar @mails, 3, "autoreply, to bad user, to RT owner";
}
