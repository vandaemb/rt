# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

package RT::CachedGroupMember;

use strict;
use warnings;


use base 'RT::Record';

sub Table {'CachedGroupMembers'}

=head1 NAME

  RT::CachedGroupMember

=head1 SYNOPSIS

  use RT::CachedGroupMember;

=head1 DESCRIPTION

=head1 METHODS

=cut

# {{ Create

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  'Group' is the "top level" group we're building the cache for. This 
  is an RT::Principal object

  'Member' is the RT::Principal  of the user or group we're adding to 
  the cache.

  This routine should _only_ be called by GroupMember->Create

=cut

sub Create {
    my $self = shift;
    my %args = (
        Group           => undef,
        Member          => undef,
        @_
    );

    unless (    $args{'Member'}
             && UNIVERSAL::isa( $args{'Member'}, 'RT::Principal' )
             && $args{'Member'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus Member argument");
    }

    unless (    $args{'Group'}
             && UNIVERSAL::isa( $args{'Group'}, 'RT::Principal' )
             && $args{'Group'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus Group argument");
    }

    $args{'Disabled'} = $args{'Group'}->Disabled? 1 : 0;

    $self->LoadByCols(
        GroupId           => $args{'Group'}->Id,
        MemberId          => $args{'Member'}->Id,
    );

    my $id;
    if ( $id = $self->id ) {
        if ( $self->Disabled != $args{'Disabled'} && $args{'Disabled'} == 0 ) {
            my ($status) = $self->SetDisabled( 0 );
            return undef unless $status;
        }
        return $id;
    }

    ($id) = $self->SUPER::Create(
        GroupId           => $args{'Group'}->Id,
        MemberId          => $args{'Member'}->Id,
        Disabled          => $args{'Disabled'},
    );
    unless ($id) {
        $RT::Logger->warning(
            "Couldn't create ". $args{'Member'} ." as a cached member of "
            . $args{'Group'}
        );
        return (undef);
    }
    return $id if $args{'Member'}->id == $args{'Group'}->id;

    my $table = $self->Table;
    if ( !$args{'Disabled'} && $args{'Member'}->IsGroup ) {
        # update existing records, in case we activated some paths
        my $query = "
            SELECT CGM3.id FROM
                $table CGM1 CROSS JOIN $table CGM2
                JOIN $table CGM3
                    ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
            WHERE
                CGM1.MemberId = ? AND (CGM1.GroupId != CGM1.MemberId OR CGM1.MemberId = ?)
                AND CGM2.GroupId = ? AND (CGM2.GroupId != CGM2.MemberId OR CGM2.GroupId = ?)
                AND CGM1.Disabled = 0 AND CGM2.Disabled = 0 AND CGM3.Disabled > 0
        ";
        $RT::Handle->SimpleUpdateFromSelect(
            $table, { Disabled => 0 }, $query,
            $args{'Group'}->id, $args{'Group'}->id,
            $args{'Member'}->id, $args{'Member'}->id
        ) or return undef;
    }

    my @binds;

    my $disabled_clause;
    if ( $args{'Disabled'} ) {
        $disabled_clause = '?';
        push @binds, $args{'Disabled'};
    } else {
        $disabled_clause = 'CASE WHEN CGM1.Disabled + CGM2.Disabled > 0 THEN 1 ELSE 0 END';
    }

    my $query = "SELECT CGM1.GroupId, CGM2.MemberId, $disabled_clause FROM
        $table CGM1 CROSS JOIN $table CGM2
        LEFT JOIN $table CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
        WHERE
            CGM1.MemberId = ? AND (CGM1.GroupId != CGM1.MemberId OR CGM1.MemberId = ?)
            AND CGM3.id IS NULL
    ";
    push @binds, $args{'Group'}->id, $args{'Group'}->id;

    if ( $args{'Member'}->IsGroup ) {
        $query .= "
            AND CGM2.GroupId = ?
            AND (CGM2.GroupId != CGM2.MemberId OR CGM2.GroupId = ?)
        ";
        push @binds, $args{'Member'}->id, $args{'Member'}->id;
    }
    else {
        $query .= " AND CGM2.id = ?";
        push @binds, $id;
    }
    $RT::Handle->InsertFromSelect(
        $table, ['GroupId', 'MemberId', 'Disabled'], $query, @binds,
    );

    return $id;
}

=head2 Delete

Deletes the current CachedGroupMember from the group it's in and cascades 
the delete to all submembers. This routine could be completely excised if
mysql supported foreign keys with cascading deletes.

=cut

sub Delete {
    my $self = shift;

    if ( $self->MemberId == $self->GroupId ) {
        # deleting self-referenced means that we're deleting a principal
        # itself and all records where it's a parent or member should
        # be deleted beforehead
        return $self->SUPER::Delete( @_ );
    }

    my $table = $self->Table;
    my $query = "
        SELECT CGM1.id FROM
            CachedGroupMembers CGM1
            JOIN CachedGroupMembers CGMA ON CGMA.MemberId = ?
            JOIN CachedGroupMembers CGMD ON CGMD.GroupId = ?
            LEFT JOIN GroupMembers GM1
                ON GM1.GroupId = CGM1.GroupId AND GM1.MemberId = CGM1.MemberId
        WHERE
            CGM1.GroupId = CGMA.GroupId AND CGM1.MemberId = CGMD.MemberId
            AND CGM1.GroupId != CGM1.MemberId
            AND GM1.id IS NULL 
    ";

    my $res = $RT::Handle->DeleteFromSelect(
        $table, $query,
        $self->GroupId, $self->MemberId,
    );
    return $res unless $res;

    $query =
        "SELECT CGM1.GroupId, CGM2.MemberId,
            CASE WHEN CGM3.Disabled + CGM4.Disabled > 0 THEN 1 ELSE 0 END
        FROM $table CGM1 CROSS JOIN $table CGM2
        JOIN $table CGM3 ON CGM3.GroupId != CGM3.MemberId AND CGM3.GroupId = CGM1.GroupId
        JOIN $table CGM4 ON CGM4.GroupId != CGM4.MemberId AND CGM4.MemberId = CGM2.MemberId
            AND CGM3.MemberId = CGM4.GroupId
        LEFT JOIN $table CGM5
            ON CGM5.GroupId = CGM1.GroupId AND CGM5.MemberId = CGM2.MemberId
        WHERE
            CGM1.MemberId = ?
            AND CGM2.GroupId = ?
            AND CGM5.id IS NULL
    ";
    $res = $RT::Handle->InsertFromSelect(
        $table, ['GroupId', 'MemberId', 'Disabled'], $query,
        $self->GroupId,
        $self->MemberId, 
    );
    return $res unless $res;

    if ( my $m = $self->can('_FlushKeyCache') ) { $m->($self) };

    return 1;
}

=head2 SetDisabled

SetDisableds the current CachedGroupMember from the group it's in and cascades 
the SetDisabled to all submembers. This routine could be completely excised if
mysql supported foreign keys with cascading SetDisableds.

=cut

sub SetDisabled {
    my $self = shift;
    my $val = shift;
    $val = $val ? 1 : 0;

    # if it's already disabled, we're good.
    return (1) if $self->__Value('Disabled') == $val;

    if ( $val ) {
        unless ( $self->GroupId == $self->MemberId ) {
            $RT::Logger->error("SetDisabled should only be applied to (G->G) records");
            return undef;
        }

        my $query = "SELECT main.id FROM CachedGroupMembers main
            JOIN CachedGroupMembers CGM1 ON main.GroupId = CGM1.GroupId
                AND CGM1.MemberId = ?
                AND CGM1.Disabled = 0
            JOIN CachedGroupMembers CGM2 ON main.MemberId = CGM2.MemberId
                AND CGM2.GroupId = ?
            WHERE main.Disabled = 0";

        $RT::Handle->SimpleUpdateFromSelect(
            $self->Table, { Disabled => 1 }, $query,
            ($self->GroupId)x2,
        ) or return undef;

        $query = "SELECT main.id FROM CachedGroupMembers main
            JOIN CachedGroupMembers CGM1 ON main.GroupId = CGM1.GroupId
                AND CGM1.MemberId = ?
                AND CGM1.Disabled = 0
            JOIN CachedGroupMembers CGM2 ON main.MemberId = CGM2.MemberId
                AND CGM2.GroupId = ?

            JOIN CachedGroupMembers CGM3 ON CGM3.Disabled = 0
                AND main.GroupId = CGM3.GroupID
            JOIN CachedGroupMembers CGM4 ON CGM4.Disabled = 0
                AND main.MemberId = CGM4.MemberId
                AND CGM4.GroupId = CGM3.MemberId

            WHERE main.Disabled = 1";

        $RT::Handle->SimpleUpdateFromSelect(
            $self->Table, { Disabled => 0 }, $query,
            ($self->GroupId)x2,
        ) or return undef;
    }
    else {
        my ($status, $msg) = $self->_Set(Field => 'Disabled', Value => $val);
        unless ( $status ) {
            $RT::Logger->error(
                "Couldn't SetDisabled CachedGroupMember #" . $self->Id .": $msg"
            );
            return $status;
        }
        my $query = "SELECT main.id FROM CachedGroupMembers main
            JOIN CachedGroupMembers CGM1 ON main.GroupId = CGM1.GroupId
                AND CGM1.MemberId = ?
                AND CGM1.Disabled = 0
            JOIN CachedGroupMembers CGM2 ON main.MemberId = CGM2.MemberId
                AND CGM2.GroupId = ?
            WHERE main.Disabled = 1";

        $RT::Handle->SimpleUpdateFromSelect(
            $self->Table, { Disabled => 0 }, $query,
            $self->GroupId, $self->MemberId
        ) or return undef;
    }
    if ( my $m = $self->can('_FlushKeyCache') ) { $m->($self) };
    return (1);
}



=head2 GroupObj  

Returns the RT::Principal object for this group Group

=cut

sub GroupObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->GroupId );
    return ($principal);
}



