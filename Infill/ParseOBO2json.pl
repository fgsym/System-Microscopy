#!/usr/bin/perl
use strict;
use MongoDB;
use warnings;
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $onto = $db->get_collection( 'Ontology' );
    my $obo = "../Ontology/CMPO/release/cmpo.obo";
open (OBO, $obo) || die "$obo : $!";
my @arobo;
my $data;
while(<OBO>) {
	$data .= $_ unless $_ =~/^\n/;
	push @arobo, $data if $_ =~/^\n/;
	$data = "" if $_ =~/^\n/;
}
close OBO;

foreach (1..$#arobo) {
	my $term = $arobo[$_];
	my @lines = split(/\n/,$term);
	if ($lines[0] =~/\[Term\]/) {
		my %json;
		my @syns;
		my @is_a;
		foreach my $i (@lines) {
			if ($i =~/\:/) {
				my ($key,$val) = split(/\: /,$i);
				$val =~s/(\S+)(\".*?$)/$1/gsm;					
				$val =~s/(\"|\[|\])//gsm;				
				if ($key eq "id" || $key eq "name" || $key eq "def") {
					$json{"Ont".uc($key)} = $val;
				}
				if ($key eq "synonym") {
					my %v = (OntAlias=>$val);
					push @syns, \%v;
				}
				if  ($key eq "is_a") {
					my ($id,$name) = split(/ \! /,$val);
					my %h = (OntID=>$id,OntNAME=>$name);
					push @is_a, \%h;
				}
			}	
		}
		$onto->insert({%json, synonyms => \@syns, is_a=>\@is_a});
	}
}

print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}

