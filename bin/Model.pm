#############################################################################
### Model object definition
#############################################################################

package Model;

use feature state;
use integer;

use Moose;
use DateTime;
use DoPlot;
use threads;
use threads::shared;
use FileHandle;
use Fcntl qw(:flock);

extends 'ModelDef';

# JobArg that created this model
has 'jobArg' => (
is          => 'rw',
isa         => 'Str',
);

# Grid to use
has 'grid' => (
is          => 'ro',
isa         => 'Str',
required	=> 1,
);

# Timezone for job
has 'timeZone' => (
is          => 'ro',
isa         => 'Str',
required    => 1,
);

# Relative output directory for plots
has 'day' => (
is          => 'ro',
isa         => 'Int',
required    => 1,
);

# Plot times
has 'plotTimes' => (
is          => 'ro',
isa         => 'ArrayRef[Int]',
required    => 1,
);

# Plot image size
has 'plotSize' => (
is          => 'ro',
isa         => 'Str',
);

# Directory holding grib files
has 'gribDir' => (
is          => 'rw',
isa         => 'Str',
);

# Reference directory for the region
has 'refDir' => (
is          => 'rw',
isa         => 'Str',
);

# Temp directory for working files
has 'tempDir' => (
is          => 'rw',
isa         => 'Str',
);

# Directory for log files
has 'logDir' => (
is          => 'rw',
isa         => 'Str',
);

# Base directory for output plots
has 'plotBaseDir' => (
is          => 'rw',
isa         => 'Str',
);

# Directory for output plots
has 'plotDir' => (
is          => 'rw',
isa         => 'Str',
);

# Log verbosity
has 'VERBOSE' => (
is          => 'rw',
isa         => 'Int',
);

# start time
has 'firstGribDate' => (
is          => 'rw',
isa         => 'DateTime',
init_arg    => undef,
);

# wps end time
has 'lastGribDate' => (
is          => 'rw',
isa         => 'DateTime',
init_arg    => undef,
);

# list of grib files
has 'gribList' => (
is          => 'ro',
isa         => 'ArrayRef[Str]',
lazy        => 1,
builder     => '_buildGribList',
);

# Stages of processing (in order)
our @stages = (
"download",
"ungrib",
"metgrid",
"real",
"wrf",
"plot",
"final",
);

# First processing stage
our $firstStage = $stages[0];

# Lock file fileHandle

my $lockFile;

sub doStage
{
    my $stageName = shift;
    state $first = 1;
    for (@stages)
    {
        last if ($_ eq $firstStage);
        return 0 if ($_ eq $stageName);
    }
    print "   Starting at stage $firstStage\n" if ($first && ($stageName eq $firstStage));
    $first = 0;
    return 1;
}

my $_modelList;

# Add plots from web page to modelList
{
    open PARAM_LIST, "<", "HTML/newParamList.js";
    # Skip to start of full list
    while (<PARAM_LIST>)
    {
        last if m/var[\s]+plotsList *=/;
    }
    
    $_modelList = "soundings";      # Always do soundings
    # Append plots
    while (<PARAM_LIST>)
    {
        last if m/\]/;
        chomp;
        s|//.*||;
        s/[\s]+"*//;
        s/".*//;
        next if m/^nope_/;
        next if m/topo/;
        next unless $_;
        $_modelList .= ":$_";
    }
    close PARAM_LIST;
    my $count = split ":", $_modelList;
    die "No plots found" if ($count == 1);
}

# Print out formatted log message
sub _log {
    my $self = shift;
    my $time = `/usr/bin/date +%H:%M:%S`;
    chomp $time;
    print "   $time ", $self->jobArg, ": ", @_, "\n";
}

# Print out formatted log message
sub _debug {
    my $self = shift;
    return unless $self->VERBOSE;
    print "-- ", $self->jobArg, ": ", @_, "\n";
}

