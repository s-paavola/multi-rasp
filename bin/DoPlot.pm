#############################################################################
### DoPlot object definition
#############################################################################

package DoPlot;

use Moose;

# Job being processed process
has 'time' => (
is          => 'ro',
isa         => 'Str',
required    => 1,
);

# Menu row
has 'row' => (
is          => 'ro',
isa         => 'Int',
required    => 1,
);

# Input wrf file to process
has 'wrfFile' => (
is          => 'ro',
isa         => 'Str',
required    => 1,
);

# Environmental args
has 'args' => (
is          => 'ro',
isa         => 'Str',
required    => 1,
);

# Plot directory
has 'plotDir' => (
is          => 'ro',
isa         => 'Str',
required    => 1,
);

# Log filename
has 'logFile' => (
is          => 'ro',
isa         => 'Str',
required    => 1,
);

# plot flag
has 'doPlot' => (
is          => 'ro',
isa         => 'Int',
required    => 1,
);

sub run {
    my $self = shift;
    my $time;
    my $plotDir = $self->plotDir;
    my $wrfFile = $self->wrfFile;
    my $logFile = $self->logFile;
    my $args = $self->args;
    
    chomp ($time = `/usr/bin/date +%H:%M:%S`);
    # NOTE: the following line prints the number of plot jobs remaining, including
    # those currently in process. It will never be 1 unless there's only one thread.
    print "   $time: Plotting $wrfFile - $::plotCount\n";
    $? = 0;
    qx(cd $::BASEDIR/GM; . ../rasp.site.runenvironment;
       echo \$LD_LIBRARY_PATH > ~/lib_path;
       $args ncl -n -p < wrf2gm.ncl > $logFile 2>&1) if $self->doPlot;
    
    qx($args /usr/bin/cp -p `/usr/bin/dirname $wrfFile`/namelist.wps HTML/$plotDir);
    
    if ($? != 0 )
    {
        die "***  ncl $wrfFile failed: See $logFile\n" ;
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
