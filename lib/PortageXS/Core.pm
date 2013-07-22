use strict;
use warnings;

package PortageXS::Core;

# -----------------------------------------------------------------------------
#
# PortageXS::Core
#
# author      : Christian Hartmann <ian@gentoo.org>
# license     : GPL-2
# header      : $Header: /srv/cvsroot/portagexs/trunk/lib/PortageXS/Core.pm,v 1.19 2008/12/01 19:53:27 ian Exp $
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
use Shell::EnvImporter;

use Moo::Role;
use Path::Tiny qw(path);

# Description:
# Returnvalue is ARCH set in the system-profile.
# Wrapper for old getArch()-version. Use getPortageMakeParam() instead.
#
# Example:
# $arch=$pxs->getArch();

sub getArch {
	my $self	= shift;
	return $self->getPortageMakeParam('ARCH');
}

# Description:
# Returns the profile tree as array
# "depth ﬁrst, left to right, with duplicate parent paths being sourced 
# for every time they are encountered"
sub getProfileTree {
	my $self	= shift;
	my $curPath	= shift;
	my @path;

	if ( -e "$curPath/parent" ) {
		my $parent=$self->getFileContents("$curPath/parent");
		foreach (split /\n/, $parent) {
			push @path, $self->getProfileTree("$curPath/$_");
		}
	}
	push @path, $curPath;
	return @path;
}

# Description:
# Helper for getPortageMakeParam()
sub getPortageMakeParamHelper {
	my $self	= shift;
	my $curPath	= shift;
	my @files	= ();

	foreach my $profile ( $self->getProfileTree($curPath) ) {
		push(@files,path("$profile/make.defaults")) if (-e "$profile/make.defaults");
	}
	return @files;
}

# Description:
# Returnvalue is $PARAM set in the system-profile.
#
# Example:
# $arch=$pxs->getPortageMakeParam();
sub getPortageMakeParam {
	my $self		= shift;
	my $param		= shift;
	my @files		= ();
	my $v			= '';
	my $parent		= '';
	my $curPath;
	
	if(!-e $self->paths->make_profile) {
		$self->print_err('Profile not set!');
		exit(0);
	}
	else {
		$curPath=$self->getProfilePath();
	}
	
	@files=$self->getPortageMakeParamHelper($curPath);
	push @files,
        $self->paths->make_globals_old,
        $self->paths->make_globals,
        $self->paths->make_conf_old,
        $self->paths->make_conf;

	foreach (@files) {
        next if not -e -f $_;
		my $importer = Shell::EnvImporter->new(	shell		=> "bash",
							file		=> $_->stringify,
							auto_run	=> 1,
							auto_import	=> 1
					);
		
		$importer->shellobj->envcmd('set');
		$importer->run();
		
		if ($ENV{$param}) {
			$v=$ENV{$param};
			$v=~s/\\t/ /g;
			$v=~s/\t/ /g;
			$v=~s/^\$'(.*)'$/$1/m;
			$v=~s/^'(.*)'$/$1/m;
			$v=~s/\\n/ /g;
			$v=~s/\\|\'|\\'|\$//gmxs;
			$v=~s/^\s//;
			$v=~s/\s$//;
			$v=~s/\s{2,}/ /g;
		}
		
		$importer->restore_env();
	}
	
	# - Defaults >
	if ($param eq 'PORTDIR' && !$v) {
		$v='/usr/portage';
	}
	
	return $v;
}

# Description:
# Returnvalue is PORTDIR from make.conf or make.globals (make.conf overrules make.globals).
# This function initializes itself at the first time it is called and reuses $self->{'PORTDIR'}
# as a return value from then on.
#
# Provides:
# $self->{'PORTDIR'}
#
# Parameters:
# $forcereload is optional and forces a reload of the make.conf and make.globals files.
#
# Example:
# $portdir=$pxs->getPortdir([$forcereload]);
sub getPortdir {
	my $self	= shift;
	my $forcereload	= shift;

    my $param = $self->config->getParam('PORTDIR','lastseen');

    if ( not $param ) {
        if ( exists $ENV{PORTDIR} ) {
            return $ENV{PORTDIR};
        }
        else {
            die "Could not determine PORTDIR, no make.conf or make.globals could be found in the right places on your system, and PORTDIR is not in ENV";
        }
    }
    return $param;
}

