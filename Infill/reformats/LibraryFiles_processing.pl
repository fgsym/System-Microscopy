#!/usr/bin/perl

use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $re = $db->get_collection( 'Reagents' );
	my $genes = $db->get_collection( 'HMSPNSgenes' );  

# files: name=>column to parse
my %files = ("../infill-load-data/Phagokinetic/libraries/Human_Adhesome.csv"=>"3,4,9","../infill-load-data/Phagokinetic/libraries/Human_Phosphatase.csv"=>"2,3,8");
# M-003000-03     D-003000-05     GACAAGGACGGGCACAUUA     Human_Adhesome

# my %files = ("../infill-load-data/Phagokinetic/libraries/Human_Protein_Kinase.csv"=>"2,1000,6");
# Plate 10        F11     M-005398-04     ZAP70   7,535   NM_001079       GACGACAGCUACUACACUG , GCAAGAAGCAGAUCGACGU , AGGCAGACACGGAAGAGAU , GCGAUAACCUCCUCAUAGC

my $output = "../infill-load-data/Phagokinetic/libraries/Processed.csv";
my $fasta = "../infill-load-data/Phagokinetic/libraries/Dharmacon.fa";

my %outreags;
open(OUT, ">$output" || "can't open $output! $!");

foreach my $f (keys %files) {
	my ($libID,$mime) = split(/\./, (reverse split (/\//,$f))[0] );
	open(LF, $f || "can't open $f! $!");
	my @columns = split(/\,/,$files{$f});
	while (<LF>) {
		$_ =~s/\n//gsm;
		if ($_ =~/M-/ || $_ =~/D-/) {
			my @fields = split(/\t/,$_);
			my $probeID = $fields[$columns[0]];
			my $pID =  $columns[1] < 1000 ? $fields[$columns[1]] : 0;
			my $seq = $columns[1] < 1000 ? $fields[$columns[2]] : $fields[$columns[2]];			
			$outreags{$probeID} .= "$pID:$seq,";
			print OUT "$probeID\t$pID\t$seq\t$libID\n";
		}	
	}
	close LF
}
close OUT;
print showtime().": ".scalar (keys %outreags)." reagents loaded from libraries\n";
map { chop $outreags{$_} } keys %outreags;
my $gcrs =  $re->find({aligner=>"bowtie","prefix" => "DHARM"},{rgID=>1, probeID=>1, seq_array=>1});
my @all;
my %reags; # hash for reagents for extID => seq2
push(@all,$gcrs->all);
#map { $reags{ $_->{probeID} } = \@{$_->{seq_array}} if scalar @{$_->{seq_array}} > 0 } @all;
map { $reags{ $_->{probeID} } = $_->{rgID} } @all;
print showtime().": ".scalar (keys %reags)." reagents read from Reagents\n";

open(LOG, ">../infill-logs/$0.log" || "can't open log $!");
open(FA, ">$fasta" || "can't open $!");
foreach my $probeID (reverse sort keys %outreags) {
	print LOG "$probeID: not found in DB :( \n" unless $reags{$probeID};
	unless ($reags{$probeID}) {
		foreach (split(/\,/,$outreags{$probeID})) {
			my ($pID,$seq) = split(/\:/,$_);
			$seq =~s/U/T/gsm;
			print FA ">$probeID"."::$pID\n$seq\n";
		}
	}	
#	print LOG "$probeID: we have it in DB :: $reags{$probeID} ! \n" if $reags{$probeID};
}
close FA;
close LOG;
print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
