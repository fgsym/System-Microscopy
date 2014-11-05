#/usr/bin/perl
use MongoDB;
use strict;
use warnings;
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->sym;
    my $data = $db->Datasets;
    my $re = $db->Reagents; 
# inputs:
my $path = "/home/jes/SysMicroscopy/DATAfiles/";
my %datafiles = ("BZH_SH4-mCherry-GFP/Ritzerfeld_BZH_SH4_domain_targeting_primary_screen_data.csv" => "8,9",
				"CGSR_DNA_damage/siRNAlibrary.csv" => "4,5"); # "4,5" - are the column numbers with reagID and seq1
my @all; # all existing in DB AMBN reagents
my $crs =  $re->find({prefix => qr/AMBN/},{extID=>1, seq1=>1});				
my %reags; # hash for reagents for extID => seq1
push(@all,$crs->all);
foreach my $obj (@all) {
	$reags{ $obj->{extID} } = $obj->{seq1};
}
open (LOG, ">/home/jes/Git/Logs/Compare_Reagents_data.log" || "cannot open $!");
foreach my $f (keys %datafiles) {
	my %hash; # new reagents to compare
	my ($p1,$p2) = split(/\,/,$datafiles{$f});
	open (F, $path.$f || "cannot open ".$path.$f.": $!");
	while (<F>) {
		my @arr = split(/\t/,$_);
		$hash{$arr[$p1]} = $arr[$p2] unless $_=~/RNA/;
		print $arr[$p2]."\n" if $arr[$p1] eq "227256";
	}
	close F;
	my %seen;
	map {$seen{$_}++} keys %reags;

	foreach my $r (keys %hash) {
		print LOG "$f: new reagent ID: ".$r."\n" unless ($seen{$r} || $r!~/\S/);
		print LOG "$f: reagent sequence changed for ".$r."\n" if ($seen{$r} && uc($reags{$r}) ne uc($hash{$r}))
	}
}
close LOG;
print "end: ".showtime()."\n";
# => 2343 new reagents from more siRNAlibrary.csv | wc = 2535
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
