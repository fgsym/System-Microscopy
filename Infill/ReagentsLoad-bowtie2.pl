#!/usr/local/bin/perl
# load reagents data after mapping from SAM format files 

use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
my $log = "$0.log";
my $fasta = "/home/jes/Git/infill-load-data/Droso_2014-10-27.fa";
# sed '/@SQ\tSN:/d' Drosophila-bowtie2.map > Drosophila-bowtie2-cleanup.map
# my $bowtie2 = "/home/jes/Git/infill-load-data/Drosophila-bowtie2-77.map";
my $bowtie2 = "/home/jes/Git/infill-load-data/Drosophila_remap_to_release_77.map";

my $prfx = "DRSC";

print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' );
    my $rgnts = $db->get_collection( 'Reagents' );  
#######################    
    $rgnts->remove({aligner=>"bowtie2"});
#######################      
open (FA, $fasta || "can't open $fasta: $!");
my %seqs;
my ($rgID,$probeID);
my %cnts; # if fasta is unclean (with repeats)
my %ndIDs; # because we have more than 1 seq per ID!
# if update (probeID <=> rgID) otherwise see $rgID commented lines below
my %IDs;
while(<FA>) {
	$_ =~s/\n//gsm;	
	if ($_=~/^\>/) {
		my $pID = $_;
		$pID =~s/\>//gsm;
		($rgID,$probeID) = split(/\:/,$pID);
		$ndIDs{$rgID}++;
		warn $ndIDs{$rgID}." :: $rgID >> 2nd" if ($ndIDs{$rgID} >= 2);
		$IDs{ $rgID } = $probeID;
		# $cnts{$pID."-".$ndIDs{$pID}}++;
	} else {
		$seqs{$rgID} .= $_ ;#if $cnts{$pID."-".$ndIDs{$pID}} == 1;
		# warn $seqs{$pID."-".$ndIDs{$pID}} ." >> ".$ndIDs{$pID} if $pID eq "DRSC07278";		
	};
}
close FA;

print showtime()." ".scalar keys %seqs, " sequences in FA file\n";
# warn $seqs{"DRSC00267"};
# warn $seqs{"DRSC08471"};
open (LOG, ">$log" || "can't open $log: $!");
open (BO, $bowtie2 || "can't open $bowtie2: $!");
# DRSC03287       16      FBtr0080930     570     42      508M    *       0       0       TGG
my %aligns;
my %dupls;
my $c;
my %adIDs; # because we have more than 1 seq per ID!
while (<BO>) {
	if ($_=~/DRSC/) {
		$_ =~s/\n//gsm;
	# for $n0: http://bowtie-bio.sourceforge.net/bowtie2/manual.shtml#sam-output
	# 4: The read has no reported alignments
	# 16: The alignment is to the reverse reference strand
	# 0: 
	# reverse seq: join("",reverse(split//,$seq)) } 
		my ($pID,$n0,$ensTID,$coord,$n1,$nm,$st,$z1,$z2,$seq,@rests) = split(/\t/,$_);
		$aligns{$pID} .= "$n0,$ensTID,$coord,$seq\n" unless $n0 eq "4";
		# warn $pID."-".$ndIDs{$pID}.">>".$aligns{$pID."-".$adIDs{$pID}} if $pID eq "DRSC00331";		
		print LOG "DUPLS: $pID,$n0,$ensTID,$coord,$n1 \n" if ($dupls{$pID.",".$ensTID}++ > 1 && $ensTID ne "*");
	} else {
		# print $_;
	}
	$c++;
}
close (BO);
# warn $aligns{"DRSC14729"};
# warn $aligns{"DRSC00267"};
# warn $aligns{"DRSC08471"};

