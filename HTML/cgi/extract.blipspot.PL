#!/usr/bin/perl -w

if ( $#ARGV < 5 || $ARGV[0] eq '-?' ) {
#-----------------adescription1------------------------------------
print "Extract+print BlipSpot info for \$1=dataDir \$2=region \$3=lat \$4=lon \$5=LINFO \$6=time \$7=parameter \$7,8=i,j(integer)_or_lat,lon(decimal)\n";
print "  optional trailing arguments set time (must include number) or parameter - else are internally set \n";
print "  input LINFO =0 to return numerical results only, sans text - also skips trigger temp calc \n";
print "  input LINFO =1 to return numerical results with text, but skips trigger temp calc \n";
print "  input LINFO =2 to return numerical results and trigger temp calc \n";
print "  (reads blipmap datafiles, not wrf output file)\n";
print "  (requires region params in file extract.blipspot.site_params.PL)\n";
exit 0; }
#########################################################################
### FOR DEBUG MODE: run with -d flag  (but not for neptune)
### In debug mode, set package name + local variables so X,V don't show "main" variables, ie:
# package Main; local ($a,$b,...);
### To enable verbose diagnostics (but not for CRAY):
#   use diagnostics;
### To restrict unsafe constructs (vars,refs,subs)
###    vars requires variables to be declared with "my" or fully qualified or imported
###    refs generates error if symbolic references uses instead of hard refs
###    subs requires subroutines to be predeclared
#    use strict;
### To provide aliases for buit-in punctuation variables (p403)
use English;
#########################################################################

### NOTE: SCRIPTS ij2latlon.PL & latlon2ij.PL MUST BE IN SAME DIRECTORY

### MODIFIED FROM BLIP extract.minispot.PL

my $programname = 'extract.blipspot';

### DETERMINE SCRIPT DIRECTORY - this should be automatic but can over-ride here if necessary
### require latlon<->ij conversion scripts to be in current directory
if( $0 =~ m|^/| ) {
	( $SCRIPTDIR = "${0}" ) =~ s|/[^/]*$|| ;
}
else {
	( $SCRIPTDIR = "$ENV{'PWD'}/${0}" ) =~ s|[\./]*/[^/]*$|| ;
}

### PARSE INPUT ARGUMENTS
$DATADIR = shift;
$REGION  = shift;

### PARSE GRID LOCATION - can be lat,lon (decimal) or i,j (integer)
### allow location to be either grid pt (integer) or lat,lon
if( $ARGV[0] !~ m|\.| && $ARGV[1] !~ m|\.| ) {
	$IGRID = $ARGV[0]; 
	$JGRID = $ARGV[1];
	$result = `perl $SCRIPTDIR/ij2latlon.PL $DATADIR $IGRID $JGRID` ;
	my $tail ;
	( $alat,$alon, $tail ) = split /\s+/, $result ;
}
else {
	$alat = $ARGV[0] ; 
	$alon = $ARGV[1] ;
	### assume latlon2ij utility to be in same directory as this script
	$result = `perl $SCRIPTDIR/latlon2ij.PL $DATADIR $alat $alon` ;
	my $tail ;
	( $aigrid,$ajgrid, $tail ) = split /\s+/, $result ;
	$IGRID = &nint( $aigrid );
	$JGRID = &nint( $ajgrid );
}
shift; shift;

$LINFO = shift;

### PARSE OPTIONAL TIME/PARAM ARGUMENTS
foreach (@ARGV)
{
    if (m|^\d+$|) {
        push @timedolist, $_;
    }
    else {
        push @paramdolist, $_;
    }
}

########################################################################################3

###### INITIALIZATION
$mapinfo = '';
$blankdata = '     ' ;