# Description:
# Returnvalue is PORTDIR_OVERLAY from make.conf or make.globals (make.conf overrules make.globals).
#
# Parameters:
# $forcereload is optional and forces a reload of the make.conf and make.globals files.
#
# Example:
# @portdir_overlay=$pxs->getPortdirOverlay();
sub getPortdirOverlay {
	my $self	= shift;
	my $forcereload	= shift;
	
	return split(/ /,$self->getParamFromFile($self->getFileContents('/etc/make.globals').$self->getFileContents('/etc/make.conf'),'PORTDIR_OVERLAY','lastseen'));
}

# Description:
# Returnvalue is the content of the given file.
# $filecontent=$pxs->getFileContents($file);
sub getFileContents {
    warn "DEPRECATED: use Path::Tiny + path(mypath)->slurp or path(mypath)->lines as appropriate";
	my $self = shift;
	my $file = shift;
	my $content = do {
		local $/;
		open my $fh, '<', $file or die "Cannot open file $file";
		<$fh>;
	};
	return $content;
}

# Description:
# Returns an array containing all packages that match $searchString
# @packages=$pxs->searchInstalledPackage($searchString);
sub searchInstalledPackage {
	my $self		= shift;
	my $searchString	= shift; if (! $searchString) { $searchString=''; }
	my @matches		= ();
	my $s_cat		= '';
	my $s_pak		= '';
	my $m_cat		= 0;
	my $dhp;
	my $tp;
	
	# - escape special chars >
	$searchString =~ s/\+/\\\+/g;

	# - split >
	if ($searchString=~m/\//) {
		($s_cat,$s_pak)=split(/\//,$searchString);
	}
	else {
		$s_pak=$searchString;
	}
	
	$s_cat=~s/\*//g;
	$s_pak=~s/\*//g;
	
	# - read categories >
    my $cat_iter = $self->paths->pkg_db_dir->iterator;
    while( defined ( my $cat = $cat_iter->() )){ 
        my $tc = $cat->basename;
		$m_cat=0;
		if ($s_cat ne '') {
		    if ($tc=~m/$s_cat/i) {
			$m_cat=1;
			}
			else {
			    next;
			}
		}
			
		next if $self->_should_exclude($cat);	# - not excluded and $_ is a dir?
        next unless -d $cat;

        my $pkg_iter = $cat->iterator;
        while( defined ( my $pkg = $pkg_iter->() )) {
            my $tp = $pkg->basename;
			# - check if packagename matches
			#   (faster if we already check it now) >
			next unless ($tp =~m/$s_pak/i || $s_pak eq '');
            next if $self->_should_exclude( $pkg );
            next unless -d $pkg;

					# - not excluded and $_ is a dir?

			if (($s_cat ne '') && ($m_cat)) {
			    push(@matches,$tc.'/'.$tp);
			}
			elsif ($s_cat eq '') {
			    push(@matches,$tc.'/'.$tp);
			}
		}
	}
	
	return (sort @matches);
}

# Description:
# Search for packages in given repository.
# @packages=$pxs->searchPackage($searchString [,$mode, $repo] );
#
# Parameters:
# searchString: string to search for
# mode: like || exact
# repo: repository to search in
#
# Examples:
# @packages=$pxs->searchPackage('perl');
# @packages=$pxs->searchPackage('perl','exact');
# @packages=$pxs->searchPackage('perl','like','/usr/portage');
# @packages=$pxs->searchPackage('git','exact','/usr/local/portage');
sub searchPackage {
	my $self		= shift;
	my $searchString	= shift;
	my $mode		= shift;
	my $repo		= shift;
	my $dhc;
	my $dhp;
	my $tc;
	my $tp;
	my @matches		= ();
	
	if (!$mode) { $mode='like'; }
	$repo=$self->{'PORTDIR'} if (!$repo);
	if (!-d $repo) { return (); }
	
	# - escape special chars >
	if ($mode eq 'like') {
		$searchString =~ s/\+/\\\+/g;
		
		# - read categories >
		$dhc = new DirHandle($repo);
		if (defined $dhc) {
			while (defined($tc = $dhc->read)) {
				# - not excluded and $_ is a dir?
				if (! $self->{'EXCLUDE_DIRS'}{$tc} && -d $repo.'/'.$tc) {
					$dhp = new DirHandle($repo.'/'.$tc);
					while (defined($tp = $dhp->read)) {
						# - look up if entry matches the search
						#  (much faster if we already check now) >
						if ($tp =~m/$searchString/i) {
							# - not excluded and $_ is a dir?
							if (! $self->{'EXCLUDE_DIRS'}{$tp} && -d $repo.'/'.$tc.'/'.$tp) {
								push(@matches,$tc.'/'.$tp);
							}
						}
					}
					undef $dhp;
				}
			}
		}
		undef $dhc;
	}
	elsif ($mode eq 'exact') {
		# - read categories >
		$dhc = new DirHandle($repo);
		if (defined $dhc) {
			while (defined($tc = $dhc->read)) {
				# - not excluded and $_ is a dir?
				if (! $self->{'EXCLUDE_DIRS'}{$tc} && -d $repo.'/'.$tc) {
					$dhp = new DirHandle($repo.'/'.$tc);
					while (defined($tp = $dhp->read)) {
						# - look up if entry matches the search
						#  (much faster if we already check now) >
						if ($tp eq $searchString) {
							# - not excluded and $_ is a dir?
							if (! $self->{'EXCLUDE_DIRS'}{$tp} && -d $repo.'/'.$tc.'/'.$tp) {
								push(@matches,$tc.'/'.$tp);
							}
						}
					}
					undef $dhp;
				}
			}
		}
		undef $dhc;
	}
	
	return (sort @matches);
}

# Description:
# Returns the value of $param. Expects filecontents in $file.
# $valueOfKey=$pxs->getParamFromFile($filecontents,$key,{firstseen,lastseen});
# e.g.
# $valueOfKey=$pxs->getParamFromFile($pxs->getFileContents("/path/to.ebuild"),"IUSE","firstseen");
sub getParamFromFile {
	my $self	= shift;
	my $file	= shift;
	my $param	= shift;
	my $mode	= shift; # ("firstseen","lastseen") - default is "lastseen"
	my $c		= 0;
	my $d		= 0;
	my @lines	= ();
	my $value	= ''; # value of $param
	
	# - split file in lines >
	@lines = split(/\n/,$file);
	
	for($c=0;$c<=$#lines;$c++) {
		next if $lines[$c]=~m/^#/;
		
		# - remove comments >
		$lines[$c]=~s/#(.*)//g;
		
		# - remove leading whitespaces and tabs >
		$lines[$c]=~s/^[ \t]+//;
		
		if ($lines[$c]=~/^$param="(.*)"/) {
			# single-line with quotationmarks >
			$value=$1;
		
			last if ($mode eq 'firstseen');
		}
		elsif ($lines[$c]=~/^$param="(.*)/) {
			# multi-line with quotationmarks >
			$value=$1.' ';
			for($d=$c+1;$d<=$#lines;$d++) {
				# - look for quotationmark >
				if ($lines[$d]=~/(.*)"?/) {
					# - found quotationmark; append contents and leave loop >
					$value.=$1;
					last;
				}
				else {
					# - no quotationmark found; append line contents to $value >
					$value.=$lines[$d].' ';
				}
			}
		
			last if ($mode eq 'firstseen');
		}
		elsif ($lines[$c]=~/^$param=(.*)/) {
			# - single-line without quotationmarks >
			$value=$1;
			
			last if ($mode eq 'firstseen');
		}
	}
	
	# - clean up value >
	$value=~s/^[ \t]+//; # remove leading whitespaces and tabs
	$value=~s/[ \t]+$//; # remove trailing whitespaces and tabs
	$value=~s/\t/ /g;     # replace tabs with whitespaces
	$value=~s/ {2,}/ /g;  # replace 1+ whitespaces with 1 whitespace
	
	return $value;
}

# Description:
# Returns useflag settings of the given (installed) package.
# @useflags=$pxs->getUseSettingsOfInstalledPackage("dev-perl/perl-5.8.8-r3");
sub getUseSettingsOfInstalledPackage {
	my $self		= shift;
	my $package		= shift;
	my $tmp_filecontents	= '';
	my @package_IUSE	= ();
	my @package_USE		= ();
	my @USEs		= ();
	my $hasuse		= '';
	
	if (-e (my $path = $self->paths->pkg_db_dir->child($package,'IUSE') ) ) {
		$tmp_filecontents	= $path->slurp();
	}
	$tmp_filecontents	=~s/\n//g;
	@package_IUSE		= split(/ /,$tmp_filecontents);
	if (-e (my $path = $self->paths->pkg_db_dir->child($package,'USE'))) {
		$tmp_filecontents	= $path->slurp;
	}
	$tmp_filecontents	=~s/\n//g;
	@package_USE		= split(/ /,$tmp_filecontents);
	
	foreach my $thisIUSE (@package_IUSE) {
		next if ($thisIUSE eq '');
		$hasuse = '-';
		foreach my $thisUSE (@package_USE) {
			if ($thisIUSE eq $thisUSE) {
				$hasuse='';
				last;
			}
		}
		push(@USEs,$hasuse.$thisIUSE);
	}
	
	return @USEs;
}

# Description:
# @listOfEbuilds=$pxs->getAvailableEbuilds(category/packagename,[$repo]);
sub getAvailableEbuilds {
	my $self	= shift;
	my $catPackage	= shift;
	my $repo	= shift;
	my @packagelist	= ();
	
	$repo=$self->paths->portdir if (!$repo);
    if (!-d $repo) { return (); }
	
	if (-e $repo.'/'.$catPackage) {
		# - get list of ebuilds >
		my $dh = new DirHandle($repo.'/'.$catPackage);
		while (defined($_ = $dh->read)) {
			if ($_ =~ m/(.+)\.ebuild$/) {
				push(@packagelist,$_);
			}
		}
	}
	
	return @packagelist;
}

# Description:
# @listOfEbuildVersions=$pxs->getAvailableEbuildVersions(category/packagename,[$repo]);
sub getAvailableEbuildVersions {
	my $self	= shift;
	my $catPackage	= shift;
	my $repo	= shift;
	my @packagelist;

	@packagelist = map { $self->getEbuildVersion($_) } $self->getAvailableEbuilds($catPackage,$repo);

	return @packagelist;
}

# Description:
# $bestVersion=$pxs->getBestEbuildVersion(category/packagename,[$repo]);
sub getBestEbuildVersion {
	my $self	= shift;
	my $catPackage	= shift;
	my $repo	= shift;

	my @versions = map { PortageXS::Version->new($_) } $self->getAvailableEbuildVersions($catPackage,$repo);
	my @best_version = sort { $a <=> $b } (@versions);
	return $best_version[-1];
}

# Description:
# @listOfArches=$pxs->getAvailableArches();
sub getAvailableArches {
	my $self	= shift;
	return $self->paths->portdir->child('profiles','arch.list')->lines({chomp => 1 });
}

# Description:
# Reads from /etc/portagexs/categories/$listname.list and returns all entries as an array.
# @listOfCategories=$pxs->getPortageXScategorylist($listname);
sub getPortageXScategorylist {
	my $self	= shift;
	my $category	= shift;
	
	return $self->paths->etc_pxs->child('categories', $category . '.list')->lines({chomp => 1 });
}

# Description:
# Returns all available packages from the given category.
# @listOfPackages=$pxs->getPackagesFromCategory($category,[$repo]);
# E.g.:
# @listOfPackages=$pxs->getPackagesFromCategory("dev-perl","/usr/portage");
sub getPackagesFromCategory {
	my $self	= shift;
	my $category	= shift;
	my $repo	= shift;
	my @packages	= ();
	
	return () if !$category;
    if (!$repo ){ 
    	$repo=$self->paths->portdir
    } else {
        $repo = path($repo);
    }
	
	if (-d (my $dir = $repo->child($category))) {
        my $it = $dir->iterator;
		while (defined( my $tp = $it->() )) {
			# - not excluded and $_ is a dir?
            next if $self->_should_exclude($tp);
            next unless -d $tp;
			push(@packages,$tp);
		}
	}

	return @packages;
}

# Description:
# Returns package(s) where $file belongs to.
# (Actually this is an array and not a scalar due to a portage design bug.)
# @listOfPackages=$pxs->fileBelongsToPackage("/path/to/file");
sub fileBelongsToPackage {
	my $self	= shift;
	my $file	= shift;

	my @matches	= ();
	
    my $pkgdb = $self->paths->pkg_db_dir;

    my $cat_iterator = $pkgdb->iterator;

    while ( my $cat = $cat_iterator->() ) {
	# - read categories >
        my $tc = $cat->basename;
        next unless -d $cat;
        next if $self->_should_exclude($cat);
        my $pkg_iterator = $cat->iterator();
        if ( $ENV{PXS_DEBUG} ) {
            *STDERR->print("scanning $cat\n");
        }
        while ( my $pkg = $pkg_iterator->() ) {
            next unless -d $pkg;
            my $cfile = $pkg->child('CONTENTS');
            next unless -e -f $cfile;
            my $tp = $pkg->basename;
            my $fh = $cfile->openr;
			while (<$fh>) {
			    if ($_=~m/$file/) {
			        push(@matches,$tc.'/'.$tp);
    				last;
	    		}
			}
			close $fh;
        }
	}
	
	return @matches;
}

# Description:
# Returns all files provided by $category/$package.
# @listOfFiles=$pxs->getFilesOfInstalledPackage("$category/$package");
sub getFilesOfInstalledPackage {
	my $self	= shift;
	my $package	= shift;
	my @files	= ();
	
	# - find installed versions & loop >
	foreach ($self->searchInstalledPackage($package)) {
		foreach ($self->paths->pkg_db_dir->child($_)->child('CONTENTS')->lines({chomp => 1 }) ) {
			push(@files,(split(/ /,$_))[1]);
		}
	}

	return @files;
}

# Description:
# Returns version of an ebuild.
# $version=$pxs->getEbuildVersion("foo-1.23-r1.ebuild");
sub getEbuildVersion {
	my $self	= shift;
	my $version	= shift;
	$version =~ s/\.ebuild$//;
	$version =~ s/^([a-zA-Z0-9\-_\/\+]*)-([0-9\.]+[a-zA-Z]?)/$2/;
	
	return $version;
}

# Description:
# Returns name of an ebuild (w/o version).
# $version=$pxs->getEbuildName("foo-1.23-r1.ebuild");
sub getEbuildName {
	my $self	= shift;
	my $version	= shift;
	my $name	= $version;
	
	$version =~ s/^([a-zA-Z0-9\-_\/\+]*)-([0-9\.]+[a-zA-Z]?)/$2/;
	
	return substr($name,0,length($name)-length($version)-1);
}

# Description:
# Returns the repo_name of the given repo.
# $repo_name=$pxs->getReponame($repo);
# Example:
# $repo_name=$pxs->getRepomane("/usr/portage");
sub getReponame {
	my $self	= shift;
	my $repo	= shift;
	my $repo_name	= '';
	
	if (-f ( my $reponame_file = path($repo)->child('profiles','repo_name'))) {
		$repo_name = $reponame_file->slurp;
		chomp($repo_name);
		return $repo_name;
	}
	
	return '';
}

# Description:
# Returns an array of URLs of the given mirror.
# @mirrorURLs=$pxs->resolveMirror($mirror);
# Example:
# @mirrorURLs=$pxs->resolveMirror('cpan');
sub resolveMirror {
	my $self	= shift;
	my $mirror	= shift;
	
	foreach ($self->paths->portdir->child('profiles')->child('thirdpartymirrors')->lines({chomp => 1}) ) {
		my @p=split(/\t/,$_);
		if ($mirror eq $p[0]) {
			return split(/ /,$p[2]);
		}
	}
	
	return;
}

# Description:
# Returns list of valid categories (from $repo/profiles/categories)
# @categories=$pxs->getCategories($repo);
# Example:
# @categories=$pxs->getCategories('/usr/portage');
sub getCategories {
	my $self	= shift;
	my $repo	= shift;
	
	if (-e $repo.'/profiles/categories') {
		return path($repo)->child('profiles/categories')->lines;
	}
	
	return ();
}

# Description:
# Returns path to profile.
# $path=$pxs->getProfilePath();
sub getProfilePath {
	my $self	= shift;
	
	if (-e ( my $path = $self->paths->make_profile )) { 
        if ( -l $path ) { 
            return path(readlink($path));
        } else {
            return $path;
        }
	}
	
	return;
}

# Description:
# Returns all packages that are in the world file.
# @packages=$pxs->getPackagesFromWorld();
sub getPackagesFromWorld {
	my $self	= shift;
	
    return if not -e $self->paths->worldfile;
	return $self->paths->worldfile->lines({chomp => 1});
	
	return ();
}

# Description:
# Records package in world file.
# $pxs->recordPackageInWorld($package);
sub recordPackageInWorld {
	my $self	= shift;
	my $package	= shift;
	my %world	= ();
	
	# - get packages already recorded in world >
	foreach ($self->getPackagesFromWorld()) {
		$world{$_}=1;
	}
	
	# - add $package >
	$world{$package}=1;
	
	# - write world file >
	my $fh = $self->paths->worldfile->openw;
	foreach (keys %world) {
		print $fh $_,"\n";
	}
	close $fh;
	
	return 1;
}

# Description:
# Removes package from world file.
# $pxs->removePackageFromWorld($package);
sub removePackageFromWorld {
	my $self	= shift;
	my $package	= shift;
	my %world	= ();
	
	# - get packages already recorded in world >
	foreach ($self->getPackagesFromWorld()) {
		$world{$_}=1;
	}
	
	# - remove $package >
	$world{$package}=0;
	
	# - write world file >
	my $fh = $self->paths->worldfile->openw;
	foreach (keys %world) {
		print $fh $_,"\n" if ($world{$_});
	}
	close $fh;
	
	return 1;
}

# Description:
# Returns path to profile.
# $pxs->resetCaches();
sub resetCaches {
	my $self	= shift;
	
	# - Core >
    my $portdir = $self->paths->portdir;	
	# - Console >
	
	# - System - getHomedir >
	$self->{'CACHE'}{'System'}{'getHomedir'}{'homedir'}=undef;
	
	# - Useflags - getUsedescs >
	foreach my $k1 (keys %{$self->{'CACHE'}{'Useflags'}{'getUsedescs'}}) {
		$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$k1}{'use.desc'}{'initialized'}=undef;
		foreach my $k2 (keys %{$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$k1}{'use.desc'}{'use'}}) {
			$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$k1}{'use.desc'}{'use'}{$k2}=undef;
		}
		$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$k1}{'use.desc'}{'use'}=undef;
		$self->{'CACHE'}{'Useflags'}{'getUsedescs'}{$k1}{'use.local.desc'}=undef;
	}
	
	# - Useflags - getUsemasksFromProfile >
	$self->{'CACHE'}{'Useflags'}{'getUsemasksFromProfile'}{'useflags'}=undef;
	
	return 1;
}

