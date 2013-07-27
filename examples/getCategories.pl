#!/usr/bin/perl

use warnings;
use strict;

use PortageXS;

my $pxs   = PortageXS->new();
my @repos = ();

push( @repos, $pxs->getPortdir() );
push( @repos, $pxs->getPortdirOverlay() );

foreach (@repos) {
    printf qq[List of available categories in repo :%s\n], $_;
    my @categories = $pxs->getCategories($_);
    if ( not @categories ) {
        print qq[No categories defined for this repo.\n];
        next;
    }
    print join( qq{\n}, @categories ) . qq{\n};
}
