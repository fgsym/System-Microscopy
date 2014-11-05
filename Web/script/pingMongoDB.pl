#!/usr/local/bin/perl

use strict;
use warnings;
#use lib '/nfs/public/rw/homes/fg_sym/live/perl-libs/';
use MongoDB;

        my $log = "$0.log";
        my $conn;
        eval {
                $conn = MongoDB::Connection->new(host => "mongodb://mongodb-hxvm-sym-001:27017,mongodb-oyvm-sym-001:27017,mongodb-pgvm-sym-001:27017",
                $conn = MongoDB::Connection->new(host => "mongodb-hxvm-sym-001:27017",
#                 $conn = MongoDB::Connection->new(host => "localhost:27017",       
                                username => "usym",
                                password => "i5b4SvmN",
                                db_name=>"sym"
#                                query_timeout => 10000
#                                find_master => 1
                );
        };
        unless ($conn) {
                #open (LOG, ">>$log" || $!);
                print showtime()." >> something wrong with the MongoDB connection\n";
                #close LOG;
                #`hypnotoad -s sym`;
                #sleep(10);
                #`hypnotoad sym`;
                exit;
        }
        my $db = $conn->get_database( 'sym' );
        my $genes = $db->get_collection( 'HMSPNSgenes' );
        my @all = $genes->query({"coord" => "MT"},{"symbol" => 1,"synonyms" => 1, "ensGID" => 1})->all();
##############################################################
sub showtime {
        my @arr=localtime();
        $arr[5]+=1900;$arr[4]++;$#arr=5;
        my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
        return "$year-$month-$day $hour:$min:$sec";
}
