# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
package RT::EmailParser;


use base qw/RT::Base/;

use strict;
use Mail::Address;
use MIME::Entity;
use MIME::Head;

=head1 NAME

  RT::Interface::CLI - helper functions for creating a commandline RT interface

=head1 SYNOPSIS


=head1 DESCRIPTION


=begin testing

ok(require RT::EmailParser);

=end testing


=head1 METHODS

=head2 new


=cut

sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  return $self;
}



# {{{ sub debug

sub debug {
    my $val = shift;
    my ($debug);
    if ($val) {
        $RT::Logger->debug( $val . "\n" );
        if ($debug) {
            print STDERR "$val\n";
        }
    }
    if ($debug) {
        return (1);
    }
}

# }}}

# {{{ sub CheckForLoops 

sub CheckForLoops {
    my $self = shift;

    my $head = $self->Head;

    #If this instance of RT sent it our, we don't want to take it in
    my $RTLoop = $head->get("X-RT-Loop-Prevention") || "";
    chomp($RTLoop);    #remove that newline
    if ( $RTLoop =~ /^$RT::rtname/ ) {
        return (1);
    }

    # TODO: We might not trap the case where RT instance A sends a mail
    # to RT instance B which sends a mail to ...
    return (undef);
}

# }}}

# {{{ sub CheckForSuspiciousSender

sub CheckForSuspiciousSender {
    my $self = shift;

    #if it's from a postmaster or mailer daemon, it's likely a bounce.

    #TODO: better algorithms needed here - there is no standards for
    #bounces, so it's very difficult to separate them from anything
    #else.  At the other hand, the Return-To address is only ment to be
    #used as an error channel, we might want to put up a separate
    #Return-To address which is treated differently.

    #TODO: search through the whole email and find the right Ticket ID.

    my ( $From, $junk ) = $self->ParseSenderAddressFromHead();

    if ( ( $From =~ /^mailer-daemon/i ) or ( $From =~ /^postmaster/i ) ) {
        return (1);

    }

    return (undef);

}

# }}}

# {{{ sub CheckForAutoGenerated
sub CheckForAutoGenerated {
    my $self = shift;
    my $head = $self->Head;

    my $Precedence = $head->get("Precedence") || "";
    if ( $Precedence =~ /^(bulk|junk)/i ) {
        return (1);
    }
    else {
        return (undef);
    }
}

# }}}

# {{{ sub ParseMIMEEntityFromSTDIN

sub ParseMIMEEntityFromSTDIN {
    my $self = shift;
    return $self->ParseMIMEEntityFromFileHandle(\*STDIN);
}

# }}}


sub ParseMIMEEntityFromScalar {
    my $self = shift;
    my $message = shift;

    # Create a new parser object:

    my $parser = MIME::Parser->new();
    $self->_SetupMIMEParser($parser);


    # TODO: XXX 3.0 we really need to wrap this in an eval { }

    unless ( $self->{'entity'} = $parser->parse_data($message) ) {
        # Try again, this time without extracting nested messages
        $parser->extract_nested_messages(0);
        unless ( $self->{'entity'} = $parser->parse_data($message) ) {
            $RT::Logger->crit("couldn't parse MIME stream");
            return ( undef);
        }
    }
    $self->_PostProcessNewEntity();
    return (1);
}

# {{{ ParseMIMEEntityFromFilehandle *FH

=head2 ParseMIMEEntityFromFilehandle *FH

Parses a mime entity from a filehandle passed in as an argument

=cut

sub ParseMIMEEntityFromFileHandle {
    my $self = shift;
    my $filehandle = shift;

    # Create a new parser object:

    my $parser = MIME::Parser->new();
    $self->_SetupMIMEParser($parser);


    # TODO: XXX 3.0 we really need to wrap this in an eval { }

    unless ( $self->{'entity'} = $parser->parse($filehandle) ) {

        # Try again, this time without extracting nested messages
        $parser->extract_nested_messages(0);
        unless ( $self->{'entity'} = $parser->parse($filehandle) ) {
            $RT::Logger->crit("couldn't parse MIME stream");
            return ( undef);
        }
    }
    $self->_PostProcessNewEntity();
    return (1);
}

# }}}

# {{{ _PostProcessNewEntity 

=head2 _PostProcessNewEntity

cleans up and postprocesses a newly parsed MIME Entity

=cut

