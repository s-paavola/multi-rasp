#! /usr/bin/perl -w -T

### CALC RASP BLIPMAP TRACK AVG, SPATIAL AND OPTIMAL FLIGHT
### ala http://www.drjack.info/cgi-bin/get_rasptrackavg.cgi?region=GREATBRITAIN&grid=d2&date=yyyy-mm-dd&time=1500&polar=LS-3&wgt=1&tsink=1&tmult=1&latlons=51.,0.,52.,-1.,52.,1.,51.,0.
### OR ...&turnpts=LAS,MEM,PAR,...
# 
#rasp- ### CAN INPUT EITHER LAT,LONS OR IMAGE INFORMATION

################################################################################

  ### MODIFIED FROM get_bliptrackavg.pl

  ### NOTE - if input parameter argument changes may need to change its detainting

  ### TO UNTAINT PATH
  $ENV{'PATH'} = '/bin:/usr/bin';
  delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

  my $script_filename = $ENV{"SCRIPT_FILENAME"};
  my ($PROGRAMNAME, $SCRIPTDIR);
  die "SCRIPT_FILENAME not defined" unless defined $script_filename;
  if ($script_filename =~ m|^((/[\w][\w.-]*)+)/([\w.-]+)$| ) {$SCRIPTDIR = $1; $PROGRAMNAME = $3};
  my $rasp_basedir;
  if ($SCRIPTDIR =~ m|^((/[\w][\w.-]*)+)/([\w.-]+)$| ) { $rasp_basedir = $1; }

  ### SET EXTERNAL SCRIPT WHICH OUTPUTS RESULT IN TEXT FORMAT
  $EXTRACTSCRIPT = "$SCRIPTDIR/rasptrackavg.PL";

