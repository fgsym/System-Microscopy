#!/usr/local/bin/perl
use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
use MongoDB::GridFS;
use MongoDB::GridFS::File;

    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->sym;
    my $data = $db->Datasets;
    my $re = $db->Reagents; 
    
my $grid = $db->get_gridfs;
my $datafile="/home/jes/Git/infill-load-data/_idf/RNAi-template.csv";
my $fh = IO::File->new($datafile, "r");
$grid->insert($fh, {"screenID"=>100000000000,"md5sum"=>"325d1cc600b1df6520b9831a526df1a3"});

printFILE();
#print "\n\n check removal:\n";
# $grid->remove({"screenID"=>100000000000});
# printFILE(100000000000);

sub printFILE {
    my $screenID = shift;
    my $file = $grid->find_one({"md5sum"=>qr/^\S/});
    # my $file = $grid->find_one({"screenID"=>"5"});
    if ($file) {
        my $all = $file->slurp();

        my $n=0;
        foreach (split(/\n/,$all)) {
             print $_."\n"; 
             $n++;
             last if $n>5;
        }
    } else {
        print "no file found\n";
    }   
}
