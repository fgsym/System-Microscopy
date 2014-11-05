#!/usr/bin/perl
use strict;
use warnings;
use MongoDB;
# create load dir if needed:
my $loaddir = "/home/jes/Git/infill-load-data";

# uncomment the corresponding reagents downloading! — for $fa, $cfa, $drfa
print "start: ".showtime()."\n";
	my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
	my $db = $conn->get_database( 'sym' );
    my $re = $db->get_collection( 'Reagents' ); 
my ($date,$l) = split(/\s/, showtime());

# we have to download these 3 reagent types:
my $fa = $loaddir."/Reagents_$date.fa";
my $cfa = $loaddir."/CompoundReagents_$date.fa";
my $drfa = $loaddir."/Droso_$date.fa";

my @all; # all existing in DB AMBN reagents
my @ar_all; # all existing in DB compound reagents
my %reags; # hash for reagents for extID => seq2
my %ar_reags; # hash for reagents for extID => seq_array
my $n;

# BELOW uncomment the action for $fa or for $cfa !!
#
#	TODO: downoad reagents by prefixes (and genome): db.runCommand({ distinct:"Reagents",key:"prefix"})
#
# for $fa :
# my $crs =  $re->find({seq2=>qr/\S/},{rgID=>1, seq2=>1});
# push(@all,$crs->all);
# map { $reags{ $_->{rgID} } = $_->{seq2} } @all;
# warn scalar (keys %reags)." non-compound reagents are in DB (for Human Genome)";
# open (FA, ">$fa" || "cannot open ".$fa.": $!");
# foreach my $rgID (keys %reags) {
# 	print FA ">".$rgID."\n".$reags{$rgID}."\n" if $reags{$rgID};
# 	$n++;
# } 
# close FA;

#for $drfa :
# my $crs =  $re->find({prefix=>"DRSC", genome=>"FruitFLY"},{rgID=>1, seq1=>1,probeID=>1});
# push(@all,$crs->all);
# my %probes;
# map { $reags{ $_->{rgID} } = $_->{seq1} } @all;
# map { $probes{ $_->{rgID} } = $_->{probeID} } @all;
# warn scalar (keys %reags)." non-compound reagents are in DB (for FruitFLY)";
# open (FA, ">$drfa" || "cannot open ".$fa.": $!");
# foreach my $rgID (keys %reags) {
# 	print FA ">".$rgID.":".$probes{$rgID}."\n".$reags{$rgID}."\n" if $reags{$rgID};
# 	$n++;
# } 
# close FA;
 
# for $cfa :
my $ar_crs =  $re->find({prefix=>"DHARM","seq_array.pID"=>qr/\S/},{rgID=>1, seq_array=>1});
push(@ar_all,$ar_crs->all);
map { $ar_reags{ $_->{rgID} } = \@{$_->{seq_array}} } @ar_all;
warn scalar (keys %ar_reags)." compound reagents are in DB";

open (FA, ">$cfa" || "cannot open ".$cfa.": $!");
foreach my $rgID (keys %ar_reags) {
	my @seq_array = @{$ar_reags{$rgID}};
	if (scalar @seq_array > 0) {
		foreach my $s (@seq_array) {
			# warn $s->{pID};
			my @tagins = @{ $s->{tagin} } if $s->{tagin};
			my $seq;
			map {$seq = $_->{sbjct}} $tagins[0];
			print FA ">".$rgID."::".$s->{pID}."\n".$seq."\n" if $seq;
		}
	}
	$n++;	
}
close FA;

print "Reagents have read: $n in ".showtime()."\n";

##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}	   