# Get grib list
sub _buildGribList {
    my $self = shift;
    my $validTimes = $self->validTimes;

    my @plotTimes = @{$self->plotTimes};
    # firstTime is one hour early because first plot is garbage
    
    my $firstTime = substr $plotTimes[0]-1, 0, 2;
    my $lastTime = substr $plotTimes[-1] + 59, 0, 2;
    $firstTime += $self->day * 24;
    $lastTime += $self->day * 24;
    
    $self->_debug( "Get grib files spanning " . $firstTime . " to " . $lastTime);
    my $series = $self->analTime->hour;
    
    # Check if lastTime is beyond the last valid time
    return [] if ($$validTimes[0] < $lastTime - $series);
    # Check if firstTime is before analTime
    return [] if ($firstTime < $series);
    
    # Find first valid offset to use
    my $stride = $$validTimes[1];
    my $first_offset = ($firstTime - $series)/$stride;
    my $last_offset = ($lastTime - $series + $stride - 1) / $stride;
    # return if run starts after first time for the day
    return [] if $first_offset < 0;
    my @list;
    for (my $i = $first_offset; $i <= $last_offset; $i++)
    {
        push( @list, sprintf( $self->fileNameProto, $series, $i*$stride ) );
    }
    
    # Cache first & last grib date/time
    $self->firstGribDate($self->analTime->clone->add(hours => $first_offset * $stride));
    $self->lastGribDate($self->analTime->clone->add(hours => $last_offset * $stride));
    return \@list;
}

# Determine directory that holds run tables
sub _getTablePath {
    my $self = shift;
    my $table = shift;
    my $base = "$::BASEDIR/RUN.TABLES";
    my $ret = "$base/" . $self->modelName . "/$table";
    return $ret if -f $ret;
    return "$base/$table";
}

# Do wps prep
sub _do_prep {
    my $self = shift;
    my $refDir  = $self->refDir;
    my $tempDir = $self->tempDir;
    my $logDir  = $self->logDir;
    my $gribDir = "$::BASEDIR/".$self->gribDir;

    # setup links to RUN.TABLES
    (my $ucName = $self->modelName) =~ tr/a-z/A-Z/;
    for ("GENPARM.TBL", "LANDUSE.TBL", "SOILPARM.TBL", "VEGPARM.TBL",
        "ETAMPNEW_DATA.expanded_rain", "Vtable.".$ucName, "RRTM_DATA",
	)
    {
        next if -e "$tempDir/$_";
	`rm -f $tempDir/$_`;
	my $tablePath = $self->_getTablePath($_);
	`/usr/bin/ln -s $tablePath $tempDir`;
        die "Failed to link $tempDir/$_" unless -e "$tempDir/$_";
    }
    `/usr/bin/rm -f $tempDir/Vtable; /usr/bin/ln -s Vtable.$ucName $tempDir/Vtable`;
    die "Failed to link $tempDir/Vtable" unless $? == 0;
    
    
    # setup links to ref dir
    for ("geo_em.d01.nc", "geo_em.d02.nc")
    {
        my $src = "$refDir/" . $self->grid . "/$_";
        qx|/usr/bin/rm -f $tempDir/$_; /usr/bin/ln -s $src $tempDir|;
        die "Failed to link $src to $tempDir/$_" unless $? == 0;
    }
    
    # create namelist.wps
    my $startDate = $self->firstGribDate->format_cldr("yyyy-MM-dd_HH:mm:ss");
    my $endDate = $self->lastGribDate->format_cldr("yyyy-MM-dd_HH:mm:ss");
    
    # Seconds between valid times to use
    my $validTimes = $self->validTimes;
    my $interval_seconds = $$validTimes[1] * 3600;

    # Path to METGRID.TBL
    my $path = $self->_getTablePath("METGRID.TBL");
    my $METGRID_TBL_PATH = `dirname $path`;
    chomp ($METGRID_TBL_PATH);
    
    my $wpsInput = "$refDir/" . $self->grid . "/namelist.wps";
    open (NAMELIST, "<", "$wpsInput") or die "Can't open $wpsInput - $!";
    open (NEWNAMELIST, ">", "$tempDir/namelist.wps") or die "Can't open namelist.wps - $!";
    while (<NAMELIST>)
    {
        s|=.*|= \'$startDate\', \'$startDate\'| if m|start_date|i;
        s|=.*|= \'$endDate\', \'$endDate\'| if m|end_date|i;
        s|=.*|= $interval_seconds|   if m|interval_seconds|i;
        s|=.*|= \'$gribDir/UNGRIB\'|   if m|fg_name|i;
        s|=.*|= \'$METGRID_TBL_PATH\'|   if m|METGRID_TBL_PATH|i;
        print NEWNAMELIST $_;
    }
    close NAMELIST;
    close NEWNAMELIST;
}

