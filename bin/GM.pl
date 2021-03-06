#! /usr/bin/perl

use strict;
use warnings;

#########################################################################################
###  RASP (Regional Atmospheric Soaring Predictions) COMPUTER PROGRAM
###  Original Creator:  Dr. John W. (Jack) Glendening, Meterologist  2005
###  Script copyright 2005-2006  by Dr. John W. Glendening  All rights reserved.
###  External credits:
###    utilizes Weather Research and Forecasting (WRF) meteorological model
###    utilizes National Center for Atmospheric Research (NCAR) graphics
###    utilizes model output from the National Center for Environmental Prediction (NCEP)
#########################################################################################
### rasp.pl runs weather prediction model, producing soaring info from model output
### Written by Jack Glendening <glendening@drjack.info>, Jan 2005+
### Updated by Paul Scorer
### Re-written by Steve Paavola

#########################################################################
##
## Usage: GM.pl [jobarg*] [-d] [-t xx] [-v] [-s stage] [-h]
##
## jobarg is zero more more region/run.parameter references. If not specified,
##   *.run.parameters from the current directory will be run. If that doesn't
##   find any parameter files, $BINDIR/../*/*.run.parameters will be run, where
##   $BINDIR is the location of this script. Not providing any jobargs will
##   normally run all the region/run.parameter jobs.
##
##   If jobarg(s) are provided, they are passed through the bash filename
##   expansion capabilities to find run.parameter files to run. Useful
##   variations include:
##
##     NewEngland - will run all run.parameters files found in NewEngland
##     NewEngland/nam - will run NewEngland/nam.run.parameters
##     NewEngland/gfs\* - will run all NewEngland/gfs run.parameters
##
## -d will purge results for days prior to today
##
## -t xx specifies the requested model run time (in zulu hours). The minutes
##   and seconds in the current zulu time are zeroed, and the hour is set
##   to the argument. Pre-pending the time with + or - signs will adjust
##   the time by a day. -t +5 says to set the run time to 5Z tomorrow.
##   Specifying -t -5 says to use yesterday's data. Then for each weather
##   model being run, the time is rounded down to the latest valid run time
##   for that model. For example, specifying -t 7 for gfs or nam will result
##   in using the results of the 06z run because they only run every 6 hours.
##   This same -t 7 will use the 07z run from rap or hrrr because they run
##   every hour.
##
## -v increases verbosity to the log output. -v -v increases it even more.
##
## -s stage starts processing at a later stage for use when testing new features
##   and control flow. For example, -s ungrib start processing at the ungrib
##   stage bypassing downloading data, assuming that data has already been
##   downloaded. Note that this feature always requires that the corresponding
##   downloads are available. Specifying -s wrf still requires the downloads
##   to be available, even though they won't be used in the computations. Use the
##   -h option to see the list of stage keywords.
##
#########################################################################

use English;

### Find bindir, add it to @INC
our $BINDIR;
my $WORKING_DIR;
BEGIN
{
    $BINDIR = $0;
    $BINDIR =~ s|[^/]*$||;
    $BINDIR = "$ENV{'PWD'}/$BINDIR" unless ($BINDIR =~ m|^/|);
    push @INC, $BINDIR;
    $WORKING_DIR = $ENV{'PWD'};
    chdir "$BINDIR/.." or die "Couldn't chdir to $BINDIR/..";
    push @INC, ".";
}

### Turn on autoflush on STDOUT
$| = 1;

###### GET PROGRAM NAME
my $PROGRAM = $0;
$PROGRAM =~ s|.*/||;
$PROGRAM  =~ s|\.pl$||;
### Get program location
print "   $PROGRAM running from $BINDIR\n";
chomp (our $BASEDIR = `pwd`);
#our $NCLDIR = "$BASEDIR/GM";
$ENV{BASEDIR} = $BASEDIR;

### Process arguments
use DateTime;
use List::MoreUtils qw(uniq);
use threads;
use threads::shared;
use Model;
use Update;