=head2 MemberObj

Returns the RT::Principal object for this group member

=cut

sub MemberObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->MemberId );
    return ($principal);
}

# }}}






=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 GroupId

Returns the current value of GroupId.
(In the database, GroupId is stored as int(11).)



=head2 SetGroupId VALUE


Set GroupId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, GroupId will be stored as a int(11).)


=cut


=head2 MemberId

Returns the current value of MemberId.
(In the database, MemberId is stored as int(11).)



=head2 SetMemberId VALUE


Set MemberId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, MemberId will be stored as a int(11).)


=cut

=head2 Disabled

Returns the current value of Disabled.
(In the database, Disabled is stored as smallint(6).)

=head2 SetDisabled VALUE

Set Disabled to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a smallint(6).)

=cut


=head1 FOR DEVELOPERS

=head2 SQL behind maintaining CGM table

=head3 Terminology

=over 4

=item * An(E) - all ancestors of E including E itself

=item * De(E) - all descendants of E including E itself

=back

=head3 Adding a (G -> M) record

When a new (G -> M) record added we should connect all An(G) to all De(M), so it's
the following select:

    SELECT CGM1.GroupId, CGM2.MemberId FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
    WHERE
        CGM1.MemberId = G
        AND CGM2.GroupId = M
    ;

