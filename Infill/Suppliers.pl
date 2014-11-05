#!/usr/local/bin/perl
# load experiment data /home/jes/SysMicroscopy/DATAfiles/Mitocheck/mitocheck_siRNAs_phenotypes.txt
use MongoDB;
use strict;
use warnings;
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' );
# loading Suppliers
    my $sup = $db->get_collection( 'Suppliers' ) ;
    $sup->drop;
# description: the same Suppliers may provide different type of oligos 
# Ambion :
    $sup->insert( { 
	"SupID" => 1,
	"SupName" => "Ambion",
	"Prefix" => "AMBN",
	"Libraries" => {1=>"Silencer Pre-designed siRNA",2=>"Silencer Select Pre-designed siRNA"}
      } );
# Qiagen :
    $sup->insert( { 
	"SupID" => 2,
	"SupName" => "Qiagen",
	"Prefix" => "QIAGN",
	"Libraries" => {1=>"siRNA duplexes designed by QIAGEN"}
      } );
# Dharmacon :        
    $sup->insert( { 
	"SupID" => 3,
	"SupName" => "Dharmacon",
	"Prefix" => "DHARM",
	"Libraries" => {1=>"Gene Silencers: 4 siRNAs per well"}
      } );
# Drosophila :
    $sup->insert( { 
	"SupID" => 4,
	"SupName" => "Drosophila RNAi Screening Center",
	"Prefix" => "DRSC",
	"Libraries" => {1=>"DRSC 2.0"}
      } );    
      print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}