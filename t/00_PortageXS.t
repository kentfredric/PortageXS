#!/usr/bin/perl -w

use Test::More tests => 3;

use lib '../lib/';
use lib 'lib/';
use PortageXS;

my $pxs = PortageXS->new();
ok(defined $pxs,'check if PortageXS->new() works');
ok(-d $pxs->getPortdir(),'getPortdir: '.$pxs->getPortdir());
ok(-d $pxs->paths->pkg_db_dir,'PKG_DB_DIR: '.$pxs->paths->pkg_db_dir);