# check if can run ungrib - checks for lock
sub canRunUngrib
{
    my $self = shift;
    my $gribDir = "$::BASEDIR/".$self->gribDir;

    # Open the lock file
    my $fileName="$gribDir/.lock";
    $self->_debug("lockfile $fileName");
    `touch $fileName`;		# make sure file exists before opening
    open($lockFile, "+<", $fileName) or die "$fileName: $!";
    # lock the GRIB directory from other ungribs
    if (!flock ($lockFile, LOCK_EX | LOCK_NB))
    {
	close $lockFile;
	return 0;
    }
    #seek($lockFile, 0, 0);
    truncate($lockFile, 0);
    print $lockFile $self->jobArg."\n";
    return 1;
}

# run ungrib
sub _do_ungrib
{
    my $self = shift;
    my $refDir  = $self->refDir;
    my $tempDir = $self->tempDir;
    my $logDir  = $self->logDir;
    my $gribDir = "$::BASEDIR/".$self->gribDir;

    $self->_log( "Starting ungrib");
    # verify the lock
    seek($lockFile, 0, 0);
    my $cnt = read ($lockFile, my $lock, 100);
    die "$!" unless defined $cnt;
    die "Wrong ungrib lock: found '$lock' should be '" . $self->jobArg . "'" unless ($lock eq $self->jobArg."\n");
    # determine needed date ranges
    while ($self->_create_grib_namelist())
    {
	# run ungrib
	`rm -f $gribDir/PFILE* > /dev/null 2>&1`;
	(my $ucName = $self->modelName) =~ tr/a-z/A-Z/;
	my $tablePath = $self->_getTablePath("Vtable.$ucName");
	`/usr/bin/rm -f $gribDir/Vtable; /usr/bin/ln -s $tablePath $gribDir/Vtable`;
	`cd $gribDir; $::BINDIR/ungrib.exe > $logDir/ungrib.out 2>&1`;
	`mv $gribDir/ungrib.log $tempDir`;
	`/usr/bin/grep -q 'Successful completion of ' $logDir/ungrib.out`;
	if ($? != 0)
	{
	    flock($lockFile, LOCK_UN);
	    close $lockFile;
	    die "***  Ungrib failed: See $tempDir/ungrib.log and LOG/ungrib.out\n" ;
	}
    }
    flock($lockFile, LOCK_UN);
    close $lockFile;
}

