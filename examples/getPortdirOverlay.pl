#!/usr/bin/perl

use warnings;
use strict;

use PortageXS;

my $pxs=PortageXS->new();
print "Overlays:\n";
print join("\n",$pxs->getPortdirOverlay())."\n";
