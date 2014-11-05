#!/usr/bin/perl
use strict;
use warnings;
use MongoDB;
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $re = $db->get_collection( 'Reagents' );
    my $workdir = "/home/jes/Git/infill-load-data/JCB-metazoan-actinome/libraries/";
	my @m_ids = ($workdir."M-IDs_from_Actin_Pools.csv",$workdir."M-IDs_from_Rho_Pools.csv");
	my @d_ids = ($workdir."D-IDs_from_Actin_ind.csv",$workdir."D-IDs_from_Rho_ind.csv");
	my $cfa = $workdir."DHARM.fa";
#Plate 1 A03     M-007290-00     ABI1    10006   NM_005470
#Plate 1 F08     M-009302-00     CENTD1  116984  NM_015230
#Plate 1 E09     D-008243-03     BAF53A  86      NM_004301       GAAGUUGGAGCCCUUGUUU
#Plate 1 E10     D-019080-04     ARHGAP22        58504   NM_021226       GGGAUUUAUUUCUCUACAA
my %m_ids;
my %d_ids;
foreach my $f (@m_ids) {
	open (mIDs, $f || "cannot open ".$f.": $!");
		while (<mIDs>) {
			$_ =~s/\n//gsm;
			my @arr = split(/\t/,$_);
			$m_ids{$arr[5]} = $arr[2] if $_=~/M\-/;
		}
	close mIDs;
}
foreach my $f (@d_ids) {
	open (dIDs, $f || "cannot open ".$f.": $!");
		while (<dIDs>) {
			$_ =~s/\n//gsm;
			my @arr = split(/\t/,$_);
			if (defined $arr[5] && $_=~/D\-/ && $arr[5] =~/\w+/) {			
				$d_ids{$arr[5]} .= $arr[2].":".$arr[6].",";
			}	
		}
	close dIDs;
}
my $n;
open (FA, ">$cfa" || "cannot open ".$cfa.": $!");
foreach my $id (keys %m_ids) {
	my @seq_array = split(/\,/,$d_ids{$id});
	foreach my $s (@seq_array) {
		if ($s=~/\:/) {
			my ($d,$seq) = split(/\:/,$s);
			print FA ">".$m_ids{$id}."::".$d."\n".$seq."\n" if $seq;
			$n++;
		}	
	}
}
close FA;
print "end: ".showtime()." ".$n." Dharmacon reagents are written to FASTA $cfa\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}