sub _PostProcessNewEntity {
    my $self = shift;

    #Now we've got a parsed mime object. 

    # try to convert text parts into utf-8 charset
    RT::I18N::SetMIMEEntityToEncoding($self->{'entity'}, 'utf-8');
    # ... and subject too
    {
	my $head = $self->Head;
	$head->replace('Subject',
		       RT::I18N::DecodeMIMEWordsToUTF8( $head->get('Subject') ) );
    }


    # Unfold headers that are have embedded newlines
    $self->Head->unfold;


}

# }}}

# {{{ sub ParseTicketId 

sub ParseTicketId {
    my $self = shift;

    my $Subject = shift;

    if ( $Subject =~ s/\[$RT::rtname \#(\d+)\s*\]//i ) {
        my $id = $1;
        $RT::Logger->debug("Found a ticket ID. It's $id");
        return ($id);
    }
    else {
        return (undef);
    }
}

# }}}

# {{{ sub MailError 

=head2 MailError { }


# TODO this doesn't belong here.
# TODO doc this


=cut


sub MailError {
    my $self = shift;

    my %args = (
        To          => $RT::OwnerEmail,
        Bcc         => undef,
        From        => $RT::CorrespondAddress,
        Subject     => 'There has been an error',
        Explanation => 'Unexplained error',
        MIMEObj     => undef,
        LogLevel    => 'crit',
        @_
    );

    $RT::Logger->log(
        level   => $args{'LogLevel'},
        message => $args{'Explanation'}
    );
    my $entity = MIME::Entity->build(
        Type                   => "multipart/mixed",
        From                   => $args{'From'},
        Bcc                    => $args{'Bcc'},
        To                     => $args{'To'},
        Subject                => $args{'Subject'},
        'X-RT-Loop-Prevention' => $RT::rtname,
    );

    $entity->attach( Data => $args{'Explanation'} . "\n" );

    my $mimeobj = $args{'MIMEObj'};
    $mimeobj->sync_headers();
    $entity->add_part($mimeobj);

    if ( $RT::MailCommand eq 'sendmailpipe' ) {
        open( MAIL, "|$RT::SendmailPath $RT::SendmailArguments" ) || return (0);
        print MAIL $entity->as_string;
        close(MAIL);
    }
    else {
        $entity->send( $RT::MailCommand, $RT::MailParams );
    }
}

# }}}



# {{{ sub GetCurrentUser 

sub GetCurrentUser {
    my $self     = shift;
    my $ErrorsTo = shift;

    my %UserInfo = ();

    #Suck the address of the sender out of the header
    my ( $Address, $Name ) = $self->ParseSenderAddressFromHead();

    my $tempuser = RT::User->new($RT::SystemUser);

    #This will apply local address canonicalization rules
    $Address = $tempuser->CanonicalizeEmailAddress($Address);

    #If desired, synchronize with an external database
    my $UserFoundInExternalDatabase = 0;

    # Username is the 'Name' attribute of the user that RT uses for things
    # like authentication
    my $Username = undef;
    ( $UserFoundInExternalDatabase, %UserInfo ) =
      $self->LookupExternalUserInfo( $Address, $Name );

    $Address  = $UserInfo{'EmailAddress'};
    $Username = $UserInfo{'Name'};

    #Get us a currentuser object to work with. 
    my $CurrentUser = RT::CurrentUser->new();

    # First try looking up by a username, if we got one from the external
    # db lookup. Next, try looking up by email address. Failing that,
    # try looking up by users who have this user's email address as their
    # username.

    if ($Username) {
        $CurrentUser->LoadByName($Username);
    }

    unless ( $CurrentUser->Id ) {
        $CurrentUser->LoadByEmail($Address);
    }

    #If we can't get it by email address, try by name.  
    unless ( $CurrentUser->Id ) {
        $CurrentUser->LoadByName($Address);
    }

    unless ( $CurrentUser->Id ) {

        #If we couldn't load a user, determine whether to create a user

        # {{{ If we require an incoming address to be found in the external
        # user database, reject the incoming message appropriately
        if ( $RT::SenderMustExistInExternalDatabase
             && !$UserFoundInExternalDatabase ) {

            my $Message =
              "Sender's email address was not found in the user database.";

            # {{{  This code useful only if you've defined an AutoRejectRequest template

            require RT::Template;
            my $template = new RT::Template($RT::Nobody);
            $template->Load('AutoRejectRequest');
            $Message = $template->Content || $Message;

            # }}}

            MailError(
                 To      => $ErrorsTo,
                 Subject => "Ticket Creation failed: user could not be created",
                 Explanation => $Message,
                 MIMEObj     => $self->Entity,
                 LogLevel    => 'notice' );

            return ($CurrentUser);

        }

        # }}}

        else {
            my $NewUser = RT::User->new($RT::SystemUser);

            my ( $Val, $Message ) = $NewUser->Create(
                                  Name => ( $Username || $Address ),
                                  EmailAddress => $Address,
                                  RealName     => "$Name",
                                  Password     => undef,
                                  Privileged   => 0,
                                  Comments => 'Autocreated on ticket submission'
            );

            unless ($Val) {

                # Deal with the race condition of two account creations at once
                #
                if ($Username) {
                    $NewUser->LoadByName($Username);
                }

                unless ( $NewUser->Id ) {
                    $NewUser->LoadByEmail($Address);
                }

                unless ( $NewUser->Id ) {
                    MailError(To          => $ErrorsTo,
                              Subject     => "User could not be created",
                              Explanation =>
                                "User creation failed in mailgateway: $Message",
                              MIMEObj  => $self->Entity,
                              LogLevel => 'crit' );
                }
            }
        }

        #Load the new user object
        $CurrentUser->LoadByEmail($Address);

        unless ( $CurrentUser->id ) {
            $RT::Logger->warning(
                               "Couldn't load user '$Address'." . "giving up" );
            MailError(
                   To          => $ErrorsTo,
                   Subject     => "User could not be loaded",
                   Explanation =>
                     "User  '$Address' could not be loaded in the mail gateway",
                   MIMEObj  => $self->Entity,
                   LogLevel => 'crit' );

        }
    }

    return ($CurrentUser);

}

# }}}


# {{{ ParseCcAddressesFromHead 

=head2 ParseCcAddressesFromHead HASHREF

Takes a hashref object containing QueueObj, Head and CurrentUser objects.
Returns a list of all email addresses in the To and Cc 
headers b<except> the current Queue\'s email addresses, the CurrentUser\'s 
email address  and anything that the $RTAddressRegexp matches.

=cut

sub ParseCcAddressesFromHead {

    my $self = shift;

    my %args = (
        QueueObj    => undef,
        CurrentUser => undef,
        @_
    );

    my (@Addresses);

    my @ToObjs = Mail::Address->parse( $self->Head->get('To') );
    my @CcObjs = Mail::Address->parse( $self->Head->get('Cc') );

    foreach my $AddrObj ( @ToObjs, @CcObjs ) {
        my $Address = $AddrObj->address;
        my $user = RT::User->new($RT::SystemUser);
        $Address = $user->CanonicalizeEmailAddress($Address);
        next if ( $args{'CurrentUser'}->EmailAddress   =~ /^$Address$/i );
        next if ( $args{'QueueObj'}->CorrespondAddress =~ /^$Address$/i );
        next if ( $args{'QueueObj'}->CommentAddress    =~ /^$Address$/i );
        next if ( IsRTAddress($Address) );

        push ( @Addresses, $Address );
    }
    return (@Addresses);
}

# }}}

# {{{ ParseSenderAdddressFromHead

=head2 ParseSenderAddressFromHead

Takes a MIME::Header object. Returns a tuple: (user@host, friendly name) 
of the From (evaluated in order of Reply-To:, From:, Sender)

=cut

sub ParseSenderAddressFromHead {
    my $self = shift;

    #Figure out who's sending this message.
    my $From = $self->Head->get('Reply-To')
      || $self->Head->get('From')
      || $self->Head->get('Sender');
    return ( $self->ParseAddressFromHeader($From) );
}

# }}}

# {{{ ParseErrorsToAdddressFromHead

=head2 ParseErrorsToAddressFromHead

Takes a MIME::Header object. Return a single value : user@host
of the From (evaluated in order of Errors-To:,Reply-To:, From:, Sender)

=cut

sub ParseErrorsToAddressFromHead {
    my $self = shift;

    #Figure out who's sending this message.

    foreach my $header ( 'Errors-To', 'Reply-To', 'From', 'Sender' ) {

        # If there's a header of that name
        my $headerobj = $self->Head->get($header);
        if ($headerobj) {
            my ( $addr, $name ) = $self->ParseAddressFromHeader($headerobj);

            # If it's got actual useful content...
            return ($addr) if ($addr);
        }
    }
}

# }}}

# {{{ ParseAddressFromHeader

=head2 ParseAddressFromHeader ADDRESS

Takes an address from $self->Head->get('Line') and returns a tuple: user@host, friendly name

=cut

sub ParseAddressFromHeader {
    my $self = shift;
    my $Addr = shift;

    my @Addresses = Mail::Address->parse($Addr);

    my $AddrObj = $Addresses[0];

    unless ( ref($AddrObj) ) {
        return ( undef, undef );
    }

    my $Name = ( $AddrObj->phrase || $AddrObj->comment || $AddrObj->address );

    #Lets take the from and load a user object.
    my $Address = $AddrObj->address;

    return ( $Address, $Name );
}

# }}}

# {{{ IsRTAddress

=item IsRTaddress ADDRESS

Takes a single parameter, an email address. 
Returns true if that address matches the $RTAddressRegexp.  
Returns false, otherwise.

=cut

sub IsRTAddress {
    my $self = shift;
    my $address = shift;

    # Example: the following rule would tell RT not to Cc 
    #   "tickets@noc.example.com"
    if ( defined($RT::RTAddressRegexp) &&
                       $address =~ /$RT::RTAddressRegexp/ ) {
        return(1);
    } else {
        return (undef);
    }
}

=for testing
is(RT::EmailParser::IsRTAddress("","rt\@example.com"),1, "Regexp matched rt address" );
is(RT::EmailParser::IsRTAddress("","frt\@example.com"),undef, "Regexp didn't match non-rt address" );

=cut

# }}}


# {{{ LookupExternalUserInfo


# LookupExternalUserInfo is a site-definable method for synchronizing
# incoming users with an external data source. 
#
# This routine takes a tuple of EmailAddress and FriendlyName
#   EmailAddress is the user's email address, ususally taken from
#       an email message's From: header.
#   FriendlyName is a freeform string, ususally taken from the "comment" 
#       portion of an email message's From: header.
#
# If you define an AutoRejectRequest template, RT will use this   
# template for the rejection message.


=item LookupExternalUserInfo

 LookupExternalUserInfo is a site-definable method for synchronizing
 incoming users with an external data source. 

 This routine takes a tuple of EmailAddress and FriendlyName
    EmailAddress is the user's email address, ususally taken from
        an email message's From: header.
    FriendlyName is a freeform string, ususally taken from the "comment" 
        portion of an email message's From: header.

 It returns (FoundInExternalDatabase, ParamHash);

   FoundInExternalDatabase must  be set to 1 before return if the user was
   found in the external database.

   ParamHash is a Perl parameter hash which can contain at least the following
   fields. These fields are used to populate RT's users database when the user 
   is created

    EmailAddress is the email address that RT should use for this user.  
    Name is the 'Name' attribute RT should use for this user. 
         'Name' is used for things like access control and user lookups.
    RealName is what RT should display as the user's name when displaying 
         'friendly' names

=cut

sub LookupExternalUserInfo {
  my $self = shift;
  my $EmailAddress = shift;
  my $RealName = shift;

  my $FoundInExternalDatabase = 1;
  my %params;

  #Name is the RT username you want to use for this user.
  $params{'Name'} = $EmailAddress;
  $params{'EmailAddress'} = $EmailAddress;
  $params{'RealName'} = $RealName;

  # See RT's contributed code for examples.
  # http://www.fsck.com/pub/rt/contrib/
  return ($FoundInExternalDatabase, %params);
}

# }}}

# {{{ Accessor methods for parsed email messages

=head2 Head

Return the parsed head from this message

=cut

sub Head {
    my $self = shift;
    return $self->Entity->head;
}

=head2 Entity 

Return the parsed Entity from this message

=cut

sub Entity {
    my $self = shift;
    return $self->{'entity'};
}

# }}}
# {{{ _SetupMIMEParser 

=head2 _SetupMIMEParser $parser

A private instance method which sets up a mime parser to do its job

=cut


    ## TODO: Does it make sense storing to disk at all?  After all, we
    ## need to put each msg as an in-core scalar before saving it to
    ## the database, don't we?

    ## At the same time, we should make sure that we nuke attachments 
    ## Over max size and return them

sub _SetupMIMEParser {
    my $self = shift;
    my $parser = shift;
    my $AttachmentDir = File::Temp::tempdir( TMPDIR => 1, CLEANUP => 1 );

    # Set up output directory for files:
    $parser->output_dir("$AttachmentDir");

    #If someone includes a message, don't extract it
    $parser->extract_nested_messages(1);

    # Set up the prefix for files with auto-generated names:
    $parser->output_prefix("part");

    # If content length is <= 50000 bytes, store each msg as in-core scalar;
    # Else, write to a disk file (the default action):

    $parser->output_to_core(50000);
}
# }}}
eval "require RT::EmailParser_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/EmailParser_Local.pm});

1;
