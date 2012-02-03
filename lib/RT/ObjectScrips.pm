use strict;
use warnings;

package RT::ObjectScrips;
use base 'RT::SearchBuilder::ApplyAndSort';

use RT::Scrips;
use RT::ObjectScrip;

sub _Init {
    my $self = shift;
    $self->{'with_disabled_column'} = 1;
    return $self->SUPER::_Init( @_ );
}

sub Table { 'ObjectScrips'}

sub LimitToScrip {
    my $self = shift;
    my $id = shift;
    $self->Limit( FIELD => 'Scrip', VALUE => $id );
}

RT::Base->_ImportOverlays();

1;
