#!/usr/local/bin/perl
use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
use MongoDB::GridFS;
use MongoDB::GridFS::File;

    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' );

my $grid = $db->get_gridfs;
#my $datafile="/nfs/ma/home/sym/_dev-live/app/RNAi-template.csv";
my $datafile="/home/jes/Git/infill-load-data/_idf/RNAi-template.csv";
my $fh = IO::File->new($datafile, "r");    
my $md5sum = (split(/\s/,`md5sum /home/jes/Git/infill-load-data/_idf/RNAi-template.csv`))[0];
print $md5sum.": md5sum of this template\n";
$grid->insert($fh, {name=>"RNAi",md5sum=>$md5sum, type=>"template"});
print "check file insert:\n";
printFILE($md5sum);
# print "\n\ncheck removal:\n";
# $grid->remove({type=>"template"});
# printFILE($md5sum);


sub printFILE {
    my $md5sum = shift;
    my $file = $grid->find_one({md5sum => $md5sum});
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
