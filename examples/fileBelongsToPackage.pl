#!/usr/bin/perl

use warnings;
use strict;

use PortageXS;
use PortageXS::UI::Spinner::Rainbow;
use Time::HiRes qw( setitimer ITIMER_VIRTUAL );

$| = 1;

my $pxs     = PortageXS->new();
my $color   = $pxs->colors;
my $spinner = PortageXS::UI::Spinner::Rainbow->new();

my $USAGE = <<"_USAGE_";
    $0 /path/to/file

    Finds packages shipping given file

_USAGE_

if ( not $ARGV[0] ) {
    die $USAGE;
}

if ( !-f $ARGV[0] ) {
    $color->printColored( RED => qq{Given file does not exist - Aborting!\n} );
    exit 1;
}

my @results;
{
    local $SIG{VTALRM} = sub {
        $spinner->spin;
    };
    setitimer( ITIMER_VIRTUAL, 0.01, 0.01 );
    $color->printColored(
        LIGHTGREEN => sprintf q{Searching for '%s'..},
        $ARGV[0]
    );

    @results = $pxs->fileBelongsToPackage( $ARGV[0] );
    $spinner->reset;
}

print "\n";
if ( $#results < 0 ) {
    $color->printColored(
        RED => qq{This file has not been installed by portage.\n} );
    exit 2;
}

$color->printColored(
    LIGHTGREEN => sprintf qq{The file '%s' was installed by these packages:\n},
    $ARGV[0]
);
print q[   ] . join( qq[\n   ], @results ) . qq[\n];

exit(0);

