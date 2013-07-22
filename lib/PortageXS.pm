use strict;
use warnings;

package PortageXS;

# ABSTRACT: Portage abstraction layer for perl

# -----------------------------------------------------------------------------
#
# PortageXS
#
# author      : Christian Hartmann <ian@gentoo.org>
# license     : GPL-2
# header      : $Header: /srv/cvsroot/portagexs/trunk/lib/PortageXS.pm,v 1.14 2008/12/01 19:53:27 ian Exp $
#
# -----------------------------------------------------------------------------
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# -----------------------------------------------------------------------------

use Moo;
use Path::Tiny qw(path);

with 'PortageXS::Core';
with 'PortageXS::System';
with 'PortageXS::UI::Console';
with 'PortageXS::Useflags';

use PortageXS::Version;

sub has_lazy {
    my ( $name, @args ) = @_;
    unshift @args, ( is => ro => );
    unshift @args, ( lazy => 1 );
    has( $name, @args );
}

has_lazy config => builder => sub {
    require PortageXS::Config;
    return PortageXS::Config->new( portagexs => $_[0] );
};
has_lazy paths => builder => sub {
    require PortageXS::Paths;
    return PortageXS::Paths->new( portagexs => $_[0], );
};

has_lazy exclude_dirs_list => (
    builder => sub {
        return
          [ qw( . .. metadata licenses eclass distfiles profiles CVS .cache )];
    }
);
has_lazy exclude_dirs => (
    builder => sub {
        return { map { ( $_, 1 ) } @{ $_[0]->exclude_dirs_list } };
    }
);

sub _should_exclude {
    my ( $self, $path ) = @_ ; 
    my $basename = $path->basename;
    return 1 if exists $self->exclude_dirs->{ $basename };
    return;
}

has colors => (
    is      => ro =>,
    lazy    => 1,
    builder => sub {
        my $self = shift;
        if ( $self->_want_nocolor ) {
            return { map { ( $_, '' ) }
                  qw( YELLOW GREEN LIGHTGREEN WHITE CYAN RED BLUE RESET ) };
        }
        require Term::ANSIColor;
        return {
            YELLOW     => Term::ANSIColor::color('bold yellow'),
            GREEN      => Term::ANSIColor::color('green'),
            LIGHTGREEN => Term::ANSIColor::color('bold green'),
            WHITE      => Term::ANSIColor::color('bold white'),
            CYAN       => Term::ANSIColor::color('bold cyan'),
            RED        => Term::ANSIColor::color('bold red'),
            BLUE       => Term::ANSIColor::color('bold blue'),
            RESET      => Term::ANSIColor::color('reset'),
        };
    },
);
has_lazy _want_nocolor => builder => sub {
    my ( $self, ) = @_;
    my $param = $self->config->getParam('NOCOLOR', 'lastseen');
    if ( lc $param eq 'true' ) {
        return 1;
    }
    return;
};

sub BUILD {
    my $self = shift;
    require Tie::Hash::Method;
    tie %{$self}, 'Tie::Hash::Method', FETCH => sub {
        if ( $_[1] ne 'CACHE' and $_[1] =~ /[A-Z]/ ) {
            die "Internal property $_[1] deprecated, use an accessor please"; 
        }
        return $_[0]->base_hash->{ $_[1] };
    }, STORE => sub {
        if ( $_[1] ne 'CACHE' and $_[1] =~ /[A-Z]/ ) {
            die "Internal property $_[1] deprecated, use an accessor please"; 
        }
        return $_[0]->base_hash->{ $_[1] } = $_[2];
    };
    return $self;
}

1