#..... Getting all genes into hash to work with them faster
my %tr2genes = %{getGenes('FruitFLYgenes')};
my $n=0;
my $r=0;
my %logdupls;
print showtime()." ".scalar keys %aligns, " aligns in SAM file and ", $c, " lines in SAM file\n\n";
my %tr2ids;
foreach my $pID (keys %aligns) {
	# my $adID = 0-$adIDs{$pID};
	my @trnsc;
	my @ugenes;	
	my %gseen;
	if ($aligns{$pID}) {
		foreach my $map (split(/\n/, $aligns{$pID})) {
			my ($str, $ensTID, $coord, $subj) = split(/\,/,$map);
			warn "$pID,$ensTID" if ($pID=~/DRSC10311/);
			$str = ($str =~/\0/) ? "+" : "-";						
			my ($ensGID, $symbol, @synonyms);
			if ($tr2genes{ $ensTID } && $ensTID ne "*") {
				($ensGID, $symbol, @synonyms) = @{$tr2genes{ $ensTID } };
				my %tdt = (
					"ensTID" => $ensTID,
					"ensGID" => $ensGID,
					"symbol" => $symbol,
					"synonyms" => [@synonyms],
					"length" => length($subj),
					"mismatch" => 0,
					"strand" => $str,
					"sbjct" => $subj,
					"s_begin" => $coord,
					"s_end" => $coord+length($subj)-1
					);
				 push(@trnsc,\%tdt);
				 push(@ugenes,$ensGID) if $gseen{$ensGID}++ ==0;
			} else {
				 print LOG $ensTID." for ".$pID." not found in the genes collection\n" if ($logdupls{$pID}++ == 1) # some transcripts are in haplotypes genes
			}
		}
	} else {
		print LOG $pID." not aligned\n";
	}
	# my $rgID = "000000".($n+1);
	# $rgID = substr($rgID,-7);
	# $rgID = $prfx.$rgID;
	my $libID = 1;
	my $supl = 4;
	($rgID,$probeID) = split(/\:/,$pID);	
	if (scalar @trnsc >0) {
	  	$rgnts->insert( {
		    rgID => $rgID,
		    prefix => $prfx,
		    probeID => $IDs{ $rgID },
		    supID => $supl,
		    libID => $libID,
		    seq1 => uc($seqs{$rgID}),
		    seq2 => "",
		    tagfor => "",
		    type => "siRNA",
		    tagin => [@trnsc],
		    t_mapfreq=> scalar @trnsc,
		    genes=> [@ugenes],
		    g_mapfreq=> scalar @ugenes,
		    aligner=>"bowtie2",
		    genome=>"FruitFLY"		    
		});
		$n++;
	} else {
	  	$rgnts->insert( {
		    rgID => $rgID,
		    prefix => $prfx,
		    probeID => $IDs{ $rgID },
		    supID => $supl,
		    libID => $libID,
		    seq1 => uc($seqs{$rgID}),
		    seq2 => "",
		    tagfor => "",
		    type => "siRNA",
		    tagin => [],
		    t_mapfreq=> 0,
		    genes=> [@ugenes],
		    g_mapfreq=> scalar @ugenes,
		    aligner=>"bowtie2",
		    genome=>"FruitFLY"
		}) if $seqs{$pID};
		print LOG $pID." > non-targeting reagent\n";
		# $adID++;
	}
	$r++;
	print "$r reagents loaded: ".showtime()."\n" if ($r%10000 == 0);
} 
close(LOG);
print "$r reagents loaded\n";
$r = $r-$n;
print "$r non-targeting loaded: see not targeting in log file as well\n";
print showtime().": $n targeting reagents loaded\n";
print "end: ".showtime()."\n";
##############################################################
sub getGenes {
	my ($collection) = @_;
	my %tr2genes;
	my $genes = $db->get_collection( $collection );
	my $crs = $genes->find({},{"ensGID" => 1, "symbol" => 1, "synonyms" => 1, "transcripts.ensTID"=> 1});
	$crs->immortal(1);
	my $g;
	while (my $obj = $crs->next) {
	   grep { my @g = ( $obj->{"ensGID"}, $obj->{"symbol"}, @{$obj->{"synonyms"}} ); $tr2genes{ ${$_}{"ensTID"} } = \@g } @{$obj->{"transcripts"}};
	   $g++;
	}
	print showtime().": $g genes read from $collection\n";
	return \%tr2genes;
}

sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}    