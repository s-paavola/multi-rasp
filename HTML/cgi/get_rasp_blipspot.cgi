#!/usr/bin/perl -w -T

### GET RASP BLIPSPOT FOR SPECIFIED IMAGE LOCATION
### eg call ala http://www.drjack.info/cgi-bin/get_rasp_blipspot.cgi?&region=PANOCHE&grid=d2&day=0&i=559&k=70&width=585&height=585

################################################################################

### MODIFIED FROM BLIP's get_image_minispot.cgi

use warnings;
use strict;

use CGI::Carp qw(fatalsToBrowser);

#untaint - UNTAINT PATH
$ENV{'PATH'} = '/bin:/usr/bin';

#print "Content-type: text/plain\n\n";
#for my $k (sort (keys %ENV))
#{
#    print "$k= $ENV{$k}<br>\n";
#}

my $script_filename = $ENV{"SCRIPT_FILENAME"};
my ($PROGRAMNAME, $SCRIPTDIR);
die "SCRIPT_FILENAME not defined" unless defined $script_filename;
if ($script_filename =~ m|^((/[\w][\w.-]*)+)/([\w.-]+)$| ) {$SCRIPTDIR = $1; $PROGRAMNAME = $3};
my $rasp_basedir;
if ($SCRIPTDIR =~ m|^((/[\w][\w.-]*)+)/([\w.-]+)$| ) { $rasp_basedir = $1; }

### SET EXTERNAL SCRIPT WHICH EXTRACTS BLIPSPOT DATA INTO PRINTABLE FORMAT
my $EXTRACTSCRIPT = "$SCRIPTDIR/extract.blipspot.PL";

### SET PARAMETER FOR XI TESTS
my $LTEST = 0;
#4XItest: $LTEST = 1;

### PARSE CGI INPUT
use CGI qw(:standard);
my $query = new CGI;
my $region = $query->param('region');
my $date = $query->param('date');
my $model = $query->param('model');
my $plottime = $query->param('time');
my $ilat = $query->param('lat');
my $klon = $query->param('lon');
my $parameter = $query->param('param');
#untaint - untaint input arguments
if ( defined $region && $region =~ m|^(\w+)$| ) { $region = $1 ; } # alphanumeric+
else { die "$PROGRAMNAME ERROR EXIT: bad region argument - $region"; }
if ( defined $date && $date =~ m|^([[:digit:]-]+)$| ) { $date = $1 ; } # date format
else { die "$PROGRAMNAME ERROR EXIT: bad date argument - $date"; }
if ( defined $model && $model =~ m|^(\w+)$| ) { $model = $1 ; } # date format
else { die "$PROGRAMNAME ERROR EXIT: bad date argument - $model"; }
if ( defined $plottime && $plottime =~ m|^([0-9][0-9][0-9][0-9])$| ) { $plottime = $1 ; } # alphanumeric+
else { die "$PROGRAMNAME ERROR EXIT: bad TIME argument - $plottime"; }
if ( defined $ilat && $ilat =~ m|^([0-9+-][0-9.]*)$| ) { $ilat = $1 ; } # decimal only
if ( defined $klon && $klon =~ m|^([0-9+-][0-9.]*)$| ) { $klon = $1 ; } # decimal only
if ( defined $parameter && $parameter =~ m|^([a-z][a-z0-9_ ]*)$| ) {
    $parameter = $1 ;  # alphanumeric+
}
else {
    $parameter = '';
}

### TEST FOR MISSING ARGUMENTS

########################################

# PAULS === Can now also take lat ($ilat) & lon ($klon) directly

my $dataDir = join "/", $rasp_basedir, $region, $date, $model;

my @spotlines = `/usr/bin/perl ${EXTRACTSCRIPT} $dataDir $region $ilat $klon 1 $plottime $parameter 2>&1`;

### PRINT HTML TEXT HEADER+array
#print "<html><body> <style=text/plain><pre>@{spotlines}</pre>\n</body></html>";
print "Content-type: text/plain\n\n@{spotlines}\n";

###########################################################################################kj
### FIND NEAREST INTEGER
sub nint { int($_[0] + ($_[0] >=0 ? 0.5 : -0.5)); }
###########################################################################################
### TAINT TEST
#unused sub is_tainted { not eval { join("",@_), kill 0; 1; }; }
###########################################################################################
