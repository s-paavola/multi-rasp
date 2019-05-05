#! /usr/bin/perl

# Package to the runStatus.js file

package RunStatus;

use strict;
use warnings;

use JSON;
use DateTime::Format::Strptime;

my $file;
my $VERBOSE;
my $runStatus;

# Initialize run status
sub init
{
    $file = shift;
    $VERBOSE = shift;
    
    return unless open (RUNSTAT, "<", $file); # OK if not found
    my $json = join '', <RUNSTAT>;
    close RUNSTAT;
    
    $runStatus = decode_json $json;
}

# Mark model to be updated
sub updatingModel
{
    my $model = shift;
    
    return unless defined $model->firstGribDate;    # undefined if won't be plotted
    my $plotDir = getPlotDir($model);
    (my $region = $model->jobArg) =~ s|/.*||;
    my $days = $$runStatus{$region}{$model->name};
    shiftDays_($days, $model);
    # Find it
    for my $day (@$days)
    {
        if ($$day{"items"}[1] eq $plotDir)
        {
            # annotate it
            print "-- RunStatus: Found $plotDir\n" if $VERBOSE;
            my $items = $$day{"items"};
            for my $i (2 .. $#$items)
            {
                $$items[$i] = "old " . $$items[$i];
            }
        }
    }
}

# get plot directory path
sub getPlotDir
{
    my $model = shift;
    (my $region = $model->jobArg) =~ s|/.*||;
    
    my $gribDate = $model->firstGribDate;
    return "$region/" . $gribDate->strftime("%F") . "/" . $model->name;
}

# Create a new row
sub rowSetup_
{
    my ($rows, $plot, $row, $dateString) = @_;
    
    my $strp = DateTime::Format::Strptime->new(
    pattern => "%F_%H%M",
    locale  => 'en_US');
    $dateString .= "_" . $plot->time;
    my $t = $strp->parse_datetime($dateString);         # local date/time
    my $option = $t->format_cldr("EEEE MMMM dd");
    if (defined $$rows[$row]{"items"})
    {
        $$rows[$row]{"items"}[0] = $option;
        $$rows[$row]{"items"}[1] = $plot->plotDir;
    }
    else
    {
        $$rows[$row]{"items"} = [$option, $plot->plotDir];
    }
}

# shift rows if have an old run for this date
sub shiftDays_
{
    my $rows = shift;
    my $model = shift;
    
    return if ($model->day() != 0);
    
    my $plotDir = getPlotDir($model);
    
    # Look for previous defs
    for my $idx (0 .. $#$rows)
    {
        if ($$rows[$idx]{"items"}[1] eq $plotDir)
        {
            return if ($idx == 0);
            print "-- RunStatus: Shifting down starting at row $idx\n" if $VERBOSE;
            my @newRows =@$rows[$idx .. $#$rows];
            @$rows = @newRows;
            return;
        }
    }
    
    @$rows = ();
}

# add job to runStatus
sub addPlot
{
    my $plot = shift;
    
    my($region, $dateString, $model) = split m|/|, $plot->plotDir;
    my $row = $plot->row;
    
    $$runStatus{$region}{$model} = [] unless (defined $$runStatus{$region}{$model});
    my $rows = $$runStatus{$region}{$model};
    
    # Setup the row
    rowSetup_( $rows, $plot, $row, $dateString);
    
    # Get updated plot params
    $$rows[$row]{"pltLog"} = $plot->logFile;
    
    # Update time in items
    my $items = $$runStatus{$region}{$model}[$row]{"items"};
    for my $idx (2 .. $#$items)
    {
        (my $t = $$items[$idx]) =~ s/[\D]*//g;
        if ($t eq $plot->time)
        {
            $$items[$idx] = $plot->time;
            last;
        }
        elsif ($t gt $plot->time)
        {
            @$items = ( @$items[0 .. ($idx - 1)], $plot->time, @$items[$idx .. $#$items] );
            last;
        }
    }
    print "-- addJob: $region/$dateString:", $plot->time, "/$model\n" if $VERBOSE;
    (my $last = $$items[-1]) =~ s/[\D]*//g;
    push @$items, $plot->time if ((@$items <= 2) || ($plot->time gt $last));
    writeStatus();
}

# write out runStatus
sub writeStatus
{
    # Write .json file
    $file =~ s/\.js.*/.json/;
    open (STATUS, ">", $file) or die "Can't open $file: $!";

    print STATUS "{\n";
    
    my $regionSep = "\n";    # separator between models
    while (my($region, $status) = each %$runStatus)
    {
        print STATUS "$regionSep\"${region}\" : {";
        my $modelSep = "";    # separator between models
        while (my($modelName, $days) = each %$status)
        {
            print STATUS "$modelSep\n    \"$modelName\" : [";
            my $daySep = "";        # separator between days
            for my $day (0 .. $#$days)
            {
                print STATUS "$daySep\n        {\n";
                my ($corners, $center);
                if (defined $$days[$day]{"pltLog"} && -f $$days[$day]{"pltLog"})
                {
                    # get corners info
                    open (PLT, "<", $$days[$day]{pltLog}) or
                    die "Can't open " . $$days[$day]{pltLog} . ": $!";
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
                }
                elsif (defined $$days[$day]{"corners"})
                {
                    #$corners = $$days[$day]{"corners"};
                    $corners = "[[" . join(", ", @{$$days[$day]{"corners"}[0]}) .
                    "], [" . join(", ", @{$$days[$day]{"corners"}[1]}) . "]]";
                    $center = '[' . join(", ", @{$$days[$day]{"center"}}) . ']';
                }
                if (defined $corners)
                {
                    my @items = @{$$days[$day]{"items"}};
                    print "-- Doing $region $modelName $day\n" if $VERBOSE;
                    print STATUS "        \"items\" : " .
                    '["', join('", "', @items[0, 1]), "\",\n" .
                    '            "', join('", "', @items[2 .. $#items]), "\"],\n";
                    $corners =~ s/.*\n.*\(/[[/;
                    $corners =~ s/\).*\(/],[/s;
                    $corners =~ s/\).*/]]/s;
                    print STATUS "        \"corners\" : $corners,\n";
                    $center =~ s/.*\(/[/;
                    $center =~ s/\).*/]/s;
                    print STATUS "        \"center\" : $center\n";
                }
                print STATUS "        }";
                $daySep = ",";
            }
            print STATUS "\n    ]";
            $modelSep = ",";
        }
        print STATUS "\n}";
        $regionSep = ",\n";
    }
    print STATUS "\n}\n";
    
    close STATUS;
}

# Remove unreferenced plot directories
sub cleanup
{
    my $baseDir = shift;
    my $VERBOSE = shift;
    
    for my $region (keys %$runStatus)
    {
        print "-- Looking at $region\n" if $VERBOSE;
        opendir (my $regionDir, "$baseDir/$region") || die "Can't opendir $baseDir/$region: $!";
        while (my $dayDir = readdir $regionDir)
        {
            next if $dayDir =~ /^\./;
            print "--   DateDir $dayDir\n" if $VERBOSE;
            my $count = 0;
            opendir (my $modelDir, "$baseDir/$region/$dayDir") || die "Can't opendir $baseDir/$region/$dayDir: $!";
            while (my $modelName = readdir $modelDir)
            {
                next if $modelName =~ /^\./;
                my $plotDir = "$region/$dayDir/$modelName";
                print "--     Checking $plotDir\n" if $VERBOSE;
                while (my($modelName, $days) = each %{$$runStatus{$region}})
                {
                    print "--       $region/$modelName\n" if $VERBOSE;
                    for my $day (0 .. $#$days)
                    {
                        my $path = $$days[$day]{"items"}[1];
                        print "--         path $path " . ($path eq $plotDir ? "match" : "nomatch") . "\n" if $VERBOSE;
                        $count++ if ($path eq $plotDir);
                    }
                }
            }
            if ($count == 0)
            {
                print "   Deleting HTML/$region/$dayDir\n";
                # This rm may look unusual, but it's safer than a simpler form
                `cd HTML/$region; /usr/bin/rm -rf $dayDir`;
            }
        }
        closedir $regionDir;
    }
}

no RunStatus;
1;
