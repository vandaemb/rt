use strict;
use warnings;

use RT::Test nodb => 1;
use File::Find;

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
            "$File::Find::name has 'use strict'"
        ) if $check{strict};

        like(
            $content,
            qr/^use warnings(?:;|\s+)/m,
            "$File::Find::name has 'use warnings'"
        ) if $check{warnings};

        if ($check{shebang} == 1) {
            like( $content, qr/^#!/, "$File::Find::name has shebang" );
        } elsif ($check{shebang} == -1) {
            unlike( $content, qr/^#!/, "$File::Find::name has no shebang" );
        }
    }

    my $mode = sprintf( '%04o', ( stat $file )[2] & 07777 );
    if ($check{exec} == 1) {
        if ( $file =~ /\.in$/ ) {
            is( $mode, '0644', "$File::Find::name permission is 0644 (.in will add +x)" );
        } else {
            like( $mode, qr/^075[45]$/, "$File::Find::name permission is 0754 or 0755" );
        }
    } elsif ($check{exec} == -1) {
        like( $mode, qr/^06[40][40]$/, "$File::Find::name permission is 0644" );
    }
}

find(
    sub {
        return unless -f && /\.pm$/;
        check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1 );
    },
    'lib',
);

find(
    sub {
        return unless -f && /\.t$/;
        check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1 );
    },
    't',
);

find(
    sub {
        return unless -f;
        check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1 );
    },
    'bin',
    'sbin',
);

find(
    sub {
        return unless -f && $_ !~ /\.conf$/;
        check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1 );
    },
    'devel/tools',
);
