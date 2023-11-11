#! /usr/bin/perl -w

# Eric - This version of rasptrackavg.PL from http://drjack.info/RASP/SCORER/rasp-uk.uk/SOFTWARE/cgi-bin/index.html
#        Modified:
#        1. Using GBSC RASP file structure
#        2. Modified error reporting
#        3. Returning JSON
#
# Example call:
#   perl get_rasp_optimized_route.PL  ../NewEngland/2023-08-11/gfs NewEngland  d2 1000x  "LS-4a" 1 1 1 "42.42617,-71.79383,42.805,-72.003,42.90133,-72.26983,42.42617,-71.79383"

##### PAULS - 2017-10-16 BLOCKED if optgroundspd < 0.05 mps (= 0.1 Knot)  [Was <= 0.0] See line 940
##### PAULS - 2008-08-02 Warnings turned off at lines 900 1025 1039 & 1062 to avoid cluttering logs with errors from sqrt(-ve num) #####
##### PAULS - 2008-08-03 Can't have -T flag to perl. Opening a file for writing is not allowed - see "man perlsec"

# Eric - Debugging
#my $total = $#ARGV;
#print "Number of arguments (0 based): $total \n";
#my $counter = 0;
#foreach my $a (@ARGV) {
#    print "Arg # $counter : $a\n";
#    $counter++;
#}
#End debugging

    # Input argument order
    # 0 Root directory  (includes date and model in path)
    # 1 Region
    # 2 Grid   e.g. d2
    # 3 Time  0 or specific hour (e.g. 1000)
    # 4 Glider type (e.g. LS-4a) - used just for reference
    # 5 Polar adjustment -
    # 6 Polar coefficients (a,b,c)
    # 7 default Thermal sink rate in m/s
    # 8 Thermal multiplier (???)
    # 9 Type - indicate format of following turnpoint list - either 'latlons' or 'turnpts'
    # 10 Lat/Long of turnpoints e.g. "42.42617,-71.79383,42.805,-72.003,42.90133,-72.26983,42.42617,-71.79383"
    #     or "1,42.42617,-71.79383,Sterling,2,42.805,-72.003,Jaffrey,..."
my $summaryJson;
$summaryJson = "";
if ($#ARGV < 10) {
    # $#ARGV is 0 based so really looking for 11 arguments
    #-----------------description------------------------------------
    $summaryJson = $summaryJson . "{ \"error\" : \"Calc+Output optimal time along path based on \\\"speed to fly\\\" eqns.";
    $summaryJson = $summaryJson . "\\n\\t0 = Data directory";
    $summaryJson = $summaryJson . "\\n\\t1 = Region";
    $summaryJson = $summaryJson . "\\n\\t2 = Grid";
    $summaryJson = $summaryJson . "\\n\\t3 = Time eg. 1300 (use single forecast) or 1100x (start task at 1100)";
    $summaryJson = $summaryJson . "\\n\\t4 = Glider name";
    $summaryJson = $summaryJson . "\\n\\t5 = Polar factor (% above below weight used when generating polar info ";
    $summaryJson = $summaryJson . "\\n\\t6 = Polar coefficients (a,b,c)";
    $summaryJson = $summaryJson . "\\n\\t7 = ThermallingSinkrate(m/s)";
    $summaryJson = $summaryJson . "\\n\\t8 = ThermalMultiplier";
    $summaryJson = $summaryJson . "\\n\\t9 = Turnpoint formats - \\\"latlons\\\"  or \\\"turnpts\\\"  used to indicate format of turnpoints below. ";
    $summaryJson = $summaryJson . "\\n\\t10 = If type  \\\"latlons\\\"  format is: Lat,Lon  pairs , if  \\\"turnpts\\\" then  #(1,2,3), lat, lon, turnpoint name ";
    $summaryJson = $summaryJson . " \\nInput: Day=-yyyy-mm-dd  Valid.Time=hhmm[x]  ThermalingSink=m/sec Lat / Lon = degrees(Wlon = -) ";
    $summaryJson = $summaryJson . "\\nValidTime \\\"hhmm\\\" => single datafile time (lst)  \\\"hhmm+\\\" => flight start time (lst) ";
    $summaryJson = $summaryJson . " \\nOutput: std out  ";
    $summaryJson = $summaryJson . "\\n eg:  NewEngland/2023-08-11/gfs  NewEngland d2  1000 LS-4a 1.0 \\\"-0.0002,0.0350,-2.1900\\\"1 1 1 latlons \\\"42.42617,-71.79383,42.805,-72.003,42.90133,-72.26983,42.42617,-71.79383\\\"  ";
    $summaryJson = $summaryJson . "\\nReminder: This routine requires american unit data file input = do not use for metric data files \\n\"}";
    print $summaryJson;
    exit 0;
}

############ PROGRAM NOTICE AND LICENSE #################################
#
### rasptrackavg.PL COMPUTER PROGRAM - April 12, 2008
### Original Author: Dr. John W. (Jack) Glendening, Meteorologist (drjack@drjack.net)
### Copyright (C) 2007-2008 by John W. Glendening
#
# This program is free software and is provided by the copyright
# holder under the following license.  By obtaining, using and/or
# copying this work, you (the licensee) agree that you have read,
# understood, and will comply with the following terms and conditions.
#
# Permission to use, copy, modify, and distribute this program and its
# documentation, with or without modification, for any purpose and
# without fee or royalty is hereby granted, provided that the following
# terms and conditions are complied with:
#
# 1. The full text of this NOTICE AND LICENSE is provided in a location
# viewable to users of the redistributed or derivative work.
#
# 2. Pre-existing intellectual property notices and conditions,
# including the above statement of original authorship, the names of
# subsequent modification authors, the original copyright notice, and
# this list of conditions is to be included on all copies of the
# program and documentation or portions thereof, including all
# modifications.
#
# 3. The terms of version 2 of the GNU General Public License are
# complied with.  The GNU General Public License can be viewed
# at on-line http://www.drjack.net/INFO/gnu_gpl_license_2.txt
# or obtained from the Free Software Foundation, Inc.,
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
# This program is distributed in the hope that it will be useful.
# The program and documentation is provided "as is," and copyright
# holders make no representations or warranties, express or implied,
# including but not limited to, warranties of merchantability or fitness
# for any particular purpose or that the use of the program or
# documentation will not infringe any third party patents, copyrights,
# trademarks or other rights.
#
#########################################################################
### for cgi use taint checking option -T
### FOR VISUAL DEBUGGER:  perl -d:ptkdb example.pl
### FOR DEBUG MODE: run with -d flag
###    i debug mode, set package name + local variables so X,V don't show "main" variables, ie:
# package Main; local ($a,$b,...);
### To restrict unsafe constructs (vars,refs,subs)
###    vars requires variables to be declared with "my" or fully qualified or imported
###    refs generates error if symbolic references uses instead of hard refs
###    subs requires subroutines to be predeclared
#use strict;
### To provide aliases for buit-in punctuation variables (p403)
use English;
### for non-buffered STDOUT,STDERR ouput:
select STDERR;
$| = 1;
select STDOUT;
$| = 1; #must be last select
### to append new line to each print record:     $\="\n"; #($OUTPUT_RECORD_SEPARATOR)
### for error statements with subroutine traceback
use Math::Trig; ### need asin function

local $SIG{__WARN__} = \&Carp::cluck;
### To enable verbose diagnostics:
#   use diagnostics;

############################  PROGRAMMING NOTES  ##############################

# *NB* datafile units must be "american" - might later allow for metric !

###############################################################################


### ALLOW USE OF LARGEST W VALUE IN SURROUNDING AREA
### $LWSURROUND cells surrounding flight grid cell for which largest w will be used (instead of w at flight grid cell)
my $LWSURROUND = 1;

### CONVERSIONS
my $mps2fpm = 196.850;
my $mps2kt = 1.943849;
my $kmphr2mps = 0.277778;


require "./ij2latlon_gbsc.PL";
require "./keyValuesToJson.PL";

our ($GRID, $KGRID, $VALIDTIME, $LVALIDTIME);
our ($DATADIR);
our ($REGION);
#use Data::Dumper;
#print Dumper(\@_);

my ($glider, $polarFactor, $polarCoefficients , $thermallingsinkrate, $thermalmultiplier,  $type, $taskpoints );
###### PARSE ARGUMENTS
# Eric - updated
$DATADIR = $ARGV[0];
$REGION = $ARGV[1];

($GRID = $ARGV[2]) =~ tr/A-Z/a-z/; # ensure lower case
if ($GRID eq 'd1') {$KGRID = 1;}   # set KGRID
elsif ($GRID eq 'd2') {$KGRID = 2;}
elsif ($GRID eq 'w1') {$KGRID = 2;}
elsif ($GRID eq 'w2') {$KGRID = 3;}

($VALIDTIME = $ARGV[3]) =~ tr/A-Z/a-z/;
if ($VALIDTIME =~ m|x$|) {
    # LVALIDTIME: 0=starttime 1=constant
    $LVALIDTIME = 0;
    chop($VALIDTIME);
}
else {$LVALIDTIME = 1;}

$glider = $ARGV[4];    # Eric - switch to gliderarg as removed polar file

$polarFactor = $ARGV[5];   # adjustment to polar based on 'real' glider weight (empty + pilot + ballast) vs weight polar was calculated at

$polarCoefficients = $ARGV[6];   # a,b,c coefficients to calc glider polar

if ($ARGV[7] =~ m|^([0-9.]+)*kt[s]*$|i)    # default ThermallingSinkrate input units = m/s
{$thermallingsinkrate = ${1} / ${mps2kt};} #  append kt/kts to change units
else {$thermallingsinkrate = $ARGV[7];}

$thermalmultiplier = $ARGV[8];

$type = $ARGV[9];        # indicate if next parm is in latlon or turnpt format
$taskpoints = $ARGV[10]; # Task turnpoints in LAT,LON

#print "\ntype : $ARGV[8]";
#print "\ntaskpoints : $ARGV[9]";

my ($latlonargtail, @adesc, @atp, $nturnpts, $nleg);
$nturnpts = 0;
$latlonargtail = $taskpoints;

my (@alatpts, @alonpts);
my ($tp, $lat, $lon, $name);

while (defined $latlonargtail && $latlonargtail ne "") {
    if ($type eq "latlons") {
        ($alatpts[$nturnpts], $alonpts[$nturnpts], $latlonargtail) = split /,/, $latlonargtail, 3;
        $nturnpts = $nturnpts + 1;
    }
    else {
        ($tp, $lat, $lon, $name,$latlonargtail) = split /,/, $latlonargtail, 5;
        $atp[$nturnpts] = $tp;
        $alatpts[$nturnpts] = $lat;
        $alonpts[$nturnpts] = $lon;
        $adesc[$nturnpts] = $name;
       # print "\nTP : $tp, lat : $lat  lon : $lon  name : $name   latlonargtail : $latlonargtail" ;
       # print "\nTP $nturnpts: $atp[$nturnpts] - $adesc[$nturnpts] ($alatpts[$nturnpts], $alonpts[$nturnpts]) \n";
        $nturnpts++;
    }
}

our $errorMsg = "";
our @subData = ();

$nleg = $nturnpts - 1;
#4test: print "NLEG= $nleg \n";
#4test: for( $ileg=0; $ileg<=$nleg; $ileg++ )
#4test: { print "$ileg = $alatpts[$ileg] & $alonpts[$ileg] = \n"; }

### check for lat,lon pairs
if (!defined $alonpts[$nleg] || $alonpts[$nleg] eq "") {
    reportError("*** ERROR: Number of latitude and longitude points does not match.  Number nleg : $nleg");
    exit 0;
}

our $program = 'rasptrackavg';

## INITIALIZATION
our %monthname = ('1', 'Jan', '2', 'Feb', '3', 'Mar', '4', 'Apr', '5', 'May', '6', 'Jun', '7', 'Jul', '8', 'Aug', '9', 'Sep', '10', 'Oct', '11', 'Nov', '12', 'Dec', '01', 'Jan', '02', 'Feb', '03', 'Mar', '04', 'Apr', '05', 'May', '06', 'Jun', '07', 'Jul', '08', 'Aug', '09', 'Sep');

our $PI = 4. * atan2(1, 1);
our $TWOPI = 2. * $PI;
our $HALFPI = 0.5 * $PI;
our $DEG2RAD = $PI / 180.;
our $warningfooter = '';
my $titleline3;

### SET REGION DEPENDENT PARAMS
### *NB* domain param arrays are _0_ index based
our ($MOAD_STAND_LAT, $MOAD_STAND_LAT_0, $MOAD_STAND_LAT_1, $MOAD_KNOWN_LAT);
our ($MOAD_KNOWN_LON, $MOAD_STAND_LONS, $RATIO_TO_MOAD);
our (@DOMAIN_ORIGIN_URI, @DOMAIN_ORIGIN_URJ, @DOMAIN_ORIGIN_LLI, @DOMAIN_ORIGIN_LLJ, @RATIO_TO_PARENT);
our (@e_we, @e_sn, $MOAD_DELTA_X, $MOAD_DELTA_Y, $MAP_PROJ_NAME);
our ($DX, $GRID_IMIN, $GRID_IMAX, $GRID_JMIN, $GRID_JMAX);
our ($NXmassMOAD, $NYmassMOAD);

if (-r "$DATADIR/namelist.wps") {
    &read_region_params($DATADIR, ${REGION});
}
else {
    reportError("*** ERROR: No region data for $REGION : $DATADIR/namelist.wps");
    exit 0;
}


### params derived from regional grid params
# note param arrays use _perl_ indexing
$RATIO_TO_MOAD = 1;
# Eric - predefined a number of variables to prevent warning/error msgs
# my ($NXmassMOAD,$NYmassMOAD, $GRID_CONE,
#    $se_subgridi2moadcenteri,$se_subgridj2moadcenterj,$nw_subgridi2moadcenteri, $nw_subgridj2moadcenterj
#      , $b_subgridi2moadcenteri) = 0,0,0,0,0,0,0,0;


