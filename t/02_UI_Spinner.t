#!/usr/bin/perl -w

use Test::More tests => 1;

use lib '../lib/';
use lib 'lib/';
use PortageXS::UI::Spinner;

my $spinner = PortageXS::UI::Spinner->new();
ok(defined $spinner,'check if PortageXS::UI::Spinner->new() works');