################################################################################

  use CGI::Carp qw(fatalsToBrowser);

  my $PROGRAM = 'get_rasptrackavg.cgi' ;

  ### SET PLOT SCRIPT INFORMATION
  #$NCARG_ROOT    = '/usr/local/ncarg/' ;
  #$NCARG_LIB     = '$NCARG_ROOT/lib/' ;
  #$NCARG_NCARG   = '$NCARG_LIB/ncarg/' ;
  #$NCARG_DATABASE= '$NCARG_NCARG/database/' ;

  #$ENV{'NCARG_ROOT'}     = $NCARG_ROOT ;
  #$ENV{'NCARG_LIB'}      = $NCARG_LIB ;
  #$ENV{'NCARG_NCARG'}    = $NCARG_NCARG ;
  #$ENV{'NCARG_DATABASE'} = $NCARG_DATABASE ;

  $NCL_COMMAND = 'ncl' ;
  ${NCLSCRIPT} = "$SCRIPTDIR/rasptrackavg.multiplot.ncl";

  ### ALLOW XI TESTS
  $LTEST = 0;
  #4XItest: $LTEST = 1;
  ### SET INPUT PARAMETERS
  if ( $LTEST == 0 ) {
    ### PARSE CGI INPUT
    use CGI qw(:standard);
    $query = new CGI;
    $region = $query->param('region');
    $grid = $query->param('grid');
    $date = $query->param('date');
    $model = $query->param('model');
    $validtime = $query->param('time');
    $polar = $query->param('polar');
    $wgt = $query->param('wgt');
    $tsink = $query->param('tsink');
    $tmult = $query->param('tmult');
    $latlons = $query->param('latlons');
    $turnpts = $query->param('turnpts');
    $imagewidth = $query->param('width');
    $imageheight = $query->param('height');
    ### UNTAINT INPUT PARAMS - do not allow leading "-" except with numeric value
    if ( defined $region && $region =~ m|^([A-Za-z0-9][A-Za-z0-9_.+-]*)$| )  { $region      = $1 ; }
    if ( defined $grid && $grid =~ m|^([dw][0-9])$|i)                        { $grid        = $1 ; }
    if ( defined $date && $date =~ m|^([0-9-]+)$| )                          { $date        = $1 ; }
    if ( defined $model && $model =~ m|^(\w+)$| )			     { $model       = $1 ; }
    if ( defined $validtime && $validtime =~ m|^([0-9a-zA-Z+]*)$| )          { $validtime   = $1 ; }
    if ( defined $polar && $polar =~ m|^([A-Za-z0-9+-][A-Za-z0-9,_+.-]*)$| ) { $polar       = $1 ; }
    if ( defined $wgt && $wgt =~ m|^([0-9.-]*)$| )                           { $wgt         = $1 ; }
    if ( defined $tsink && $tsink =~ m|^([0-9.mkts]*)$| )                    { $tsink       = $1 ; }
    if ( defined $tmult && $tmult =~ m|^([0-9.]*)$| )                        { $tmult       = $1 ; }
    if ( defined $latlons && $latlons =~ m|^([0-9,.-]*)$| )                  { $latlons     = $1 ; }
    if ( defined $turnpts && $turnpts =~ /^([A-Z][A-Z][A-Z0-9],.*)/ )        { $turnpts     = $1 ; }
    if ( defined $imagewidth && $imagewidth =~ m|^([0-9]*)$| )               { $imagewidth  = $1 ; }
    if ( defined $imageheight && $imageheight =~ m|^([0-9]*)$| )             { $imageheight = $1 ; }
  }
  else {
    ###### INITIALIZATION FOR XI TESTS
    #4test: $EXTRACTSCRIPT = "${BASEDIR}/RASP/ANAL/TRACK/test.rasptrackavg.PL";
    ###### CASE
    $grid = 'd2' ;
    $validtime = 1500 ;
    ### ARTIFICIAL INPUT
    #alternate: $latlons = "51.,0.,52.,-1.,52.,1.,51.,0.," ;
    $imagewidth = $imageheight = 1000 ;
    $polar = '-1.3419e-4,2.077e-2,-1.37' ;
    $wgt = 1 ;
    $tsink = 0.8 ;
    $tmult = 1.0 ;
  }

  #### ALLOW DEFAULTS FOR CERTAIN PARAMETERS
  if ( ! defined $wgt || $wgt eq '' )     { $wgt = '1' ; }
  if ( ! defined $tsink || $tsink eq '' ) { $tsink = '1.0' ; }
  if ( ! defined $tmult || $tmult eq '' ) { $tmult = '1' ; }

  #### TEST FOR MISSING ARGUMENTS
  if ( ! defined $region || $region eq '' )       { die "${PROGRAM} ERROR EXIT: missing region argument"; }
  if ( ! defined $grid || $grid eq '' )           { die "${PROGRAM} ERROR EXIT: missing grid argument"; }
  if ( ! defined $validtime || $validtime eq '' ) { die "${PROGRAM} ERROR EXIT: missing time argument"; }
  if ( ! defined $date || $date eq '' )           { die "${PROGRAM} ERROR EXIT: missing date argument"; }
  if ( ! defined $model || $model eq '' )         { die "${PROGRAM} ERROR EXIT: missing model argument"; }
  if ( ! defined $polar || $polar eq '' )         { die "${PROGRAM} ERROR EXIT: missing polar argument"; }

  ### TEST FOR LATLONS, XYLIST OR TURNPTS INPUT ALTERNATIVES
  if ( (!defined $latlons || $latlons eq '' ) &&
       (!defined $turnpts || $turnpts eq '')) {
    die "${PROGRAM} ERROR EXIT: missing latlons or turnpts argument";
  }
  ### INITIALIZATION

  ### SET TMP FILE IDENTIFIER
  $tmpid = int( rand 999998 ) +1;
    
  $dataDir = join "/", $rasp_basedir, $region, $date, $model;

  ### GET OUTPUT TEXT FROM EXTERNAL SCRIPT
  if(defined $latlons){
    $calcout = `${EXTRACTSCRIPT} $dataDir $region $grid $validtime $polar $wgt $tsink $tmult $latlons $tmpid`;
  }
  if( defined $turnpts){
    $calcout = `${EXTRACTSCRIPT} $dataDir $region $grid $validtime $polar $wgt $tsink $tmult $turnpts $tmpid`;
  }

  ### PLOT FROM OUTPUT FILE PRODUCED BY ABOVE
  if ( $calcout !~ m|error|i ){
    $plotout = `${NCL_COMMAND} ${NCLSCRIPT}  'wks="png"' 'data_filename="/tmp/rasptrackavg.out.${tmpid}"' 'plot_filename="/tmp/rasptrackavg.multiplot.${tmpid}"'`;
  }
  else {
    $plotout = 'CALC ERROR => NO PLOT' ;
  }

  ### PRINT HTML TEXT = HEADER + SCRIPT OUTPUT + FOOTER
  $headerline = '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
                 <HTML>
                 <HEAD>
                  <TITLE>RASP Track Avg</TITLE>
                  <meta http-equiv="content-type" content="text/html; charset=ISO-8859-1">
                  <meta name="author" content="Dr. John W. (Jack) Glendening">
                 </HEAD>
                 <BODY text="black" bgcolor="white">' ;

  $footerline = ' </BODY></HTML>' ;
  if ( $calcout !~ m|error|i ) {
    print "Content-type: text/html\n\n${headerline}<TABLE><TR valign=\"top\"><TD><BR><PRE>${calcout}</PRE></TD><TD><IMG SRC=\"/cgi-bin/display_png.cgi?file=/tmp/rasptrackavg.multiplot.${tmpid}.png\"></TD></TR></TABLE> ${footerline}\n";
  }
  else {
    print "Content-type: text/html\n\n${headerline}<PRE>${calcout}<BR>${plotout}</PRE> ${footerline}\n";
  }
  #4test: print "Content-type: text/html\n\n${headerline}<PRE>${calcout}</PRE> <BR> PLOTOUT= $plotout <BR>${footerline}\n";

  #PAULS - CLEAN UP THE DETRITUS
  { `/bin/rm -f /tmp/rasptrackavg.out.${tmpid}` ; }
