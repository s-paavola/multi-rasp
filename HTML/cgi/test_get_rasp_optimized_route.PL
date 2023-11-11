#! /usr/bin/perl -w
$ENV{'PATH'} = '/bin:/usr/bin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

require "./get_rasp_optimized_route.PL";
my $dataDir = "../NewEngland/2023-08-11/gfs";
my $region = "NewEngland";
my $grid = "d2";
my $validtime = "1000+";
my $polar = "LS-4a";
my $wgt = 1;
my $tsink = 1;
my $tmult = 1;
my $latlons = "42.42617,-71.79383,42.805,-72.003,42.90133,-72.26983,42.42617,-71.79383";

$routeData = getRaspOptimizedRoute($dataDir, $region, $grid, $validtime, $polar, $wgt, $tsink, $tmult, $latlons);

print "routeData : $routeData";


