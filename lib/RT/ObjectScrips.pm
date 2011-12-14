use strict;
use warnings;

package RT::ObjectScrips;
use base 'RT::SearchBuilder::ApplyAndSort';

use RT::Scrips;
use RT::ObjectScrip;

sub Table { 'ObjectScrips'}

sub LimitToScrip {
    my $self = shift;
    my $id = shift;
    $self->Limit( FIELD => 'Scrip', VALUE => $id );
}

RT::Base->_ImportOverlays();

1;
