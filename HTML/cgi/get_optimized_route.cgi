#! /usr/bin/perl -w -T

### CALC RASP BLIPMAP TRACK AVG, SPATIAL AND OPTIMAL FLIGHT
### Eric - Modified from original get_rasptrackavg for GBSC RASP  - return JSON containing route
###
### Call https:/wwww.soargbsc.net/RASP/get_rasptrackavg_gbsc?region=NewEngland&grid=d2&date=2023-08-11&time=1100+&polar=LS-4a&wgt=1&sink=1&tmult=1&latlons=42.42617,-71.79383,42.805,-72.003,42.90133,-72.26983,42.42617,-71.79383
###
################################################################################
#print "Content-type: text/html\n\n${headerline}";
print  "Content-type:application/json \n\n" ;

### TO UNTAINT PATH
$ENV{'PATH'} = '/bin:/usr/bin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

my $script_filename = $ENV{"SCRIPT_FILENAME"};
#print "script_filename : $script_filename \n";
my ($PROGRAMNAME, $SCRIPTDIR);
die "SCRIPT_FILENAME not defined" unless defined $script_filename;
if ($script_filename =~ m|^((/[\w][\w.-]*)+)/([\w.-]+)$|) {
    $SCRIPTDIR = $1;
    $PROGRAMNAME = $3
};
my $rasp_basedir;
if ($SCRIPTDIR =~ m|^((/[\w][\w.-]*)+)/([\w.-]+)$|) {$rasp_basedir = $1;}

### SET EXTERNAL SCRIPT WHICH OUTPUTS RESULT IN TEXT FORMAT
$EXTRACTSCRIPT = "$SCRIPTDIR/get_rasp_optimized_route.PL";

#print "rasp_basedir : $rasp_basedir";

################################################################################

use warnings FATAL => 'all';
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard);
use JSON;

my $PROGRAM = 'get_rasptrackavg_cgi.cgi';

### PARSE CGI INPUT
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



### UNTAINT INPUT PARAMS - do not allow leading "-" except with numeric value
if (defined $region && $region =~ m|^([A-Za-z0-9][A-Za-z0-9_.+-]*)$|) {$region = $1;}
if (defined $grid && $grid =~ m|^([dw][0-9])$|i) {$grid = $1;}
if (defined $date && $date =~ m|^([0-9-]+)$|) {$date = $1;}
if (defined $model && $model =~ m|^(\w+)$|) {$model = $1;}
if (defined $validtime && $validtime =~ m|^([0-9]{4}x?)$|) { $validtime = $1;}
if (defined $polar && $polar =~ m|^([A-Za-z0-9+-][A-Za-z0-9,_+.-]*)$|) {$polar = $1;}
if (defined $wgt && $wgt =~ m|^([0-9.-]*)$|) {$wgt = $1;}
if (defined $tsink && $tsink =~ m|^([0-9.mkts]*)$|) {$tsink = $1;}
if (defined $tmult && $tmult =~ m|^([0-9.]*)$|) {$tmult = $1;}
if (defined $latlons && $latlons =~ m|^([0-9,.-]*)$|) {$latlons = $1;}
if (defined $turnpts && $turnpts =~ /^([A-Z][A-Z][A-Z0-9],.*)/) {$turnpts = $1;}



#### ALLOW DEFAULTS FOR CERTAIN PARAMETERS
if (!defined $wgt || $wgt eq '') {$wgt = '1';}
if (!defined $tsink || $tsink eq '') {$tsink = '1.0';}
if (!defined $tmult || $tmult eq '') {$tmult = '1';}

#### TEST FOR MISSING ARGUMENTS
if (!defined $region || $region eq '') {die "${PROGRAM} ERROR EXIT: missing region argument";}
if (!defined $grid || $grid eq '') {die "${PROGRAM} ERROR EXIT: missing grid argument";}
if (!defined $validtime || $validtime eq '') {die "${PROGRAM} ERROR EXIT: missing time argument";}
if (!defined $date || $date eq '') {die "${PROGRAM} ERROR EXIT: missing date argument";}
if (!defined $model || $model eq '') {die "${PROGRAM} ERROR EXIT: missing model argument";}
if (!defined $polar || $polar eq '') {die "${PROGRAM} ERROR EXIT: missing polar argument";}

### TEST FOR LATLONS, XYLIST OR TURNPTS INPUT ALTERNATIVES
if (!defined $latlons || $latlons eq '') {
    die "${PROGRAM} ERROR EXIT: missing latlons argument";
}
### INITIALIZATION

$dataDir = join "/", $rasp_basedir, $region, $date, $model;

my $routeData = "";
#print STDERR("calling getRaspOptimizedRoute");
if (defined $latlons) {
    #$routeData = `${EXTRACTSCRIPT} "../NewEngland/2023-08-11/gfs" $region  $grid $validtime  $polar  $wgt  $tsink  $tmult  $latlons`;

    $routeData = `$SCRIPTDIR/get_rasp_optimized_route.PL  $dataDir $region  $grid $validtime  $polar  $wgt  $tsink  $tmult  $latlons`;
   # print "Finished get_optimized_route.cgi";
}
print $routeData;