It handles G and M itself as we always have (E->E) records.

Some of this records may exist in the table, so we should skip them:

    SELECT CGM1.GroupId, CGM2.MemberId FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
        LEFT JOIN CachedGroupMembers CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
    WHERE
        CGM1.MemberId = G
        AND CGM2.GroupId = M
        AND CGM3.id IS NULL
    ;

In order to do less checks we should skip (E->E) records, but not those
that touch our G and M:

    SELECT CGM1.GroupId, CGM2.MemberId FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
        LEFT JOIN CachedGroupMembers CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
    WHERE
        CGM1.MemberId = G AND (CGM1.GroupId != CGM1.MemberId OR CGM1.MemberId = G)
        AND CGM2.GroupId = M AND (CGM2.GroupId != CGM2.MemberId OR CGM2.GroupId = M)
        AND CGM3.id IS NULL
    ;

=head4 Disabled column

We should handle properly Disabled column.

If the new records we're adding is disabled then all new paths we add as well
disabled and existing one are not affected.

Otherwise activity of new paths depends on entries that got connected and existing
paths have to be updated.

New paths:

    SELECT CGM1.GroupId, CGM2.MemberId, IF(CGM1.Disabled+CGM2.Disabled > 0, 1, 0) FROM
    ...

Updating old paths, the following records should be activated:

    SELECT CGM3.id FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
        JOIN CachedGroupMembers CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
    WHERE
        CGM1.MemberId = G AND (CGM1.GroupId != CGM1.MemberId OR CGM1.MemberId = G)
        AND CGM2.GroupId = M AND (CGM2.GroupId != CGM2.MemberId OR CGM2.GroupId = M)
        AND CGM1.Disabled = 0 AND CGM2.Disabled = 0 AND CGM3.Disabled > 0
    ;

It's better to do this before we insert new records, so we scan less records
to find things we need updating.

=head3 mysql performance

Sample results:

    10k  - 0.4x seconds
    100k - 4.x seconds
    1M   - 4x.x seconds

As long as innodb_buffer_pool_size is big enough to store insert buffer,
and MIN(tmp_table_size, max_heap_table_size) allow us to store tmp table
in the memory. For 100k records we need less than 15 MBytes. Disk I/O
heavily degrades performance.

=head2 Deleting a (G->M) record

In case record is deleted from GM table we should re-evaluate records in CGM.

Candidates for deletion are any records An(G) -> De(M):

    SELECT CGM3.id FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
        JOIN CachedGroupMembers CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
    WHERE
        CGM1.MemberId = G
        AND CGM2.GroupId = M
    ;

