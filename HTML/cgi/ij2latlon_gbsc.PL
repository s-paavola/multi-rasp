#! /usr/bin/perl -w
# ERIC - Modified version of ij2latlon.PL for GBSC file structure
#        Also turned into subroutine
sub ij2latlon_gbsc {
    ### now parse args
    my ($datafilename, $kgrid, @gridpoints);

    $datafilename = $_[0];
    #print " datafilename : ${datafilename} \n";
    $kgrid = $_[1];
    @gridpoints = @{$_[2]};
    #print " gridpoints passed into ij2latlon_gbsc : @gridpoints  \n";

    ### allow for grid specification ala d1,d2,w1,w2
    if ($kgrid eq 'd1') {$kgrid = 1;}
    elsif ($kgrid eq 'd2') {$kgrid = 2;}
    elsif ($kgrid eq 'w1') {$kgrid = 2;}
    elsif ($kgrid eq 'w2') {$kgrid = 3;}
    #4test: print "ij[0] ij[1]= $ij[0] $ij[1]  \n";
    #old  if ( $ARGV[0] !~ m/,/ )
    #old  {
    #old    $datafilename = shift @ARGV;
    #old    $kgrid = shift @ARGV;
    #old    @aij = @ARGV;
    #old  }
    #old  else
    #old  {
    #old    ($datafilename,$kgrid,@aij) = split m/,/, $ARGV[0] ;
    #old    #old ($datafilename,$kgrid,$ai,$aj) = split m/,/, $ARGV[0] ;
    #old  }
    #old
    ### allow $datafilename ABBREVIATION using directory of this program as basename
    if ($datafilename !~ m|/|) {
        ### SET BASE DIRECTORY for local "DRJACK" directory setup, based on location of this program
        if ($0 =~ m|^/|) {($SCRIPTDIR = "${0}") =~ s|/[^/]*$||;}
        else {($SCRIPTDIR = "$ENV{'PWD'}/${0}") =~ s|[\./]*/[^/]*$||;}
        ## PAULS ( $BASEDIR = $SCRIPTDIR ) =~ s|/[R]*ASP/UTIL[/]*||i ;
        ## PAULS $datafilename = "$BASEDIR/WRF/WRFSI/domains/${datafilename}/static/wrfsi.nl";
        #$datafilename = "/var/www/html/${datafilename}/wrfsi.nl";
        $datafilename = "${datafilename}/namelist.wps";

    }
    ### INITIALIZATION
    #unused ### convert degrees into radians
    #unused $deg2rad = 0.01745329252 ;
    #unused ### following cone is for tangent conic projection only
    #unused       $cone = cos( $deg2rad*( 90. - $LAT_TAN_P ) );
    ### READ RASP GRID DATA FROM NAMELIST FILE
    #print "ijlatlog_gbsc  datafilename: $datafilename \n";
    open(DATAFILE, "<$datafilename") or die "*** ERROR EXIT - OPEN FAILURE for $datafilename";

    my @MOAD_STAND_LATS = ();
    @datalines = <DATAFILE>;
    for ($iiline = 0; $iiline <= $#datalines; $iiline++) {
        #print $datalines[$iiline];
        ### do not allow blank in simulation name (so number of blank-delimited fields in output line always known)
        if ($datalines[$iiline] =~ m|^ *SIMULATION_NAME * = * [\"\'] *([^\"\']*)[\"\' ]|i) {$SIMULATION_NAME = $1;};
        # Eric - updated file parm names to match logic in get_rasp_optimized_route.PL and latlon2ij.PL
        if ($datalines[$iiline] =~ m|^ *parent_grid_ratio\s*=\s*(.*)\s*$|i) {@RATIO_TO_PARENT = split(/ *,/, $1);}
        if ($datalines[$iiline] =~ m|^ *i_parent_start\s*=\s*(.*)\s*$|i) {@DOMAIN_ORIGIN_LLI = split(/ *,/, $1);}
        if ($datalines[$iiline] =~ m|^ *j_parent_start\s*=\s*(.*)\s*$|i) {@DOMAIN_ORIGIN_LLJ = split(/ *,/, $1);}
        if ($datalines[$iiline] =~ m|^ *e_we * = * (.*) *$|i) {@DOMAIN_ORIGIN_URI = split(/ *,/, $1);}
        if ($datalines[$iiline] =~ m|^ *e_sn * = * (.*) *$|i) {@DOMAIN_ORIGIN_URJ = split(/ *,/, $1);}
        if ($datalines[$iiline] =~ m|^ *ref_lat *= *(-*[0-9]+.*[0-9]*),.*$|i) {$MOAD_KNOWN_LAT = $1;}
        if ($datalines[$iiline] =~ m|^ *ref_lon *= *(-*[0-9]+.*[0-9]*),.*$|i) {$MOAD_KNOWN_LON = $1;}
        if ($datalines[$iiline] =~ m|^ *truelat1 *= *(-*[0-9]+.*[0-9]*),.*$|i) {@MOAD_STAND_LATS[0] = $1;}
        if ($datalines[$iiline] =~ m|^ *truelat1 *= *(-*[0-9]+.*[0-9]*),.*$|i) {@MOAD_STAND_LATS[1] = $1;}
        if ($datalines[$iiline] =~ m|^ *stand_lon *= *(-*[0-9]+.*[0-9]*),.*$|i) {$MOAD_STAND_LONS = $1;}
        if ($datalines[$iiline] =~ m|^ *dx * = * ([^, ]*).*$|i) {$MOAD_DELTA_X = $1;}
        if ($datalines[$iiline] =~ m|^ *map_proj * = * ([^, ]*).*$|i) {$MAP_PROJ_NAME = $1;}

    }
    ### do sanity checks
    if (!defined $MOAD_KNOWN_LAT || !defined $MOAD_KNOWN_LON ||
        !defined MOAD_STAND_LATS || !defined $MOAD_STAND_LONS ||
        !defined $MAP_PROJ_NAME) {
        print " MOAD_KNOWN_LAT : $MOAD_KNOWN_LAT \n";
        print " MOAD_KNOWN_LON : $MOAD_KNOWN_LON \n";
        print " MOAD_STAND_LATS : $MOAD_STAND_LATS \n";
        print " MOAD_STAND_LONS : $MOAD_STAND_LONS \n";
        print " MAP_PROJ_NAME : $MAP_PROJ_NAME \n";
        die "ERROR: MISSING DATA in DATAFILE $datafilename ";
    }
    $iigrid = $kgrid - 1;
    if (!defined $RATIO_TO_PARENT[$iigrid] ||
        !defined $DOMAIN_ORIGIN_LLI[$iigrid] || !defined $DOMAIN_ORIGIN_LLJ[$iigrid] ||
        !defined $DOMAIN_ORIGIN_URI[$iigrid] || !defined $DOMAIN_ORIGIN_URJ[$iigrid]) {die "ERROR: MISSING DATA FOR GRID $kgrid in DATAFILE $datafilename ";}
    ### this program only valid for tangent lambert projection
    if ($MOAD_STAND_LATS[0] == $MOAD_STAND_LATS[1] && $MAP_PROJ_NAME =~ m|lambert|i) {$MOAD_STAND_LAT = $MOAD_STAND_LATS[0];}
    else {die "ERROR: PROGRAM ONLY VALID FOR CASE OF TANGENT LAMBERT PROJECTION ";}
    ### set simulation name
    if (!defined $SIMULATION_NAME) {$SIMULATION_NAME = '???';}
    ### TEST GRID DATA overrides above
    #old # RASP PANOCHE GRID
    # XDIM = 43
    # YDIM = 49
    # @RATIO_TO_PARENT = ( 1, 3, 3, );
    # @DOMAIN_ORIGIN_LLI = ( 1, 12, 18 );
    # @DOMAIN_ORIGIN_LLJ = ( 1, 16, 31 );
    # @DOMAIN_ORIGIN_URI = ( 43, 29, 41 );
    # @DOMAIN_ORIGIN_URJ = ( 49, 39, 52 );
    # $MAP_PROJ_NAME = 'lambert'
    # $MOAD_KNOWN_LAT = 36.5 ;
    # $MOAD_KNOWN_LON = -120.7 ;
    # $MOAD_STAND_LAT = 40.0 ;
    # $MOAD_STAND_LONS = -73. ;
    # $MOAD_DELTA_X = 12000. ;
    #unused MOAD_STAND_LATS = 40.0, 40.0
    #unused MOAD_DELTA_Y = 12000.
    #4test:   ### RUC GRID
    #4test:   $NXmassMOAD = 301 ;
    #4test:   $NYmassMOAD = 225 ;
    #4test:   $DX_P       =  20317.63 ;
    #4test:   $LAT_MOAD_CENTER   =  16.2810  ;
    #4test:   $LON_MOAD_CENTER   = -126.1378 ;
    #4test:   $LON_XX_P   = -95.0     ;
    #4test:   $LAT_TAN_P  =  25.0 ;
    ### PUT GRID DATA INTO LOCAL VARIABLES
    $NXmassMOAD = $DOMAIN_ORIGIN_URI[0] - 1;
    $NYmassMOAD = $DOMAIN_ORIGIN_URJ[0] - 1;
    #old $NXmass       = $XDIM -1 ;
    #old $NYmass       = $YDIM -1 ;
    $DX_P = $MOAD_DELTA_X;
    $LAT_MOAD_CENTER = $MOAD_KNOWN_LAT;
    $LON_MOAD_CENTER = $MOAD_KNOWN_LON;
    $LON_XX_P = $MOAD_STAND_LONS;
    $LAT_TAN_P = $MOAD_STAND_LAT;
    ### LOOP OVER ALL INPUT ai,aj
    for ($iindex = 0; $iindex < $#gridpoints; $iindex = $iindex + 2) {
        $ai = $gridpoints[$iindex];
        $aj = $gridpoints[$iindex + 1];

        #printf " %i I,J= %5.5f %5.5f  \n",  $iindex, $ai, $aj;

        ### COMPUTE LAMBERT I,J FOR MOAD
        $aimoad = $ai;
        $ajmoad = $aj;
        ### CONVERT NON-MOAD *MASS* SUBGRID INDEX TO MOAD *MASS* INDEX
        ### note iigrid is one less than kgrid (i.e. param arrays use perl indexing)
        for ($iigrid = ($kgrid - 1); $iigrid >= 1; $iigrid--) {
            if (!defined $RATIO_TO_PARENT[$iigrid] || !defined $DOMAIN_ORIGIN_LLI[$iigrid] || !defined $DOMAIN_ORIGIN_LLJ[$iigrid]) {
                die "ERROR: BAD GRID NUMBER = $kgrid ";
            }
            $aimoad = $DOMAIN_ORIGIN_LLI[$iigrid] - 0.5 + ($aimoad - 0.5) / $RATIO_TO_PARENT[$iigrid];
            $ajmoad = $DOMAIN_ORIGIN_LLJ[$iigrid] - 0.5 + ($ajmoad - 0.5) / $RATIO_TO_PARENT[$iigrid];
            #old=3:1only $aimoad = $DOMAIN_ORIGIN_LLI[$iigrid] + ( $aimoad - 2.0 ) / $RATIO_TO_PARENT[$iigrid]  ;
            #old=3:1only $ajmoad = $DOMAIN_ORIGIN_LLJ[$iigrid] + ( $ajmoad - 2.0 ) / $RATIO_TO_PARENT[$iigrid]  ;
            #4testprint: print "GRID $iigrid =>  RATIO_TO_PARENT= $RATIO_TO_PARENT[$iigrid] \n";
        }

        ### CALC MOAD LAMBERT I,J (non-integer) SHIFTED RELATIVE TO CENTER OF MOAD GRID
        $airelative = $aimoad - 0.5 * ($NXmassMOAD - 1);
        $ajrelative = $ajmoad - 0.5 * ($NYmassMOAD - 1);

        ### CALC LAT,LON FROM LAMBERT I,J (non-integer) RELATIVE TO CENTER OF MOAD GRID
        ($alat, $alon) = &W3FB12($airelative, $ajrelative, $LAT_MOAD_CENTER, $LON_MOAD_CENTER, $DX_P, $LON_XX_P, $LAT_TAN_P);
        ### convert to negative W longitude
        if ($alon > 180.) {$alon = $alon - 360.;}

        #printf " %i I,J= %5.5f %5.5f => Lat,Lon= %7.5f %8.5f \n",  $iindex, $ai, $aj, $alat, $alon;

        push @latlonList, ($alat, $alon );
        ### END OF LOOP OVER ALL INPUT ij
    }
    return @latlonList;

}
# Following required to keep PERL happy
1.

