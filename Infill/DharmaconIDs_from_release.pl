#!/usr/bin/perl

use MongoDB;
use MongoDB::OID;
use strict;
use warnings;

print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $re = $db->get_collection( 'Reagents' );

open (OUT, ">$0.tab");
my $gcrs =  $re->find({"prefix" => "DHARM","seq_array.pID"=>qr/D/},{rgID=>1, probeID=>1, seq_array=>1});
my @all;
my %reags; # hash for reagents for extID => seq2
push(@all,$gcrs->all);
map { $reags{ $_->{rgID} } = \@{$_->{seq_array}} if @{$_->{seq_array}} > 0  } @all;
print showtime().": ".scalar (keys %reags)." reagents read from Reagents\n";  

foreach my $rgID (sort keys %reags) {
	print OUT $rgID."\t";
	my @seq_array = @{ $reags{ $rgID } };
	my $str;
	my %seen;
	foreach my $r (@seq_array) {
		$str .= $r->{pID}."," if $seen{$r->{pID}}++ == 1;
	}
	chop $str;
	print OUT "$str\n";
}
close OUT;
`mv $0.tab ../infill-load-data/`;
print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
