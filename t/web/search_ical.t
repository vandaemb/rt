#!/usr/bin/perl

use strict;

use Data::ICal;
use RT::Test tests => 40;

my $start_obj = RT::Date->new( RT->SystemUser );
$start_obj->SetToNow;
my $start = $start_obj->iCal( Time => 1);

my $due_obj = RT::Date->new( RT->SystemUser );
$due_obj->SetToNow;
$due_obj->AddDays(2);
my $due = $due_obj->iCal( Time => 1);

diag 'Test iCal with date only';
{
    my ($baseurl, $agent) = RT::Test->started_ok;

    my $ticket = RT::Ticket->new(RT->SystemUser);

    for ( 1 .. 5 ) {
        $ticket->Create(
                        Subject   => 'Ticket ' . $_,
                        Queue     => 'General',
                        Owner     => 'root',
                        Requestor => 'ical@localhost',
                        Starts    => $start_obj->ISO,
                        Due       => $due_obj->ISO,
                       );
    }

    ok $agent->login('root', 'password'), 'logged in as root';

    $agent->get_ok('/Search/Build.html');
    $agent->form_name('BuildQuery');
    $agent->field('idOp', '>');
    $agent->field('ValueOfid', '0');
    $agent->submit('DoSearch');
    $agent->follow_link_ok({id => 'page-results'});

    for ( 1 .. 5 ) {
        $agent->content_contains('Ticket ' . $_);
    }

    $agent->follow_link_ok( { text => 'iCal' } );

    is( $agent->content_type, 'text/calendar', 'content type is text/calendar' );

    for ( 1 .. 5 ) {
        $agent->content_like(qr/URL\:$baseurl\/\?q=$_/);
    }

    my $ical = Data::ICal->new(data => $agent->content);

    my @entries = $ical->entries;
    my $ical_count = @{$entries[0]};
    is( $ical_count, 10, "Got $ical_count ical entries");

    my $prop_ref = $entries[0]->[0]->properties;
    my $start = $start_obj->ISO( Time => 0);
    $start =~ s/-//g;
    is($prop_ref->{'dtstart'}->[0]->value, $start, "Got start date: $start");

    $prop_ref = $entries[0]->[1]->properties;
    my $due = $due_obj->ISO( Time => 0);
    $due =~ s/-//g;
    is($prop_ref->{'dtend'}->[0]->value, $due, "Got due date: $due");
}

RT::Test->stop_server;

diag 'Test iCal with date and time';
{
    RT->Config->Set(TimeInICal =>1);
    my ($baseurl, $agent) = RT::Test->started_ok;

    my $ticket = RT::Ticket->new(RT->SystemUser);

    ok $agent->login('root', 'password'), 'logged in as root';

    $agent->get_ok('/Search/Build.html');
    $agent->form_name('BuildQuery');
    $agent->field('idOp', '>');
    $agent->field('ValueOfid', '0');
    $agent->submit('DoSearch');
    $agent->follow_link_ok({id => 'page-results'});

    for ( 1 .. 5 ) {
        $agent->content_contains('Ticket ' . $_);
    }

    $agent->follow_link_ok( { text => 'iCal' } );

    is( $agent->content_type, 'text/calendar', 'content type is text/calendar' );

    for ( 1 .. 5 ) {
        $agent->content_like(qr/URL\:$baseurl\/\?q=$_/);
    }

    my $ical = Data::ICal->new(data => $agent->content);

    my @entries = $ical->entries;
    my $ical_count = @{$entries[0]};
    is( $ical_count, 10, "Got $ical_count ical entries");

    my $prop_ref = $entries[0]->[0]->properties;
    $start =~ s/-//g;
    is($prop_ref->{'dtstart'}->[0]->value, $start, "Got start date with time: $start");

    $prop_ref = $entries[0]->[1]->properties;
    $due =~ s/-//g;
    is($prop_ref->{'dtend'}->[0]->value, $due, "Got due date with time: $due");
}
