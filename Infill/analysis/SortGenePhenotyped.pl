#!/usr/local/bin/perl
use MongoDB;
use MongoDB::OID;
use strict;
# use warnings;

my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
my $db   = $conn->get_database( 'sym' );
my $std = $db->get_collection( 'Studies' );
my $gc = $db->get_collection( 'HMSPNSgenes' );
my $crs = $gc->query({"phenolist.goodmatch"=>1});
my $logfile = "./GenesSorted.tsv";

my @gphes;
push(@gphes,$crs->all);
open(LOG,">$logfile" || "$!");
print LOG "mapped with phenotypes\tensGID\tphenotypes count\n";
my %statgenes;
foreach my $obj (@gphes) {
	my %count;
	my $phenotypes;
	foreach (@{$obj->{phenolist}}) {
		if ($_->{goodmatch} == 1) {
			$count{ $obj->{ensGIG} }++;
			$phenotypes += scalar @{$_->{phenodata}};
		}
	}
	$statgenes{ $count{ $obj->{ensGIG} }."__".$obj->{ensGIG} } = $phenotypes;
}
foreach (sort keys %statgenes) {
	my ($count, $gene) = split(/__/,$_);
	print LOG "$count\t$gene\t$statgenes{$_}\n";
}
close LOG;