for (my $igrid = 2; $igrid <= $KGRID; $igrid++) {
    $RATIO_TO_MOAD = $RATIO_TO_MOAD * $RATIO_TO_PARENT[$KGRID];
}
$DX = $MOAD_DELTA_X / $RATIO_TO_MOAD;

### must allow for change from domain grid to mass point grid
$GRID_IMIN = 1;
$GRID_IMAX = ($DOMAIN_ORIGIN_URI[$KGRID] - $DOMAIN_ORIGIN_LLI[$KGRID]) * $RATIO_TO_PARENT[$KGRID];

$GRID_JMIN = 1;
$GRID_JMAX = ($DOMAIN_ORIGIN_URJ[$KGRID] - $DOMAIN_ORIGIN_LLJ[$KGRID]) * $RATIO_TO_PARENT[$KGRID];

### params needed for latlon->ij conversion
$NXmassMOAD = $DOMAIN_ORIGIN_URI[1] - 1;
#print " NXmassMOAD : $NXmassMOAD \n";

$NYmassMOAD = $DOMAIN_ORIGIN_URJ[1] - 1;
#print " NYmassMOAD : $NYmassMOAD\n";

### param needed for uv2wd conversion
our $GRID_CONE = cos($DEG2RAD * (90. - $MOAD_STAND_LAT));

### GET SUBGRIDij TO MOADij LINEAR CONVERSION SLOPE,INTERCEPT (speeds lat,lon calc since invariant for grid)
my ($se_subgridi2moadcenteri, $se_subgridj2moadcenterj) = &subgridij2moadcenterij($KGRID, $GRID_IMIN, $GRID_JMIN);
my ($nw_subgridi2moadcenteri, $nw_subgridj2moadcenterj) = &subgridij2moadcenterij($KGRID, $GRID_IMAX, $GRID_JMAX);
my $b_subgridi2moadcenteri = $se_subgridi2moadcenteri;
my $b_subgridj2moadcenterj = $se_subgridj2moadcenterj;
my $m_subgridi2moadcenteri = ($nw_subgridi2moadcenteri - $se_subgridi2moadcenteri) / ($GRID_IMAX - $GRID_IMIN);
my $m_subgridj2moadcenterj = ($nw_subgridj2moadcenterj - $se_subgridj2moadcenterj) / ($GRID_JMAX - $GRID_JMIN);
my ($wstardata, $blwindspddata, $blwinddirdata) = (), (), ();

my %filetimelist;
my %lslist;

# Eric GBSC RASP uses explicit dates in directory names
# Removed  unneeded date logic

if ($LVALIDTIME == 1) {
    ### SINGLE-TIME CASE, READ NON-ARCHIVE DATA
    #print "Doing single-time case \n";
    ### TEST FOR AVAILABLE DATA
    my $checkfile = "${DATADIR}/wstar.${VALIDTIME}local.${GRID}.data";
    if ($checkfile =~ m|^(\.\./)?[A-Za-z]+/[0-9]{4}-[0-9]{2}-[0-9]{2}/([a-z0-9]+(\.[a-z0-9]+)+)$|) {$checkfile = $1;}
    #print "checkfile : $checkfile \n";
    my $filetest = `grep '^ *---' $checkfile 2>&1`;
    if ($filetest !~ m|---|) {
        reportError(" *** ERROR: Data not available for:  $REGION :  ${DATADIR}/wstar.${VALIDTIME}local.${GRID}.data");
        exit 0;
    }
    ### TRY TO REPLACE GENERIC DATE WITH DATE EXTRACTED FROM DATA FILE

    ### READ W* DATA
    my $inputdatafile = "${DATADIR}/wstar.${VALIDTIME}local.${GRID}.data";
    #print "inputdatafile : $inputdatafile  \n";
    # @wstardata = &zmapxyplotread($inputdatafile);
    ($errorMsg, @subData) = &zmapxyplotread($inputdatafile);
    if ($errorMsg != "") {
        reportError($errorMsg);
        exit 0;
    }
    else {
        @wstardata = @subData;
    }
    ### READ WIND DATA
    $inputdatafile = "${DATADIR}/blwindspd.${VALIDTIME}local.${GRID}.data";
    #@blwindspddata  = &zmapxyplotread($inputdatafile);
    ($errorMsg, @subData) = &zmapxyplotread($inputdatafile);
    if ($errorMsg != "") {
        reportError($errorMsg);
        exit 0;
    }
    else {
        @blwindspddata = @subData;
    }
    $inputdatafile = "${DATADIR}/blwinddir.${VALIDTIME}local.${GRID}.data";
    #@blwinddirdata  = &zmapxyplotread($inputdatafile);
    ($errorMsg, @subData) = &zmapxyplotread($inputdatafile);
    if ($errorMsg != "") {
        reportError($errorMsg);
        exit 0;
    }
    else {
        @blwinddirdata = @subData;
    }
    #print ("wstardata : @wstardata \nblwindspddata : @blwindspddata \n blwinddirdata : @blwinddirdata");
}
else {
    ### MULTI-TIME CASE, READ NON-ARCHIVE DATA
    ### SET DATAFILE & TIME LISTS
    # Need to ensure ALL files relate to correct date: DST change can leave old files around
    # Assume that 1200lst contains correct date: all others must have this date
    my $gooddate;
    my $dateline = `grep 'Day=' "${DATADIR}/wstar.${VALIDTIME}local.${GRID}.data" 2>&1`;
    if ($dateline =~ m|Day= ([^= ]+)  *([^= ]+)  *([^= ]+)  *([^= ]+) |) {
        $validdayprt = "$4 $3 $monthname{$2} $1";
        $gooddate = "Day= $1 $2 $3";
    }
    foreach my $param ('wstar', 'blwindspd', 'blwinddir') {
        $wildcard = "${DATADIR}/$param.*local.${GRID}.data";
        #print ("wildcard : $wildcard \n");
        @unsortfiles = `ls ${wildcard} `;
        @sortfiles = sort @unsortfiles;
        #print "sortfiles: @sortfiles\n ";
        foreach my $f (@sortfiles) {
            chomp($f);
            #print "f: $f\n";
            my $founddate = `grep -c '$gooddate' $f 2>&1`;
            chomp($founddate);
            if ($founddate > 0) {
                #print ("param : $param   $f \n");
                push @{$lslist{$param}}, $f; # adds $f to list
                #print "lstist{param} :  @{$lslist{$param}}\n";
            }
            # Flag unused datafiles
            # else { print "Not using $f for $param\n"; }
        }
        my $maxindex = $#{$lslist{$param}};
        for (my $ii = 0; $ii <= $maxindex; $ii++) {
            chomp($lslist{$param}[$ii]);
            my $local = "local";
            if ($lslist{$param}[$ii] =~ m|^.*\.([0-9][0-9][0-9][0-9])\Q$local\E|) {
                $filetimelist{$param}[$ii] = $1;
            }
        }
    }
    # Check data available for all params
    #print "wstar last index:  $#{$lslist{'wstar'}}  blwindspd last index:  $#{$lslist{'blwindspd'}}  blwinddir last index: $#{$lslist{'blwinddir'}} \n ";
    if ($#{$lslist{'wstar'}} == -1 || $#{$lslist{'blwindspd'}} == -1 || $#{$lslist{'blwinddir'}} == -1) {
        reportError(" *** ERROR: Data not available for :  $REGION  $validdayprt ");
        exit 0;
    }
    ## Check data times same for all params
    if ($#{$filetimelist{'wstar'}} != $#{$filetimelist{'blwindspd'}}
        ||
        $#{$filetimelist{'blwindspd'}} != $#{$filetimelist{'blwinddir'}}) {
        reportError(" *** ERROR: Data times for  wstar, blwindspd & blwinddir are different:  $REGION  $validdayprt ");
        exit 0;
    }
    ### READ ONE DATA FILE TO SET NNX,NNY
    #@wstardata  = &zmapxyplotread("${DATADIR}/wstar.1200local.${GRID}.data");
    ($errorMsg, @subData) = &zmapxyplotread("${DATADIR}/wstar.1200local.${GRID}.data");
    if ($errorMsg ne "") {
        reportError($errorMsg);
        exit 0;
    }
    else {
        @wstardata = @subData;
    }
}
# Eric - removed archive day as GBSC RASP doesn't have archives

our ($imap1in, $imap2in, $jmap1in, $jmap2in);

#print "Setting grid parms\n";
### SET 2D ARRAY DIMENSIONS FROM DATAFILE READ
my $NNX = $GRID_IMAX - $GRID_IMIN + 1;
my $NNY = $GRID_JMAX - $GRID_JMIN + 1;
### SANITY CHECK OF DATA FILE EXTENT
if ($imap1in != $GRID_IMIN) {
    reportError("*** ERROR - data file imap1 does not match expected value : $imap1in != $GRID_IMIN ");
    exit 0;
}
if ($imap2in != $GRID_IMAX) {
    reportError("*** ERROR - data file imap2 does not match expected value : $imap2in != $GRID_IMAX ");
    exit 0;
}
if ($jmap1in != $GRID_JMIN) {
    reportError("*** ERROR - data file jmap1 does not match expected value : $jmap1in != $GRID_JMIN ");
    exit 0;
}
if ($jmap2in != $GRID_JMAX) {
    reportError("*** ERROR - data file jmap2 does not match expected value : $jmap2in != $GRID_JMAX ");
    exit 0;
}