Some of this records may still have alternative routes. A candidate (G', M')
stays in the table if following records exist in GM and CGM tables.
(G', X) in CGM, (X,Y) in GM and (Y,M') in CGM, where X ~ An(G) and Y !~ An(G).

    SELECT CGM3.id FROM
        CachedGroupMembers CGM1
        CROSS JOIN CachedGroupMembers CGM2
        JOIN CachedGroupMembers CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId

    WHERE
        CGM1.MemberId = G
        AND CGM2.GroupId = M
        AND NOT EXISTS (
            SELECT CGM4.GroupId FROM
                CachedGroupMembers CGM4
                    ON CGM4.GroupId = CGM3.GroupId
                JOIN GroupMembers GM1
                    ON GM1.GroupId = CGM4.MemberId
                JOIN GroupMembers CGM5
                    ON CGM4.GroupId = GM1.MemberId
                    AND CGM4.MemberId = CGM3.MemberId
                JOIN CachedGroupMembers CGM6
                    ON CGM6.GroupId = CGM4.MemberId
                    AND CGM6.MemberId = G
                LEFT JOIN CachedGroupMembers CGM7
                    ON CGM7.GroupId = CGM5.GroupId
                    AND CGM7.MemberId = G
            WHERE
                CGM7.id IS NULL
        )
    ;

Fun.

=head3 mysql performance

    10k  - 4.x seconds
    100k - 13x seconds
    1M   - not tested

Sadly this query perform much worth comparing to the insert operation. Problem is
in the select.

=head3 Delete all candidates and re-insert missing

We can delete all candidates (An(G)->De(M)) from CGM table that are not
real GM records: then insert records once again.

    SELECT CGM1.id FROM
        CachedGroupMembers CGM1
        JOIN CachedGroupMembers CGMA ON CGMA.MemberId = G
        JOIN CachedGroupMembers CGMD ON CGMD.GroupId = M
        LEFT JOIN GroupMembers GM1
            ON GM1.GroupId = CGM1.GroupId AND GM1.MemberId = CGM1.MemberId
    WHERE
        CGM1.GroupId = CGMA.GroupId AND CGM1.MemberId = CGMD.MemberId
        AND CGM1.GroupId != CGM1.MemberId
        AND GM1.id IS NULL
    ;

Then we can re-insert data back with insert from select described above.

=head4 mysql performance

This solution is faster than perviouse variant, 4-5 times slower than
create operation and behaves linear.

=head3 Recursive delete

Again, some (An(G), De(M)) pairs should be deleted, but some may stay. If
delete any pair from the set then An(G) and De(M) sets don't change, so
we can delete things step by step. Run delete operation, if any was deleted
then run it once again, do it until operation deletes no rows. We shouldn't
delete records where:

=over 4

=item * GroupId == MemberId

=item * exists matching GM

=item * exists equivalent GM->CGM pair

=item * exists equivalent CGM->GM pair

=over

Query with most conditions in one NOT EXISTS subquery:

    SELECT CGM1.id FROM
        CachedGroupMembers CGM1
        JOIN CachedGroupMembers CGMA ON CGMA.MemberId = G
        JOIN CachedGroupMembers CGMD ON CGMD.GroupId = M
    WHERE
        CGM1.GroupId = CGMA.GroupId AND CGM1.MemberId = CGMD.MemberId
        AND CGM1.GroupId != CGM1.MemberId
        AND NOT EXISTS (
            SELECT * FROM
                CachedGroupMembers CGML
                CROSS JOIN GroupMembers GM
                CROSS JOIN CachedGroupMembers CGMR
            WHERE
                CGML.GroupId = CGM1.GroupId
                AND GM.GroupId = CGML.MemberId
                AND CGMR.GroupId = GM.MemberId
                AND CGMR.MemberId = CGM1.MemberId
                AND (
                    (CGML.GroupId = CGML.MemberId AND CGMR.GroupId != CGMR.MemberId)
                    OR 
                    (CGML.GroupId != CGML.MemberId AND CGMR.GroupId = CGMR.MemberId)
                )
        )
    ;

=head4 mysql performance

It's better than first solution, but still it's not linear. Problem is that
NOT EXISTS means that for every link that should be deleted we have to check too
many conditions (too many rows to scan). Still delete + insert behave better and
more linear.

=head3 Alternative ways

Store additional info in a table, similar to Via and IP we had. Then we can
do iterative delete like in the last solution. However, this will slowdown
insert, probably not that much as I suspect we would be able to push new data
in one query.

=head2 TODO

Update disabled on delete. Update SetDisabled method. Delete all uses of Via and
IntermidiateParent. Review indexes on all databases. Create upgrade script.

=cut

sub _CoreAccessible {
    {
        id =>
		{read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        GroupId =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        MemberId =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Disabled =>
		{read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},
    }
};

RT::Base->_ImportOverlays();

1;
