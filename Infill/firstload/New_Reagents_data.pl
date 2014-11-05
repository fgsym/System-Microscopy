#!/usr/bin/perl
use MongoDB;
use strict;
use warnings;
my $daytime = showtime();
print "start: ".$daytime."\n";
my ($date,$t) = split(/\s/,$daytime);
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->sym;
    my $re = $db->Reagents; 
# inputs:
my $path = "/home/jes/SysMicroscopy/DATAfiles/";
my %datafiles = ("BZH_SH4-mCherry-GFP/Ritzerfeld_BZH_SH4_domain_targeting_primary_screen_data.csv" => "8,9,10",
		"BZH_SH4-mCherry-GFP/Ritzerfeld_BZH_SH4_domain_targeting_validation_screen_data.csv" => "8,9,10",
				"CGSR_DNA_damage/siRNAlibrary.csv" => "4,5,6"); # "4,5,6" - are the column numbers with probeID and seq1, seq2
my $fa = "/home/jes/SysMicroscopy/DATAfiles/".$date."_oligo_seqT.fa";
my @all; # all existing in DB AMBN reagents
my $crs =  $re->find({prefix => qr/AMBN/},{probeID=>1, seq2=>1});				
my %reags; # hash for reagents for extID => seq2
push(@all,$crs->all);
foreach my $obj (@all) {
	$reags{ $obj->{probeID} } = $obj->{seq2};
}
open (LOG, ">/home/jes/Git/infill-logs/Compare_Reagents_data.log" || "cannot open $!");
open (FA, ">$fa" || "cannot open ".$fa.": $!");
foreach my $f (keys %datafiles) {
	my %hash; # new reagents to compare
	my ($p1,$p2,$p3) = split(/\,/,$datafiles{$f});
	open (F, $path.$f || "cannot open ".$path.$f.": $!");
	while (<F>) {
		my @arr = split(/\t/,$_);
		map {$_=~s/\n//} @arr;
		$hash{$arr[$p1]} = $arr[$p3] unless ($_=~/siRNA/ || $_=~/scrambl/);
		print $arr[$p3]."\n" if $arr[$p1] eq "227256";
	}
	close F;
	my %seen;
	map {$seen{$_}++} keys %reags;

	foreach my $r (keys %hash) {
		my $seq = uc($hash{$r});
		unless ($seen{$r} || $r!~/\S/) {
			 print LOG "$f: new reagent ID: ".$r."\n";
			 $seq =~s/U/T/gsm;
			 print FA ">".$r."\n".$seq."\n";	    
		}
		print LOG "$f: reagent sequence changed for ".$r."\n" if ($seen{$r} && uc($reags{$r}) ne $seq);
	}
}
close LOG;
close FA;
print "end: ".showtime()."\n";
# => 2343 new reagents from more siRNAlibrary.csv | wc = 2535
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
