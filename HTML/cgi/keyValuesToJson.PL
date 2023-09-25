#! /usr/bin/perl -w
use warnings FATAL => 'all';
sub keyValuesToJson {
    my (@keyNames, @values);
    @keyNames = @{$_[0]};
    @values = @{$_[1]};
    #print " keyNames = @keyNames\n";
    #print " values = @values\n";
    if ($#keyNames != $#values) {
        print "Unequal number of key value pairs. Number keys: $#keyNames, Number values: $#values \n";
        return '{"error": "Unequal number of key value pairs"}';
    }
    my $jsonString = "";

    $jsonString = $jsonString . "{";
    for (my $i = 0; $i <= $#values; $i++) {
        # print "keyNames[$i] : $keyNames[$i] , values[$i] : $values[$i] \n";
        $jsonString = $jsonString . "\"$keyNames[$i]\" : \"$values[$i]\"";
        if ($i != $#keyNames) {
            $jsonString = $jsonString . ",";
        }
    }
    $jsonString = $jsonString . "}";
    return $jsonString;
}

# Following required to keep PERL happy
1.