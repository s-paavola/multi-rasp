#! /usr/bin/perl -w
# OLD /usr/local/bin/perl -w
if ( $#ARGV == -1 || $ARGV[0] eq '-?' ) {
#-----------------adescription1---------------------------------------------------------
print "Output mass gridpt(s) i,j for arguments (comma OR space can be delimiter): dataDir lat1 lon1 lat2 lon2 ... \n";
print "  option: preceeding arguments with -v gives verbose printout\n";
print "  option: preceeding arguments with -n gives nearest integer printout\n";
print "  uses namelist.wps\n";
print "  input W longitude can be negative or > 180 \n";
print "  output grid I,J is non-integer decimal - note: (1,1)=SWcorner \n";
print "  input/output points are _not_ confined to actual grid limits \n";
print "eg: ' latlon2ij.pl PANOCHE 2 36.361 -121.264 37.417 -120.867' OUTPUTS '17.66 30.66 40.34 51.34' \n";
exit 0; }
########################################################################################
### Originally Coded by:  Jack Glendening  drjack@drjack.info  July 2006
########################################################################################
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
### To eliminate old SGI files from library path  (done at _compile_ time)
    no lib '/usr/lib/perl';
###############################################################################

### FOR INPUT LAT,LONG PRINT (FLOAT) I,J OF LAMBERT GRID
### FIRST CALC FROM MOAD CENTRAL POINT, THEN SHIFT TO ACTUAL GRID
### converted from RUC latlon2gridpt.pl
### *NB* some odd-looking offset choices due to need for *mass* point lat/longs
###      results agree with wrfout lat/lon => arrays of size (xdim-1)x(ydim-1)
### TRY TO KEEP PARALLELISM WITH ij2latlon.pl

### PARSE ARGUMENTS
  ### allow for -v option for verbose printout
  if ( $ARGV[0] ne '-v' )
  { $LPRINT = 0 ; }
  else
  { 
    $LPRINT = 1 ;
    shift;
  }
  ### allow for -n option for nearest integer printout
  if ( $ARGV[0] ne '-n' )
  { $LNINT = 0 ; }
  else
  { 
    $LNINT = 1 ;
    shift;
  }

  ### set argument parameters
  ### convert comma-separated-variables into array
  if ( $ARGV[0] =~ m/,/ )
  {
    @alatlon = split ',', $ARGV[0] ;
    $LCOMMA = 1;
  }
  else
  {
    @alatlon = @ARGV ;
    $LCOMMA = 0;
  }
  ### now parse args
  $datadirname = shift @alatlon;
  #4test: print "alatlon[0] alatlon[1]= $alatlon[0] $alatlon[1]  \n";

### READ RASP GRID DATA FROM NAMELIST FILE
#print STDERR ("latlon2ij.pl   datadirname: $datadirname");
open ( DATAFILE, "<$datadirname/namelist.wps" )
or die "Unable to open $datadirname/namelist.wps: $@";
while (<DATAFILE>)
{
    ### do not allow blank in simulation name (so number of blank-delimited fields in output line always known)
    if ( m|^ *max_dom\s+=\s+(\d+) *,?$|i)       { $kgrid = $1; }
    if ( m|^ *parent_grid_ratio * = * (.*) *$|i )   { @RATIO_TO_PARENT = split ( / *,/, $1 ) ; }
    if ( m|^ *i_parent_start * = * (.*) *$|i )  { @DOMAIN_ORIGIN_LLI = split ( / *,/, $1 ) ; }
    if ( m|^ *j_parent_start * = * (.*) *$|i )  { @DOMAIN_ORIGIN_LLJ = split ( / *,/, $1 ) ; }
    if ( m|^ *e_we * = * (.*) *$|i )            { @DOMAIN_ORIGIN_URI = split ( / *,/, $1 ) ; }
    if ( m|^ *e_sn * = * (.*) *$|i )            { @DOMAIN_ORIGIN_URJ = split ( / *,/, $1 ) ; }
    if ( m|^ *ref_lat * = * ([^, ]*).*$|i )     { $MOAD_KNOWN_LAT = $1 ; }
    if ( m|^ *ref_lon * = * ([^, ]*).*$|i )     { $MOAD_KNOWN_LON = $1 ; }
    if ( m|^ *truelat1 * = * ([\d.]+) *,$|i )   { $MOAD_STAND_LATS[0] = $1 ; }
    if ( m|^ *truelat1 * = * ([\d.]+) *,$|i )   { $MOAD_STAND_LATS[1] = $1 ; }
    if ( m|^ *stand_lon * = * ([^, ]*).*$|i )   { $MOAD_STAND_LONS = $1 ; }
    if ( m|^ *dx * = * ([^, ]*).*$|i )          { $MOAD_DELTA_X = $1 ; }
    if ( m|^ *dy * = * ([^, ]*).*$|i )          { $MOAD_DELTA_Y = $1 ; }
    if ( m|^ *map_proj * = * ([^, ]*).*$|i )    { $MAP_PROJ_NAME = $1 ; }
}
close DATAFILE;

