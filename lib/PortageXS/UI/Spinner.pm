use strict;
use warnings;

package PortageXS::UI::Spinner;

# ABSTRACT: Console progress spinner bling.
# -----------------------------------------------------------------------------
#
# PortageXS::UI::Spinner
#
# author      : Christian Hartmann <ian@gentoo.org>
# license     : GPL-2
# header      : $Header: /srv/cvsroot/portagexs/trunk/lib/PortageXS/UI/Spinner.pm,v 1.1.1.1 2006/11/13 00:28:34 ian Exp $
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
use IO::Handle;

=head1 SYNOPSIS

    use PortageXS::UI::Spinner;

    my $spinner = PortageXS::UI::Spinner->new();

    for ( 0..1000 ){
        sleep 0.1;
        $spinner->spin;
    }
    $spinner->reset;

=cut

=attr spinstate

=cut

has spinstate => ( is => rwp =>, default => sub { 0 } );

=attr output_handle

=cut

has output_handle => (
    is => ro =>, default => sub {
        my $handle = \*STDOUT;
        $handle->autoflush(1);
        return $handle;
});

=attr spinstates

=cut

has spinstates => ( is => ro =>, default => sub {
    ['/', '-', '\\','|']
});

=p_method _last_spinstate

=cut

sub _last_spinstate {  return $#{ $_[0]->spinstates } }

=p_method _increment_spinstate

=cut

sub _increment_spinstate {
    my $self = shift;
    my $rval = $self->spinstate;
    my $nextstate = $rval + 1;
    if ( $nextstate > $self->_last_spinstate ) {
        $nextstate = 0;
    }
    $self->_set_spinstate($nextstate);
    return $rval;
}
=p_method _get_next_spinstate

=cut

sub _get_next_spinstate {
    my (@states) = @{ $_[0]->spinstates };
    return $states[ $_[0]->_increment_spinstate ];
}

=p_method _print_to_output

=cut

sub _print_to_output {
    my $self = shift;
    $self->output_handle->print(@_);
}

=method spin

=cut

sub spin {
	my $self	= shift;
    $self->_print_to_output("\b" . $self->_get_next_spinstate );
}

=method reset

=cut

sub reset {
    $_[0]->_print_to_output("\b \b");
}

1;
