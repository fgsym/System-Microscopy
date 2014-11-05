#!/usr/bin/perl

use strict;
use warnings;

#libs: probeID => Accession
my %libs = ("../infill-load-data/Phagokinetic/libraries/Human_Adhesome.csv"=>"3,7",
			"../infill-load-data/Phagokinetic/libraries/Human_Phosphatase.csv"=>"2,6",
			"../infill-load-data/Phagokinetic/libraries/Human_Protein_Kinase.csv"=>"2,5");

#files: 1=Accession to change for probeID
my %files = ("../infill-load-data/Phagokinetic/primary_screen.csv"=>"1", "../infill-load-data/Phagokinetic/validation_screen.csv"=>"1");

# accession to probes hash:
my %ac2pr;
foreach my $f (keys %libs) {
	my @columns = split(/\,/,$libs{$f});	
	open (LF, $f || "can't open $f: $!");
	while(<LF>) {
		$_ =~s/\n//gsm;	
		my @fields = split(/\t/,$_);
		$ac2pr { $fields[$columns[1]] } = $fields[$columns[0]] if ($fields[$columns[0]] && $fields[$columns[0]] =~/M-/);
	}
	close LF;
}

foreach my $s (keys %files) {
	my $num = $files{$s}; # column to change	
	open (SF, $s || "can't open $s: $!");
	my ($name,$mime) = split(/\./, (reverse split (/\//,$s))[0] );	
	open (NSF, ">$name"."-r.csv" || "$!");
	if ($s=~/primary/) {
		print NSF "ProbeID\tGene Symbol\tTArea\tNArea\tMinorAxis\tMajorAxis\tAxialRatio\tPerimeter\tSolidity\tRoughness\tTArea\tNArea\tMinorAxis\tMajorAxis\tAxialRatio\tPerimeter\tSolidity\tRoughness\tPhenotype\n";
	} elsif ($s=~/validation/) {
		print NSF "ProbeID\tGene Symbol\tPhenotype\tValidation Score Deconvolution Screen\tValidation (movie)\n";
	}		
	while(<SF>) {
		$_ =~s/\n//gsm;	
		my @fields = split(/\t/,$_);
		my $probeID = $ac2pr { $fields[ $num] };
		print $fields[ $num]."\n" unless $probeID; # NM_173655 !
		if ($probeID=~/M-/) {
			print NSF $probeID;
			foreach my $n (2 .. $#fields) {
				print NSF "\t".$fields[$n];
			}
			print NSF "\n";
		}
	}
	close SF;
	close NSF;	
}