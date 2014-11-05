#!/usr/local/bin/perl
# reformating in accord /home/jes/Git/Infill/formats/Loader-format_string.tsv

use strict;
print "start: ".showtime()."\n";
my $input = "/home/jes/Git/infill-load-data/JCB-metazoan-actinome/seqs_Dharm_JCB_201103168_TableS3.csv";
my $output = "/home/jes/Git/infill-load-data/JCB-metazoan-actinome/libraries/Dharmacon.fa";

# input format: ACTG1   ACTG1-01        GAGAAGAUGACUCAGAUUA     NM_001614       D-005265-01
open (IN, $input || "can't open $input: $!");
open (OUT, ">$output" || "can't open $output: $!");
my %seqs;
my $pID;
my %cnts; # if input is unclean (with repeats)
my $n;
while(<IN>) {
	$_ =~s/\n//gsm;
	if ($_!~/siRNA/) {
		my ($g, $g0, $seq, $id, $pID) = split(/\t/,$_);	
		print OUT ">$pID\n$seq\n" unless $cnts{$pID}++ == 1;
		$n++;
	} 
}
close IN;
close OUT;

print "end: ".showtime().": $n reagents to FASTA $output\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}