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

=head2 LimitTargetToNotApplied

Takes either list of object ids or nothing. Limits collection
to custom fields to listed objects or any corespondingly. Use
zero to mean global.

=cut

sub LimitTargetToNotApplied {
    my $self = shift;
    my $collection = shift;
    my @ids = @_;

    my $alias = $self->JoinTargetToApplied($collection => @ids);

    $collection->Limit(
        ENTRYAGGREGATOR => 'AND',
        ALIAS    => $alias,
        FIELD    => 'id',
        OPERATOR => 'IS',
        VALUE    => 'NULL',
    );
}

=head2 LimitTargetToApplied

Limits collection to custom fields to listed objects or any corespondingly. Use
zero to mean global.

=cut

sub LimitTargetToApplied {
    my $self = shift;
    my $collection = shift;
    my @ids = @_;

    my $alias = $self->JoinTargetToApplied($collection => @ids);

    $collection->Limit(
        ENTRYAGGREGATOR => 'AND',
        ALIAS    => $alias,
        FIELD    => 'id',
        OPERATOR => 'IS NOT',
        VALUE    => 'NULL',
    );
}

sub JoinTargetToApplied {
    my $self = shift;
    my $collection = shift;
    my @ids = @_;

    my $alias = $self->JoinTargetToThis( $collection, New => 1, Left => 1 );
    return $alias unless @ids;

    # XXX: we need different EA in join clause, but DBIx::SB
    # doesn't support them, use IN (X) instead
    my $dbh = $self->_Handle->dbh;
    $collection->Limit(
        LEFTJOIN   => $alias,
        ALIAS      => $alias,
        FIELD      => 'ObjectId',
        OPERATOR   => 'IN',
        QUOTEVALUE => 0,
        VALUE      => "(". join( ',', map $dbh->quote($_), @ids ) .")",
    );

    return $alias;
}

sub JoinTargetToThis {
    my $self = shift;
    my $collection = shift;
    my %args = ( New => 0, Left => 0, @_ );

    my $table = $self->Table;
    my $key = "_sql_${table}_alias";

    return $collection->{ $key } if $collection->{ $key } && !$args{'New'};

    my $alias = $collection->Join(
        $args{'Left'} ? (TYPE => 'LEFT') : (),
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => $table,
        FIELD2 => $self->RecordClass->TargetField,
    );
    return $alias if $args{'New'};
    return $collection->{ $key } = $alias;
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
