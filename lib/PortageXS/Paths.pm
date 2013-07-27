
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
    has( $name, @args );
}

sub has_path {
    my ( $name, @args ) = @_;
    push @args, coerce => sub {
        return $_[0] if ref $_[0];
        return path( $_[0] );
    };
    push @args, isa => sub {
        die "Not a Path::Tiny" if not ref $_[0] or not $_[0]->isa('Path::Tiny');
    };
    has_lazy( $name, @args );
}

sub has_path_list {
    my ( $name, @args ) = @_;
    push @args, coerce => sub {
        die "not a list" if not ref $_[0] eq 'ARRAY';
        [ map { ref $_ ? $_ : path($_) } @{ $_[0] } ];
    };
    push @args, isa => sub {
        die "not a list" if not ref $_[0] eq 'ARRAY';
        my $i = 0;
        for ( @{ $_[0] } ) {
            die "element $i is not a Path::Tiny"
              if not ref $_
              or not $_->isa('Path::Tiny');
        }
    };
    has_lazy( $name, @args );
}

=attr C<root> 

The root path of the operating system.

Usually /

=cut

has_path root => builder => sub {
    '/';
};

=attr C<pkg_db_dir>

The path to the portage package database.

Usually C<<< B<< <root> >>/var/db/pkg >>>

=cut

has_path pkg_db_dir => builder => sub {
    $_[0]->root->child('var/db/pkg');
};

=attr C<worldfile>

The path to the portage 'world' file.

Usually C<<< B<< <root> >>/var/lib/portage/world >>>

=cut

has_path worldfile => builder => sub {
    $_[0]->root->child('var/lib/portage/world');
};

=attr C<etc>

The path to the platforms 'etc' directory

Usually C<<< B<< <root> >>/etc >>>

=cut

has_path etc => builder => sub {
    $_[0]->root->child('etc');
};

=attr C<etc_portage>

The path to the platforms 'etc/portage' directory

Usually C<<< B<< <etc> >>/portage >>>

=cut

has_path etc_portage => builder => sub {
    $_[0]->etc->child('portage');
};

=attr C<etc_pxs>

The path to the platforms 'etc/pxs' directory

Usually C<<< B<< <etc> >>/pxs >>>

=cut

has_path etc_pxs => builder => sub {
    $_[0]->etc->child('pxs');
};

=attr C<make_conf_list>

A list of paths C<make.conf> may be found in

=cut

has_path_list make_conf_list => builder => sub {
    return [
        $_[0]->etc->child('make.conf'),
        $_[0]->etc_portage->child('make.conf'),
    ];
};

has_path_list make_globals_list => builder => sub {
    return [
        $_[0]->etc->child('make.conf.globals'),
        $_[0]->root->child('usr/share/portage/config/make.globals')
    ];
};

has_path_list make_profile_list => builder => sub {
    return [
        $_[0]->etc->child('make.profile'),
        $_[0]->etc_portage->child('make.profile')
    ];
};
1;
