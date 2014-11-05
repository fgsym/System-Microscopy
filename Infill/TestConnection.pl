#!/usr/local/bin/perl
# load experiment data /home/jes/SysMicroscopy/DATAfiles/Mitocheck/mitocheck_siRNAs_phenotypes.txt
use MongoDB;
use strict;
use warnings;

my $conn = MongoDB::Connection->new(host => "mongodb://mongodb-oyvm-sym-001.ebi.ac.uk:27017,mongodb-pgvm-sym-001.ebi.ac.uk:27017,mongodb-hxvm-sym-001.ebi.ac.uk:27017",
				username => "usym",password => "i5b4SvmN",db_name=>"sym"
        );
# my $conn = MongoDB::Connection->new("host" => "localhost:27017");
$MongoDB::Cursor::slave_okay = 1;

        my $db = $conn->get_database( 'sym' );
        my $genes = $db->get_collection( 'HMSPNSgenes' );
        my @all = $genes->query({"coord" => "MT"},{"symbol" => 1,"synonyms" => 1, "ensGID" => 1})->all();
        foreach (@all) {
        	print $_->{ensGID}."\n";

        }
# ./live/mongodb-2.4.3/bin/mongorestore -d sym /nfs/ma/home/sym/_dev-live/Symdump/