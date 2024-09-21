#! /usr/bin/perl

# Package to ftp files to server and provide status files

package Final;

use strict;
use warnings;

use Moose;
use JSON;
use DateTime::Format::Strptime;
use threads;
use threads::shared;
use Thread::Queue;
use Net::FTP;
use Net::SFTP::Foreign;
use Cwd;

has 'HTMLdir' =>    ( is => 'ro', isa => 'Str', required => 1 );
has 'AirspaceFiles' => ( is => 'ro', isa => 'ArrayRef' );
has 'AirspaceBaseUrl' => ( is => 'ro', isa => 'Str' );
has 'InitialRegion' => ( is => 'ro', isa => 'Str' );
has 'Server' =>     ( is => 'ro', isa => 'Maybe[Str]' );
has 'ServerDir' =>  ( is => 'ro', isa => 'Maybe[Str]' );
has 'UserName' =>   ( is => 'ro', isa => 'Maybe[Str]' );
has 'Password' =>   ( is => 'ro', isa => 'Maybe[Str]' );
has 'Mode' =>       ( is => 'ro', isa => 'Maybe[Str]' );
has 'AnalTime' =>   ( is => 'ro', isa => 'DateTime'   );
has 'Today' =>      ( is => 'rw', isa => 'Maybe[Str]' );
has 'VERBOSE' =>    ( is => 'ro', isa => 'Int' );
has 'daysStatus' => ( is => 'rw', isa => 'HashRef', builder => '_buildDaysStatus');
has 'plotQueue' =>  ( is => 'ro', isa => 'Thread::Queue', default => sub
{ my $Queue = Thread::Queue->new(); return $Queue; } );
has 'SendModified' => ( is => 'ro', isa => 'Thread::Queue', default => sub
{ my $Queue = Thread::Queue->new(); return $Queue; } );

my @inventory = (
    "ExtDraggableObject.js",
    "index.html",
    "w3.css",
    "newParamList.js",
    "rasp.js",
    "RASPoverlay.js",
    "slider.png",
    "sndmkr.png",
    "Today.png",
    "cgi"
);

my $json = JSON->new->pretty([1]);
my $modelsStatus;
my $modelsDir;

# Print out formatted log message
sub _log {
    my $self = shift;
    my $time = `/usr/bin/date +%H:%M:%S`;
    chomp $time;
    print "   $time: Final: ", @_, "\n";
}

# Print out formatted log message
sub _debug {
    my $self = shift;
    return unless $self->VERBOSE;
    print "-- Final: ", @_, "\n";
}

# Initialize run status
sub BUILD {
    my $self = shift;
    # Create link to today's image
    if ($self->Today)
    {
	my $link = $self->Today;
	my $date = $self->AnalTime->strftime('%F');
	$link =~ s/date/$date/;
	my $TodayLink = $self->HTMLdir."/Today.png";
	unlink $TodayLink;
	symlink ($link, $TodayLink);
    }
    threads->create(\&sendPlotsThread, $self);
    # Upload basic inventory
    for (@inventory, @{$self->AirspaceFiles})
    {
	$self->SendModified->enqueue( $_ );
	if ( -d $self->HTMLdir."/$_")
	{
	    opendir (DIR, $self->HTMLdir."/$_");
	    while (my $file = readdir(DIR))
	    {
		next if ($file =~ m|^\.|);
		$self->SendModified->enqueue( "$_/$file" );
	    }
	}
    }
}

# Initialize daysStatus
sub _buildDaysStatus
{
    my $self = shift;
    my $ret :shared;

    if ( open (CURRENT, "<", $self->HTMLdir."/current.json") )
    {
        my $jsonText = join "", <CURRENT>;
        close CURRENT;
        $ret = shared_clone(decode_json $jsonText);
    } else {
        $ret = shared_clone({});
	$ret->{regions} = shared_clone([]);
    }
    my $airspace = {
	baseUrl => $self->AirspaceBaseUrl,
	files => $self->AirspaceFiles
    };
    $ret->{airspace} = shared_clone($airspace);
    $ret->{initialRegion} = $self->InitialRegion;
    return $ret;
}

