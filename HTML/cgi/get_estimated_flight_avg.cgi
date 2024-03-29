#! /usr/bin/perl -w -T

### CALC RASP BLIPMAP TRACK AVG, SPATIAL AND OPTIMAL FLIGHT
### Eric - Modified from original get_rasptrackavg for GBSC RASP  - return JSON containing route
###
### curl 'http://192.168.1.6/cgi/get_estimated_flight_avg.cgi?region=NewEngland&date=2023-08-11&model=gfs&grid=d2&time=1300&glider=206%20Hornet&polarFactor=1.0&polarCoefficients=-0.0002%2C0.0244%2C-1.4700&tsink=1.0&tmult=1.0&turnpts=1%2C42.42616666666667%2C-71.7938333333333%2CSter%2C2%2C42.805%2C-72.00283333333333%2CJaff%2C3%2C42.100833333333334%2C-72.03883333333333%2CSout%2C4%2C42.42616666666667%2C-71.79383333333332%2CSter'
################################################################################
#print "Content-type: text/html\n\n${headerline}";
print "Content-type:application/json \n\n";

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

### Program that executes summary and outputs JSON
my $EXTRACTSCRIPT = "$SCRIPTDIR/get_estimated_flight_avg.PL";

#print "rasp_basedir : $rasp_basedir";

################################################################################

use warnings FATAL => 'all';
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard);
use JSON;

my $PROGRAM = 'get_rasptrackavg_cgi.cgi';
my $routeData = "";
my $errorMsg;
my ($query, $dataDir, $region, $grid, $date, $validtime, $glider, $polarFactor, $tsink, $tmult, $latlons, $turnpts, $type, $polarCoefficients);


### PARSE CGI INPUT
$query = new CGI;
$region = $query->param('region');
$grid = $query->param('grid');
$date = $query->param('date');
$model = $query->param('model');
$validtime = $query->param('time');
$glider = $query->param('glider'); # was polar but renamed to glider (e.g. LS-4a)
$polarFactor = $query->param('polarFactor');
$polarCoefficients = $query->param('polarCoefficients');
$tsink = $query->param('tsink');
$tmult = $query->param('tmult'); # Per emails with Dr Jack, this can be used as fudge factor to adjust
# sink rate calc up/down, if you believe thermal strength (wstar) are over/under forecast.
$latlons = $query->param('latlons');
$turnpts = $query->param('turnpts');

#print "1 latlons: $latlons";
#print "1 turnpts: $turnpts";


### UNTAINT INPUT PARAMS - do not allow leading "-" except with numeric value
if (defined $region && $region =~ m|^([A-Za-z0-9][A-Za-z0-9_.+-]*)$|) {$region = $1;}
if (defined $grid && $grid =~ m|^([dw][0-9])$|i) {$grid = $1;}
if (defined $date && $date =~ m|^([0-9-]+)$|) {$date = $1;}
if (defined $model && $model =~ m|^(\w+)$|) {$model = $1;}
if (defined $validtime && $validtime =~ m|^([0-9]{4}x?)$|) {$validtime = $1;} # Perl doesn't like + so switched to x
if (defined $glider && $glider =~ m|^([A-Za-z0-9 \/\-\(\)\\\*\.]*)$|) {$glider = $1;} # Eric - was polar
if (defined $polarFactor && $polarFactor =~ m|^([0-9.-]*)$|) {$polarFactor = $1;}
if (defined $polarCoefficients && $polarCoefficients =~ m|^([0-9\+\-\.Ee]+,[0-9\+\-\.Ee]+,[0-9\+\-\.]+)$|) {$polarCoefficients = $1;}
if (defined $tsink && $tsink =~ m|^([0-9.mkts]*)$|) {$tsink = $1;}
if (defined $tmult && $tmult =~ m|^([0-9.]*)$|) {$tmult = $1;}
if (defined $latlons && $latlons =~ m|^([0-9,.-]*)$|) {$latlons = $1;}
#if ( defined $turnpts && $turnpts =~ /^([A-Z][A-Z][A-Z0-9],.*)/ )        { $turnpts     = $1 ; }
if (defined $turnpts && $turnpts =~ m|^((([0-9],([0-9.-]*),([0-9.-]*),[A-Za-z]([A-Za-z0-9\s\-]{0,3})*),?)*)$|) {$turnpts = $1;}

#### ALLOW DEFAULTS FOR CERTAIN PARAMETERS
if (!defined $polarFactor || $polarFactor eq '') {$polarFactor = '1';}
if (!defined $tsink || $tsink eq '') {$tsink = '1.0';}
if (!defined $tmult || $tmult eq '') {$tmult = '1';}

#### TEST FOR MISSING ARGUMENTS
if (!defined $region || $region eq '') {reportError("ERROR EXIT: missing region argument");exit 0;}
if (!defined $grid || $grid eq '') {reportError( "ERROR EXIT: missing grid argument");exit 0;}
if (!defined $validtime || $validtime eq '') {reportError( "ERROR EXIT: missing time argument");exit 0;}
if (!defined $date || $date eq '') {reportError( "ERROR EXIT: missing date argument");exit 0;}
if (!defined $model || $model eq '') {reportError( "ERROR EXIT: missing model argument");exit 0;}
if (!defined $glider || $glider eq '') {reportError( "ERROR EXIT: missing polar argument");exit 0;}
### TEST FOR LATLONS, XYLIST OR TURNPTS INPUT ALTERNATIVES
### TEST FOR LATLONS, XYLIST OR TURNPTS INPUT ALTERNATIVES
if ((!defined $latlons || $latlons eq '') &&
    (!defined $turnpts || $turnpts eq '')) {
    $errorMsg = " Either  latlons or turnpts parameter must be defined";
    print "{ \"error\" : \"$errorMsg\" }";
}
else {
    if (defined $latlons && $latlons ne "") {
        $type = "latlons"
    }
    else {
        $type = "turnpts";
    }
}
### INITIALIZATION
$dataDir = join "/", $rasp_basedir, $region, $date, $model;

if (defined $turnpts) {
    $latlons = $turnpts;
}

my @args = ($dataDir, $region, $grid, $validtime, $glider, $polarFactor, $polarCoefficients, $tsink, $tmult, $type, $latlons);
#$routeData = `$SCRIPTDIR/get_estimated_flight_avg.PL  $dataDir $region  $grid $validtime  $glider  $polarFactor $polarCoefficients  $tsink  $tmult  $type $latlons`;
system($EXTRACTSCRIPT, @args);

#print "Finished get_estimated_flight_avg.cgi";
#print $routeData;


sub reportError {
    my ($errorMsg) = $_[0];
    my $errorJson = "{ \"error\" : \"$errorMsg\" }";
    print $errorJson;

}