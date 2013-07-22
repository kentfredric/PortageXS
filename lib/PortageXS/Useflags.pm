use strict;
use warnings;

package PortageXS::Useflags;

# -----------------------------------------------------------------------------
#
# PortageXS::Useflags
#
# author      : Christian Hartmann <ian@gentoo.org>
# license     : GPL-2
# header      : $Header: /srv/cvsroot/portagexs/trunk/lib/PortageXS/Useflags.pm,v 1.7 2008/12/01 20:30:23 ian Exp $
#
# -----------------------------------------------------------------------------
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# -----------------------------------------------------------------------------

use DirHandle;
use Moo::Role;
use Path::Tiny;

# Description:
# Returns useflag description of the given useflag and repository.
# Returns only global usedescs.
# $usedesc=getUsedesc($use,$repo);
# Example:
# $usedesc=getUsedesc('perl','/usr/portage');
sub getUsedesc {
	my $self	= shift;
	
	return ($self->getUsedescs(@_))[0];
}

# Description:
# Returns useflag descriptions of the given useflag and repository.
# Returns global and local usedescs. (Local usedescs only if the optional parameter $categoryPackage is set.)
# @usedescs=getUsedescs($use,$repo[,$categoryPackage]);
# Example:
# @usedescs=getUsedescs('perl','/usr/portage'[,'dev-lang/perl']);
sub getUsedescs {
	my $self	= shift;
	my $use		= shift;
	my $repo	= shift;
	my $package	= shift;
	my @p		= ();
	my @descs	= ();
	
	if (-e ( my $use_desc = path($repo.'/profiles/use.desc'))) {
		if (!$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$repo}{'use.desc'}{'initialized'}) {
			foreach ($use_desc->lines({ chomp => 1 })) {
				if ($_) {
					@p=split(/ - /,$_);
					$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$repo}{'use.desc'}{'use'}{$p[0]}=$p[1];
				}
			}
			$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$repo}{'use.desc'}{'initialized'}=1;
		}
		
		if ($self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$repo}{'use.desc'}{'use'}{$use}) {
			push(@descs,$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$repo}{'use.desc'}{'use'}{$use});
		}
	}
	
	if ($package) {
		if (-e ( my $use_local_desc = path($repo.'/profiles/use.local.desc'))) {
			if (!$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$repo}{'use.local.desc'}) {
				$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$repo}{'use.local.desc'}=$use_local_desc->slurp();
			}
			foreach (split(/\n/,$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$repo}{'use.local.desc'})) {
				if ($_) {
					@p=split(/ - /,$_);
					if ($p[0] eq $package.':'.$use) {
						push(@descs,$p[1]);
					}
				}
			}
		}
	}
	
	return @descs;
}

# Description:
# Sorts useflags the way portages does.
# @sortedUseflags = sortUseflags(@useflags);
sub sortUseflags {
	my $self	= shift;
	my @useflags	= @_;
	my (@use1,@use2);

	foreach my $useflag (sort @useflags) {
		if (substr($useflag,0,1) eq '-') {
			push @use1, $useflag;
		}
		else {
			push @use2, $useflag;
		}
	}
	return (@use2,@use1);
}

# Description:
# Helper for getUsemasksFromProfile()
sub getUsemasksFromProfileHelper {
	my $self	= shift;
	my $curPath	= shift;
	my @files	= ();
	my $parent	= '';

	if (-e $curPath.'/use.mask') {
		push(@files,$curPath.'/use.mask');
	}
	if (! -e $curPath.'/parent') {
		return @files;
	}
	$parent=$self->getFileContents($curPath.'/parent');
	foreach (split(/\n/,$parent)) {
		push(@files,$self->getUsemasksFromProfileHelper($curPath.'/'.$_));
	}

	return @files;
}

# Description:
# Returnvalue is an array containing all masked useflags set in the system-profile.
#
# Example:
# @maskedUseflags=$pxs->getUsemasksFromProfile();
sub getUsemasksFromProfile {
	my $self	= shift;
	my $curPath	= '';
	my @files	= ();
	my $parent	= '';
	my $buffer	= '';
	my $c		= 0;
	my %maskedUses	= ();

    if ($self->{'CACHE'}{'Useflags'}{'getUsemasksFromProfile'}{'useflags'}) {
	    return split(/ /,$self->{'CACHE'}{'Useflags'}{'getUsemasksFromProfile'}{'useflags'});
    }

    if(!-e $self->paths->make_profile ) {
	    $self->print_err('Profile not set!');
		exit(0);
	}
	else {
	    $curPath=$self->getProfilePath();
	}
		
# 		while(1) {
# 			print "-->".$curPath."<--\n";
# 			if (-e $curPath.'/use.mask') {
# 				push(@files,$curPath.'/use.mask');
# 			}
# 			if (! -e $curPath.'/parent') { last; }
# 			$parent=$self->getFileContents($curPath.'/parent');
# 			chomp($parent);
# 			$curPath.='/'.$parent;
# 		}
	@files = $self->getUsemasksFromProfileHelper($curPath);
	
    my @lines;

	push @lines, $self->paths->portdir->child('profiles','base','use.mask')->lines({ chomp => 1 });

	foreach(reverse(@files)) {
        push @lines, $_->lines({ chomp => 1 });
	}
		
    for($c=0;$c<=$#lines;$c++) {
        next if $lines[$c]=~m/^#/;
        next if $lines[$c] eq "\n";
        next if $lines[$c] eq '';
        
        if (substr($lines[$c],0,1) eq '-') {
            # - unmask use >
            $maskedUses{substr($lines[$c],1,length($lines[$c])-1)}=0;
        }
        else {
            $maskedUses{$lines[$c]}=1;
        }
    }

    my @useflags;
    
    foreach (keys %maskedUses) {
        if ($maskedUses{$_}) {
            push(@useflags,$_);
        }
    }
    
    # - Setup cache >
    $self->{'CACHE'}{'Useflags'}{'getUsemasksFromProfile'}{'useflags'}=join(' ',@useflags);
	
	return @useflags;
}

1;