# Description:
# Search packages by maintainer. Returns an array of packages.
# @packages=$pxs->searchPackageByMaintainer($searchString,[$repo]);
# Example:
# @packages=$pxs->searchPackageByMaintainer('ian@gentoo.org');
# @packages=$pxs->searchPackageByMaintainer('ian@gentoo.org','/usr/local/portage/');
sub searchPackageByMaintainer {
	my $self		= shift;
	my $searchString	= shift;
	my $repo		= shift;
	my $dhc;
	my $dhp;
	my $tc;
	my $tp;
	my @matches		= ();
	my @fields		= ();
	
	#if (!$mode) { $mode='like'; }
	$repo=$self->{'PORTDIR'} if (!$repo);
	if (!-d $repo) { return (); }
	
	# - read categories >
	foreach ($self->searchPackage('','like',$repo)) {
		if (-e $repo.'/'.$_.'/metadata.xml') {
			my $buffer=$self->getFileContents($repo.'/'.$_.'/metadata.xml');
			if ($buffer =~ m/<email>$searchString(.*)?<\/email>/i) {
				push(@matches,$_);
			}
			elsif ($buffer =~ m/<name>$searchString(.*)?<\/name>/i) {
				push(@matches,$_);
			}
		}
	}
	
	return (sort @matches);
}

# Description:
# Search packages by herd. Returns an array of packages.
# @packages=$pxs->searchPackageByHerd($searchString,[$repo]);
# Example:
# @packages=$pxs->searchPackageByHerd('perl');
# @packages=$pxs->searchPackageByHerd('perl','/usr/local/portage/');
sub searchPackageByHerd {
	my $self		= shift;
	my $searchString	= shift;
	my $repo		= shift;
	my $dhc;
	my $dhp;
	my $tc;
	my $tp;
	my @matches		= ();
	my @fields		= ();
	
	#if (!$mode) { $mode='like'; }
	$repo=$self->{'PORTDIR'} if (!$repo);
	if (!-d $repo) { return (); }
	
	# - read categories >
	foreach ($self->searchPackage('','like',$repo)) {
		if (-e $repo.'/'.$_.'/metadata.xml') {
			my $buffer=$self->getFileContents($repo.'/'.$_.'/metadata.xml');
			if ($buffer =~ m/<herd>$searchString(.*)?<\/herd>/i) {
				push(@matches,$_);
			}
		}
	}
	
	return (sort @matches);
}

1;
