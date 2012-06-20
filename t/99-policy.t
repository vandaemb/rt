use strict;
use warnings;

use RT::Test nodb => 1;
use File::Find;

my @files;
find( sub { push @files, $File::Find::name if -f },
      qw{lib share t bin sbin devel/tools} );

sub check {
    my $file = shift;
    my %check = (
        strict   => 0,
        warnings => 0,
        shebang  => 0,
        exec     => 0,
        @_,
    );

    if ($check{strict} or $check{warnings} or $check{shebang}) {
        local $/;
        open my $fh, '<', $file or die $!;
        my $content = <$fh>;

        like(
            $content,
            qr/^use strict(?:;|\s+)/m,
            "$file has 'use strict'"
        ) if $check{strict};

        like(
            $content,
            qr/^use warnings(?:;|\s+)/m,
            "$file has 'use warnings'"
        ) if $check{warnings};

        if ($check{shebang} == 1) {
            like( $content, qr/^#!/, "$file has shebang" );
        } elsif ($check{shebang} == -1) {
            unlike( $content, qr/^#!/, "$file has no shebang" );
        }
    }

    my $mode = sprintf( '%04o', ( stat $file )[2] & 07777 );
    if ($check{exec} == 1) {
        if ( $file =~ /\.in$/ ) {
            is( $mode, '0644', "$file permission is 0644 (.in will add +x)" );
        } else {
            like( $mode, qr/^075[45]$/, "$file permission is 0754 or 0755" );
        }
    } elsif ($check{exec} == -1) {
        like( $mode, qr/^06[40][40]$/, "$file permission is 0644" );
    }
}

check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1 )
    for grep {m{^lib/.*\.pm$}} @files;

check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1 )
    for grep {m{^t/.*\.t$}} @files;

check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1 )
    for grep {m{^s?bin/}} @files;

check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1 )
    for grep {m{^devel/tools/} and not m{\.conf$}} @files;
