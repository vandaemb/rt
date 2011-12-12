use strict;
use warnings;

package RT::SearchBuilder::ApplyAndSort;
use base 'RT::SearchBuilder';

sub RecordClass {
    my $class = ref($_[0]) || $_[0];
    $class =~ s/s$// or return undef;
    return $class;
}

sub _Init {
    my $self = shift;

    # By default, order by SortOrder
    $self->OrderByCols(
         { ALIAS => 'main',
           FIELD => 'SortOrder',
           ORDER => 'ASC' },
         { ALIAS => 'main',
           FIELD => 'id',
           ORDER => 'ASC' },
    );

    return $self->SUPER::_Init(@_);
}

sub LimitToObjectId {
    my $self = shift;
    my $id = shift || 0;
    $self->Limit( FIELD => 'ObjectId', VALUE => $id );
}

=head2 NewItem

Returns an empty new collection's item

=cut

sub NewItem {
    my $self = shift;
    return $self->RecordClass->new( $self->CurrentUser );
}

RT::Base->_ImportOverlays();

1;