# Get region info - initialize new one if needed
# Argument - region name
# Return - reference to region info
sub getRegionInfo
{
    my $self = shift;
    my $region = shift;

    my $regions = $self->daysStatus->{regions};
    my $regionInfo;
    if (defined $regions)
    {
	# Look for existing region
	for my $idx (0 .. $#$regions)
	{
	    if ($self->daysStatus->{regions}[$idx]{name} eq $region)
	    {
		return $self->daysStatus->{regions}[$idx];
	    }
	}

	# not found - prepare for a new region
	push @$regions, shared_clone({});
	$regionInfo = $regions->[-1];
    }
    else
    {
	$self->daysStatus->{regions} = shared_clone([]);
	$self->daysStatus->{regions}[0] = shared_clone({});
	$regionInfo = $self->daysStatus->{regions}[0];
    }

    # setup new region
    $regionInfo->{name} = $region;
    $regionInfo->{printDates} = shared_clone([]);
    $regionInfo->{dates} = shared_clone([]);
   
    return $regionInfo;
}

# Mark model to be updated
sub updatingModel
{
    my $self = shift;
    my $model = shift;		# model object being updated
    my $soundings = shift;	# null if no soundings
    
    return unless defined $model->firstGribDate;    # undefined if won't be plotted
    (my $region = $model->jobArg) =~ s|/.*||;
    my $gribDate = $model->firstGribDate;
    my $dateDir = $gribDate->strftime("%F");
    my $plotDir = "$region/$dateDir/".$model->modelName;
    my $modelInfo = $self->getModelInfo($plotDir);
    my $times = $modelInfo->{times};
    if (defined $times->[0])
    {
	# Previously run model - now updating
	for my $i (0  .. $#$times)
	{
	    $times->[$i] = "old " . $$times[$i];
	}
	$self->savePlotStatus;
    }
    else
    {
	return;
    }

    # Find previous location, then shift days
    my $day = $model->day;
    my $regionInfo = $self->getRegionInfo($region);
    my $dates = $regionInfo->{dates};
    if ((defined $dates) && (defined $$dates[$day]))
    {
	if ($$dates[$day] ne $dateDir)
	{
	    # Shift days
	    my $foundDate = 0;
	    for my $idx ($day .. $#$dates)
	    {
		next if ($$dates[$idx] ne $dateDir);
		$self->_debug ("::updatingModel: shifting down starting at $idx - $day");
		$foundDate = 1;
		my $numDates = $#$dates;
		my @newRows = @$dates[($idx - $day) .. $numDates];
		@$dates = @newRows;
		@newRows = @{$regionInfo->{printDates}}[($idx - $day) .. $numDates];
		@{$regionInfo->{printDates}} = @newRows;
		last;
	    }
	    if (! $foundDate)
	    {
		$regionInfo->{dates} = shared_clone([]);
		$regionInfo->{printDates} = shared_clone([]);
	    }
	}
	# Mark for upload
	$self->SendModified->enqueue( "$region/$dateDir/status.json" );
    }
    $regionInfo->{soundings} = shared_clone($soundings) if defined $soundings && @$soundings;
}

# get plot directory path
sub getPlotDir
{
    my $self = shift;
    my $model = shift;
    (my $region = $model->jobArg) =~ s|/.*||;
    
    my $gribDate = $model->firstGribDate;
    return "$region/" . $gribDate->strftime("%F") . "/" . $model->modelName;
}

# get region/date/model info
# arguments
#   model directory
#
# return
#   pointer to model info
sub getModelInfo
{
    my $self = shift;
    $modelsDir = shift;
    (my $statDir = $modelsDir) =~ s|/[^/]+$||;
    (my $modelName = $modelsDir) =~ s|.*/||;
    my $modelInfo;
    if ( open RUNSTAT, "<", $self->HTMLdir."/$statDir/status.json")
    {
        my $jsonText = join "", <RUNSTAT>;
        close RUNSTAT;
        $modelsStatus = $json->decode( $jsonText );
	my $models = $modelsStatus->{models};
	# look for the model
	for my $idx (0 .. $#$models)
	{
	    if ($models->[$idx]{name} eq $modelName)
	    {
		return $models->[$idx];
	    }
	}
	# model doesn't exist
	push @$models, {};
	$modelInfo = $models->[-1];
    } else {
	# no file - build prototype
	$modelsStatus = {};
	$modelsStatus->{models} = [];
	$modelsStatus->{models}[0] = {};
	$modelInfo = $modelsStatus->{models}[0];
    }
    $modelInfo->{name} = $modelName;
    $modelInfo->{times} = [];
    return $modelInfo;
}

# Save plot status to plotdir
sub savePlotStatus
{
    my $self = shift;
    (my $statDir = $modelsDir) =~ s|/[^/]+$||;
    if ( open RUNSTAT, ">", $self->HTMLdir."/$statDir/status.json")
    {
        print RUNSTAT ($json->encode($modelsStatus));
        close RUNSTAT
    } else {
        die $self->HTMLdir."/$statDir/status.json: $!";
    }
}

# add job to push
sub addPlot
{
    my $self = shift;
    my $plot = shift;
    
    $self->plotQueue->enqueue($plot);
}

# mark end of queue
sub end
{
    my $self = shift;
    $self->plotQueue->end();
}

# Thread to send plots and status to web server
sub sendPlotsThread
{
    my $self = shift;
    
    $json = JSON->new->pretty([1]);
    while (defined (my $plot = $self->plotQueue->dequeue()))
    {
        $self->_debug ("::dequeue: ", $plot->plotDir(), " - ", $plot->time());
        $self->updateStatus($plot);
        $self->updateDaysStatus($plot);
	if ($self->Mode)
	{
	    if ($self->Mode eq "sftp")
	    {
		$self->_sendSftpFiles($plot);
	    }
	    elsif ($self->Mode eq "ftp" || $self->Mode eq "")
	    {
		$self->_sendFtpFiles($plot);
	    }
	    else
	    {
		die ("Unknown transfer mode ".$self->Mode);
	    }
	}
	else
	{
	    $self->_sendFtpFiles($plot);
	}
    }
    $self->_log(" exiting");
}

# update status in day directory
sub updateStatus
{
    my $self = shift;
    my $plot = shift;
    
    my $modelInfo = $self->getModelInfo($plot->plotDir);
    # insert/overwrite time in array
    my $times = $modelInfo->{times};
    for my $idx (0 .. $#$times)
    {
        (my $t = $$times[$idx]) =~ s/[\D]*//g;
        if ($t eq $plot->time)
        {
            $$times[$idx] = $plot->time;
            last;
        }
        elsif ($t gt $plot->time)
        {
            @$times = ( @$times[0 .. ($idx - 1)], $plot->time, @$times[$idx .. $#$times] );
            last;
        }
    }
    # handle case where time didn't get added by previous loop
    if (@$times <= 0)
    {
        push @$times, $plot->time;
    } else {
        (my $last = $$times[-1]) =~ s/[\D]*//g;
        push @$times, $plot->time if ($plot->time gt $last);
    }
    
    # Get corners/center from log file
    open (PLT, "<", $plot->logFile) or
        die "Can't open " . $plot->logFile . ": $!";
    my ($corners, $center);
    while (<PLT>)
    {
        if ($_ =~ m|corners.Bounds|)
        {
            $corners = $_ . <PLT> . <PLT> . <PLT>;
            $corners =~ s|corners.*= ||;
            ($center = <PLT>) =~ s|corners.*= ||;
            last;
        }
    }
    close PLT;

    if (! defined $corners)
    {
	print ">> no corners in " . $plot->logFile . "\n";
	return;
    }

    $corners =~ s/.*\n.*\(/[[/;
    $corners =~ s/\).*\(/],[/s;
    $corners =~ s/\).*/]]/s;
    $center =~ s/.*\(/[/;
    $center =~ s/\).*/]/s;
    $modelInfo->{corners} = $json->decode($corners);
    $modelInfo->{center} = $json->decode($center);
    
    $self->savePlotStatus($plot->plotDir);
}

# update list of days
sub updateDaysStatus
{
    my $self = shift;
    my $plot = shift;
    
    my($region, $date, $model) = split '/', $plot->plotDir;
    
    # parse time from plotdir to get print name
    my $dateTime = $date . "_0100";
    my $strp = DateTime::Format::Strptime->new(
        pattern => "%F_%H%M",
        locale  => 'en_US');
    my $t = $strp->parse_datetime($dateTime);         # local date/time
    my $title = $t->format_cldr("EEEE MMMM dd");

    # Find/initialize region info
    my $regionInfo = $self->getRegionInfo($region);
    $regionInfo->{dates}[$plot->row] = shared_clone($date);
    $regionInfo->{printDates}[$plot->row] = shared_clone($title);
    
    # write out new file
    open STAT, ">", $self->HTMLdir."/current.json"
        or die $self->HTMLdir."/current.json: $!";
    print STAT ($json->encode($self->daysStatus));
    close STAT;
}

sub _sendFtpFiles
{
    my $self = shift;
    my $plot = shift;
    
    return unless $self->Server;
    
    # Get list of files
    my($region, $date, $model) = split '/', $plot->plotDir;
    my $time = $plot->time;
    my $cmd = "cd ".$self->HTMLdir."; ls ".join "/", $plot->plotDir, "*${time}local*";
    my @files = (join("/", $region, $date, "status.json"), "current.json");
    push @files, `$cmd`;
    push @files, join "/", $plot->plotDir, "namelist.wps";
    
    my $ftp;
    for (my $try = 0; $try < 3 && @files; $try++)
    {
        $self->_log("::sendFiles retry # $try") if $try > 0;
        # Create connection
        $ftp = Net::FTP->new($self->Server, Timeout => 10, Debug => $self->VERBOSE > 1);
        if (!$ftp)
        {
            print "Cannot connect to ".$self->Server.": $@\n";
            next;
        }
        if (!$ftp->login($self->UserName, $self->Password))
        {
            print "Cannot login ", $ftp->message, "\n";
            next;
        }
        if (!$ftp->cwd($self->ServerDir))
        {
            print $self->ServerDir, ": ", $ftp->message;
            next;
        }
        $ftp->binary();
        $ftp->mkdir($plot->plotDir, 1);
        
        # Upload annotated status files
        while (my $statFile = $self->SendModified->dequeue_nb())
        {
            if ( -d $self->HTMLdir."/$statFile")
            {
                $ftp->mkdir($statFile, 1)
            } else {
                if (!$ftp->put($self->HTMLdir."/$statFile", $statFile))
                {
                    print $ftp->message, ": $statFile\n" unless $ftp->code == 421;
                    $self->SendModified->enqueue($statFile);
                    last;
                }
            }
        }
        while (my $f = pop @files)
        {
            chomp $f;
            if (!$ftp->put($self->HTMLdir."/$f", $f) )
            {
		# failed, report it, put it back onto the queue, and try again
                print $ftp->message, ": $f\n" unless $ftp->code == 421;
                push @files, $f;
                last;
            }
	    $try = 0;
        }
    }
    $ftp->quit();
    die "Upload failed" if @files;
}

sub _sendSftpFiles
{
    my $self = shift;
    my $plot = shift;
    
    return unless $self->Server;
    
    # Get list of files
    my($region, $date, $model) = split '/', $plot->plotDir;
    my $time = $plot->time;
    
    my $sftp;
    #for (my $try = 0; $try < 3 && @files; $try++)
    {
	#$self->_log("::sendFiles retry # $try") if $try > 0;
        # Create connection
	$sftp = Net::SFTP::Foreign->new($self->Server,
				  user => $self->UserName,
			          timeout => 10);
				  #more => ['-C']);
        if ($sftp->error)
        {
            print "Cannot connect to ".$self->Server.": ".$sftp->error."\n";
            next;
        }
        if (!$sftp->setcwd($self->ServerDir))
        {
            print $self->ServerDir, ": ", $sftp->error;
            next;
        }
        $sftp->mkpath($plot->plotDir);
        
        # Upload annotated status files
        while (my $statFile = $self->SendModified->dequeue_nb())
        {
            if ( -d $self->HTMLdir."/$statFile")
            {
                $sftp->mkpath($statFile)
            } elsif ( -l $self->HTMLdir."/$statFile")
	    {
		my $link = $self->HTMLdir."/$statFile";
		chomp($link = `ls -l $link`);
		$link =~ s/^.*-> //;
		$sftp->remove($statFile);
		$sftp->symlink($statFile, $link);
	    } else {
                if (!$sftp->put($self->HTMLdir."/$statFile", $statFile))
                {
                    print $sftp->error, ": $statFile\n";
                    $self->SendModified->enqueue($statFile);
                    last;
                }
            }
        }
	$sftp->mput([
		join ("/", $self->HTMLdir, $plot->plotDir, "namelist.wps"),
		join ("/", $self->HTMLdir, $plot->plotDir, "*${time}local*")
	    ], $plot->plotDir);
	my $statDir = join("/", $region, $date, "status.json");
	$sftp->put( join("/", $self->HTMLdir, $statDir), $statDir)
	    or print "status.json: ", $sftp->error, "\n";
	$sftp->put( join("/", $self->HTMLdir, "current.json"), "current.json");
    }
}

# Remove unreferenced plot directories
sub cleanup
{
    my $self = shift;

    # Local directories
    my $regions = $self->daysStatus->{regions};
    for my $regionIdx (0 .. $#$regions)
    {
	my $region = $$regions[$regionIdx]{name};
        $self->_debug("::cleanup looking at local $region");
        opendir (my $regionDir, $self->HTMLdir."/$region")
            or die "Can't opendir ".$self->HTMLdir."/$region: $!;";
    DIR:
        while (my $dayDir = readdir $regionDir)
        {
            next if $dayDir =~ /^\./;
            $self->_debug("::cleanup checking $dayDir");
            my $dates = $$regions[$regionIdx]{dates};;
            for my $i (0 .. $#$dates)
            {
                next DIR if ($dayDir eq $$dates[$i]);
            }
            $self->_log("::cleanup removing $region/$dayDir");
            # This rm may look unusual, but it's safer than a simpler form
            my $cmd = "cd ".$self->HTMLdir."/$region; /usr/bin/rm -rf $dayDir";
            `$cmd`;
        }
    }

    # cleanup server directories
    return unless $self->Server;
    if ($self->Mode)
    {
	if ($self->Mode eq "sftp")
	{
	    $self->_cleanupSftp();
	}
	else
	{
	    $self->_cleanupFtp();
	}
    }
    else
    {
	$self->_cleanupFtp();
    }
}

# Remove unreferened server plot directories using ftp
sub _cleanupFtp
{
    my $self = shift;
    
    # Server directories
    my $regions = $self->daysStatus->{regions};
    DIR_RETRY: for my $try (0 .. 3)
    {
	$self->_log("FTP dir retry #  ".$try) unless $try == 0;
	my $ftp = Net::FTP->new($self->Server, Debug => $self->VERBOSE > 1)
	    or die "Cannot connect to ".$self->Server.": $@";
	$ftp->login($self->UserName, $self->Password)
	    or die "Cannot login ", $ftp->message;
	$ftp->cwd($self->ServerDir)
	    or die $self->ServerDir, ": ", $ftp->message;
	for my $regionIdx (0 .. $#$regions)
	{
	    my $region = $$regions[$regionIdx]{name};
	    $self->_debug("::cleanup looking at server $region");
	    my @days = $ftp->ls($region)
		or die("Couldn't get ftp directory: ".$ftp->message);
	    DIR: foreach my $dayDir (@days)
	    {
		$self->_debug("::cleanup checking $dayDir");
		my (undef, $date) = split "/", $dayDir;
		my $localDays = $$regions[$regionIdx]{dates};;
		for my $i (0 .. $#$localDays)
		{
		    next DIR if ($date eq $$localDays[$i]);
		}
		$self->_log("::cleanup removing server $dayDir");
		if (!$ftp->rmdir($dayDir, 1))
		{
		    next DIR_RETRY if ($ftp->code == 421);
		    die("::cleanup failed rmdir: ".$ftp->message);
		}
	    }
	}
	# nothing more to do
	last;
    }
}

# Remove unreferenced server plot directories using sftp
sub _cleanupSftp
{
    my $self = shift;
    
    # Server directories
    my $regions = $self->daysStatus->{regions};
    DIR_RETRY: for my $try (0 .. 3)
    {
	$self->_log("SFTP dir retry #  ".$try) unless $try == 0;
	my $sftp = Net::SFTP::Foreign->new($self->Server,
				  user => $self->UserName);
	$sftp->die_on_error("Cannot connect to ".$self->Server);
	$sftp->setcwd($self->ServerDir);
	$sftp->die_on_error("Cannot chdir to ".$self->ServerDir);
	for my $regionIdx (0 .. $#$regions)
	{
	    my $region = $$regions[$regionIdx]{name};
	    $self->_debug("::cleanup looking at server $region");
	    my $days = $sftp->ls($region, names_only=>1);
	    $sftp->die_on_error("Couldn't get sftp directory $region");
	    DIR: foreach my $date (@$days)
	    {
		$self->_debug("::cleanup checking $date");
		$date eq "." and next;
		$date eq ".." and next;
		my $localDays = $$regions[$regionIdx]{dates};;
		for my $i (0 .. $#$localDays)
		{
		    next DIR if ($date eq $$localDays[$i]);
		}
		my $dayDir = "$region/$date";
		$self->_log("::cleanup removing server $dayDir");
		my $code = $sftp->rremove($dayDir);
		$sftp->die_on_error("::cleanup failed rmdir $dayDir");
	    }
	}
	# nothing more to do
	last;
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
