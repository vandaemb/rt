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

  RT::ACL -- Class Description
 
=head1 SYNOPSIS

  use RT::ACL

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::ACL;

use RT::SearchBuilder;
use RT::ACE;

use vars qw( @ISA );
@ISA= qw(RT::SearchBuilder);


sub _Init {
    my $self = shift;
    $self->{'table'} = 'ACL';
    $self->{'primary_key'} = 'id';


    return ( $self->SUPER::_Init(@_) );
}


=item NewItem

Returns an empty new RT::ACE item

=cut

sub NewItem {
    my $self = shift;
    return(RT::ACE->new($self->CurrentUser));
}

        eval "require RT::ACL_Overlay";
        if ($@ && $@ !~ qr{^Can't locate RT/ACL_Overlay.pm}) {
            die $@;
        };

        eval "require RT::ACL_Local";
        if ($@ && $@ !~ qr{^Can't locate RT/ACL_Local.pm}) {
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

RT::ACL_Overlay, RT::ACL_Local

=cut


1;
