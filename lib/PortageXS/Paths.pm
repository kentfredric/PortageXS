
use strict;
use warnings;

package PortageXS::Paths;
BEGIN {
  $PortageXS::Paths::AUTHORITY = 'cpan:KENTNL';
}
{
  $PortageXS::Paths::VERSION = '0.2.13';
}

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


has_path root => builder => sub {
    '/';
};


has_path pkg_db_dir => builder => sub {
    $_[0]->root->child('var/db/pkg');
};
has_path worldfile => builder => sub {
    $_[0]->root->child('var/lib/portage/world');
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

has_path_list make_conf_list => builder => sub {
    return [
        $_[0]->etc->child('make.conf'),
        $_[0]->etc_portage->child('make.conf')
    ];
};

has_path_list make_globals_list => builder => sub {
    return [
        $_[0]->etc->child('make.conf.globals'),
        $_[0]->root->child('usr/share/portage/config/make.globals')
    ];
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

PortageXS::Paths - Path resolution for various important paths

=head1 VERSION

version 0.2.13

=head1 ATTRIBUTES

=head2 C<root> 

The root path of the operating system.

Usually /

=head2 C<pkg_db_dir>

The path to the portage package database.

Usually C<<<B<< <root> >>/var/db/pkg >>>

=head1 AUTHORS

=over 4

=item *

Christian Hartmann <ian@gentoo.org>

=item *

Torsten Veller <tove@gentoo.org>

=item *

Kent Fredric <kentnl@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2013 by Christian Hartmann.

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut
