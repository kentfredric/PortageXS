#!/usr/bin/perl -w

use Test::More tests => 1;

use lib '../lib/';
use lib 'lib/';
use PortageXS;

my $pxs = PortageXS->new();

# - getHomedir >
{
	my $homeDir=$pxs->getHomedir();
	ok(-d $homeDir,'getHomedir: '.$homeDir);
}