# create namelist.wps for _do_ungrib - covers just a range not run yet
sub _create_grib_namelist
{
    my $self = shift;
    my $tempDir = $self->tempDir;
    my $gribDir = "$::BASEDIR/".$self->gribDir;
    my $stride = ${$self->validTimes}[1];
    my @alphabet = ('A' .. 'Z');

    qx|rm -f $gribDir/GRIBFILE*|;
    my ($start, $end);
    my $gribList = $self->gribList();
    my $seq = 0;
    for my $idx (0 .. $#$gribList)
    {
	my $t = $self->firstGribDate->clone->add(hours => $idx * $stride);
	my $fname = "UNGRIB:" . $t->format_cldr("yyyy-MM-dd_HH");
	if (-f "$gribDir/$fname")
	{
	    last if $end;
	}
	else
	{
	    $end = $t->format_cldr("yyyy-MM-dd_HH:mm:ss");
	    $start = $end unless ($start);
	    my $a1 = $seq % @alphabet;
	    my $a2 = ($seq / @alphabet) % @alphabet;
	    my $a3 = ($seq / @alphabet / @alphabet);
	    my $localName = "GRIBFILE." . $alphabet[$a3] . $alphabet[$a2] . $alphabet[$a1];
	    $self->_debug( "-- link $localName to ".$$gribList[$idx]);
	    qx(ln -s $$gribList[$idx] $gribDir/$localName);

	    $seq ++;
	    last if ($seq >= 5);
	}
    }
    return undef unless $start;;
    my $wpsInput = "$tempDir/namelist.wps";
    open (NAMELIST, "<", "$wpsInput") or die "Can't open $wpsInput - $!";
    open (NEWNAMELIST, ">", "$gribDir/namelist.wps") or die "Can't open namelist.wps - $!";
    while (<NAMELIST>)
    {
        s|=.*|= \'$start\',| if m|start_date|i;
        s|=.*|= \'$end\',| if m|end_date|i;
        s|=.*|= \'UNGRIB\',| if m|prefix|i;
        print NEWNAMELIST $_;
    }
    close NAMELIST;
    close NEWNAMELIST;
    return 1;
}

#run metgrid
sub _do_metgrid
{
    my $self = shift;
    my $refDir  = $self->refDir;
    my $tempDir = $self->tempDir;
    my $logDir  = $self->logDir;

    # Run metgrid
    $self->_log( "Starting metgrid" );
    `rm -f $tempDir/met_em* > /dev/null 2>&1`;
    `cd $tempDir; $::BINDIR/metgrid.exe > $logDir/metgrid.out 2>&1`;
    `/usr/bin/grep -q 'Successful completion of ' $logDir/metgrid.out`;
    if ( $? != 0 )
    {
        die "***  Metgrid failed: See $tempDir/metgrid.log and LOG/metgrid.out\n" ;
    }
}

# Create namelist.input from namelist.wps and start/stop dateTimes
sub _create_namelistInput
{
    my $self = shift;
    my $start = shift;
    my $stop = shift;
    my $refDir  = $self->refDir;
    my $tempDir = $self->tempDir;
    my %subs;

    
    # Get values from a met_em file
    my $filename = `/usr/bin/ls $tempDir/met_em.d01*.nc | /usr/bin/tail -1`;
    chomp $filename;
    foreach my $name ("num_metgrid_levels", "num_metgrid_soil_levels", "num_land_cat")
    {
        my $n = `ncdump -h $filename | /usr/bin/grep -i "$name *="`;
        next if ($n eq "");
        my ($num) = $n =~ m{([0-9]+)};
        $self->_debug(  "$name = $num" );
        $subs{lc $name} = $num if ($num ne "")
    }
    
    # get grid parameters from namelist.wps
    my $wpsInput = "$refDir/" . $self->grid . "/namelist.wps";
    open (WPS, "<", "$wpsInput") or die "Can't open $wpsInput - $!";
    while (<WPS>)
    {
        chomp;
        my @line = split;
        my $name = $line[0];
        ($subs{$name} = $_) =~ s|.*=[\s]*|| if m|max_dom|;
        ($subs{$name} = $_) =~ s|.*=[\s]*|| if m|i_parent_start|;
        ($subs{$name} = $_) =~ s|.*=[\s]*|| if m|j_parent_start|;
        ($subs{$name} = $_) =~ s|.*=[\s]*|| if m|e_we|;
        ($subs{$name} = $_) =~ s|.*=[\s]*|| if m|e_sn|;
        ($subs{$name} = $_) =~ s|.*=[\s]*|| if m|parent_grid_ratio|;
        ($subs{$name} = $_) =~ s|.*=[\s]*|| if m|dx|;
        ($subs{$name} = $_) =~ s|.*=[\s]*|| if m|dy|;
    }
    close WPS;
    (my $dx = $subs{"dx"}) =~ s/,//;
    (my $ratio = $subs{"parent_grid_ratio"}) =~ s/.*,.*([0-9])+,/$1/;
    $subs{"dx"} = join (", ", ($dx, $dx/$ratio)) . ",";
    (my $dy = $subs{"dy"}) =~ s/,//;
    $subs{"dy"} = join (", ", ($dy, $dy/$ratio)) . ",";
    
    # get times for namelist.input
    $subs{"run_days"}         = "0,";	# Make sure = 0, so that only start_* & end_* are used
    $subs{"run_hours"}        = "0,";
    $subs{"run_minutes"}      = "0,";
    $subs{"run_seconds"}      = "0,";
    $subs{"start_year"}       = "";
    $subs{"start_month"}      = "";
    $subs{"start_day"}        = "";
    $subs{"start_hour"}       = "";
    $subs{"start_minute"}     = "";
    $subs{"start_second"}     = "";
    $subs{"end_year"}         = "";
    $subs{"end_month"}        = "";
    $subs{"end_day"}          = "";
    $subs{"end_hour"}         = "";
    $subs{"end_minute"}       = "";
    $subs{"end_second"}       = "";

    (my $MAXDOMAIN = $subs{"max_dom"}) =~ s/,//;
    for ( 1 .. $MAXDOMAIN )
    {
        $subs{"start_year"}   .= $start->format_cldr(" yyyy,");
        $subs{"start_month"}  .= $start->format_cldr(" MM,");
        $subs{"start_day"}    .= $start->format_cldr(" dd,");
        $subs{"start_hour"}   .= $start->format_cldr(" HH,");
        $subs{"start_minute"} .= " 00,";
        $subs{"start_second"} .= " 00,";
        $subs{"end_year"}     .= $stop->format_cldr(" yyyy,");
        $subs{"end_month"}    .= $stop->format_cldr(" MM,");
        $subs{"end_day"}      .= $stop->format_cldr(" dd,");
        $subs{"end_hour"}     .= $stop->format_cldr(" HH,");
        $subs{"end_minute"}   .= " 00,";
        $subs{"end_second"}   .= " 00,";
    }
    
    
    # Seconds between valid times to use
    my $validTimes = $self->validTimes;
    $subs{"interval_seconds"} = $$validTimes[1] * 3600;
    
    foreach my $k (keys %subs)
    {
        $self->_debug("$k = " . $subs{$k});
    }

    # Create namelist.input
    my $namelistTemplate = $self->_getTablePath("namelist.input.template");
    open(OLDNAMELIST, "<", "$namelistTemplate") or
      die "Missing $namelistTemplate - Run aborted" ;
    open(NEWNAMELIST, ">", "$tempDir/namelist.input");
    while (<OLDNAMELIST>)
    {
        my @line = split;
        if (@line > 2)
        {
            my $name = $line[0];
            s|=.*|= $subs{$name}|     if (defined($subs{$name}));
        }
        print NEWNAMELIST;
    }
    close OLDNAMELIST;
    close NEWNAMELIST;
}

# Run real
sub _do_real
{
    my $self = shift;
    my $refDir  = $self->refDir;
    my $tempDir = $self->tempDir;
    my $logDir  = $self->logDir;
    
    $self->_log( "Starting real");
    
    $self->_create_namelistInput($self->firstGribDate, $self->lastGribDate);
    
    # run real.exe
    `cd $tempDir; $::BINDIR/real.exe > $logDir/real.out 2>&1`;
    `/usr/bin/grep -q 'SUCCESS COMPLETE REAL_EM INIT' $logDir/real.out`;
    if ($? != 0 )
    {
        die "***  real.exe failed: See $tempDir/LOG/real.out\n" ;
    }
}

# Delete any previous wrf output files
sub _clean_wrf {
    my $self = shift;
    my $tempDir = $self->tempDir;
    `rm -f $tempDir/wrfout_d*`;
}

# Run wrf
sub _run_wrf {
    my $self = shift;
    my $tempDir = $self->tempDir;
    my $logDir  = $self->logDir;
    
    # run wrf.exe
    $self->_log( "Starting wrf" );

    # Build namelist.input
    my $t = $self->firstGribDate->clone;
    $t->set_hour(0)->set_minute(0);
    my $hour = substr ${$self->plotTimes}[-1], 0, 2;
    my $minute = substr ${$self->plotTimes}[-1], 2, 2;
    my $t1 = $t->add(hours => $hour, minutes => $minute);
    $self->_create_namelistInput($self->firstGribDate, $t);
    
    `cd $tempDir; $::BINDIR/wrf.exe >| $logDir/wrf.out 2>&1`;
    my $time = `date +%H:%M:%S`;
    chomp $time;
    `/usr/bin/grep -q 'SUCCESS COMPLETE WRF' $logDir/wrf.out`;
    if ($? != 0 )
    {
        die "***  wrf.exe failed: See $tempDir/LOG/wrf.out\n" ;
    }
}

# Generate the plots
sub _get_plots {
    my $self = shift;
    my $outBase = shift;
    my $plotQueue = shift;
    my $refDir  = $self->refDir;
    my $tempDir = $self->tempDir;
    my $logDir  = $self->logDir;
    my $plotBaseDir = $self->plotBaseDir;
    my $plotDir = $self->plotDir;

    $self->_debug( "Queue plots" );
    
    # Get max number domains
    my $wpsInput = "$refDir/" . $self->grid . "/namelist.wps";
    my $MAXDOMAIN = `/usr/bin/awk 'tolower(\$1) == "max_dom" {print \$3}' $wpsInput`;
    $MAXDOMAIN =~ s/[^0-9]+//;
    $self->_debug( "MAXDOMAIN is $MAXDOMAIN" );
    
    # Collect some NCL parameters
    (my $GRIBFILE_MODEL = $self->modelName) =~ tr/a-z/A-Z/;
    (my $regionname = $self->jobArg) =~ s|/.*||;
    `mkdir -p "$plotBaseDir/$plotDir"`;
    my $imageSize = 1600;
    if (defined $self->plotSize)
    {
        my ($imagewidth, $imageheight) = split( /[^0-9]/, $self->plotSize);
        $imageSize = $imagewidth > $imageheight ? $imagewidth : $imageheight;
    }
    $self->_debug( "NCL params: model $GRIBFILE_MODEL region $regionname size $imageSize" );
    
    my $t = $self->firstGribDate->clone;
    $t->set_hour(0)->set_minute(0);
    my $first = 1;
    for (@{$self->plotTimes})
    {
        my $hour = substr $_, 0, 2;
        my $minute = substr $_, 2, 2;
        my $hrFcst = $hour - $self->analTime->hour() + $self->day * 24;
        my $t1 = $t->clone->add(hours => $hour, minutes => $minute);
        my $zTime = $t1->format_cldr("HHmm");
        my $file = "wrfout_d0$MAXDOMAIN" . $t1->format_cldr("_yyyy-MM-dd_HH:mm:ss");
        $self->_debug( "Queueing $file" );
        
        my $args = "ENV_NCL_INITMODE=$GRIBFILE_MODEL";
        $args .= " ENV_NCL_REGIONNAME=$regionname";
        $args .= " ENV_NCL_FILENAME=$::BASEDIR/$tempDir/$file";
        $args .= " ENV_NCL_OUTDIR=$::BASEDIR/$plotBaseDir/$plotDir";
        $t1->set_time_zone($self->timeZone);
        $args .= " ENV_NCL_ID='Valid " . $t1->format_cldr("HHmm vvv") .
                            " ~Z75~(" . $zTime . "Z)~Z~" .
                            " " . $t1->format_cldr("EEE dd LLL yyyy") .
                            " ~Z75~[". $self->modelName . " " . $hrFcst .
                            "hrFcst\@" . DateTime->now->format_cldr("HHmm") . "z]~Z~'";
        $args .= " ENV_NCL_DATIME='Day= " . $t1->format_cldr("yyyy MM dd EEE") .
                            " ValidLST= " . $t1->format_cldr("HHmm vvv") .
                            " ValidZ= " . $zTime .
                            " Fcst= fx Init= ix'";
        $args .= " ENV_NCL_PARAMS=$_modelList";
        $args .= " GMIMAGESIZE=$imageSize";
        if ($ENV{"CONVERT"})
        {
            $args .= " CONVERT=$ENV{'CONVERT'}";
        } else {
            $args .= " CONVERT=convert";
        }
        if ($first && ($self->VERBOSE > 1))
        {
            my @envParams = `$args env`;
            $self->_debug( "NCL environmental params:" );
            for (@envParams)
            {
                $self->_debug( "  $_" );
            }
        }
        $first = 0;
        my $plot = DoPlot->new(
            time => $t1->strftime("%H%M"),
            row => $self->day,
            wrfFile => $self->tempDir . "/$file",
            args => $args,
            plotDir => $self->plotDir,
            logFile => "$logDir/ncl.out.$_",
            doPlot => doStage("plot"));
        $plotQueue->enqueue( shared_clone( $plot ) );
    }
}

# Check if model is runnable
# Returns >0 if all Grib files are available
#          0 if grib files will never be available (invalid config for this anal time)
#         -1 if grib files not yet available
sub runnable {
    my $self = shift;
    my $gribDir = $self->gribDir;
    my $tempDir = $self->tempDir;
    my $logDir  = $self->logDir;
    
    $self->_debug( "Checking" );
    qx(mkdir -p $tempDir);
    qx(mkdir -p $logDir);
    
    # check that files exist
    my $seq = 0;
    for (@{$self->gribList()})
    {
        my $file = "$gribDir/$_";
        return -1 unless ( -f $file && ! -z $file);
        $seq ++;
    }
    return $seq;
}

# Run model
sub run {
    my $self = shift;
    my $plotQueue = shift;
    my $outBase = "$self->plotBaseDir/$self->plotDir";
    
    $self->_do_prep();
    $self->_do_ungrib() if (doStage("ungrib"));
    $self->_do_metgrid() if (doStage("metgrid"));
    $self->_do_real() if (doStage("real"));
    $self->_clean_wrf() if (doStage("wrf"));
    $self->_get_plots($outBase, $plotQueue) if (doStage("plot") || doStage("final"));
    $self->_run_wrf() if (doStage("wrf"));
}

no Moose;
__PACKAGE__->meta->make_immutable;
