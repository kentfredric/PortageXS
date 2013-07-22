
use strict;
use warnings;
 
package PortageXS::Paths;

# ABSTRACT: Path resolution for various important paths

use Path::Tiny;
use Moo;

sub has_lazy {
    my ( $name, @args ) = @_;
    unshift @args, ( is => ro => );
    unshift @args, ( lazy => 1 );
    has($name, @args);
}
sub has_path {
    my ( $name, @args ) = @_;
    push @args, coerce => sub {
        return $_[0] if ref $_[0];
        return path($_[0]);
    };
    push @args, isa => sub {
         die "Not a Path::Tiny" if not ref $_[0] or not $_[0]->isa('Path::Tiny');
    };
    has_lazy($name,@args);
}

has_lazy 'portagexs' => weak_ref => 1;

has_path root => builder => sub {
    '/';
};
has_path portdir => builder => sub {
    $_[0]->portagexs->getPortdir()
};

has_path pkg_db_dir => builder => sub {
    $_[0]->root->child('var','db','pkg');
};
has_path worldfile => builder => sub {
    $_[0]->root->child('var','lib','portage','world');
};
has_path etc => builder => sub {
    $_[0]->root->child('etc');
};
has_path make_profile => builder => sub {
    $_[0]->etc->child('make.profile');  
};
has_path etc_portage => builder => sub {
    $_[0]->etc->child('portage');
};
has_path etc_pxs => builder => sub {
    $_[0]->etc->child('pxs');
};

has_path make_conf_old => builder => sub {
    return $_[0]->etc->child('make.conf'); 
};
has_path make_conf => builder => sub {
    return $_[0]->etc_portage->child('make.conf');
};
has_path make_globals_old => builder => sub {
    return $_[0]->etc->child('make.conf.globals') 
};
has_path make_globals => builder => sub {
    return $_[0]->root->child('usr','share','portage','config','make.globals');
};

1;
