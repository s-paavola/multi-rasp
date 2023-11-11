#! /usr/bin/perl -w
$ENV{'PATH'} = '/bin:/usr/bin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

### Use on server to test call to get_rasp_optimized_route.PL
#require "./get_rasp_optimized_route.PL";
my $program = "./get_rasp_optimized_route.PL";
my $dataDir = "../NewEngland/2023-08-11/gfs";
my $region = "NewEngland";
my $grid = "d2";
my $validtime = "1000x";
my $glider = "LS-4a";
my $polarFactor = 1.0;
my $polarCoefficients = "-0.0002,0.0350,-2.1900";
my $tsink = 1;
my $tmult = 1;
my $type = "turnpts";
my $latlons = "1,42.42616666666667,-71.79383333333332,Ster,2,42.805,-72.00283333333333,Jaff,3,42.100833333333334,-72.03883333333333,Sout,4,42.42616666666667,-71.79383333333332,Ster";
my @parms = ( $program, $dataDir, $region, $grid, $validtime, $glider, $polarFactor, $polarCoefficients, $tsink, $tmult, $type, $latlons);
system($^X, @parms);


