#!/usr/bin/perl

use warnings;
use strict;

use PortageXS;

my $pxs = PortageXS->new();

my $USAGE = <<"_USAGE_";
    $0 packagename

Formats the useflags of <packagename>

Example:

    $0 perl
    $0 gcc

_USAGE_
if ( not $ARGV[0] ) {
    die $USAGE;
}

my ($result) = $pxs->searchPackage( $ARGV[0], 'exact' );
my @example_useflags = qw(abc abc% abc* abc%* -abc -abc* -abc% -abc*%);

if ($result) {
    printf q[Package '%s' has been compiled with useflags set: ], $result;
    print join(
        q[ ],
        $pxs->formatUseflags(
            $pxs->getUseSettingsOfInstalledPackage(
                $pxs->searchInstalledPackage($result)
            )
        )
    ) . qq[\n];
}
else {
    printf qq[Did not get a result for '%s'\n], $ARGV[0];
}

print qq[\nMore examples:\n];

print join( q[ ], $pxs->formatUseflags(@example_useflags) ) . qq[\n];
my $umasked = ( $pxs->getUsemasksFromProfile() )[0];
print join(
    q[ ],
    $pxs->formatUseflags(
        (
            $umasked,
            $umasked . '%',
            $umasked . '*',
            $umasked . '%*',
            '-' . $umasked,
            '-' . $umasked . '*',
            '-' . $umasked . '%',
            '-' . $umasked . '*%'
        )
    )
) . qq[\n];

