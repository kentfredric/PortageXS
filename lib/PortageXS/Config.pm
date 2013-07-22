
use strict;
use warnings;

package PortageXS::Config;

# ABSTRACT: Wrapper around C<make.*> in portage.
use Moo;

sub has_lazy {
    my ( $name, @args ) = @_;
    unshift @args, ( is => ro => );
    unshift @args, ( lazy => 1 );
    has ($name,@args);
}

has_lazy 'portagexs' => weak_ref => 1;

has_lazy configlines => builder => sub {

    my @lines;

    my @targets;
    push @targets, $_[0]->portagexs->paths->make_globals_old;
    push @targets, $_[0]->portagexs->paths->make_globals;
    push @targets, $_[0]->portagexs->paths->make_conf_old;
    push @targets, $_[0]->portagexs->paths->make_conf;

    for my $target ( @targets ) { 
        next unless -e $target;
        push @lines, $target->lines({chomp => 1 });
    }
    return \@lines;
};


sub getParam {
	my $self	= shift;
	my $param	= shift;
	my $mode	= shift; # ("firstseen","lastseen") - default is "lastseen"
	my $c		= 0;
	my $d		= 0;
	my @lines	= ();
	my $value	= ''; # value of $param
	
	# - split file in lines >
	@lines = @{ $self->configlines };
	
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

1;
