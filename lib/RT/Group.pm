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
# Autogenerated by DBIx::SearchBuilder factory (by <jesse@bestpractical.com>)
# WARNING: THIS FILE IS AUTOGENERATED. ALL CHANGES TO THIS FILE WILL BE LOST.  
# 
# !! DO NOT EDIT THIS FILE !!
#

use strict;


=head1 NAME

RT::Group


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut

package RT::Group;
use RT::Record; 


use vars qw( @ISA );
@ISA= qw( RT::Record );

sub _Init {
  my $self = shift; 

  $self->Table('Groups');
  $self->SUPER::_Init(@_);
}





=item Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varchar(255) 'Description'.
  varchar(64) 'Domain'.
  varchar(64) 'Type'.
  varchar(64) 'Instance'.

=cut




sub Create {
    my $self = shift;
    my %args = ( 
                Name => '',
                Description => '',
                Domain => '',
                Type => '',
                Instance => '',

		  @_);
    $self->SUPER::Create(
                         Name => $args{'Name'},
                         Description => $args{'Description'},
                         Domain => $args{'Domain'},
                         Type => $args{'Type'},
                         Instance => $args{'Instance'},
);

}



=item id

Returns the current value of id. 
(In the database, id is stored as int(11).)


=cut


=item Name

Returns the current value of Name. 
(In the database, Name is stored as varchar(200).)



=item SetName VALUE


Set Name to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(200).)


=cut


=item Description

Returns the current value of Description. 
(In the database, Description is stored as varchar(255).)



=item SetDescription VALUE


Set Description to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=cut


=item Domain

Returns the current value of Domain. 
(In the database, Domain is stored as varchar(64).)



=item SetDomain VALUE


Set Domain to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Domain will be stored as a varchar(64).)


=cut


=item Type

Returns the current value of Type. 
(In the database, Type is stored as varchar(64).)



=item SetType VALUE


Set Type to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Type will be stored as a varchar(64).)


=cut


=item Instance

Returns the current value of Instance. 
(In the database, Instance is stored as varchar(64).)



=item SetInstance VALUE


Set Instance to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Instance will be stored as a varchar(64).)


=cut



sub _ClassAccessible {
    {
     
        id =>
		{read => 1, type => 'int(11)', default => ''},
        Name => 
		{read => 1, write => 1, type => 'varchar(200)', default => ''},
        Description => 
		{read => 1, write => 1, type => 'varchar(255)', default => ''},
        Domain => 
		{read => 1, write => 1, type => 'varchar(64)', default => ''},
        Type => 
		{read => 1, write => 1, type => 'varchar(64)', default => ''},
        Instance => 
		{read => 1, write => 1, type => 'varchar(64)', default => ''},

 }
};


        eval "require RT::Group_Overlay";
        if ($@ && $@ !~ qr{^Can't locate RT/Group_Overlay.pm}) {
            die $@;
        };

        eval "require RT::Group_Local";
        if ($@ && $@ !~ qr{^Can't locate RT/Group_Local.pm}) {
            die $@;
        };




=head1 SEE ALSO

This class allows "overlay" methods to be placed
into the following files _Overlay is for a System overlay by the original author,
while _Local is for site-local customizations.  

These overlay files can contain new subs or subs to replace existing subs in this module.

If you'll be working with perl 5.6.0 or greater, each of these files should begin with the line 

   no warnings qw(redefine);

so that perl does not kick and scream when you redefine a subroutine or variable in your overlay.

RT::Group_Overlay, RT::Group_Local

=cut


1;