### Get param descriptions
my @info;
open PARAM_LIST, "<", "$SCRIPTDIR/../newParamList.js";
while (<PARAM_LIST>)
{
    if ( m|^/*paramList\["([^"]+)"[^,]+, *"([^"]*)"| ) { $info{$1} = $2; }
    if ( m|^/*paramName\["([^"]+)"[^"]+"([^"]*)"| ) { $info{$1} = $2; }
}
close PARAM_LIST;

###### READ NECESSARY PARAMETER DATA
### LOOP OVER POSSIBLE REGION TIMES
foreach $time (@timedolist) {
	### LOOP OVER PARAMETERS
	$nparams = 0;
	foreach $param (@paramdolist) {
		### initialize print output
		$prtspot{$param}{$time}  = $blankdata ;
		### initialize denormalization if not already set
		if( ! defined $denorm{$param} ) {
			$denorm{$param} = 0;
		}
		### OPEN FILE if available
        $datafilename = "$DATADIR/${param}.${time}local.d2.data";
		### read data pt
		$value = &read_datafile_pt ( $datafilename, $IGRID, $JGRID, $denorm{$param} );
        #4test: print STDERR "At $time $param ($IGRID, $JGRID) value is $value\n";
		# There is a problem re _FillValue: It is -999 in V5; -999999 in V6
		# Some params can be < -999 !!
		# Must use NCL V6 for GM, so use V6 _FillValue
		if( $value ne "-" && $value < -999990 ){
			$value = '-';
		}
		### extracted forecast period is global variable 
		$forecastpd{$time} = $fcstpd ;
		### skip if no value
		if( ! defined $value ) { next; }
		#4testprint: print "READ_DATAFILE_PT: $datafilename, $IGRID,$JGRID => $value \n";
		$prtspot{$param}{$time}  = $value;
		$nparams++;
	} ### END OF LOOP OVER PARAMETERS
} ### END OF LOOP OVER POSSIBLE REGION TIMES

###### DO PRINTING
if( $LINFO != 0 )
{
	### `echo "extractBLIPspot ARGS: LINFO -- $LINFO " >> /var/www/cgi-bin/LOG/get_rasp_blipspot.test_prints`;
	### STANDARD PRINT - with additional info
	### print header
	print " ${model} BLIPSPOT:  ${mapinfo}\n";
	print "$REGION gridpt= ${IGRID},${JGRID}\n";
	# PAULS - increase resolution printf "Lat,Lon= %.3f,%.3f\n",  $alat,$alon ;
	printf "Lat,Lon= %.5f,%.5f\n",  $alat,$alon ;
	### this is the first header line - if has initial white space likely the mapinfo extraction is bad
	$headerborder = "------------";
	foreach $time (@timedolist) {
		$headerborder  .= '--------';
	}
	#add trailing parameter id column
	if( $#timedolist > 0 ) {
		$headerborder = $headerborder . "-------------";
	}
	print "${headerborder}\n";
	### print validation times
	$printline = sprintf "%12s  ", 'VALID.TIME';
	#unused $printline2 = sprintf "%12s  ", '----------';
	foreach $time (@timedolist) {
		$printline  .= sprintf "%6s ",  $time;
		#unused $printline2 .= sprintf "%6s ",  ' -----';
	}
	#add trailing parameter id column
	if( $#timedolist > 0 ) {
		$printline .= sprintf " %-12s",'VALID.TIME';
	}
	print "$printline\n"; 
	### print forecast period
	$printline = sprintf "%12s  ", 'ForecastPd';
	#unused $printline2 = sprintf "%12s  ", '----------';
	foreach $time (@timedolist) {
		$printline  .= sprintf "%6sh ",  $forecastpd{$time};
		#unused $printline2 .= sprintf "%6s ",  ' -----';
	}
	#add trailing parameter id column
	if( $#timedolist > 0 ) {
		$printline .= sprintf " %-12s",'ForecastPd';
	}
	print "$printline\n"; 
	### this is the final header line
	print "${headerborder}\n";
	#unused print "$printline2\n"; 
	### LOOP OVER PARAMETERS
	foreach $param (@paramdolist) {
		### create header for each parameter line
		$printline = sprintf "%12s  ", $info{$param};
		### LOOP OVER POSSIBLE REGION TIMES
		foreach $time (@timedolist) {
			if($param eq "sfcsunpct"){
				if($prtspot{$param}{$time} eq '-999.00'){
					$printline .= sprintf "%7s ", "-" ;
				}
				else{
					$printline .= sprintf "%7s ",  $prtspot{$param}{$time};
				}
			}
			else{
				$printline .= sprintf "%7s ",  $prtspot{$param}{$time};
			 }
		}
		#add trailing parameter id column
		if( $#timedolist > 0 ) {
			$printline .= sprintf " %-12s",$info{$param};
		}
		print "$printline\n"; 
		# Test `echo "extractBLIPspot printline:-- $printline " >> LOG/get_rasp_blipspot.test_prints`;
	}
}
else {
	### PRINT ONLY NUMERICAL PARAMETER VALUES (all times on one row for each parameter, ala table)
	foreach $param (@paramdolist) {
		$printline .= sprintf "%s ", $param;
		foreach $time (@timedolist) {
			if($param eq "sfcsunpct"){
				if($prtspot{$param}{$time} eq '-999.00'){
					$printline .= sprintf "%s ", "-" ;
				}
				else{
					$printline .= sprintf "%s ",  $prtspot{$param}{$time};
				}
			}
			else{
				$printline .= sprintf "%s ",  $prtspot{$param}{$time};
			 }
		}
		$printline .= "\n"; 
	}
	print "$printline"; 
	# Test `echo "extractBLIPspot printline:-- $printline " >> LOG/get_rasp_blipspot.test_prints`;
}
 
# PAULS Mod to give fine control over Trigger Temp display
if( $LINFO < 2 )
{
	exit;
}

### ADD TRIGGER TIME/TEMP CALC/PRINT to BLIPSPOT if LINFO>1

###### WARNING ######
#
# Code below depends on having the params in triggertempparamdolist
# filled in from above
#
#####################

### SET DESIRED TRIGGER DEPTH (units=ft/m ala local site)
#EXAMPLE_TRIGGER_DEPTH=none:  @trigdepthdolist = ( );
#EXAMPLE_TRIGGER_DEPTH=american(ft):  
@trigdepthdolist = ( 1500, 2000, 2500, 3000 );
#EXAMPLE_TRIGGER_DEPTH=metric(m):    @trigdepthdolist = (  400, 600, 800, 1000 );

# Must have dbl, hwcrit & sfctemp (explicitly or implicitly) in @paramdolist
$stuffdbl = grep /dbl/, @paramdolist;
$stuffhwcrit = grep /hwcrit/, @paramdolist;
$stuffsfctemp = grep /sfctemp/, @paramdolist;
if( $stuffdbl < 1 || $stuffhwcrit < 1 || $stuffsfctemp < 1 ){
	exit;
}

if( $#trigdepthdolist > -1 ) {
	### set desired parameters
	@triggertempparamdolist = ( "dbl","hwcrit" );

	### create header for trigger temp printout
	print "\n${headerborder}\n";
	print " TRIGGER TIME & SURFACE (2m) TEMPERATURE \n (+++ = before first time, --- = not found) \n";
	print "${headerborder}\n";

	foreach $param (@triggertempparamdolist) {
		### dwcrit is not output to a datafile so must create it here if needed
		# PAULS: I have dwcrit in a datafile
		# if( $param eq 'dwcrit' ) {
		# 	$info{'dwcrit'} = 'Hcrit Depth'; 
		# 	foreach $time (@timedolist) {
		# 		### error_log occasionally says 'Argument "     " isn't numeric in subtraction (-)'  here ???
		# 		### so added if test
		# 		if( $prtspot{'hbl'}{$time} !~ m|^ *$| && $prtspot{'hbl'}{$time} !~ m|^ *$| ) {
		# 			$prtspot{dwcrit}{$time} = $prtspot{'hwcrit'}{$time} - ( $prtspot{'hbl'}{$time} - $prtspot{'dbl'}{$time} );     
		# 		}
		# 		else {
		# 			$prtspot{dwcrit}{$time} = $blankdata ;
		# 		}
		# 	}
		# }
		### create header for each parameter line
		$printheaderline = sprintf "%12s =", $info{$param};
		$printline1 = sprintf "%12s =", "     Hour";
		$printline2 = sprintf "%12s =", " Sfc.Temp";

		foreach $trigdepth (@trigdepthdolist) {
			### LOOP OVER POSSIBLE MODEL TIMES TO DO CALC
			$itime = 0 ;    
			$triggerhr = -1. ;
			$triggertemp = -1. ;

			foreach $time (@timedolist) {
				if( $prtspot{$param}{$time} eq "-" ){
					next;
				}
				### ignore times after soln found
				if( $prtspot{$param}{$time} !~ m|^ *$| && $prtspot{$param}{$time} > $trigdepth ) {
					### treat first time specially
					if( $itime > 0 ) {
						### adjust time to allow for day switchover
						### remove non-numbers from time
						( $calctime = $time ) =~ s|[a-zA-Z]||g ; 
						( $testtime = $timedolist[0] ) =~ s|[a-zA-Z]||g ; 
						if( $calctime < $testtime ) {
							$calctime += 2400. ;
						}
						### convert to hour
						$calchr = (substr($calctime,0,length($calctime)-2)) + (substr($calctime,length($calctime)-2,2))/60.;
						$triggerhr = $lastcalchr + ( ( $trigdepth - $lastdepth )*( $calchr - $lastcalchr )/( $prtspot{$param}{$time} - $lastdepth ) ) ;
						$triggertemp = $lastsfctemp + ( ( $trigdepth - $lastdepth )*( $prtspot{"sfctemp"}{$time} - $lastsfctemp )/( $prtspot{$param}{$time} - $lastdepth ) ) ;
					}
					else {
						$lastsfctemp = $prtspot{"sfctemp"}{$time} ;
						$triggerhr = -2. ;
						$triggertemp = -2. ;
					}
					last; 
				}
				$lastdepth = $prtspot{$param}{$time} ;
				$lastsfctemp = $prtspot{"sfctemp"}{$time} ;
				( $lastcalctime = $time ) =~ s|[a-zA-Z]||g ; 
				( $testtime = $timedolist[0] ) =~ s|[a-zA-Z]||g ; 
				if( $lastcalctime < $testtime ) {
					$lastcalctime += 2400. ;
				}
				$lastcalchr = (substr($lastcalctime,0,length($lastcalctime)-2)) + (substr($lastcalctime,length($lastcalctime)-2,2))/60.;
				$itime++ ;    
			}
			### convert results to printable strings
			if( $triggerhr > 0 ) {
				### adjust time to allow for day switchover
				if( $triggerhr > 24. ) {
					$triggerhr -= 24. ;
				 } 
				### convert triggerhr to hhmm (Zulu)
				$hrint = int( $triggerhr ) ;
				$minint = int( 60* ($triggerhr - $hrint ) );
				$triggerhrprt = sprintf "%02i:%02i",$hrint,$minint ;
				$triggertempprt = sprintf "%5.1f", $triggertemp ;
			}
			elsif ( $triggerhr == -2. ) {
				### for result prior to first time
				$triggerhrprt = '  +++' ;
				$triggertempprt = '  +++' ;
			}
			elsif ( $triggerhr == -1. ) {
				### for result not within time span
				$triggerhrprt = '  ---' ;
				$triggertempprt = '  ---' ;
			}
			$printheaderline .= sprintf " %5.0f ",  $trigdepth ;
			$printline1 .= sprintf " %5s ",  $triggerhrprt ;
			$printline2 .= sprintf " %5s ",  $triggertempprt ;
			#4test: $printline .= sprintf " %6.2f %6.1f",  $triggerhr, $triggertemp ;
		}
		print "$printheaderline\n"; 
		print "$printline1\n"; 
		print "$printline2\n"; 
		print "${headerborder}\n";
	}
} 

#########################################################################

sub read_datafile_pt ()
{
	### READ+RETURN BLIPMAP DATA IN $datafilename FOR PT $igrid,$jgrid $info=1=>after multiplier correction
	### RETURN UNDEFINED VALUE IF NO FILE OR ERROR
	my ($datafilename,$igrid,$jgrid,$linfo) = @_;
	my $value ;
	my  @monthname = ( 'Dummy', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec' );
	### $fcstpd is global variable used in main routine
	$fcstpd = '--';
	#unused ### $TMPFILE used to unzip data to
	#unused my $tmpfile = '/tmp/extract.spot.tmp';
	### extract from file
	### allow for zip/nonzip file
	my @FILE;
	if(    -s ${datafilename} ) {
		@FILE = `cat $datafilename`;
	}
	elsif( -s "${datafilename}.zip" ) {
		@FILE = `unzip -p ${datafilename}.zip`;
	}
	else { ### fixup for missing file - return "-"
		print STDERR "$programname read_datafile_pt ERROR - missing datafile $datafilename \n";
		return '-' ; 
		# PAULS - DIAGNOSTIC return "${datafilename}" ; 
	}
	### RETURN IF NO DATA FILE
	if ( $#FILE < 1 ) {
		return;
	}
	### READ INPUT FILE DATA
	### read header info
	# search for marker line
	my $iline = 0; 
	while ( $FILE[$iline] !~ /^---/ ) {
		$iline++;
	}
	### READ HEADER LINES
	chomp( my $titleline1 = $FILE[$iline+1] );
	chomp( my $titleline2 = $FILE[$iline+2] );
	chomp( my $titleline3 = $FILE[$iline+3] );
    #4test: print "FILE= $datafilename  TITLE= $titleline1 \n";

	### get date/time info from header line
	# mapinfo = day monthname year
	if ( $titleline3 =~ m|Day= *([0-9]+) +([0-9]+) +([0-9]+) +| ) {
		$mapinfo = "$3 $monthname[$2] $1";
	}
    
    ### Model and forecast period
    if ( $titleline1 =~ m|\[(\w+) +(\d+)hrFcst| ) {
        $model = $1; $fcstpd = $2;
    }
    
	# mapinfo = valid local time
    #if ( $titleline3 =~ m|Fcst= *([0-9\.]+) +| ) {
    #	$fcstpd = $1 ;
    #}

	#alternate if ( $titleline1 =~ m|.* +([A-Z]+) +([0-9/]+) +([0-9]+)Z.* +([0-9])h.* +([A-Z]+)| ) { $mapinfo = "$1 $2 ${3}Z ${4}hFcst $5";  }  

	### get grid info from file  
	my ($head,$filegridname,$equal,$imap1in,$imap2in,$jmap1in,$jmap2in,$tail);
	### allow for old and new grid array index delimiter
	if( $titleline2 =~ m|Indexs=| ) {
		($head,$tail) = split( /  *Indexs=  */, $titleline2 );
	}
	else {
		($head,$tail) = split( /  *=  */, $titleline2 );
	}
	($imap1in,$imap2in,$jmap1in,$jmap2in,$tail) = split( /  */, $tail );
	### validity test
	if ( $igrid < $imap1in || $igrid > $imap2in || $jgrid < $jmap1in || $jgrid > $jmap2in ) {  
		# A useful diagnostic, but it fills up the logs!!
		# print STDERR "$programname read_datafile_pt ERROR - BAD GRID POINT ${igrid},${jgrid} vs ${imap1in}-${imap2in}+${jmap1in}-${jmap2in} \n";
		return '-' ;
	} 
	### get needed data line
	my @data = split ( / +/, $FILE[$iline+$JGRID-$jmap1in+4] );
	### DO MULTIPLIER CORRECTION IF REQUESTED
	if( defined $linfo && $linfo > 0 ) { 
		### get multiplier info from file  
		if ( $titleline3 =~ m| Mult= *([0-9\.]+) | ) {
			$cmult = $1;
		 }
		else {
			$cmult = 1.0;
		}
		$value = $data[$IGRID-$imap1in] / $cmult ;
	}
	else {
		chomp( $value = $data[$IGRID-$imap1in] );
	}
	return $value;
}

#########################################################################
### FIND NEAREST INTEGER
sub nint () { int($_[0] + ($_[0] >=0 ? 0.5 : -0.5)); }
#########################################################################