my (%posttimedata, %posttimesec, %pretimedata, %pretimesec, %posttimeindex);
my (%posthhmm, %prehhmm, $clocksec);
#print "LVALIDTIME : $LVALIDTIME\n";
if ($LVALIDTIME == 0) {
    ### MULTI-TIME CASE, SET UP INITIAL PRE,POST_TIME DATA ARRAYS
    ### INITIALIZE
    my (@paramwarning0, @paramwarning1);
    #print "VALIDTIME: $VALIDTIME \n";
    $clocksec = 3600. * substr($VALIDTIME, 0, 2) + 60. * substr($VALIDTIME, 2, 2);
    #print "clocksec : $clocksec \n";
    ### FIND INDEX OF TIME IMMEDIATELY _AFTER_ INPUT $VALIDTIME
    foreach my $param ('wstar', 'blwindspd', 'blwinddir') {
        for (my $ii = 0; $ii <= $#{$filetimelist{$param}}; $ii++) {
            #print " $filetimelist{$param}[$ii]  >? $VALIDTIME \n" ;
            if ($filetimelist{$param}[$ii] > $VALIDTIME) {
                $posttimeindex{$param} = $ii;
                last;
            }
        }
        ### IF NONE, write warning & set $posttimeindex to last time and set pre,post arrays to that time
        if (!defined $posttimeindex{$param}) {
            $posttimeindex{$param} = $#{$lslist{$param}};
            ### get new data
            ### FOR NON-ARCHIVE DATA
            #print "zmapxyplotread on file: ${DATADIR}/${filetimelist {$param}[ $posttimeindex{$param} ]}local.${GRID}.data \n";
            #@{$posttimedata{$param}} = &zmapxyplotread($inputdatafile);
            $inputdatafile = "${DATADIR}/${filetimelist {$param}[ $posttimeindex{$param} ]}local.${GRID}.data";
            ($errorMsg, @subData) = &zmapxyplotread($inputdatafile);
            if ($errorMsg ne "") {
                reportError($errorMsg);
                exit 0;
            }
            else {
                @{$posttimedata{$param}} = @subData;
            }


            ### set posttimesec large so will never again try to update data
            $posthhmm{$param} = 9999;
            $prehhmm{$param} = $posthhmm{$param};
            push @paramwarning0, $param;
        }
        ### IF FIRST, write warning
        elsif ($posttimeindex{$param} == 0) {
            ### NON-ARCHIVE DATA
            #print "first zmapxyplotread on file: ${DATADIR}/${param}.${filetimelist {$param}[ 0 ]}local.${GRID}.data \n";
            #@{$posttimedata{$param}} = &zmapxyplotread("${DATADIR}/${param}.${filetimelist {$param}[ 0 ]}local.${GRID}.data");
            $inputdatafile = "${DATADIR}/${param}.${filetimelist {$param}[ 0 ]}local.${GRID}.data";
            ($errorMsg, @subData) = &zmapxyplotread($inputdatafile);
            if ($errorMsg ne "") {
                reportError($errorMsg);
                exit 0;
            }
            else {
                @{$posttimedata{$param}} = @subData;
            }

            $posthhmm{$param} = $filetimelist{$param}[$posttimeindex{$param}];
            $prehhmm{$param} = $posthhmm{$param};
            push @paramwarning1, $param;
        }
        ### ELSE set pre/post arrays to time before/after $VALIDTIME
        else {
            ### FOR NON-ARCHIVE DATA
            #@{$posttimedata{$param}} = &zmapxyplotread("${DATADIR}/${param}.${filetimelist {$param}[ $posttimeindex{$param} ]}local.${GRID}.data");
            $inputdatafile = "${DATADIR}/${param}.${filetimelist {$param}[ $posttimeindex{$param} ]}local.${GRID}.data";
            ($errorMsg, @subData) = &zmapxyplotread($inputdatafile);
            if ($errorMsg ne "") {
                reportError($errorMsg);
                exit 0;
            }
            else {
                @{$posttimedata{$param}} = @subData;
            }

            #@{$pretimedata{$param}} = &zmapxyplotread("${DATADIR}/${param}.${filetimelist {$param}[ $posttimeindex{$param} - 1 ]}local.${GRID}.data");
            my $inputdatafile = "${DATADIR}/${param}.${filetimelist {$param}[ $posttimeindex{$param} - 1 ]}local.${GRID}.data";
            ($errorMsg, @subData) = &zmapxyplotread($inputdatafile);
            if ($errorMsg ne "") {
                reportError($errorMsg);
                exit 0;
            }
            else {
                @{$pretimedata{$param}} = @subData;
            }

            $posthhmm{$param} = $filetimelist{$param}[$posttimeindex{$param}];
            $prehhmm{$param} = $filetimelist{$param}[$posttimeindex{$param} - 1];
        }
        ### set pre,post_time clock time
        $pretimesec{$param} = 3600. * substr($prehhmm{$param}, 0, 2) + 60. * substr($prehhmm{$param}, 2, 2);
        $posttimesec{$param} = 3600. * substr($posthhmm{$param}, 0, 2) + 60. * substr($posthhmm{$param}, 2, 2);
    }
    ### note: arrays @paramwarning0,1 give parameters missing, but currently not printed
    if ($#paramwarning0 > -1) {$warningfooter .= sprintf "data unavailable after %s so assumed constant then\n", $VALIDTIME;}
    if (defined $paramwarning1[0]) {$warningfooter .= sprintf "data unavailable before %s so assumed constant then\n", $filetimelist{$paramwarning1[0]}[$posttimeindex{$paramwarning1[0]}];}
}


### extract polar a,b,c from $polarCoefficients string
my ($apolar, $bpolar, $cpolar);
if ($polarCoefficients =~ m|[0-9\+\-\.Ee]+,[0-9\+\-\.Ee]+,[0-9\+\-\.]+|) {($apolar, $bpolar, $cpolar) = split(/,/, $polarCoefficients);}
else {
    reportError("ERROR: Invalid glider polar (a,b c) coefficients. Please contact support at  flightservice\@soaringforecast.org with this error");
    exit 0;
}

### convert input lat,lon to gridpts
### convert turnpt lat,lon into gridpt locations (can be non-integer - fortran indexing)
my (@xturnpts, @yturnpts, $iturnpt);
for ($iturnpt = 0; $iturnpt <= $nleg; $iturnpt++) {
    my $alat = $alatpts[$iturnpt];
    ### check that this is a West longitude
    my $alon = $alonpts[$iturnpt];
    ### convert negative W longitude
    if ($alon < 0) {$alon = $alon + 360.;}
    ### CALC MOAD I,J (non-integer) RELATIVE TO CENTER OF MOAD GRID
    ### *NB* W3FB11 USES LAT/LON ASSOCIATED WITH (1,1) *NOT* (0,0) SO HAVE TO SHIFT ACCORDINGLY !
    my ($airelative, $ajrelative) = &W3FB11($alat, $alon, $MOAD_KNOWN_LAT, $MOAD_KNOWN_LON, $MOAD_DELTA_X, $MOAD_STAND_LONS, $MOAD_STAND_LAT);

    #4test:  printf "CENTER aI,aJ=%8.2f%8.2f \n", $airelative,$ajrelative ;
    ### CALC MOAD LAMBERT I,J (non-integer) SHIFTED TO MOAD *MASS* GRID
    my $aimoad = $airelative + 0.5 * ($NXmassMOAD - 1);
    my $ajmoad = $ajrelative + 0.5 * ($NYmassMOAD - 1);
    ### COMPUTE MOAD I,J FOR SELECTED GRID
    my $ai = $aimoad;
    my $aj = $ajmoad;
    ### CONVERT MOAD *MASS* INDEX TO NON-MOAD SUBGRID *MASS* INDEX
    ### note param arrays use _perl_ indexing
    for (my $igrid = 2; $igrid <= $KGRID; $igrid++) {
        if (!defined $RATIO_TO_PARENT[${igrid}]
            || !defined $DOMAIN_ORIGIN_LLI[${igrid}]
            || !defined $DOMAIN_ORIGIN_LLJ[${igrid}]) {
            reportError("ERROR: Bad grid number = $KGRID ");
            exit 0;
        }
        $ai = 0.5 + $RATIO_TO_PARENT[${igrid}] * ($ai - ($DOMAIN_ORIGIN_LLI[${igrid}] - 0.5));
        $aj = 0.5 + $RATIO_TO_PARENT[${igrid}] * ($aj - ($DOMAIN_ORIGIN_LLJ[${igrid}] - 0.5));
    }
    $xturnpts[$iturnpt] = $ai;
    $yturnpts[$iturnpt] = $aj;
    #4test:  print "TURNPT $iturnpt LAT,LON $alat $alon => GRIDPT $gridi $gridj => ARRAY PT $xturnpts[$iturnpt] $yturnpts[$iturnpt] \n";
}
### set  track turnpoints in grid pt locations (fortran indexing) - need not be integer
#4test $xturnpts[0] = 4.0 ; $yturnpts[0] = 4.0 ;
#4test $xturnpts[1] = 10.0 ; $yturnpts[1] = 10.0 ;
#4test $xturnpts[2] = 4.0 ; $yturnpts[2] = 4.0 ;

my ($dummy, $revtrackdegtrue, $blwindspdmps, $blwinddirtrue, $windanglerad);
my (@tailwindmps, @thermalpct);

### PRINT HEADER
my ($clockprt, $clockprt2, $clockstr, $clockdash, $clockpr2);
### ADD EXTRA COLUMN FOR MULTI-TIME TIME
if ($LVALIDTIME == 0) {
    $clockprt = '          ';
    $clockpr2 = '    ';
    $clockstr = ' ClockTime';
    $clockdash = '---------';
}
else {$clockprt = $clockpr2 = $clockstr = $clockdash = '';}

my $flightSummary = "";
# Note double escape for newline and quotes as text will be going out in JSON
$flightSummary = $flightSummary . "${clockpr2}            FLIGHT TRACK AVERAGES             \\n";
$flightSummary = $flightSummary . " ${clockdash}-------------------------------------------- \\n";
$flightSummary = $flightSummary . "${clockpr2} (\\\"optimal\\\" uses wind-adjusted speed-to-fly)\\n";
if ($LVALIDTIME == 0) {
    $flightSummary = $flightSummary . "${clockpr2} Valid: $validdayprt  StartTime: ${VALIDTIME}local\\n";
}
else {
    $flightSummary = $flightSummary . "${clockpr2} Valid: $validdayprt  ${VALIDTIME}lst\\n";
}
$flightSummary = $flightSummary . "${clockpr2} Region: $REGION\\n";

### CALC NO-WIND L/D FOR PRINTOUT
my ($vloverd, $wloverd, $LoverD);
$vloverd = sqrt($cpolar / $apolar);                                      # in km/hr
$wloverd = $apolar * $vloverd * $vloverd + $bpolar * $vloverd + $cpolar; # negative, in m/s
$LoverD = (-0.2777777777 * $vloverd) / $wloverd;                         # convert v to m/s and allow for negative w
$flightSummary = $flightSummary . sprintf("%s PolarInfo: %s (L/D=%.0f)\\n", $clockpr2, $glider, $LoverD);
$flightSummary = $flightSummary . sprintf("${clockpr2} Polar speed adjustment: %s  \\n",  $polarFactor);
# printf "${clockpr2} ThermallingSinkrate: %s m/s\n", $thermallingsinkrate ;
$flightSummary = $flightSummary . sprintf("${clockpr2} ThermallingSinkrate: %s kt\\n", $thermallingsinkrate * $mps2kt);
if ($thermalmultiplier != 1) {$flightSummary = $flightSummary . sprintf("${clockpr2} ThermalStrengthMuliplier: %.1f \\n", $thermalmultiplier);}

if (defined $adesc[0]) {
    # TriGraphs
    $flightSummary = $flightSummary . sprintf("${clockpr2} TnPts: %-3s - %s (%.3f,%.3f)\\n", $atp[0], $adesc[0], $alatpts[0], $alonpts[0]);
    for (my $i = 1; $i <= $nleg; $i++) {
        $flightSummary = $flightSummary . sprintf("${clockpr2}        %-3s - %s (%.3f,%.3f)\\n", $atp[$i], $adesc[$i], $alatpts[$i], $alonpts[$i]);
    }
}
else {
    # LatLons
    $flightSummary = $flightSummary . sprintf("${clockpr2} Lat,Lons:  %7.5f %8.5f\\n", $alatpts[0], $alonpts[0]);
    for (my $i = 1; $i <= $nleg; $i++) {
        $flightSummary = $flightSummary . sprintf("${clockpr2}            %7.5f %8.5f\\n", $alatpts[$i], $alonpts[$i]);
    }
}

### PRINT COLUMN HEADERS
$flightSummary = $flightSummary . " ${clockdash}------------------------------------------------ \\n";
$flightSummary = $flightSummary . " L ${clockprt}  -Spatial-Avg- ------Optimal-Flight-Avg------- \\n";
$flightSummary = $flightSummary . " E ${clockstr}      Tail Clmb Tail Clmb      Gnd  Gnd Air Thm \\n";
$flightSummary = $flightSummary . " G ${clockprt} Dist Wind Rate Wind Rate Time Spd  Spd Spd Pct \\n";
$flightSummary = $flightSummary . "   ${clockprt}  km   kt   kt   kt   kt   min  kt km/h  kt  % \\n";


### START OF LOOP OVER ALL TURNPOINTS
my $totallength = 0;
my $totalspatialavgclimbratesum = 0;
my $totalspatialavgtailwindsum = 0;
my $totalsec = 0;
my $totalclimbratesum = 0;
my $totalthermaltime = 0;
my $totaloptairspeedsum = 0;
my $totaltailwindsum = 0;
my $ltotalsolution = 1;
### compute % of no solution "blocked" boxes
my $totalblocked = 0;
my $totallegboxs = 0;
my $flitedist = 0;
my $flitetime = 0;
my $clockhhmm = $VALIDTIME;
my $itotpt = -1;
my $pctblocked;
my ($nlegpts, @xsort, @ysort);
my @xgridpoints = ();
my @ygridpoints = ();
my @routedata = ();

#print "Leg   Seg        XPos         YPos      Dist    Time        Length     ClimbRate       Thermal Strength   TailWind(mps)   Grnd Speed    Thermal%    Seconds \n";
#printf   " %2d   %3d  %6.2f   %6.2f    %6.0f   %5.0f      %8.0f         %5.2f                  %5.2f           %5.1f       %6.1f       %5.1f      %5.0f \n",$ileg,$i,$xsort[$i],$ysort[$i], $flitedist,$flitetime, $length[$i],$thermallingclimbrate[$i],$thermalstrength[$i],$tailwindmps[$i], $optgroundspeed[$i], $thermalpct[$i], $seconds[$i] ;

LEG:
for (my $ileg = 1; $ileg <= $#xturnpts; $ileg++) {
    ### set start,end pts for this leg
    my $xstart = $xturnpts[$ileg - 1];
    my $ystart = $yturnpts[$ileg - 1];
    my $xend = $xturnpts[$ileg];
    my $yend = $yturnpts[$ileg];
    ### SET  START,END GRID PT LOCATIONS (FORTRAN INDEXING) - need not be integer
    #4test: #45deg: $xstart = 4.0 ; $ystart = 4.0 ; $xend = 10.0 ; $yend = 10.0 ;
    #4test: #225deg: $xstart = 10.0 ;$ystart = 10.0 ;$xend = 4.0 ;$yend = 4.0 ;

    ### DO TURNPOINT VALIDITY TESTS
    if ($xturnpts[$ileg] < 1) {
        reportError("*** ERROR : Turnpoint $iturnpt x extent too small : $xturnpts[$ileg] < 1 ");
        exit 0;
    }
    if ($xturnpts[$ileg] > $NNX) {
        reportError("*** ERROR : Turnpoint $iturnpt x extent too large : $xturnpts[$ileg] > $NNX ");
        exit 0
    }
    if ($yturnpts[$ileg] < 1) {
        reportError("*** ERROR : Turnpoint $iturnpt y extent too small : $yturnpts[$ileg] < 1 ");
        exit 0
    }
    if ($yturnpts[$ileg] > $NNY) {
        reportError("*** ERROR : Turnpoint $iturnpt y extent too large : $yturnpts[$ileg] > $NNY ");
        exit 0;
    }
    if ($ileg == 1) {
        ### DO TURNPOINT VALIDITY TESTS
        if ($xturnpts[0] < 1) {
            reportError("*** ERROR : Turnpoint 0 x extent too small : $xturnpts[0] < 1 ");
            exit 0;
        }
        if ($xturnpts[0] > $NNX) {
            reportError("*** ERROR : Turnpoint 0 x extent too large : $xturnpts[0] > $NNX ");
            exit 0;
        }
        if ($yturnpts[0] < 1) {
            reportError("*** ERROR : Turnpoint 0 y extent too small : $yturnpts[0] < 1 ");
            exit 0;
        }
        if ($yturnpts[0] > $NNY) {
            reportError("*** ERROR :Turnpoint 0 y extent too large : $yturnpts[0] > $NNY ");
            exit 0;
        }
    }

    ### CALC OPTIMAL SPEED
    ### DO POLAR WEIGHT RATIO WEIGHT ADJUSTMENT
    my $anorm = $apolar / $polarFactor;
    my $bnorm = $bpolar;
    my $cnorm = $cpolar * $polarFactor;
    my @optairspeed_inglide;


    ### CONVERT POLAR COEFS TO USE VELOCITY IN m/s
    ### *NB* following calcs assume apolar,bpolar,cpolar give NEGATIVE W=m/s for V=km/hr => a,b=negative c=positive ala Reichmann
    ### so must convert to coeffs which will give all velocities in m/s
    $anorm = $anorm / ($kmphr2mps * $kmphr2mps);
    $bnorm = $bnorm / $kmphr2mps;
    $cnorm = $cnorm;
    #use_kts: ### TO USE KTS EVERYWHERE
    #use_kts+  $anorm = $apolar ;
    #use_kts+  $bnorm = $bpolar ;
    #use_kts+  $cnorm = $cpolar ;

    ### DETERMINE CELL BOXES ALONG START->END PATH
    ($nlegpts, @xsort) = &cell_path_intersections($xstart, $ystart, $xend, $yend);
    ### must split return into 2 arrays
    @ysort = splice @xsort, $nlegpts, $nlegpts;

    ### DETERMINE INTEGER GRID BOX CONTAINING LINE BETWEEN THIS AND NEXT POINT
    ###    AND LENGTH OF PATH BETWEEN THOSE POINTS
    ### *UNITS* WITHIN THIS LOOP CURRENTLY:  w=m/s(convert from datafile)  speed/wind=m/s(convert from datafile) length=m(ala grid)
    my (@igridptafter, @jgridptafter, $kgridptafter, @length, @seconds, @optgroundspeed, @lsolution, @nblocked, @nlegboxs);
    my (@thermalstrength, @thermallingclimbrate);
    # Eric - collect track data into array, eventually convert x,y grid points to lat/lons
    # @xgridpoints, @ygridpoints, @routedata must end up with same number of elements

    $igridptafter[$nlegpts - 1] = 0;
    $jgridptafter[$nlegpts - 1] = 0;
    $length[$nlegpts - 1] = 0;
    $seconds[$nlegpts - 1] = 0;
    $optgroundspeed[$nlegpts - 1] = 0;
    $lsolution[$ileg] = 0;
    ### compute % of no solution "blocked" boxes
    $nblocked[$ileg] = 0;
    $nlegboxs[$ileg] = $nlegpts - 1;
    ### START OF LOOP OVER POINTS ALONG LEG
    for (my $i = 0; $i <= ($nlegpts - 2); $i++) {
        ### set overal totals
        $itotpt += 1;
        ### determine grid box for line between this and next point
        $igridptafter[$i] = nint(0.5 * ($xsort[$i] + $xsort[$i + 1]));
        $jgridptafter[$i] = nint(0.5 * ($ysort[$i] + $ysort[$i + 1]));
        ### determine length between this and next point
        $length[$i] = $DX * sqrt(($xsort[$i + 1] - $xsort[$i]) ** 2 + ($ysort[$i + 1] - $ysort[$i]) ** 2);
        ### determine optimal time from optimal speed
        $kgridptafter = ($jgridptafter[$i] - 1) * $NNX + $igridptafter[$i] - 1;
        ### START OF OPTGROUNDSPEED CALC FOR THIS GRIDPT
        ### following assumes W* in ft/min
        ### following assumes POSITIVE thermallingsinkrate=m/s
        ### following gives thermallingclimbrate in m/s
        ### multiply thermal climb rate by fudge factor
        ### USE W* VALUE
        ### ALLOW USE OF LARGEST W VALUE IN SURROUNDING AREA
        if ($LWSURROUND <= 0) {
            ### this is code prior to adding $LWSURROUND - kept outside loop so have for reference (& slightly more efficient)
            if ($LVALIDTIME == 1) {
                $thermalstrength[$i] = $wstardata[$kgridptafter] / $mps2fpm;
            }
            elsif ($prehhmm{'wstar'} == $posthhmm{'wstar'}) {
                $thermalstrength[$i] = $posttimedata{'wstar'}[$kgridptafter] / $mps2fpm;
            }
            else {
                $thermalstrength[$i] = ($pretimedata{'wstar'}[$kgridptafter] + (($clocksec - $pretimesec{'wstar'}) / ($posttimesec{'wstar'} - $pretimesec{'wstar'})) * ($posttimedata{'wstar'}[$kgridptafter] - $pretimedata{'wstar'}[$kgridptafter])) / $mps2fpm;
            }
            $thermallingclimbrate[$i] = ($thermalmultiplier * $wstardata[$kgridptafter] / $mps2fpm) - $thermallingsinkrate;
            #4testprint: print " $i 4SURROUND=0 : $igridptafter[$i] $jgridptafter[$i] => $kgridptafter : $wstardata[$kgridptafter] \n";

        }
        else {
            ### INTERATE OVER BOX MIN,MAX INDICES
            my $kdist = $LWSURROUND;
            my $igrid = $igridptafter[$i];
            my $jgrid = $jgridptafter[$i];
            my $iixmin = &max(((1), ($igrid - $kdist)));
            my $iixmax = &min((($NNX), ($igrid + $kdist)));
            my $iiymin = &max(((1), ($jgrid - $kdist)));
            my $iiymax = &min((($NNY), ($jgrid + $kdist)));
            my $wstarmax = -99999.;
            for (my $iiy = $iiymin; $iiy <= $iiymax; $iiy++) {
                ### slightly more efficient to only iter by 1 inside x loop
                my $kk = ($iiy - 1) * $NNX + $iixmin - 1 - 1;
                for (my $iix = $iixmin; $iix <= $iixmax; $iix++) {
                    $kk++;
                    my $wstardata;
                    #4testprint: print " $kdist : $iix $iiy => $kk \n" ;
                    if ($LVALIDTIME == 1) {
                        $wstardata = $wstardata[$kk];
                        #original $thermalstrength[$i] = $wstardata[$kgridptafter] / $mps2fpm ;
                    }
                    elsif ($prehhmm{'wstar'} == $posthhmm{'wstar'}) {
                        $wstardata = $posttimedata{'wstar'}[$kk];
                    }
                    else {
                        $wstardata = $pretimedata{'wstar'}[$kk] + (($clocksec - $pretimesec{'wstar'}) / ($posttimesec{'wstar'} - $pretimesec{'wstar'})) * ($posttimedata{'wstar'}[$kk] - $pretimedata{'wstar'}[$kk]);
                    }
                    if ($wstarmax < $wstardata) {$wstarmax = $wstardata;}
                    #4testprint:  print " $i = $iix $iiy => $kk : $wstarmax $wstardata \n";
                }
            }
            $thermalstrength[$i] = $wstarmax / $mps2fpm;
            $thermallingclimbrate[$i] = ($thermalmultiplier * $wstarmax / $mps2fpm) - $thermallingsinkrate;
            #4testprint: print "DataTime $i  $clocksec  $pretimesec{'wstar'} $posttimesec{'wstar'}  $prehhmm{'wstar'} $posthhmm{'wstar'} \n";
        }
        #use_kts: ### TO USE KTS EVERYWHERE
        #use_kts+  $thermallingclimbrate = $mps2kt * ( ( $wstardata[$kgridptafter] / $mps2fpm ) ) - $thermallingsinkrate ;
        ### use eqn VI from Reichmann Appendix * REQUIRE ALL VELOCITIES TO BE M/S BUT THEN CONVERT RESULT TO KT*

        ### ADJUST GLIDE TO ALLOW FOR WIND
        ### must use kpt of entire grid - output wind speed units same as that input
        ### decided to convert grid track to true direction and use cosine of angle difference to get wind components
        #unused ( $ugrid, $vgrid ) = &ruc_wd2uv ( $kptentiregrid, $windkt[$kgridptafter], $winddeg[$kgridptafter] );
        ### only ratio of $utrack,$vtrack is important, not magnitude so dont convert to actual speed
        my $dxtrack = $xsort[$i + 1] - $xsort[$i];
        my $dytrack = $ysort[$i + 1] - $ysort[$i];
        ### allow previously computed gridpoint lat/lon to be used
        my (@alat, @alon);
        if (!defined $alat[$kgridptafter] || !defined $alon[$kgridptafter]) {
            ### subgridij to moadij linear conversion speeds lat,lon calc to do here, since invariant for grid
            my $aimoadcenter = ($igridptafter[$i] - 1) * $m_subgridi2moadcenteri + $b_subgridi2moadcenteri;
            my $ajmoadcenter = ($jgridptafter[$i] - 1) * $m_subgridj2moadcenterj + $b_subgridj2moadcenterj;
            ($alat[$kgridptafter], $alon[$kgridptafter]) = &W3FB12($aimoadcenter, $ajmoadcenter, $MOAD_KNOWN_LAT, $MOAD_KNOWN_LON, $MOAD_DELTA_X, $MOAD_STAND_LONS, $MOAD_STAND_LAT);
            ### convert to negative W longitude
            if ($alon[$kgridptafter] > 180.) {$alon[$kgridptafter] = $alon[$kgridptafter] - 360.;}
        }
        ### *NB* $revtrackdegtrue defined in "meteorological" sense, i.e. in direction _opposite_ to vector, so can be compared to tailwind
        ($dummy, $revtrackdegtrue) = &uv2wswd_4latlon($dxtrack, $dytrack, $alat[$kgridptafter], $alon[$kgridptafter]);
        #4testprint:  print " --- $kgridptafter $dxtrack $dytrack => $alat[$kgridptafter],$alon[$kgridptafter] => $revtrackdegtrue \n";
        ### due to using meteorological convention for direction, use positive cosine to get tailwind
        ### USE WIND VALUE
        if ($LVALIDTIME == 1) {
            # constant time
            $blwindspdmps = $blwindspddata[$kgridptafter] / $mps2kt;
            $blwinddirtrue = $blwinddirdata[$kgridptafter];
        }
        elsif ($prehhmm{'wstar'} == $posthhmm{'wstar'}) {
            $blwindspdmps = $posttimedata{'blwindspd'}[$kgridptafter] / $mps2kt;
            $blwinddirtrue = $posttimedata{'blwinddir'}[$kgridptafter];
        }
        else {
            # start time
            $blwindspdmps = ($pretimedata{'blwindspd'}[$kgridptafter] + (($clocksec - $pretimesec{'blwindspd'}) / ($posttimesec{'blwindspd'} - $pretimesec{'blwindspd'})) * ($posttimedata{'blwindspd'}[$kgridptafter] - $pretimedata{'blwindspd'}[$kgridptafter])) / $mps2kt;

            # print "A - blwindspd = $blwindspdmps " .
            # " pretimedata = $pretimedata{'blwindspd'}[$kgridptafter]" .
            # " clocksec = $clocksec " .
            # " pretimesec= $pretimesec{'blwindspd'} " .
            # " posttimesec= $posttimesec{'blwindspd'} " .
            # " pretimesec= $pretimesec{'blwindspd'} " .
            # " posttimedata= $posttimedata{'blwindspd'}[$kgridptafter] " .
            # " pretimedata= $pretimedata{'blwindspd'}[$kgridptafter] "  .
            # "\n";
            $blwinddirtrue = ($pretimedata{'blwinddir'}[$kgridptafter] + (($clocksec - $pretimesec{'blwinddir'}) / ($posttimesec{'blwinddir'} - $pretimesec{'blwinddir'})) * ($posttimedata{'blwinddir'}[$kgridptafter] - $pretimedata{'blwinddir'}[$kgridptafter]));
            # print "B - blwinddirtrue = $blwinddirtrue " .
            # " pretimedata = $pretimedata{'blwinddir'}[$kgridptafter] " .
            # " clocksec  = $clocksec " .
            # " pretimesec = $pretimesec{'blwinddir'} "  .
            # " posttimesec = $posttimesec{'bl2inddir'} " .
            # " pretimesec = $pretimesec{'blwinddir'} " .
            # " posttimedata = $posttimedata{'blwinddir'}[$kgridptafter] " .
            # " pretimedata = $pretimedata{'blwinddir'}[$kgridptafter] " .
            # "\n";
        }
        ### *NB* $revtrackdegtrue defined in "meteorological" sense, i.e. in direction _opposite_ to vector, so can be compared to tailwind
        $windanglerad = $DEG2RAD * ($blwinddirtrue - $revtrackdegtrue);
        $tailwindmps[$i] = $blwindspdmps * cos($windanglerad);
        #4testprint: print "$ileg $i TRACK,WINDrad= $revtrackdegtrue $blwinddirtrue => $tailwindmps[$i] \n" ;
        #4test: print "TAIL/CROSSWIND(m/s) = $ileg $i $tailwindmps[$i] m/s <= $blwindspddata[$kgridptafter] kt @ $blwinddirdata[$kgridptafter] vs $dxtrack $dytrack $revtrackdegtrue \n" ;

        ### CALC OPTIMAL SOLN (optimal between-thermal airspeed does _not_ depend upon wind, but track ground speed does)
        ### use speed to fly eqn based on thermalling climb rate
        my ($denom, $optavgairspeed, $awind2track_anglerad, $gammarad);
        if ($thermallingclimbrate[$i] > 0) {
            my $sqrtarg = ($cnorm - $thermallingclimbrate[$i]) / $anorm;
            $optairspeed_inglide[$i] = sqrt($sqrtarg);
            $denom = 2. * ${thermallingclimbrate [ $i ]} - 2. * ${cnorm} - ${bnorm} * ${optairspeed_inglide [ $i ]};
            if ($denom > 0) {
                $optavgairspeed = ((${thermallingclimbrate [ $i ]} * $optairspeed_inglide[$i]) / $denom);
                #use_kts: ### TO USE KTS EVERYWHERE
                #use_kts+ $optavgairspeed = ( ( ${thermallingclimbrate[$i]} * $optairspeed_inglide[$i] ) / $denom ) ;
                $thermalpct[$i] = 100. * (1. - ($optavgairspeed / $optairspeed_inglide[$i]));

                ### DO WIND TRIANGLE CALC to get track ground speed - for triangle with two known sides (speeds) and known non-enclosed angle
                ### START OF TESTED WIND TRIANGLE CALC
                ### ensure angle alpha=$wind2track_anglerad has range 0 to PI
                ### *NB* $revtrackdegtrue defined in "meteorological" sense, i.e. in direction _opposite_ to vector, so can be compared to tailwind
                $awind2track_anglerad = abs($DEG2RAD * ($blwinddirtrue - $revtrackdegtrue));
                if ($awind2track_anglerad > $PI) {$awind2track_anglerad = $TWOPI - $awind2track_anglerad;}
                #4test: print "blwindspdmps = $blwindspdmps blwinddirtrue  $blwinddirtrue  revtrackdegtrue $revtrackdegtrue AWIND2TRACK_ANGLERAD= $awind2track_anglerad \n" ;

                my $asinarg = $blwindspdmps * sin($awind2track_anglerad) / $optavgairspeed;
                ### always use smaller angle solution (between track and airspeed bearing) (=gamma1)

                # $gammarad = atan2($asinarg, sqrt(1 - $asinarg*$asinarg)); # An alternative, but asin works when this doesn't ???
                $gammarad = asin($asinarg);
                ### tests to ensure that my thinking/logic is correct
                if ($asinarg < 0.0) {
                    reportError("ERROR STOP - asinarg = $asinarg < 0 ");
                    exit 0;
                }
                if ($gammarad < 0.0) {
                    reportError("ERROR STOP - gammarad = $gammarad < 0 ");
                    exit 0;
                }
                if ($gammarad > $HALFPI) {
                    reportError("ERROR STOP - gammarad = $gammarad > PI/2 ");
                    exit 0;
                }
                if ($asinarg > 1.0) {
                    ### BLOCKED - Wind triangle error => BL wind too strong
                    $nblocked[$ileg]++;
                    $lsolution[$ileg] = -4;
                    $optgroundspeed[$i] = 0.0;
                    $thermalpct[$i] = 100.;
                    $seconds[$i] = 0.0;
                    #4test: print "Wind triangle error => BL wind too strong - $ileg $i $asinarg $gammarad $awind2track_anglerad $blwindspdmps $optavgairspeed \n";
                }
                else {
                    my $betarad = $PI - ($awind2track_anglerad + $gammarad);
                    $denom = sin($awind2track_anglerad);
                    ### round-off error fixups needed
                    if ($denom >= 0.0000001) {$optgroundspeed[$i] = $optavgairspeed * sin($betarad) / $denom;}
                    elsif (abs(sin($betarad)) <= 0.0000001) {
                        if (abs($betarad) <= 0.0000001) {$optgroundspeed[$i] = $optavgairspeed - $blwindspdmps;}
                        elsif ((abs($betarad) - $PI) <= 0.0000001) {$optgroundspeed[$i] = $optavgairspeed + $blwindspdmps;}
                        else {
                            reportError("ERROR : failure of fixup for sine=0 : awind2track_anglerad,gammarad,betarad= $awind2track_anglerad,$gammarad,$betarad ");
                            exit 0;
                        }
                    }
                    else {
                        reportError("ERROR :  division by sine=0 : awind2track_anglerad,gammarad,betarad= $awind2track_anglerad,$gammarad,$betarad ");
                        exit 0;
                    }
                    if ($optgroundspeed[$i] <= 0.02) {
                        # PAULS ORIGINALLY <= 0.0
                        ### BLOCKED - Backward movement => BL wind too strong
                        $nblocked[$ileg]++;
                        $lsolution[$ileg] = -3;
                        $optgroundspeed[$i] = 0.0;
                        $thermalpct[$i] = 100.;
                        $seconds[$i] = 0;
                        #4test: print "Backward movement => BL wind too strong - $ileg $i $asinarg $gammarad $awind2track_anglerad $blwindspdmps $optavgairspeed \n";
                    }
                    else {
                        ### determine time along this segment of track
                        $seconds[$i] = $length[$i] / $optgroundspeed[$i];
                        #4test: print "length = $length[$i] optgroundspeed = $optgroundspeed[$i] seconds =  $seconds[$i]\n";
                        #4test: print "OptTrackspeed - $ileg $i $thermallingclimbrate[$i] $revtrackdegtrue $blwinddirtrue $blwindspdmps $optairspeed_inglide[$i] $optavgairspeed $optgroundspeed[$i] $seconds[$i] \n";
                        #4test: print "                     $awind2track_anglerad $gammarad $betarad \n";
                    }
                    ### END OF TESTED WIND TRIANGLE CALC
                }
            }
            else {
                ### BLOCKED - no optimal airspeed solution => thermal climb rate too small
                $nblocked[$ileg]++;
                $lsolution[$ileg] = -2;
                $optgroundspeed[$i] = $seconds[$i] = 0.0;
                $thermalpct[$i] = 100.;
                $seconds[$i] = 0;
                #4test: print "Optgroundspeed=0 DENOM<0 - $ileg $i $denom $thermallingclimbrate[$i] \n";
            }
        }
        else {
            ### BLOCKED - thermalling climb rate <= 0
            $nblocked[$ileg]++;
            $lsolution[$ileg] = -1;
            $optgroundspeed[$i] = $seconds[$i] = 0.0;
            $thermalpct[$i] = 100.;
            #4test: print "Optgroundspeed=0 CLIMBRATE<0 - $ileg $i $thermallingclimbrate[$i] \n";
        }

        ### END OF OPTGROUNDSPEED CALC
        ###  NB if modify, must also modify print for last point !
        push(@xgridpoints, $xsort[$i]);
        push(@ygridpoints, $ysort[$i]);
        #print " xgridpoints[$i] : ${xgridpoints[$i]}, ygridpoints[$i] = ${ygridpoints[$i]} \n";
        my @pointdata = ($ileg, $i, $xsort[$i], $ysort[$i], $flitedist, $flitetime, $length[$i], $thermallingclimbrate[$i], $thermalstrength[$i], $tailwindmps[$i], $optgroundspeed[$i], $thermalpct[$i], $seconds[$i]);
        push(@routedata, \@pointdata);

        #4test: printf "%2d %3d %3d %6.1f %6.1f %5d %6d %8.0f %5.2f %5.2f %5.1f %6.1f %5.1f %5.0f \n",$ileg,$i,$kgridptafter,$xsort[$i],$ysort[$i], $flitetime, $flitedist, $length[$i],$thermallingclimbrate[$i],$thermalstrength[$i],$tailwindmps[$i], $optgroundspeed[$i], $thermalpct[$i], $seconds[$i] ;
        ### add to total time here so used for next file write

        $flitedist += $length[$i];
        $flitetime += $seconds[$i];
        ###- UPDATE CLOCK SECS & GET NEW DATA IF NEED BE
        if ($LVALIDTIME == 0) {
            $clocksec += $seconds[$i];
            my @paramwarning;
            $#paramwarning = -1;
            foreach my $param ('wstar', 'blwindspd', 'blwinddir') {
                if ($clocksec > $posttimesec{$param}) {
                    ### age current data
                    @{$pretimedata{$param}} = @{$posttimedata{$param}};
                    $prehhmm{$param} = $posthhmm{$param};
                    $pretimesec{$param} = $posttimesec{$param};
                    ### IF LAST, set to constant value by not updating posttimedata & write warning
                    if ($posttimeindex{$param} == $#{$lslist{$param}}) {
                        ### set posttimesec large so will never again try to update data
                        $posthhmm{$param} = 99999;
                        $posttimesec{$param} = 99999.;
                        push @paramwarning, $param;
                    }
                    else {
                        ### get new data
                        $posttimeindex{$param}++;

                        my $inputdatafile = "${DATADIR}/${param}.${filetimelist {$param}[ $posttimeindex{$param} ]}local.${GRID}.data";

                        $posthhmm{$param} = $filetimelist{$param}[$posttimeindex{$param}];
                        $posttimesec{$param} = 3600. * substr($posthhmm{$param}, 0, 2) + 60. * substr($posthhmm{$param}, 2, 2);
                    }
                }
            }
            ### note: array @paramwarning gives parameters missing, but currently not printed
            if ($#paramwarning > -1) {$warningfooter .= sprintf "data unavailable after %s so assumed constant then\n",
                $filetimelist{$paramwarning[0]}[$posttimeindex{$paramwarning[0]}];}
        }

    } ### END OF LOOP OVER POINTS ALONG LEG

    ###### PRINT LEG RESULTS
    ### CALC LEG SPATIAL AVG
    my $leglength = 0;
    my $legspatialavgclimbratesum = 0.0;
    my $legspatialavgtailwindsum = 0.0;
    for (my $i = 0; $i <= ($nlegpts - 2); $i++) {
        #4test: if ( ! defined $airspeed[$i] ) { print "UNDEFINED AIRSPEED - $i $length[$i] $seconds[$i] $vor[$i] \n" ; }
        ### sum leg time
        $leglength += $length[$i];
        $legspatialavgclimbratesum += $length[$i] * $thermallingclimbrate[$i];
        $legspatialavgtailwindsum += $length[$i] * $tailwindmps[$i];
    }
    ### TEST FOR ZERO LEG LENGTH - IF SO SKIP REST OF PROCESSING FOR THIS LEG
    if ($leglength == 0) {
        $flightSummary = $flightSummary . print "** WARNING - ignored a leg with zero length (duplicate turnpoint?)\n";
        next LEG;
    }
    $totallength += $leglength;
    $totalspatialavgclimbratesum += $legspatialavgclimbratesum;
    $totalspatialavgtailwindsum += $legspatialavgtailwindsum;
    my $legkm = 0.001 * $leglength;
    my $legspatialavgclimbrate = $legspatialavgclimbratesum / $leglength;
    my $legspatialavgclimbratekt = $legspatialavgclimbrate * $mps2kt;
    my $legspatialavgtailwindkt = $mps2kt * $legspatialavgtailwindsum / $leglength;
    ### compute % of no solution "blocked" boxes
    $totalblocked += $nblocked[$ileg];
    $totallegboxs += $nlegboxs[$ileg];
    ###### CALC + PRINT LEG OPTIMAL SOLUTION RESULTS
    if ($lsolution[$ileg] == 0) {
        my $legsec = 0;
        my $legclimbratesum = 0;
        my $legtailwindsum = 0;
        my $legthermaltimesum = 0;
        my $legoptairspeedsum = 0;
        for (my $i = 0; $i <= ($nlegpts - 2); $i++) {
            #4test: if ( ! defined $airspeed[$i] ) { print "UNDEFINED AIRSPEED - $i $length[$i] $seconds[$i] $vor[$i] \n" ; }
            ### sum leg time
            $legsec += $seconds[$i];
            $legclimbratesum += $seconds[$i] * $thermallingclimbrate[$i];
            $legtailwindsum += $seconds[$i] * $tailwindmps[$i];
            $legoptairspeedsum += $seconds[$i] * $optairspeed_inglide[$i];
            $legthermaltimesum += $seconds[$i] * $thermalpct[$i];
            #boxprint: printf "%3d %6.1f %6.1f %3d %3d %8.0f %6.1f %5.0f \n",$i,$xsort[$i],$ysort[$i], $igridptafter[$i],$jgridptafter[$i], $length[$i], $optgroundspeed[$i],$seconds[$i]  ;
        }
        $totalsec += $legsec;
        $totalclimbratesum += $legclimbratesum;
        $totalthermaltime += $legthermaltimesum;
        $totaloptairspeedsum += $legoptairspeedsum;
        $totaltailwindsum += $legtailwindsum;
        my $legmin = 0.01666667 * $legsec;
        my $legavggroundspeedkt = $mps2kt * ($leglength / $legsec);
        my $legavggroundspeedkph = 3.6 * ($leglength / $legsec);
        my $legoptairspeedavgkt = $mps2kt * $legoptairspeedsum / $legsec;
        my $legtailwindavgkt = $mps2kt * $legtailwindsum / $legsec;
        my $legclimbrateavg = $legclimbratesum / $legsec;
        my $legclimbrateavgkt = $legclimbrateavg * $mps2kt;
        my $legthermalpct = $legthermaltimesum / $legsec;
        ### MULTI-TIME LEG PRINTOUT INCLUDES TURNPOINT TIME
        if ($LVALIDTIME == 0) {
            my $oldclockhhmm = $clockhhmm;
            $clockhhmm = 100 * int($clocksec / 3600.) + int(($clocksec - 3600. * (int($clocksec / 3600.))) / 60.);
            $clockprt = sprintf "%04d-%04d", $oldclockhhmm, $clockhhmm;
        }
        else {$clockprt = '';}
        ### Now with Climb Rates in Kt
        # printf "%2d %s %4.0f %4.0f %4.1f %4.0f %4.1f %4.0f %3.0f  %3.0f %3.0f %3.0f \n", $ileg, $clockprt, $legkm, $legspatialavgtailwindkt, $legspatialavgclimbrate, $legtailwindavgkt, $legclimbrateavg, $legmin, $legavggroundspeedkt, $legavggroundspeedkph, $legoptairspeedavgkt, $legthermalpct  ;
        $flightSummary = $flightSummary . sprintf("%2d %s %4.0f %4.0f %4.1f %4.0f %4.1f %4.0f %3.0f  %3.0f %3.0f %3.0f \\n", $ileg, $clockprt, $legkm, $legspatialavgtailwindkt, $legspatialavgclimbratekt, $legtailwindavgkt, $legclimbrateavgkt, $legmin, $legavggroundspeedkt, $legavggroundspeedkph, $legoptairspeedavgkt, $legthermalpct);

    }
    else {
        # PRINT LEG RESULTS WHEN NO OPTIMAL SOLUTION
        $ltotalsolution = 0;
        # compute % of no solution "blocked" boxes
        $pctblocked = nint(100. * ($nblocked[$ileg] / $nlegboxs[$ileg]));
        # legspatialaverageclimbrate now in Kt
        $flightSummary = $flightSummary . sprintf("%2d %9s %4.0f %4.0f %4.1f   NO SOLN    %sblocked=%2d \\n", $ileg, "", $legkm, $legspatialavgtailwindkt, $legspatialavgclimbratekt, '%', $pctblocked);
        # printf "%2d  %4.0f %4.0f %4.1f   NO SOLN    %sblocked=%2d \n", $ileg, $legkm, $legspatialavgtailwindkt, $legspatialavgclimbrate, '%',$pctblocked ;
    }

} ### END OF LOOP OVER ALL TURNPOINTS

### Create JSON output
push(@xgridpoints, $xsort[$nlegpts - 1]);
push(@ygridpoints, $ysort[$nlegpts - 1]);
#print " final xgridpoints  :  $xgridpoints[$#xgridpoints]";
#print " final ygridpoints :  $ygridpoints[$#ygridpoints]) \n";
#print " xgridpoints[$#xgridpoints] : ${xgridpoints[$#xgridpoints]}, ygridpoints[$#xgridpoints] = ${ygridpoints[$#xgridpoints]} \n";
my @pointdata = ($nturnpts, 0, $xsort[$nlegpts - 1], $ysort[$nlegpts - 1], $flitedist, $flitetime, 0, 0, 0, 0, 0, 0, 0);
push(@routedata, \@pointdata);
#print "final pointdata : @pointdata";


### CALC SPATIAL AVG TOTALS
my $totalkm = 0.001 * $totallength;
my $totalspatialavgtailwindkt = $mps2kt * $totalspatialavgtailwindsum / $totallength;
my $totalspatialavgclimbrate = $totalspatialavgclimbratesum / $totallength;
my $totalspatialavgclimbratekt = $totalspatialavgclimbrate * $mps2kt; # Now Knots

### CALC + PRINT OVERALL TOTAL RESULTS
if ($ltotalsolution == 1) {
    my $totalmin = 0.01666667 * $totalsec;
    my $totalavggroundspeedkt = $mps2kt * ($totallength / $totalsec);
    my $totalavggroundspeedkph = 3.6 * ($totallength / $totalsec);
    my $totaloptairspeedavgkt = $mps2kt * $totaloptairspeedsum / $totalsec;
    my $totaltailwindavgkt = $mps2kt * $totaltailwindsum / $totalsec;
    my $totalclimbrateavg = $totalclimbratesum / $totalsec;
    my $totalclimbrateavgkt = $totalclimbrateavg * $mps2kt;
    my $totalthermalpct = $totalthermaltime / $totalsec;
    ### ADD EXTRA COLUMN FOR MULIT-TIME TIME
    if ($LVALIDTIME == 0) {
        $clockprt = sprintf "%04d-%04d", $VALIDTIME, $clockhhmm;
    }
    else {$clockprt = '';}
    #PAULS Climb Rates now in Knots
    $flightSummary = $flightSummary . sprintf("TOT%s %4.0f %4.0f %4.1f %4.0f %4.1f %4.0f %3.0f  %3.0f %3.0f %3.0f \\n", $clockprt, $totalkm, $totalspatialavgtailwindkt, $totalspatialavgclimbratekt, $totaltailwindavgkt, $totalclimbrateavgkt, $totalmin, $totalavggroundspeedkt, $totalavggroundspeedkph, $totaloptairspeedavgkt, $totalthermalpct);
    # printf "TOT%s %4.0f %4.0f %4.1f %4.0f %4.1f %4.0f %3.0f  %3.0f %3.0f %3.0f \n", $clockprt, $totalkm, $totalspatialavgtailwindkt, $totalspatialavgclimbrate, $totaltailwindavgkt, $totalclimbrateavg, $totalmin, $totalavggroundspeedkt, $totalavggroundspeedkph, $totaloptairspeedavgkt, $totalthermalpct  ;
}
else {
    ###### PRINT OVERALL TOTAL RESULTS WHEN NO OPTIMAL SOLUTION
    ### compute % of no solution "blocked" boxes
    $pctblocked = nint(100. * ($totalblocked / $totallegboxs));
    $flightSummary = $flightSummary . sprintf("TOT %8s %4.0f %4.0f %4.1f   NO SOLN    %sblocked=%2d \\n", "", $totalkm, $totalspatialavgtailwindkt, $totalspatialavgclimbrate, '%', $pctblocked);
}
### PRINT WARNING FOOTER, if any
if ($warningfooter ne '') {$flightSummary = $flightSummary . "\\nWARNING: ${warningfooter}";}

$flightSummary = $flightSummary . "\\nFAI distances may differ from values given above\\n";


# Eric - convert x,y grid points to lat/lons
# Create long string of x,y points to pass to ij2latlon_gbsc
my @convertGridPoints = ();
#print " Number of xy grid points : $#xgridpoints \n";
#print " Number of route data points: $#routedata  \n";
for (my $i = 0; $i <= $#xgridpoints; $i++) {
    #printf(" %d   %6.5f   %6.5f   \n", $i, $xgridpoints[$i], $ygridpoints[$i]);
    push(@convertGridPoints, $xgridpoints[$i], $ygridpoints[$i]);
}
# print "convertGridPoints : @convertGridPoints \n";

# Convert the long line of lat/lons to array of paired lat/lon (so array of arrays)
# print " latlons  from ij2latlon_gbsc.PL : @latlonsString \n";
#print " latlons returned : @latlons";
# print " number of latlons : $#latlons \n";
my @latlons = ij2latlon_gbsc("${DATADIR}/namelist.wps", $GRID, \@convertGridPoints);
# ij2latlon_gbsc returns the lat/lons as one long string so need to create array of lat/lon points
my @routeLatLons = ();
for (my $i = 0; $i <= $#latlons; $i = $i + 2) {
    my @latlon = ($latlons[$i], $latlons[$i + 1]);
    #print(" $i $latlon[0]   $latlon[1]  \n");
    push(@routeLatLons, \@latlon);
}
# Make sure the number of lat/lon points match the number of route points=
if ($#routeLatLons != $#routedata) {
    reportError(" *** ERROR : The number of route lat/lons doesn't equal the number of route points! ");
    exit 0;
}
# Merge the lat/lons with the rest of the route data, prepending lat/lon points to front of each route point
my @latlonRouteData = ();
for (my $i = 0; $i <= $#routedata; $i++) {
    my @latlonRoutePoint = ($routeLatLons[$i][0], $routeLatLons[$i][1], @{$routedata[$i]});
    push(@latlonRouteData, \@latlonRoutePoint);
}

# Debugging
#for (my $i = 0; $i <= $#latlonRouteData; $i++) {
#    my @routePoint  = @{$latlonRouteData[$i]};
#    print("latlonRouteData[${i}] : @routePoint \n");
#}

# Convert route points to JSON string
my $routeJson = " \"routePoints\": [";
my @routeKeys = ("Lat", "Lon", "Leg", "Segment", "XPos", "YPos", "Distance", "Time", "Length", "ClimbRate", "Thermal Strength", "TailWind(mps)", "Grnd Speed", "Thermal%", "Seconds");
for (my $i = 0; $i <= $#latlonRouteData; $i++) {
    my @routePoint = @{$latlonRouteData[$i]};
    $routeJson = $routeJson . keyValuesToJson(\@routeKeys, \@routePoint);
    if ($i != $#latlonRouteData) {$routeJson = $routeJson . ",";}

}
$routeJson = $routeJson . "]";

# create final json string.
$summaryJson = "{ \"summary\" : \"$flightSummary\", $routeJson }";
print $summaryJson;

sub reportError {
    my $errorMsg = $_[0];
    my $errorJson = "{ \"error\" : \"$errorMsg\" }";
    print $errorJson;
}

#------------------------- END OF MAIN LOGIC -----------------------------------------------

##########################  SUBROUTINES  ################################


### FIND NEAREST INTEGER
sub nint {int($_[0] + ($_[0] >= 0 ? 0.5 : -0.5));}
###

### READ (possibly zipped) DATA FILE
sub zmapxyplotread() {
    my $inputfile = $_[0];
    my @FILE;

    ### read header info
    if (-f "$inputfile") {@FILE = `cat $inputfile`;}
    elsif (-f "${inputfile}.zip") {@FILE = `unzip -p "${inputfile}.zip"`;}
    else {
        return ("*** $program ERROR: data file $inputfile NOT FOUND \n", ());
    }

    # search for marker line
    my $line = '';
    while (defined $line && $line !~ /^---/) {
        if (!defined $line) {
            return ("*** $program ERROR: Undefined line : $inputfile  \n", ());
        }
        $line = shift @FILE;
    }
    if (!defined $line || $line !~ /^---/) {
        return ("*** $program ERROR: data file $inputfile MISSING DATA \n", ());
    }

    ### READ HEADER LINES
    ### MODIFIED - make non-local to pass titleline1 between routines
    chomp(my $titleline1 = shift @FILE);
    chomp(my $titleline2 = shift @FILE);
    chomp(my $titleline3 = shift @FILE);
    #4test: print "FILE= $inputfile  TITLE= $titleline1 \n";
    ### MODIFIED - make non-local to pass array dims between routines
    my ($head, $filegridname, $equal, $tail);
    #ORIGINAL my ($head,$filegridname,$equal,$imap1in,$imap2in,$jmap1in,$jmap2in,$tail);
    ### allow for old and new grid array index delimiter
    if ($titleline2 =~ m|Indexs=|) {($head, $tail) = split(/  *Indexs=  */, $titleline2);}
    else {($head, $tail) = split(/  *=  */, $titleline2);}
    ($imap1in, $imap2in, $jmap1in, $jmap2in, $tail) = split(/  */, $tail);
    #PAULS print "FILE= $inputfile  imap1in = $imap1in imap2in = $imap2in jmap1in = $jmap1in jmap2in = $jmap2in \n";
    ### READ DATA INTO 1D FILE
    my @a = ();
    my @data = ();
    my ($iicol, $jjrow, $icol, $jrow);
    $jjrow = -1;
    for (my $ii = 0; $ii <= $#FILE; $ii++) {
        chomp($line = $FILE[$ii]);
        @data = split /  */, $line;
        push @a, @data;
    }
    return ("", @a);
}

#########################################################################
sub cell_path_intersections() {
    ### Calc cell intersections over path (i.e. where line intersects cell perimeter around integer x, y values
    ### PRESENTLY *HALF* LINE INTERSECTION ENABLED - i.e. determines location of line intersection with grid perimeter around each integer value
    ###                                              FULL LINE determines location of line intersection with integer axis value lines
    ### METHOD USES FACT THAT INTERSECTIONS MUST OCCUR ALONG HALF/FULL LINE SO JUST FIND THOSE (so do not need to trace line in detail)
    ### *NB* not tested for negative values !
    ### currently allows 0 path lengths (occurs when path passes through cell corner)
    ### ALL DONE IN INTEGER GRID SPACE
    ### POINT ORDERING IS FROM PT1 to PT2 - can treat const x or y cases
    ### RETURN: $npts,@x,@y - include start,end pts in output
    ### ARGS: xstart,ystart, xend,yend

    ### SET START, END POINT
    my ($x1, $y1, $x2, $y2) = @_;
    my ($m, $intercept, $x, $y, $xstart, $xend, $ystart, $yend, $i, $npts);
    my (@xint, @yint, @xsort, @ysort);

    #45deg: $x1 =  1.1 ; $y1 =  1.2 ; $x2 = 4.4 ; $y2 =  4.5 ;
    #backwardX: $x1 =  5.2 ; $y1 =  1.8 ; $x2 = 3.8 ; $y2 =  4.8 ;
    #constX: $x1 =  5.2 ; $y1 =  1.8 ; $x2 = 5.2 ; $y2 =  4.8 ;
    #constY: $x1 =  5.2 ; $y1 =  1.8 ; $x2 = 3.8 ; $y2 =  1.8 ;

    #full2halfline-kludge: ### KLUDGE GIVES HALF-LINE RESULTS BY SHIFTING BY 1/2 IN EACH DIRECTION, GETTING FULL-LINE RESULTS, THEN UN-SHIFTING
    #full2halfline-kludge: ### *NB* TO USE THIS MUST ENABLE "FULL-LINE" STATEMENTS, NOT "HALF-LINE" STATEMENTS
    #full2halfline-kludge  ### SET LHALFLINES=1 TO INSTEAD FIND INTERSECTION WITH LINES MID-WAY BETWEEN INTEGER VALUES
    #full2halfline-kludge  ### (for ease of treatment, simple add 0.5 to initial x,y values then subtract from answer
    #full2halfline-kludge  # $LHALFLINES = 0 ;  # find intersection with integer value x,y lines
    #full2halfline-kludge  # $LHALFLINES = 1 ;  # find intersection with lines mid-way between integer value x,y lines

    #full2halfline-kludge  ### TREAT HALF-LINE INTERSECTION CASE AS FULL-LINE SHIFT
    #full2halfline-kludge  # if ( $LHALFLINES == 1 )
    #full2halfline-kludge  # {
    #full2halfline-kludge  #  $x1 = $x1 + 0.5 ;
    #full2halfline-kludge  #  $y1 = $y1 + 0.5 ;
    #full2halfline-kludge  #  $x2 = $x2 + 0.5 ;
    #full2halfline-kludge  #  $y2 = $y2 + 0.5 ;
    #full2halfline-kludge  # }

    ### FIND INTEGER X AND Y INTERSECTIONS
    ### to include start,end values in list
    if ($x1 != $x2) {push @xint, ($x1, $x2);}
    else {push @yint, ($y1, $y2);}
    ### calc line eqn coeffs y=mx+b
    ### allow for const x case
    if ($x1 != $x2) {
        $m = ($y2 - $y1) / ($x2 - $x1);
        $intercept = $y1 - $m * $x1;
    }
    ### FIND INTEGER X INTERSECTIONS
    if ($x1 < $x2)
    #halfline+
    {
        $xstart = int($x1 + 1.5);
        $xend = int($x2 + 0.5);
    }
    #fullline+    { $xstart = int($x1+1); $xend   = int($x2) ; }
    else
    #halfline+
    {
        $xend = int($x1 + 0.5);
        $xstart = int($x2 + 1.5);
    }
    #fullline+    { $xend = int($x1) ; $xstart = int($x2+1) ; }
    for ($x = $xstart; $x <= $xend; $x++) {
        #halfline+
        push @xint, $x - 0.5;
        #fullline+    push @xint, $x ;
    }
    ### FIND INTEGER Y INTERSECTIONS
    if ($y1 < $y2)
    #halfline+
    {
        $ystart = int($y1 + 1.5);
        $yend = int($y2 + 0.5);
    }
    #fullline+    { $ystart = int($y1+1); $yend   = int($y2) ; }
    else
    #halfline+
    {
        $yend = int($y1 + 0.5);
        $ystart = int($y2 + 1.5);
    }
    #fullline+    { $yend = int($y1) ; $ystart = int($y2+1) ; }
    ### allow for const x case
    if ($x1 != $x2) {
        for ($y = $ystart; $y <= $yend; $y++) {
            #halfline+
            $x = ($y - 0.5 - $intercept) / $m;
            #fullline+      $x = ( $y - $intercept ) / $m ;
            push @xint, $x;
        }
    }
    else {
        ### below is for const x case
        for ($y = $ystart; $y <= $yend; $y++) {
            push @yint, $y - 0.5;
        }
    }
    ### SORT ORDER DEPENDS ON DIRECTION
    ### allow for const x case
    if ($x1 != $x2) {
        if ($x1 < $x2) {
            @xsort = sort {$a <=> $b;} @xint;
        }
        else {
            @xsort = sort {$b <=> $a;} @xint;
        }
        ### CALC CORRESPONDING Y
        for ($i = 0; $i <= $#xsort; $i++) {
            $ysort[$i] = $m * $xsort[$i] + $intercept;
        }
        $npts = $#xsort + 1;
    }
    else {
        ### below is for const x case
        if ($y1 < $y2) {
            @ysort = sort {$a <=> $b;} @yint;
        }
        else {
            @ysort = sort {$b <=> $a;} @yint;
        }
        ### CALC CORRESPONDING X
        for ($i = 0; $i <= $#ysort; $i++) {
            $xsort[$i] = $x1;
        }
        $npts = $#xsort + 1;
    }

    #full2halfline-kludge  ### TREAT HALF-LINE INTERSECTION CASE AS FULL-LINE SHIFT
    #full2halfline-kludge  if ( $LHALFLINES == 1 )
    #full2halfline-kludge  {
    #full2halfline-kludge    for ( $i=0; $i<=$#xsort; $i++ )
    #full2halfline-kludge    {
    #full2halfline-kludge      $xsort[$i] = $xsort[$i] - 0.5 ;
    #full2halfline-kludge      $ysort[$i] = $ysort[$i] - 0.5 ;
    #full2halfline-kludge    }
    #full2halfline-kludge  }

    #4testprint: print "cell_path_intersections : xsort= @xsort \n"; print "cell_path_intersections : ysort= @ysort \n";

    ### ELIMINATE DUPLICATE POINTS (can occur when intersection occurs at corner)
    my $newmaxi = 0;
    for ($i = 1; $i <= $#xsort; $i++) {
        if ($xsort[$i] != $xsort[$newmaxi] || $ysort[$i] != $ysort[$newmaxi]) {
            $newmaxi = $newmaxi + 1;
            $xsort[$newmaxi] = $xsort[$i];
            $ysort[$newmaxi] = $ysort[$i];
        }
    }
    ### eliminate extra points
    if ($newmaxi < $#xsort) {
        splice @xsort, ($newmaxi + 1), $#xsort;
        splice @ysort, ($newmaxi + 1), $#ysort;
    }
    #4testprint: print "cell_path_intersections : npts OLD=$npts NEW=$newmaxi+1 \n";
    $npts = $newmaxi + 1;

    return ($npts, @xsort, @ysort);
}
#########################################################################
sub W3FB11()
### CALC LAMBERT I,J (decimal) FROM LONG,LAT FOR GIVEN LAMBERT PARAMETERS
###  Args: $ALAT,$ELON, $ALAT1,$ELON1,$DX,$ELONV,$ALATAN
{
    #
    # SUBPROGRAM:  W3FB11        LAT/LON TO LAMBERT(I,J) FOR GRIB
    #   PRGMMR: STACKPOLE        ORG: NMC42       DATE:88-11-28
    #
    # ABSTRACT: CONVERTS THE COORDINATES OF A LOCATION ON EARTH GIVEN IN
    #   THE NATURAL COORDINATE SYSTEM OF LATITUDE/LONGITUDE TO A GRID
    #   COORDINATE SYSTEM OVERLAID ON A LAMBERT CONFORMAL TANGENT CONE
    #   PROJECTION TRUE AT A GIVEN N OR S LATITUDE. W3FB11 IS THE REVERSE
    #   OF W3FB12. USES GRIB SPECIFICATION OF THE LOCATION OF THE GRID
    #
    # PROGRAM HISTORY LOG:
    #   88-11-25  ORIGINAL AUTHOR:  STACKPOLE, W/NMC42
    #
    # USAGE:  CALL W3FB11 (ALAT,ELON,ALAT1,ELON1,DX,ELONV,ALATAN,XI,XJ)
    #   INPUT ARGUMENT LIST:
    #     ALAT     - LATITUDE IN DEGREES (NEGATIVE IN SOUTHERN HEMIS)
    #     ELON     - EAST LONGITUDE IN DEGREES, REAL*4
    #     ALAT1    - LATITUDE  OF LOWER LEFT POINT OF GRID (POINT (1,1))
    #     ELON1    - LONGITUDE OF LOWER LEFT POINT OF GRID (POINT (1,1))
    #                ALL REAL*4
    #     DX       - MESH LENGTH OF GRID IN METERS AT TANGENT LATITUDE
    #     ELONV    - THE ORIENTATION OF THE GRID.  I.E.,
    #                THE EAST LONGITUDE VALUE OF THE VERTICAL MERIDIAN
    #                WHICH IS PARALLEL TO THE Y-AXIS (OR COLUMNS OF
    #                OF THE GRID) ALONG WHICH LATITUDE INCREASES AS
    #                THE Y-COORDINATE INCREASES.  REAL*4
    #                THIS IS ALSO THE MERIDIAN (ON THE BACK SIDE OF THE
    #                TANGENT CONE) ALONG WHICH THE CUT IS MADE TO LAY
    #                THE CONE FLAT.
    #     ALATAN   - THE LATITUDE AT WHICH THE LAMBERT CONE IS TANGENT TO
    #                (TOUCHING) THE SPHERICAL EARTH.
    #                 SET NEGATIVE TO INDICATE A
    #                 SOUTHERN HEMISPHERE PROJECTION.
    #
    #   OUTPUT ARGUMENT LIST:
    #     XI       - I COORDINATE OF THE POINT SPECIFIED BY ALAT, ELON
    #     XJ       - J COORDINATE OF THE POINT; BOTH REAL*4
    #
    #   REMARKS: FORMULAE AND NOTATION LOOSELY BASED ON HOKE, HAYES,
    #     AND RENNINGER'S "MAP PROJECTIONS AND GRID SYSTEMS...", MARCH 1981
    #     AFGWC/TN-79/003
    #
    # ATTRIBUTES:
    #   LANGUAGE: IBM VS FORTRAN
    #   MACHINE:  NAS
    #

    my ($ALAT, $ELON, $ALAT1, $ELON1, $DX, $ELONV, $ALATAN) = @_;

    my ($H);
    my $RERTH = 6378137; # Google maps value
    # my     $RERTH = 6.3712E+6;
    # my     $PI =  4.0 * atan(1.0) # 3.14159 ;
    my $PI = 4. * atan2(1, 1);
    #
    #        PRELIMINARY VARIABLES AND REDIFINITIONS
    #
    #        H = 1 FOR NORTHERN HEMISPHERE; = -1 FOR SOUTHERN
    #
    if ($ALATAN > 0) {$H = 1.;}
    else {$H = -1.;}
    #
    my $RADPD = $PI / 180.0;
    my $REBYDX = $RERTH / $DX;
    my $ALATN1 = $ALATAN * $RADPD;
    my $AN = $H * sin($ALATN1);
    my $COSLTN = cos($ALATN1);
    #
    #        MAKE SURE THAT INPUT LONGITUDES DO NOT PASS THROUGH
    #        THE CUT ZONE (FORBIDDEN TERRITORY) OF THE FLAT MAP
    #        AS MEASURED FROM THE VERTICAL (REFERENCE) LONGITUDE.
    #
    my $ELON1L = $ELON1;
    if (($ELON1 - $ELONV) > 180.) {$ELON1L = $ELON1 - 360.;}
    if (($ELON1 - $ELONV) < -180.) {$ELON1L = $ELON1 + 360.;}
    #
    my $ELONL = $ELON;
    if (($ELON - $ELONV) > 180.) {$ELONL = $ELON - 360.;}
    if (($ELON - $ELONV) < -180.) {$ELONL = $ELON + 360.;}
    #
    my $ELONVR = $ELONV * $RADPD;
    #
    #        RADIUS TO LOWER LEFT HAND (LL) CORNER
    #
    my $ALA1 = $ALAT1 * $RADPD;
    my $RMLL = $REBYDX * ((($COSLTN) ** (1. - $AN)) * (1. + $AN) ** $AN) * (((cos($ALA1)) / (1. + $H * sin($ALA1))) ** $AN) / $AN;
    #
    #        USE LL POINT INFO TO LOCATE POLE POINT
    #
    my $ELO1 = $ELON1L * $RADPD;
    my $ARG = $AN * ($ELO1 - $ELONVR);
    my $POLEI = 1. - $H * $RMLL * sin($ARG);
    my $POLEJ = 1. + $RMLL * cos($ARG);
    #
    #        RADIUS TO DESIRED POINT AND THE I J TOO
    #
    my $ALA = $ALAT * $RADPD;
    my $RM = $REBYDX * (($COSLTN ** (1. - $AN)) * (1. + $AN) ** $AN) * (((cos($ALA)) / (1. + $H * sin($ALA))) ** $AN) / $AN;
    #
    my $ELO = $ELONL * $RADPD;
    $ARG = $AN * ($ELO - $ELONVR);
    my $XI = $POLEI + $H * $RM * sin($ARG);
    my $XJ = $POLEJ - $RM * cos($ARG);
    #
    #        IF COORDINATE LESS THAN 1
    #        COMPENSATE FOR ORIGIN AT (1,1)
    #
    #jack - following gives round-off error problems so eliminate
    #jack-        IF(XI.LT.1.)  XI = XI - 1.;
    #jack         IF(XJ.LT.1.)  XJ = XJ - 1.;
    #
    return ($XI, $XJ);
}
#############################################################################
#RASP MOD - added subroutines follow
#############################################################################
### read region parameters from wrfsi.nl or namlist.wps file
sub read_region_params() {
    my $basedirectory = $_[0];
    my $datafilename = "${basedirectory}/namelist.wps";

    my ($MOAD_STAND_LATS_0, $MOAD_STAND_LATS_1, @MOAD_STAND_LATS);
    my $iigrid = $KGRID - 1;

    if (!open(DATAFILE, "<$datafilename")) {
        reportError("Can't open " . $datafilename);
        exit 0;
    };

    #print "Opened $datafilename";
    my @datalines = <DATAFILE>;
    for (my $iiline = 0; $iiline <= $#datalines; $iiline++) {
        if ($datalines[$iiline] =~ m|^ *parent_grid_ratio\s*=\s*(.*)\s*$|i) {
            @RATIO_TO_PARENT = split /,/, $1;
            unshift @RATIO_TO_PARENT, '';
        }
        if ($datalines[$iiline] =~ m|^ *i_parent_start\s*=\s*(.*)\s*$|i) {
            @DOMAIN_ORIGIN_LLI = split /,/, $1;
            unshift @DOMAIN_ORIGIN_LLI, '';
        }
        if ($datalines[$iiline] =~ m|^ *j_parent_start\s*=\s*(.*)\s*$|i) {
            @DOMAIN_ORIGIN_LLJ = split /,/, $1;
            unshift @DOMAIN_ORIGIN_LLJ, '';
        }
        if ($datalines[$iiline] =~ m|^ *e_we\s*=\s*(.*)\s*$|i) {
            @e_we = split /,/, $1;
            unshift @e_we, '';
        }
        if ($datalines[$iiline] =~ m|^ *e_sn\s*=\s*(.*)\s*$|i) {
            @e_sn = split /,/, $1;
            unshift @e_sn, '';
        }
        if ($datalines[$iiline] =~ m|^ *ref_lat *= *(-*[0-9]+.*[0-9]*),.*$|i) {$MOAD_KNOWN_LAT = $1;}
        if ($datalines[$iiline] =~ m|^ *ref_lon *= *(-*[0-9]+.*[0-9]*),.*$|i) {$MOAD_KNOWN_LON = $1;}
        if ($datalines[$iiline] =~ m|^ *truelat1 *= *(-*[0-9]+.*[0-9]*),.*$|i) {$MOAD_STAND_LATS_0 = $1;}
        if ($datalines[$iiline] =~ m|^ *truelat2 *= *(-*[0-9]+.*[0-9]*),.*$|i) {$MOAD_STAND_LATS_1 = $1;}
        if ($datalines[$iiline] =~ m|^ *stand_lon *= *(-*[0-9]+.*[0-9]*),.*$|i) {$MOAD_STAND_LONS = $1;}
        if ($datalines[$iiline] =~ m|^ *dx * = * ([^, ]*).*$|i) {$MOAD_DELTA_X = $1;}
        if ($datalines[$iiline] =~ m|^ *dy * = * ([^, ]*).*$|i) {$MOAD_DELTA_Y = $1;}
        if ($datalines[$iiline] =~ m|^ *map_proj * = * ([^, ]*).*$|i) {$MAP_PROJ_NAME = $1;}
    }

    if (!defined $e_we[$iigrid] || !defined $e_sn[$iigrid]) {
        reportError("ERROR: Missing data for grid $KGRID in datafile $datafilename ");
        exit 0;
    }
    else {
        for (my $g = 1; $g <= $KGRID; $g++) {
            $DOMAIN_ORIGIN_URI[$g] = (($e_we[$g] - 1) / $RATIO_TO_PARENT[$g]) + $DOMAIN_ORIGIN_LLI[$g];
            $DOMAIN_ORIGIN_URJ[$g] = (($e_sn[$g] - 1) / $RATIO_TO_PARENT[$g]) + $DOMAIN_ORIGIN_LLJ[$g];
        }
    }

    if (!defined $MOAD_STAND_LATS_0 || !defined $MOAD_STAND_LATS_1) {
        reportError(("ERROR: Missing data in datafile $datafilename"));
        exit 0;
    }
    else {
        @MOAD_STAND_LATS = ($MOAD_STAND_LATS_0, $MOAD_STAND_LATS_1);
    }

    if (!defined $MOAD_KNOWN_LAT || !defined $MOAD_KNOWN_LON ||
        !defined $MOAD_STAND_LATS[0] || !defined $MOAD_STAND_LONS ||
        !defined $MAP_PROJ_NAME) {
        reportError("*** ERROR: MISSING DATA in DATAFILE $datafilename ");
        exit 0;
    }

    if (!defined $RATIO_TO_PARENT[$iigrid] ||
        !defined $DOMAIN_ORIGIN_LLI[$iigrid] || !defined $DOMAIN_ORIGIN_LLJ[$iigrid]) {
        reportError("ERROR: MISSING DATA FOR GRID $KGRID in DATAFILE $datafilename ");
        exit 0;
    }

    if ($MOAD_STAND_LATS[0] == $MOAD_STAND_LATS[1] && $MAP_PROJ_NAME =~ m|lambert|i) {
        $MOAD_STAND_LAT = $MOAD_STAND_LATS[0];
    }
    else {
        reportError("ERROR: PROGRAM ONLY VALID FOR CASE OF TANGENT LAMBERT PROJECTION ");
        exit 0;
    }
    if ($MOAD_DELTA_X != $MOAD_DELTA_Y) {
        reportError("*** $program ERROR - DX != DY");
        exit 0;
    }

    return;
}
#############################################################################################
sub subgridij2moadcenterij()
### converts subgrid i,j into moad i,j relative to moad center (used for lat,lon determination)
{
    my ($kgrid, $ai, $aj) = @_;
    my ($iigrid);
    ### COMPUTE LAMBERT I,J FOR MOAD
    my $aimoad = $ai;
    my $ajmoad = $aj;
    ### CONVERT NON-MOAD *MASS* SUBGRID INDEX TO MOAD *MASS* INDEX
    ### note iigrid uses kgrid indexing (i.e. param arrays use 1-based indexing)
    for ($iigrid = $kgrid; $iigrid >= 2; $iigrid--) {
        if (!defined $RATIO_TO_PARENT[$iigrid] || !defined $DOMAIN_ORIGIN_LLI[$iigrid] || !defined $DOMAIN_ORIGIN_LLJ[$iigrid]) {
            reportError("*** ERROR: Bad grid number = $kgrid ");
            exit 0;
        }
        $aimoad = $DOMAIN_ORIGIN_LLI[$iigrid] - 0.5 + ($aimoad - 0.5) / $RATIO_TO_PARENT[$iigrid];
        $ajmoad = $DOMAIN_ORIGIN_LLJ[$iigrid] - 0.5 + ($ajmoad - 0.5) / $RATIO_TO_PARENT[$iigrid];
        #4testprint: print "GRID $iigrid =>  RATIO_TO_PARENT= $RATIO_TO_PARENT[$iigrid] \n";
    }
    ### CALC MOAD I,J (non-integer) SHIFTED RELATIVE TO CENTER OF MOAD GRID
    my $airelative = $aimoad - 0.5 * ($NXmassMOAD - 1);
    my $ajrelative = $ajmoad - 0.5 * ($NYmassMOAD - 1);
    return $airelative, $ajrelative;
}
#############################################################################
sub uv2wswd_4latlon() {
    ### $DEG2RAD is global constant
    ### i do not understand why need test for sign of alat
    ### multiplication by CONE means that longitudes must be in range -180 to +180
    my ($u, $v, $alat, $alon) = @_;
    my ($longca, $longcb, $coslong, $sinlong, $umet, $vmet, $ws, $wd);
    # below method ala wrf_user_fortran_util_0 :: compute_uvmet( u,v, uvmet, diff, alpha, longitude,latitude, cen_
    ### requires longitude -180 to 180 !
    if ($alon > 180.) {$alon = $alon - 360.;}
    $longca = $alon - $MOAD_STAND_LONS;
    if ($alat < 0) {$longcb = -$longca * $GRID_CONE * $DEG2RAD;}
    else {$longcb = $longca * $GRID_CONE * $DEG2RAD;}
    $coslong = cos($longcb);
    $sinlong = sin($longcb);
    $umet = $v * $sinlong + $u * $coslong;
    $vmet = $v * $coslong - $u * $sinlong;
    $ws = sqrt($umet ** 2 + $vmet ** 2);
    $wd = atan2($umet, $vmet) / $DEG2RAD + 180.0;
    return $ws, $wd;
}
#############################################################################################
sub W3FB12()
### CALC LONG,LAT FOR GIVEN LAMBERT I,J (decimal)
###  Args: $XI,$XJ, $ALAT1,$ELON1,$DX,$ELONV,$ALATAN
{
    # SUBPROGRAM:  W3FB12        LAMBERT(I,J) TO LAT/LON FOR GRIB
    #   PRGMMR: STACKPOLE        ORG: NMC42       DATE:88-11-28
    #
    # ABSTRACT: CONVERTS THE COORDINATES OF A LOCATION ON EARTH GIVEN IN
    #   GRID COORDINATE SYSTEM OVERLAID ON A LAMBERT CONFORMAL TANGENT
    #   CONE PROJECTION TRUE AT A GIVEN N OR S LATITUDE TO THE
    #   NATURAL COORDINATE SYSTEM OF LATITUDE/LONGITUDE
    #   W3FB12 IS THE REVERSE OF W3FB11.
    #   USES GRIB SPECIFICATION OF THE LOCATION OF THE GRID
    #
    # PROGRAM HISTORY LOG
    #   88-11-25  ORIGINAL AUTHOR:  STACKPOLE, W/NMC42
    #
    # USAGE:  CALL W3FB12(XI,XJ,ALAT1,ELON1,DX,ELONV,ALATAN,ALAT,ELON,IERR,
    #                                   IERR)
    #   INPUT ARGUMENT LIST:
    #     XI       - I COORDINATE OF THE POINT  REAL*4
    #     XJ       - J COORDINATE OF THE POINT  REAL*4
    #     ALAT1    - LATITUDE  OF LOWER LEFT POINT OF GRID (POINT 1,1)
    #                LATITUDE <0 FOR SOUTHERN HEMISPHERE; REAL*4
    #     ELON1    - LONGITUDE OF LOWER LEFT POINT OF GRID (POINT 1,1)
    #                  EAST LONGITUDE USED THROUGHOUT; REAL*4
    #     DX       - MESH LENGTH OF GRID IN METERS AT TANGENT LATITUDE
    #     ELONV    - THE ORIENTATION OF THE GRID.  I.E.,
    #                THE EAST LONGITUDE VALUE OF THE VERTICAL MERIDIAN
    #                WHICH IS PARALLEL TO THE Y-AXIS (OR COLUMNS OF
    #                THE GRID) ALONG WHICH LATITUDE INCREASES AS
    #                THE Y-COORDINATE INCREASES.  REAL*4
    #                THIS IS ALSO THE MERIDIAN (ON THE OTHER SIDE OF THE
    #                TANGENT CONE) ALONG WHICH THE CUT IS MADE TO LAY
    #                THE CONE FLAT.
    #     ALATAN   - THE LATITUDE AT WHICH THE LAMBERT CONE IS TANGENT TO
    #                (TOUCHES OR OSCULATES) THE SPHERICAL EARTH.
    #                 SET NEGATIVE TO INDICATE A
    #                 SOUTHERN HEMISPHERE PROJECTION; REAL*4
    #
    #   OUTPUT ARGUMENT LIST
    #     ALAT     - LATITUDE IN DEGREES (NEGATIVE IN SOUTHERN HEMI.)
    #     ELON     - EAST LONGITUDE IN DEGREES, REAL*4
    #     IERR     - .EQ. 0   IF NO PROBLEM
    #                .GE. 1   IF THE REQUESTED XI,XJ POINT IS IN THE
    #                         FORBIDDEN ZONE, I.E. OFF THE LAMBERT MAP
    #                         IN THE OPEN SPACE WHERE THE CONE IS CUT.
    #                  IF IERR.GE.1 THEN ALAT=999. AND ELON=999.
    #
    #   REMARKS: FORMULAE AND NOTATION LOOSELY BASED ON HOKE, HAYES,
    #     AND RENNINGER'S "MAP PROJECTIONS AND GRID SYSTEMS...", MARCH 1981
    #     AFGWC/TN-79/003
    #
    # ATTRIBUTES:
    #   LANGUAGE: IBM VS FORTRAN
    #   MACHINE:  NAS
    #
    #$$$

    my ($XI, $XJ, $ALAT1, $ELON1, $DX, $ELONV, $ALATAN) = @_;

    #alaWRF
    my $RERTH = 6378137; # Google Maps Value
    #  my     $RERTH = 6.370E+6;
    #ORIGINAL-NCEP         $RERTH = 6.3712E+6;
    # my     $PI = 3.141592654 ;
    my $PI = 4. * atan2(1, 1);
    #ORIGINAL-NCEP         $PI = 3.14159 ;
    #        DATA  OLDRML/99999./
    #
    #        PRELIMINARY VARIABLES AND REDIFINITIONS
    #
    #        H = 1 FOR NORTHERN HEMISPHERE; = -1 FOR SOUTHERN
    #
    #        SAVE

    my ($H, $ALAT, $ELON);
    my $BETA = 1.;
    my $IERR = 0;

    if ($ALATAN > 0) {$H = 1.;}
    else {$H = -1.;}
    #
    my $PIBY2 = $PI / 2.;
    my $RADPD = $PI / 180.0;
    my $DEGPRD = 1. / $RADPD;
    my $REBYDX = $RERTH / $DX;
    my $ALATN1 = $ALATAN * $RADPD;
    my $AN = $H * sin($ALATN1);
    my $COSLTN = cos($ALATN1);
    #
    #        MAKE SURE THAT INPUT LONGITUDE DOES NOT PASS THROUGH
    #        THE CUT ZONE (FORBIDDEN TERRITORY) OF THE FLAT MAP
    #        AS MEASURED FROM THE VERTICAL (REFERENCE) LONGITUDE
    #
    my $ELON1L = $ELON1;
    if (($ELON1 - $ELONV) > +180.) {$ELON1L = $ELON1 - 360.;}
    if (($ELON1 - $ELONV) < (-180.)) {$ELON1L = $ELON1 + 360.;}
    #
    my $ELONVR = $ELONV * $RADPD;
    #
    #        RADIUS TO LOWER LEFT HAND (LL) CORNER
    #
    my $ALA1 = $ALAT1 * $RADPD;
    my $RMLL = $REBYDX * (($COSLTN ** (1. - $AN)) * (1. + $AN) ** $AN) * (((cos($ALA1)) / (1. + $H * sin($ALA1))) ** $AN) / $AN;
    #
    #        USE RMLL TO TEST IF MAP AND GRID UNCHANGED FROM PREVIOUS
    #        CALL TO THIS CODE.  THUS AVOID UNNEEDED RECOMPUTATIONS.
    #
    #         IF(RMLL.EQ.OLDRML) THEN
    #           NEWMAP = .FALSE.
    #         ELSE
    #           NEWMAP = .TRUE.
    #           OLDRML = RMLL
    #
    #          USE LL POINT INFO TO LOCATE POLE POINT
    #
    my $ELO1 = $ELON1L * $RADPD;
    my $ARG = $AN * ($ELO1 - $ELONVR);
    my $POLEI = 1. - $H * $RMLL * sin($ARG);
    my $POLEJ = 1. + $RMLL * cos($ARG);
    #         ENDIF
    #
    #        RADIUS TO THE I,J POINT (IN GRID UNITS)
    #              YY REVERSED SO POSITIVE IS DOWN
    #
    my $XX = $XI - $POLEI;
    my $YY = $POLEJ - $XJ;
    my $R2 = $XX ** 2 + $YY ** 2;
    #
    #        CHECK THAT THE REQUESTED I,J IS NOT IN THE FORBIDDEN ZONE
    #           YY MUST BE POSITIVE UP FOR THIS TEST
    #
    my $THETA = $PI * (1. - $AN);
    $BETA = abs(atan2($XX, -($YY)));
    $IERR = 0;
    if ($BETA <= $THETA) {
        $IERR = 1;
        $ALAT = 999.;
        $ELON = 999.;
        #           IF(.NOT.NEWMAP)  RETURN
    }
    #
    #        NOW THE MAGIC FORMULAE
    #
    if ($R2 == 0) {
        $ALAT = $H * 90.;
        $ELON = $ELONV;
    }
    else {
        #
        #          FIRST THE LONGITUDE
        #
        $ELON = $ELONV + $DEGPRD * atan2($H * $XX, $YY) / $AN;
        ### needed to replace amod
        $ELON = $ELON + 360. - 360. * int(($ELON + 360.) / 360.);
        #original           ELON = AMOD(ELON+360., 360.)
        #
        #          NOW THE LATITUDE
        #          RECALCULATE THE THING ONLY IF MAP IS NEW SINCE LAST TIME
        #
        #           IF(NEWMAP) THEN
        my $ANINV = 1. / $AN;
        my $ANINV2 = $ANINV / 2.;
        my $THING = (($AN / $REBYDX) ** $ANINV) / (($COSLTN ** ((1. - $AN) * $ANINV)) * (1. + $AN));
        #           ENDIF
        ### needed to replace atan
        $ALAT = $H * ($PIBY2 - 2. * atan2($THING * ($R2 ** $ANINV2), 1.)) * $DEGPRD;
        #glendeni-systax_error!           $ALAT = -$H*($PIBY2 - 2.*atan2(($THING*($R2**$ANINV2))),1.)*$DEGPRD;
        #original           ALAT = H*( PIBY2 - 2.*ATAN( THING*(R2**ANINV2) ) )*DEGPRD
    }
    #
    #        FOLLOWING TO ASSURE ERROR VALUES IF FIRST TIME THRU
    #         IS OFF THE MAP
    #
    if ($IERR != 0) {
        $ALAT = 999.;
        $ELON = 999.;
        $IERR = 2;
    }
    return ($ALAT, $ELON);
}
##################################################################################################
### GET MAX VALUE OF INPUT ARRAY/LIST
sub max {
    my ($max) = shift(@_);

    foreach my $temp (@_) {
        $max = $temp if $temp > $max;
    }
    return ($max);
}

#############################################################################
### GET MIN VALUE OF INPUT ARRAY/LIST
sub min {
    my ($min) = shift(@_);

    foreach my $temp (@_) {
        $min = $temp if $temp < $min;
    }
    return ($min);
}