### do sanity checks
if( ! defined $MOAD_KNOWN_LAT || ! defined $MOAD_KNOWN_LON ||
    ! @MOAD_STAND_LATS || ! defined $MOAD_STAND_LONS ||
    ! defined  $MAP_PROJ_NAME )
{ die "ERROR: MISSING DATA in DATAFILE $datadirname/namelist.wps "; }
$iigrid = $kgrid - 1;
if( ! defined $RATIO_TO_PARENT[$iigrid] ||
    ! defined  $DOMAIN_ORIGIN_LLI[$iigrid] || ! defined  $DOMAIN_ORIGIN_LLJ[$iigrid] ||
    ! defined  $DOMAIN_ORIGIN_URI[$iigrid] || ! defined  $DOMAIN_ORIGIN_URJ[$iigrid] )
{ die "ERROR: MISSING DATA FOR GRID $iigrid in DATAFILE $datadirname/namelist.wps "; }
### this program only valid for tangent lambert projection
if( $MOAD_STAND_LATS[0] == $MOAD_STAND_LATS[1] && $MAP_PROJ_NAME =~ m|lambert|i )
    { $MOAD_STAND_LAT = $MOAD_STAND_LATS[0] ; }
else
    { die "ERROR: PROGRAM ONLY VALID FOR CASE OF TANGENT LAMBERT PROJECTION "; }
if( $MOAD_DELTA_X != $MOAD_DELTA_Y )
    { die "ERROR: PROGRAM ONLY VALID FOR CASE OF DX == DY"; }

### PUT GRID DATA INTO LOCAL VARIABLES
  $NXmassMOAD       = $DOMAIN_ORIGIN_URI[0] -1 ;
  $NYmassMOAD       = $DOMAIN_ORIGIN_URJ[0] -1 ;
  $DX_P             = $MOAD_DELTA_X ;
  $LAT_MOAD_CENTER  = $MOAD_KNOWN_LAT ;
  $LON_MOAD_CENTER  = $MOAD_KNOWN_LON ;
  $LON_XX_P         = $MOAD_STAND_LONS ;
  $LAT_TAN_P        = $MOAD_STAND_LAT ;

