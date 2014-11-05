#!/usr/bin/perl

use strict;
use warnings;
use MongoDB;
my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
my $db = $conn->get_database( 'sym' );
my $re = $db->get_collection( 'Reagents' );

my $log = "$0.log";
#libs: probeID => Accession
my %libs = ("../infill-load-data/JCB-metazoan-actinome/seqs_Dharm_JCB_201103168_TableS3.csv"=>"0,4"); # 0,4 = symbol, D-ID

#files: 1=Accession to change for probeID
my $input  = "../infill-load-data/JCB-metazoan-actinome/scores_JCB_201103168_TableS4.csv";
my $output = "../infill-load-data/JCB-metazoan-actinome/scores_reformated_TableS4.csv";


my %reags;
my %chcks;
my $crs = $re->query({prefix=>"DHARM"},{probeID=>1,rgID=>1,seq_array=>1});
open (LOG, ">$log" || "$!");
	while (my $obj = $crs->next) {
		my @pids;
		foreach (@{$obj->{seq_array} }) {
			push @pids,$_->{pID} if $_->{pID} =~/D\-/;
		}
		if (scalar@pids >0) {
	        $reags{ join ("__",sort @pids ) } = $obj->{probeID};
    	    print LOG join (" :: ",sort @pids )." >> ".$obj->{probeID}." << duplicates \n" if $chcks{ join ("__",sort @pids ) }++ > 1;
    	}    
	}	

print showtime().": ".scalar (keys %reags)." Dharmacon reagents read from Reagents\n";
my %g2dids;
	open (LF, "../infill-load-data/JCB-metazoan-actinome/seqs_Dharm_JCB_201103168_TableS3.csv" || "$!");
	while(<LF>) {
		$_ =~s/\n//gsm;	
		my @fields = split(/\t/,$_);
		push @{ $g2dids { $fields[0] } }, $fields[4] if ($fields[4] && $fields[4] =~/D-/ && $fields[0]);
	}
	close LF;

my %g2pids;
foreach my $g (keys %g2dids) {
	$g2pids{$g} = join ("__",@{ $g2dids { $g} });
}

	open (NSF, ">$output" || "$!");
	open (SF, $input || "$!");
	print NSF "siRNA\tIncreased level of actin\tIncreased peripheral actin\tIncreased cytoplasmic actin\tIncreased actin over nucleus\tIncreased number of filopodia\tIncreased width of lamellae\tDecreased level of actin\tDecreased number of filopodia\tDecreased width of lamellae\tNuclear actin ring\tIncreased number of actin puncta or dots\tIncreased number of actin stress fibres\tIncreased number of transverse actin stress fibres\tIncreased number of cortical actin stress fibres\tIncreased number of zigzag actin stress fibres\tDisorganised peripheral actin\tIncreased cell size\tDecreased cell size\tVariable cell size\tCell shape round or non-adherent\tCell shape processes or spiky or stretchy\tCell shape bipolar or elongated\tCell shape geometric\tCell shape variable\tDecreased cell number\tIncreased cell number\tIncreased number of multinucleate cells\tIncreased DNA area\tDecreased DNA area\tMisshapen DNA\tApoptotic DNA\tIncreased mitotic index\tMicrotubules disorganised\tMicrotubule processes\tMicrotubule clumps\tMicrotubule nuclear ring\tMicrotubule nuclear bracket\tIncreased level of microtubules\tLoss of cell monolayer\tMotile lamellae";
	while(<SF>) {
		unless ($_ =~/siRNA/) {
			$_ =~s/\n//gsm;	
			my @fields = split(/\t/,$_);
			my @nf;
			for (@fields[2 .. $#fields]) {
				push @nf, $_;	
			}
			my $dids = $g2pids{ $fields[0] };
			if ( $dids =~/D-/ && $reags{ $dids } && $fields[0]) {
				my $probeID = $reags{ $dids };
				print NSF $probeID."\t".join("\t",@nf)."\n";
			} else {
				print LOG "something wrong with $dids & $fields[0]! \n"	
			}
		}	
	}
	close SF;
	close NSF;	
close LOG;	
	##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}

