#############################################################################
### Model Definitions
#############################################################################

package ModelDef;

use strict;
use warnings;
use integer;

use Moose;
use DateTime;

# Model parameters are defined in the following hash. For each model,
#
#  ftpSite - URL for the site holding the files
#  ftpDirectoryProto - prototype for the directory that holds the files.
#    use DateTime->strftime to format.
#  fileNameProto - prototype for the file name.
#    use sprintf(proto, analTime, validTime) to format.
#  analTimes - the times when the model is run.
#    array with last anal time, stride between times
#  validTimes - the time offsets to the valid data.
#    array with last valid time, stride between times
#  availDelay - expected delay from analTime until data is available.
#    DateTime Duration object

my %defs = (
    nam => {
        ftpSite => 'ftp.ncep.noaa.gov',
        ftpDirectoryProto => "pub/data/nccf/com/nam/prod/nam.%Y%m%d",
        fileNameProto => "nam.t%02dz.awip3d%02d.tm00.grib2",
        analTimes => [ 18, 6 ],
        validTimes => [ 84, 3 ],
        availDelay => DateTime::Duration->new(hours => 2, minutes => 00)
    },
    gfs => {
        ftpSite => 'ftp.ncep.noaa.gov',
        ftpDirectoryProto => "pub/data/nccf/com/gfs/prod/gfs.%Y%m%d%H",
        fileNameProto => "gfs.t%02dz.pgrb2full.0p50.f%03d",
        analTimes => [ 18, 6 ],
        validTimes => [ 240, 3 ],
        availDelay => DateTime::Duration->new(hours => 3, minutes => 25)
    },
    rap => {
        ftpSite => 'ftp.ncep.noaa.gov',
        ftpDirectoryProto => "pub/data/nccf/com/rap/prod/rap.%Y%m%d",
        fileNameProto => "rap.t%02dz.awp130bgrbf%02d.grib2",
        analTimes => [ 23, 1 ],
        validTimes => [ 21, 1 ],
        availDelay => DateTime::Duration->new(hours => 1, minutes => 00)
    },
    hrrr => {
        ftpSite => 'ftp.ncep.noaa.gov',
        ftpDirectoryProto => "pub/data/nccf/com/hrrr/prod/hrrr.%Y%m%d/conus",
        fileNameProto => "hrrr.t%02dz.wrfprsf%02d.grib2",
        analTimes => [ 23, 1 ],
        validTimes => [ 18, 1 ],
        availDelay => DateTime::Duration->new(hours => 1, minutes => 00)
    }
);

# model name
has 'modelName' => (
is          => 'ro',
isa         => 'Str',
required    => 1,
);

# ftp site that holds the model results
has 'ftpSite' => (
is          => 'ro',
isa         => 'Str',
lazy        => 1,
builder     => '_buildFtpSite',
);

sub _buildFtpSite { return $defs{$_[0]->modelName}{"ftpSite"}; }

# ftp directory that holds the model results
has 'ftpDirectoryProto' => (
is          => 'ro',
isa         => 'Str',
lazy        => 1,
builder     => '_buildFtpDirectoryProto',
);

# file name prototype
has 'fileNameProto' => (
is          => 'ro',
isa         => 'Str',
lazy        => 1,
builder     => '_buildfileNameProto',
);

# Available analysis times
has 'analTimes' => (
is          => 'ro',
isa         => 'ArrayRef[Int]',
lazy        => 1,
builder     => '_buildAnalTimes',
);

# Valid times after the analysis time
has 'validTimes' => (
is          => 'ro',
isa         => 'ArrayRef[Int]',
lazy        => 1,
builder     => '_buildValidTimes',
);

# Delay from analTime until files start to become available
has 'availDelay' => (
is          => 'ro',
isa         => 'DateTime::Duration',
lazy        => 1,
builder     => '_buildAvailDelay',
);

# Analysis time to process
has 'analTime' => (
is          => 'rw',
isa         => 'DateTime',
lazy        => 1,
default     => \&_defaultAnalTime,
);

# ftp directory
has 'ftpDirectory' => (
is          => 'ro',
isa         => 'Str',
lazy        => 1,
builder     => '_buildFtpDirectory',
);

# Expected time for first file, then time of last file
has 'expectTime' => (
is          => 'rw',
isa         => 'DateTime',
);

sub _buildFtpDirectoryProto { return $defs{$_[0]->modelName}{"ftpDirectoryProto"}; }
sub _buildfileNameProto { return $defs{$_[0]->modelName}{"fileNameProto"}; }
sub _buildAnalTimes { return $defs{$_[0]->modelName}{"analTimes"}; }
sub _buildValidTimes { return $defs{$_[0]->modelName}{"validTimes"}; }
sub _buildAvailDelay { return $defs{$_[0]->modelName}{"availDelay"}; }

sub _buildFtpDirectory {
    my $self = shift;
    return $self->analTime->strftime($self->ftpDirectoryProto);
}

# Default analysis time is now
sub _defaultAnalTime { return $_[0]->_fixAnalTime (DateTime->now); }

# Round analysis time down to valid time
around 'analTime' => sub {
    my $orig = shift;
    my $self = shift;
    
    return $self->$orig() unless @_;
    my $t = shift -> clone;
    return $self->$orig($self->_fixAnalTime ($t));
};

sub _fixAnalTime {
    my $self = shift;
    my $t = shift;
    my $times = $self->analTimes;
    # Round hour down to preceeding anal time
    my $newHour = ($t->hour / $$times[1]) * $$times[1];
    $t -> set_hour( $newHour ) -> set_minute( 0 ) -> set_second ( 0 );
    $self->expectTime($t + $self->availDelay);
    return $t;
}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    
    if ( @_ == 1 && !ref $_[0] ) {
        $defs{$_[0]}->modelName = $_[0];
        return $class->$orig( $defs{$_[0]} );
    }
    else {
        return $class->$orig(@_);
    }
};

# Get expeted duration from now
sub expectDelay {
    my $self = shift;
    my $delay = $self->expectTime - DateTime->now();
    return 0 if $delay->is_negative();
    return $delay->in_units( 'minutes' );
}

no Moose;
__PACKAGE__->meta->make_immutable;