### LOOP OVER ALL INPUT alat,alon
### ERIC - Changed start from 0 to 1.
for ( $iindex=1; $iindex<$#alatlon; $iindex=$iindex+2 )
{
  $alat = $alatlon[$iindex] ;
  $alon = $alatlon[$iindex+1] ;
  # print  ("alat:", $alat,  "  alon :" , $alon, "\n" );

  ### convert negative W longitude
  if( $alon < 0 ) { $alon = $alon + 360.; }

### CALC MOAD LAMBERT I,J (non-integer) RELATIVE TO CENTER OF MOAD GRID
  ( $airelative, $ajrelative ) = &W3FB11( $alat,$alon, $LAT_MOAD_CENTER,$LON_MOAD_CENTER,$DX_P,$LON_XX_P,$LAT_TAN_P );

### CALC MOAD LAMBERT I,J (non-integer) SHIFTED TO MOAD *MASS* GRID
  $aimoad = $airelative + 0.5*( $NXmassMOAD -1 ) ;
  $ajmoad = $ajrelative + 0.5*( $NYmassMOAD -1 ) ;

  ### COMPUTE LAMBERT I,J FOR SELECTED GRID
  $ai = $aimoad ;
  $aj = $ajmoad ;
  ### CONVERT MOAD *MASS* INDEX TO NON-MOAD SUBGRID *MASS* INDEX
  ### note iigrid is one less than kgrid (i.e. param arrays use perl indexing)
  for ( $iigrid=1 ; $iigrid<=($kgrid-1); $iigrid++ )
  {
    if( ! defined $RATIO_TO_PARENT[$iigrid] || ! defined  $DOMAIN_ORIGIN_LLI[$iigrid] || ! defined  $DOMAIN_ORIGIN_LLJ[$iigrid] )
    {
      die "ERROR: BAD GRID NUMBER = $kgrid ";
    }
    $ai = 0.5 + $RATIO_TO_PARENT[$iigrid] * ( $ai - ( $DOMAIN_ORIGIN_LLI[$iigrid] -0.5 ) ) ;
    $aj = 0.5 + $RATIO_TO_PARENT[$iigrid] * ( $aj - ( $DOMAIN_ORIGIN_LLJ[$iigrid] -0.5 ) ) ;
    $ninti = nint( $ai );
    $nintj = nint( $aj );
  }
                
  ### VERBOSE PRINT
  if ( $LPRINT != 0 )
  {
    if ( $LCOMMA == 0 )
    {
     printf STDERR "GRID %i Lat,Lon= %7.3f %8.3f => aI,aJ= %5.3f %5.3f (%d,%d)\n", $kgrid, $alat,$alon, $ai,$aj, $ninti,$nintj ;
    }
    else
    {
     printf STDERR "GRID %i Lat,Lon= %7.3f,%8.3f => aI,aJ= %5.3f,%5.3f (%d,%d)\n", $kgrid, $alat,$alon, $ai,$aj, $ninti,$nintj ;
    }
  }

  ### write to array
  if ( $LNINT == 0 )
  { push @aij, ($ai,$aj); }
  else
  { push @aij, ($ninti,$nintj); }

### END OF LOOP OVER ALL INPUT lat,lon
}

### NON-VERBOSE PRINT
#if ( $LPRINT == 0 )
{
  if ( $LNINT == 0 )
  { $fmt = '%.2f' ; }
  else
  { $fmt = '%d' ; }

  if ( $LCOMMA == 0 )
  { $format = "${fmt} " x $#aij ; }
  #old { $fmt = "%.2f " x $#aij ; }
  else
  { $format = "${fmt}," x $#aij ; }
  #old { $fmt = "%.2f " x $#aij ; }
  # ensure no blank at end
  printf "${format}${fmt}\n", @aij ;
}

exit;

##########################################################################
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

  my ( $ALAT, $ELON, $ALAT1, $ELON1, $DX, $ELONV, $ALATAN ) = @_;

  my ( $H );
  my     $RERTH = 6.3712E+6;
  my     $PI = 3.14159 ;
#
#        PRELIMINARY VARIABLES AND REDIFINITIONS
#
#        H = 1 FOR NORTHERN HEMISPHERE; = -1 FOR SOUTHERN
#
         if( $ALATAN>0)
           { $H = 1.; }
         else
           { $H = -1.; }
#
  my     $RADPD = $PI/180.0;
  my     $REBYDX = $RERTH/$DX;
  my     $ALATN1 = $ALATAN * $RADPD;
  my     $AN = $H * sin($ALATN1);
  my     $COSLTN = cos($ALATN1);
#
#        MAKE SURE THAT INPUT LONGITUDES DO NOT PASS THROUGH
#        THE CUT ZONE (FORBIDDEN TERRITORY) OF THE FLAT MAP
#        AS MEASURED FROM THE VERTICAL (REFERENCE) LONGITUDE.
#
  my     $ELON1L = $ELON1;
         if( ($ELON1 - $ELONV) > 180.)
         { $ELON1L = $ELON1 - 360. ;}
         if( ($ELON1 - $ELONV) < -180. )
         { $ELON1L = $ELON1 + 360.; }
#
  my     $ELONL = $ELON;
         if( ($ELON - $ELONV) > 180. )
         { $ELONL = $ELON - 360.; }
         if( ($ELON - $ELONV) < -180. )
         { $ELONL = $ELON + 360.; }
#
  my     $ELONVR = $ELONV *$RADPD;
#
#        RADIUS TO LOWER LEFT HAND (LL) CORNER
#
  my     $ALA1 =  $ALAT1 * $RADPD;
  my     $RMLL = $REBYDX * ((($COSLTN)**(1.-$AN))*(1.+$AN)**$AN) * (((cos($ALA1))/(1.+$H*sin($ALA1)))**$AN)/$AN;
#
#        USE LL POINT INFO TO LOCATE POLE POINT
#
  my     $ELO1 = $ELON1L * $RADPD;
  my     $ARG = $AN * ($ELO1-$ELONVR);
  my     $POLEI = 1. - $H * $RMLL * sin($ARG);
  my     $POLEJ = 1. + $RMLL * cos($ARG);
#
#        RADIUS TO DESIRED POINT AND THE I J TOO
#
  my     $ALA = $ALAT * $RADPD;
  my     $RM = $REBYDX * (($COSLTN**(1.-$AN))*(1.+$AN)**$AN) * (((cos($ALA))/(1.+$H*sin($ALA)))**$AN)/$AN;
#
  my     $ELO = $ELONL * $RADPD;
         $ARG = $AN*($ELO-$ELONVR);
  my     $XI = $POLEI + $H * $RM * sin($ARG);
  my     $XJ = $POLEJ - $RM * cos($ARG);
#
#        IF COORDINATE LESS THAN 1
#        COMPENSATE FOR ORIGIN AT (1,1)
#
#jack - following gives round-off error problems so eliminate
#jack-        IF(XI.LT.1.)  XI = XI - 1.;
#jack         IF(XJ.LT.1.)  XJ = XJ - 1.;
#
      return ($XI,$XJ);
}
#########################################################################
### FIND NEAREST INTEGER
sub nint { int($_[0] + ($_[0] >=0 ? 0.5 : -0.5)); }
#########################################################################