my $analTime;
my @JOBARG;
my $VERBOSE = 0;
my $deleteArchive = 0;
my $stage = $Model::firstStage;
while (my $arg = shift)
{
    if ($arg =~ m/^-[h?]/)
    {
        &usage;
    }
    
    if ($arg =~ m/^-t$/)
    {
        $analTime = DateTime->now;
        $analTime->set_minute( 0 );
        $analTime->set_second( 0 );
        my $t = shift;
        while ($t =~ s/-//)
        {
            $analTime->subtract( days => 1 );
        }
        while ($t =~ s/\+//)
        {
            $analTime->add( days => 1);
        }
        $analTime->set_hour( $t );
        next;
    }
    
    if ($arg =~ m/^-s$/)
    {
        $stage = shift;
        my $found = 0;
        for (@Model::stages)
        {
            if ($_ eq $stage)
            {
                $found = 1;
                last;
            }
        }
        unless ($found)
        {
            print "Unknown stage name $stage\n";
            &usage;
        }
        $Model::firstStage = $stage;
        next;
    }
    
    if ($arg =~ m/^-d/)
    {
        $deleteArchive = 1;
        next;
    }
    
    if ($arg =~ m/^-v/)
    {
        $VERBOSE++;
        next;
    }
    
    # default
    $JOBARG[@JOBARG] = $arg;
}

### If JOBARG is empty, find a default
if (! @JOBARG)
{
    @JOBARG = `ls */*.run.parameters` unless @JOBARG = `ls $WORKING_DIR/*.run.parameters 2> /dev/null`;
}

### Expand regions to regions/all_models
{
    my @new_args;
    for (@JOBARG)
    {
        chomp;
        if ( -f $_)
        {
            push @new_args, $_;
            next;
        }
        push @new_args, `ls $_.run.parameters 2>/dev/null`;
        next if ($? == 0);
        
        push @new_args, `ls $_/*.run.parameters 2>/dev/null`;
        next if ($? == 0);
        
        print "<> Unknown region $_\n"; &usage;
    }
    @JOBARG = @new_args;
}

### Cleanup JOBARG
chomp for (@JOBARG);
s|\.run\.parameters$|| for (@JOBARG);
s|.*/([^/]+/[^/]+)$|$1| for (@JOBARG);

### Check JOBARG
for (@JOBARG)
{
    if ( ! -f "$_.run.parameters")
    {
        print "Invalid region/model $_\n";
        &usage;
    }
}

### Get site params
our $numThreads = `grep -c processor /proc/cpuinfo` + 1;
our $numPlotThreads :shared = 2;
our $ADMIN_EMAIL_ADDRESS;
our @airspaceFiles;
our $airspaceBaseUrl = "";
our $initialRegion = "";
our $GRIB_BASE = "GRIB";
our $Server;
our $ServerLogin;
our $ServerPassword;
our $ServerDir;
our $Mode;
require "./site_params";

### Reorder jobargs so that initialRegion is computed first
@JOBARG = uniq @JOBARG;
if ($initialRegion)
{
    my @nonRegionPlots = grep (!/$initialRegion/, @JOBARG);
    @JOBARG = grep (/$initialRegion/, @JOBARG);
    push @JOBARG, @nonRegionPlots;
}

### Report run parameters
print "   Run parameters:\n";
print "      Analysis Time: ", defined($analTime) ? $analTime : "none", "\n";
print "      Verbosity: $VERBOSE\n";
print "      Jobs: @JOBARG\n";

### Setup for multi-threading
use Thread::Queue;
use DoPlot;
use Files;
use Final;
use Try::Tiny;

my $jobQueue = Thread::Queue->new();
my $plotQueue = Thread::Queue->new();
my $jobCount :shared;
our $plotCount :shared = 0;

# Prepare to update status and push files to server
my $final = Final->new(
    HTMLdir => "HTML",
    AirspaceFiles => \@airspaceFiles,
    AirspaceBaseUrl => $airspaceBaseUrl,
    InitialRegion => $initialRegion,
    Server => $Server,
    ServerDir => $ServerDir,
    UserName => $ServerLogin,
    Password => $ServerPassword,
    Mode => $Mode,
    VERBOSE =>$VERBOSE);

### SET RASP ENVIRONMENTAL PARAMETERS
if( ! defined $ADMIN_EMAIL_ADDRESS || $ADMIN_EMAIL_ADDRESS =~ m|^\s*$| ) {
    die "*** ERROR EXIT - parameter ADMIN_EMAIL_ADDRESS must not be blank or null"; exit 1;
}
$ENV{'RASP_ADMIN_EMAIL_ADDRESS'} =  $ADMIN_EMAIL_ADDRESS ;

### Update GM soundings if needed
Update::init("GM/rasp.region_data.ncl");

### Model run details
my @Models;
### List of files by site to retrieve
my %SiteList;

# Get models to run, files to plot
for (@JOBARG)
{
    # Note that the run.parameters file must create only a single Model object
    my($region, $run) = split('/', $_);
    our $model = undef;
    require "./$_.run.parameters";
    $model->jobArg($_);
    $model->gribDir("$GRIB_BASE/" . $model->modelName);
    $model->tempDir("$_");
    $model->refDir("$BASEDIR/$region");
    $model->logDir("$BASEDIR/$_/LOG");
    $model->plotBaseDir("HTML");
    $model->analTime( $analTime ) if defined $analTime;
    $model->VERBOSE($VERBOSE);
    
    # Update list of soundings
    my $soundings = Update::soundings($region, "$region/soundings", $VERBOSE);
    
    # Update list of files to retrieve
    my $gribFiles = $model->gribList();
    if (@$gribFiles)
    {
        my $loc = $model->ftpDirectory;
        $SiteList{ $loc } = new Files(
            model => $model,
            dir => $model->modelName ) unless defined $SiteList { $loc };
        $SiteList{ $loc }->addFiles( @$gribFiles );
        $final->updatingModel($model, $soundings);
        push @Models, $model;
        $plotCount += @{$model->plotTimes};
    } else {
        print "<> Dropping ", $model->jobArg, "\n";
    }
}

$jobCount = @Models;
print "   jobCount: $jobCount, Plot count: $plotCount\n";
exit unless $plotCount;

# Prepare for downloading/processing
while ( (undef, my $site) = each %SiteList )
{
    if ($VERBOSE)
    {
        print "-- Files from ", $site->ftpSite, "\n--  server directory: ", $site->ftpDirectory,
        "\n--  local directory: ", $site->dir, "\n";
        print "--    $_\n" for ( sort ( $site->fileList->members));
    }
    next unless $stage eq "download";
    # Remove previous versions
    $site->Clean ($GRIB_BASE, $VERBOSE);
}

my $startTime;

# Thread routine to process jobs
sub runJobs {
    # Turn on autoflush
    $| = 1;
    while ($plotCount)
    {
        # look for a plot job
        if ($numPlotThreads > 0 || $jobQueue->pending() == 0)
        {
            my $job = undef;
            {
                # Scan the queue looking for a file that's not open
                lock $plotQueue;
                for (0 .. $plotQueue->pending() - 1)
                {
                    my $try = $plotQueue->peek($_);
                    my $wrfFile = $try->wrfFile;
                    if ( -f $try->wrfFile)
                    {
                        # Check if wrf still writing file
                        qx(lsof | grep -q $wrfFile);
                        if ($? != 0)
                        {
                            # Nope - run it
                            $job = $plotQueue->extract($_);
                            last;
                        } else {
                            print "$wrfFile busy\n";
                        }
                    }
                }
            }
            if (defined $job)
            {
                {
                    lock $numPlotThreads;
                    $numPlotThreads--;
                }
                try {
                    $job->run();
                } catch {
                    warn "caught failure:\n$_";
                };
                $final->addPlot($job);
                lock $plotCount;
                $plotCount--;
                lock $numPlotThreads;
                $numPlotThreads++;
                $final->end() unless $plotCount > 0;
                next;
            }
        }
        
        # Try a model job
        my $job = undef;
	{
	    lock $jobQueue;
	    for (my $i = 0; $i < $jobQueue->pending(); $i++)
	    {
		my $try = $jobQueue->peek($i);
		if ($try->canRunUngrib())
		{
		    $job = $jobQueue->extract($i);
		    last;
		}
	    }
	}
        if (defined $job)
        {
            try {
                $job->run($plotQueue);
            } catch {
                warn "caught failure:\n$_";
                lock $plotCount;
                $plotCount -= @{$job->plotTimes};
                $final->end() unless $plotCount > 0;
            };
            lock $jobCount;
            $jobCount--;
            my $time = `/usr/bin/date +%H:%M:%S`;
            chomp $time;
            print "   $time ".$job->jobArg.": done with $jobCount jobs remaining\n";
            next
        }
        
        # Nothing to do right now
        sleep 10;
    }
    # print "runJobs exiting: jobCount = $jobCount, plotCount = $plotCount\n";
}

# Start the threads
for (1 .. $numThreads)
{
    threads->create(sub { runJobs(); });
}

# Do the work
my $delay = 0;
while (%SiteList)
{
    print ("<> Download delay $delay minutes\n") if ($VERBOSE && $delay) || $delay > 5;
    sleep $delay * 60;
    $delay = 60;       # minutes default delay
    while ( my ($key, $site) = each %SiteList)
    {
        if (Model::doStage("download"))
        {
            # Try to download some files
            my $result = $site->downloadFiles( $GRIB_BASE, $VERBOSE );
            if (! defined $result)
            {
                print "   ", $site->ftpSite, ":", $site->ftpDirectory, " Done\n";
                delete $SiteList{ $key };
                next;
            }
            print "-- Process files from ", $site->ftpDirectory, " ret $result\n" if $VERBOSE;
            
            $delay = $delay < $result ? $delay : $result;
            # check if any new files to process
            next if $result;
        }
        else
        {
            print "   ", $site->ftpSite, ":", $site->ftpDirectory, " Done\n";
            delete $SiteList{ $key };
            $delay = 0;
        }
        
        if ($delay == 0 && ! defined $startTime)
        {
            $startTime = DateTime->now;
            print "   Run starting at ", $startTime->set_time_zone("US/Eastern")->format_cldr("HH:mm:ss"), "\n";
        }
        
        # Look for a model to run
        for my $modelIdx (0 .. $#Models)
        {
            my $model = $Models[$modelIdx];
            next unless defined $model;
 
            my $ret = $model->runnable();
            if ($ret == 0 )
            {
                $jobCount --;
                print "<> Model " . $model->jobArg . " out of range - not run!!\n";
                $Models[$modelIdx] = undef;
                my $plotDir = $model->plotDir;
                $plotCount -= @{$model->plotTimes};
            }
            elsif ($ret > 0)
            {
                print "   Queue ", $model->jobArg, "\n";
                $model->plotDir($final->getPlotDir($model));
                $jobQueue->enqueue( shared_clone( $model ));
                $Models[$modelIdx] = undef;
            }
        }
    }
}

print "<> Done downloading\n";

for (threads->list())
{
    $_->join;
}

# cleanup unreferenced directories
$final->cleanup() if $deleteArchive;

# Report any un-run models
for (@Models)
{
    next unless defined;
    die "<> Model " . $_->jobArg . " not run!!\n";
}

my $endTime = DateTime->now;
$endTime->set_time_zone("US/Eastern");
my $elapsed = $endTime - $startTime;
print "   Run ending at ", $endTime->format_cldr("HH:mm:ss"), "\n";
use DateTime::Format::Duration;
my $fmtFunc = DateTime::Format::Duration->new( pattern => "%R", normalise => 1);
print "   Elapsed time was ", $fmtFunc->format_duration($elapsed), "\n";

sub usage
{
    print "Usage: GM.pl [jobarg*] [-d] [-t xx] [-v] [-s stage]\n";
    print "    -h - this message\n";
    print "    -d - delete archive plots\n";
    print "    -s stage - first processing stage - " . join(", ", @Model::stages) .
          " - default is " . $Model::stages[0] . "\n";
    print "    -t xx - series start time - -xx uses previous day\n";
    print "    -v - increase verbosity\n";
    print "    if jobarg(s) not provided, current working directory will be used if analTime,\n";
    print "       otherwise all regions will be run.\n";
    exit 0;
}

