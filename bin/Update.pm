#! /usr/bin/perl

# Package to update the soundings info

package Update;

use strict;
use warnings;

use File::stat;

my $pclFile;

my $pclMTime;

my %soundings;
my $doUpdates = 0;

# save output filenames, initialize soundings from the .pcl file
sub init
{
    $pclFile = shift;
    
    my $pclStat = stat($pclFile);
    
    $pclMTime = (defined $pclStat) ? $pclStat->mtime : 0;
    
    if (-f $pclFile)
    {
        # Load PCL file
        open SRC, "<", $pclFile or die "$pclFile: $!";
        
        my $region;
        while (<SRC>)
        {
            chomp;
            if ($_ =~ m/^===/)
            {
                # start of region spec
                ($region = $_) =~ s/^=*//;
                $soundings{$region} = {};
                my $units = <SRC>;
                chomp $units;
                $soundings{$region}{"units"} = $units;
                $soundings{$region}{"NAM"} = ();
                $soundings{$region}{"LAT"} = ();
                $soundings{$region}{"LON"} = ();
                next;
            }
            
            if ($region)
            {
                # a sounding within a region
                die "Huh? $_ in $pclFile" unless ($_ =~ m|sounding|);
                my $line = <SRC>;
                chomp $line;
                $line =~ s/.*~//;
                push @{$soundings{$region}{"NAM"}}, $line;
                $line = <SRC>;
                chomp $line;
                push @{$soundings{$region}{"LAT"}}, $line;
                $line = <SRC>;
                chomp $line;
                push @{$soundings{$region}{"LON"}}, $line;
            }
        }
    }
    close SRC;
}

sub getSoundings
{
    my $region = shift;
    my $VERBOSE = shift;
    
    my $data = \%{$soundings{$region}};
    return undef unless defined $data->{NAM};

    my $ret = [];
    for my $i (0 .. $#{$data->{"NAM"}})
    {
	my $obj = {};
	$obj->{location} = $data->{'NAM'}[$i];
	$obj->{latitude} = $$data{'LAT'}[$i];
	$obj->{longitude} = $$data{'LON'}[$i];
	push @$ret, $obj;
    }
    return $ret;
}

sub writePCLfile
{
    my $VERBOSE = shift;
    
    open DST, ">", $pclFile or die "$pclFile: $!";
    
    (my $head = q|
    #############################################################################################
    #############  RASP PLOT INFORMATION - to be read by rasp.ncl  ##############################
    #############################################################################################
    ### FORMAT FOR EACH REGION:
    ###   1st line: ===MY_REGION_NAME (matching that used in rasp.pl, spaces not allowed)
    ###   2nd line: units (american/celsius/metric)
    ###   then (optional) sounding location(s) of 4 lines each:
    ###      (1) "sounding#" (where # is an integer)
    ###      (2) sounding id (spaces allowed)
    ###      (3) latitude (decimal degrees,S=negative)
    ###      (4) longitude (decimal degrees, W=negative)
    ###
    ### IF RUN REGION IS NOT IN THIS FILE, THEN DEFAULT UNITS USED AND NO SOUNDINGS ARE PLOTTED
    ###
    ### THIS IS A GENERATED FILE - DO NOT EDIT. Edit soundings in the region directory instead
    #############################################################################################
    |) =~ s/^ {4}//mg;
    print DST $head;
    
    while (my ($region, $data) = each %soundings)
    {
        # process new region
        print "-- pcl $region\n" if $VERBOSE;
        print DST "===$region\n";
        print DST "$$data{'units'}\n";

        if ($$data{"NAM"})
        {
            for my $i (0 .. (@{$$data{"NAM"}} - 1))
            {
                print "-- pcl Sounding $i $$data{'NAM'}[$i]\n" if $VERBOSE;
                print DST "sounding" . ($i+1) . "\n";
                print DST "~F37~m~F21~$$data{'NAM'}[$i]\n";
                print DST "$$data{'LAT'}[$i]\n";
                print DST "$$data{'LON'}[$i]\n";
            }
        }
    }
    close DST;
}

sub soundings
{
    my $region = shift;
    my $file = shift;
    my $VERBOSE = shift;
    
    $soundings{$region} = {};   # Initialize region, delete any previous definition
    $soundings{$region}{"units"} = "american";
    
    my $stat = stat($file);
    my $mtime;
    
    if (defined $stat)
    {
        $mtime = $stat->mtime;
        
        open SRC, "<", $file or die "Can't open $file: $!";
        while (<SRC>)
        {
            chomp;
            s|#.*||;
            if (m|units:|)
            {
                (my $units = $_) =~ s|.*units:[\s]*||;
                $soundings{$region}{"units"} = $units;
            }
            elsif (m|;|)
            {
                my @fields = split /;[\s]*/;
                push @{$soundings{$region}{"NAM"}}, $fields[0];
                push @{$soundings{$region}{"LAT"}}, $fields[1];
                push @{$soundings{$region}{"LON"}}, $fields[2];
            }
            elsif (m/[\S]/)
            {
                die "In $file: unknown \"$_\"";
            }
        }
    } else {
        print ">> $file not found - using $soundings{$region}{'units'} units, no soundings\n";
        $doUpdates = 1;
        $mtime = 0;
    }

    $doUpdates |= $mtime > $pclMTime;
    if ($doUpdates)
    {
        print "   Updating soundings file\n";
        writePCLfile($VERBOSE);
    }

    return getSoundings($region, $VERBOSE);
}

no Update;
1;
