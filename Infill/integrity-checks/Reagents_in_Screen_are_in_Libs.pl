#!/usr/bin/perl
use strict;
use warnings;
use MongoDB;
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $re = $db->get_collection( 'Reagents' );

my $gcrs =  $re->find({aligner=>"bowtie","prefix" => "DHARM"},{rgID=>1, probeID=>1});
my @all;
my %reags; # hash for reagents for extID => seq2
push(@all,$gcrs->all);
#map { $reags{ $_->{probeID} } = \@{$_->{seq_array}} if scalar @{$_->{seq_array}} > 0 } @all;
map { $reags{ $_->{probeID} } = $_ } @all;
print showtime().": ".scalar (keys %reags)." reagents read from Reagents\n";

my $log = "/home/jes/Git/infill-logs/Phagokinetic_validation_screen-r.log";
my $screen = "/home/jes/Git/infill-load-data/Phagokinetic/validation_screen-r.csv";
my $v;
open (LOG, ">$log" || warn "$!"); 
	open (SCR, $screen || warn "$!"); 
	while (<SCR>) {
		$v++;   
		$_ =~s/\n//gsm;
		my @data = split(/\t/,$_);
		if ($_ =~/^M/) {
			my $m_id = $data[0];
			my $ph = ($data[18] && $data[18] =~/\w+/) ? $data[18] : "No phenotype observed";
			print LOG $m_id." not found in DB! and it has $ph \n" unless $reags{ $m_id };
		} else {
			warn "the line $v is out of the format";	
		}
	}
	close SCR;
close LOG;
print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}    