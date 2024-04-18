#############################################################################
### Files object definition
#############################################################################

package Files;

use Moose;
use Set::Scalar;
use Net::FTP;
use Try::Tiny;

extends 'ModelDef';

my $fnfDelay = 5; # minutes delay if no files found

# Local directory
has 'dir' => (
is          => 'ro',
isa         => 'Str',
required    => '1,'
);

# the list of files
has 'fileList' => (
is          => 'rw',
isa         => 'Set::Scalar',
default     => sub { new Set::Scalar; },
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $self = shift;

    # Build new arg list from supplied
    my @args;
    while (my $arg = shift)
    {
        if ($arg eq "model")
        {
            my $list = shift;
            push @args, (%$list);
        } else {
            push @args, $arg, shift;
        }
    }
    return $self->$orig(@args);
};

# add files to list
sub addFiles {
    my $self = shift;
    $self->fileList->insert ( @_ );
}

# clean from previous run(s)
sub Clean {
    my $self = shift;
    my $baseDir = shift;
    my $VERBOSE = shift;
    
    # Remove the old directory
    my $targetDir = "$baseDir/" . $self->dir;
    qx|rm -f $targetDir/* $targetDir/.lock 2> /dev/null|;
    print "-- Cleaned $targetDir\n" if ($VERBOSE && $? == 0);
}

# Try to download the files
sub downloadFiles {
    my $self = shift;
    my $baseDir = shift;
    my $VERBOSE = shift;
    
    return undef if $self->fileList->is_empty;
    my $delay = $self->expectDelay();
    return $delay if $delay > 0;
    
    # Make sure target directory is available
    my $targetDir = "$baseDir/" . $self->dir;
    `mkdir -p $targetDir 2>/dev/null`;

    my $ret = tryHttps($self, $baseDir, $targetDir, $VERBOSE);
    if ($ret < 0)
    {
	$ret = tryFtp($self, $baseDir, $targetDir, $VERBOSE);
    }

    if ($ret < 0)
    {
	# flush the queue on fatal
	for my $file ($self->fileList->members)
	{
	    $self->fileList->delete ($file);
	}
	return undef;
    }
    return $ret;
}

# Try using FTP
# Return: -1 if fatal error, otherwise delay time
sub tryFtp {
    my $self = shift;
    my $baseDir = shift;
    my $targetDir = shift;
    my $VERBOSE = shift;
    
    # Create connection
    my $ftp = Net::FTP->new($self->ftpSite, (Debug => $VERBOSE > 1, Timeout => 600));
    if (!$ftp)
    {
        print "Cannot connect to ".$self->ftpSite.": $@\n";
        return -1;
    }
    if (!$ftp->login("anonymous", $::ADMIN_EMAIL_ADDRESS))
    {
        print "Cannot login ", $ftp->message, "\n";
        return -1;
    }
    if (!$ftp->cwd($self->ftpDirectory))
    {
        print $self->ftpDirectory, ": ", $ftp->message;
        return $fnfDelay;
    }
    $ftp->binary();
    
    my $cnt = 0;
    for my $file ( sort $self->fileList->members )
    {
        my $where = undef;
        try {
            $where = $ftp->get($file, "$targetDir/$file");
        } catch {
            # warn "caught failure:\n$_: $file";
            my $time = `/usr/bin/date +%H:%M:%S`;
            chomp $time;
            print "   $time: Failed to download $file\n";
        };
        if ( $where )
        {
            # Make sure file transferred completely
            my $size = $ftp->size($file);
            if ( -z $where || $size != -s $where )
            {
                print "FTP file length problem - $file\n";
                $where = "";
            }
        }
        if (! $where)
        {
            my $dt = DateTime->now - $self->expectTime;
            my $late = $dt->in_units( 'minutes' );
            die "timeout waiting for " . $self->ftpDirectory if $late > 120;
            print "   Waited $late minutes for $file\n" unless $cnt > 0;
            last;
        }
        my $time = `/usr/bin/date +%H:%M:%S`;
        chomp $time;
        print "   $time: Downloaded $file\n";
        $self->fileList->delete ($file);
        $self->expectTime(DateTime->now);
        $cnt ++;
        return 0 if $cnt >= 5;   # early return if might be able to start a model
    }
    return ($cnt > 0 ? 0 : $fnfDelay);
}

# Try using HTTPS
# Return: -1 if fatal error, otherwise delay time
sub tryHttps {
    my $self = shift;
    my $baseDir = shift;
    my $targetDir = shift;
    my $VERBOSE = shift;

    use LWP::Simple;
    use HTTP::Status;

    my $cnt = 0;
    for my $file ( sort $self->fileList->members )
    {
	my $url = $self->httpSite . "/" . $self->httpDirectory
	 	. "/" . $file;
	my $response = getstore($url, "$targetDir/$file");
	if (is_error($response))
	{
	    print "Error: ", status_message($response), "\n  $url\n";
            last;
	}
        my $time = `/usr/bin/date +%H:%M:%S`;
        chomp $time;
        print "   $time: Downloaded $file\n";
        $self->fileList->delete ($file);
        $self->expectTime(DateTime->now);
        $cnt ++;
        return 0 if $cnt >= 5;   # early return if might be able to start a model
    }
    return ($cnt > 0 ? 0 : $fnfDelay);
}

no Moose;
__PACKAGE__->meta->make_immutable;
