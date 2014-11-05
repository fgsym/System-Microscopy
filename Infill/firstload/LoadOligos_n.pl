#!/usr/bin/perl

use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
my $log = "../infill-logs/LoadOligos_n.log";
my $mitos = "../infill-load-data/oligos_amb_quag.tsv";
my $bowtie = "../infill-load-data/Align-best-mitocheck.map";
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' );
    my $rgnts = $db->get_collection( 'Reagents' );
#######################    
    $rgnts->drop;
#######################     
# db.Reagents.remove({"supID":/1/}); db.Reagents.remove({"supID":2});
#..... Getting oligos sequences and reagents IDs from Mitocheck's oligo_pair
my  %oligos;
open (OL, $mitos || "can't open $mitos: $!");
# MCO_0000054     CCAGUAUCAAGUUGUUGAUTT   AUCAACAACUUGAUACUGGTT   126688  ASK     15
while(<OL>) {
	my ($mID,@params) = split(/\t/,$_); # @params = ($seq1,$seq2,$eid,$itarg,$supl);
	$oligos{$mID} = \@params;
}
close OL;
#..... Getting BOWTIE oligos to Human transcriptome alignment
my %aligns;
open (BW, $bowtie || "can't open $bowtie: $!");
# MCO_0000054     -       ENST00000498144 458     AACCAGTATCAAGTTGTTGAT   IIIIIIIIIIIIIIIIIIIII   4
while(<BW>) {
	my ($mID, $strand, $tr, $coord, $subj, $q, $frq) = split(/\t/,$_); # @params = ($mID, $strand, $tr, $coord, $subj, $q, $frq);
	# my ($mID, $strand, $tr, $coord, $subj, $q, $frq) = @aparams;
	$aligns{$mID} .= "$strand,$tr,$coord,$subj,$q,$frq\n";
}
close BW;
#..... Getting all genes into hash to work with them faster
my $genes = $db->get_collection( 'HMSPNSgenes' );
my $crs = $genes->find({},{"ensGID" => 1, "symbol" => 1, "synonyms" => 1, "transcripts.ensTID"=> 1});
$crs->immortal(1);
my %tr2genes;
my $g;
while (my $obj = $crs->next) {
	   grep { my @g = ( $obj->{"ensGID"}, $obj->{"symbol"}, @{$obj->{"synonyms"}} ); $tr2genes{ ${$_}{"ensTID"} } = \@g } @{$obj->{"transcripts"}};
	   $g++;
}
print showtime().": $g genes read from HMSPNSgenes\n";
my $n=0; my $nn=0;
open (LOG, ">$log" || "can't open $log: $!");
foreach my $mID (sort keys %oligos) {
	  my @trnsc;
	  my @param = @{ $oligos{$mID} };
	  my ($seq1,$seq2,$eid,$itarg,$supl) = @param;
	  $supl=~s/\n//;
	  my ($strand, $loc, $coord, $subj, $q, $frq);
	  my @ugenes;
	  if ($aligns{$mID}) {
		my %gseen;
	     foreach my $str (split(/\n/,$aligns{$mID})) {
			($strand, $loc, $coord, $subj, $q, $frq) = split(/\,/,$str);
			my ($tr,@loc) = split(/\s/,$loc);
			my ($ensGID, $symbol, @synonyms);
			if ($tr2genes{ $tr }) {
				($ensGID, $symbol, @synonyms) = @{$tr2genes{ $tr } };
				my %tdt = (
					"ensTID" => $tr,
					"ensGID" => $ensGID,
					"symbol" => $symbol,
					"synonyms" => [@synonyms],
					"length" => 21,
					"mismatch" => 0,
					"strand" => $strand,
					"sbjct" => $subj,
					"s_begin" => $coord,
					"s_end" => $coord+20
					);
				 push(@trnsc,\%tdt);
				 push(@ugenes,$ensGID) if $gseen{$ensGID}++ ==0;
			} else {
				 print LOG $loc." not found in HMSPNSgenes collection\n" # some transcripts are in haplotypes genes
			}
		}
	  } 
	  print LOG "bowtie returned NULL for $mID!\n" unless $aligns{$mID};
	  my $prfx = (!$supl) ? "AMBN2" : ( $supl eq "15" ) ? "AMBN1" : ( $supl eq "23" ) ? "AMBN2" : ( $supl eq "18" ) ? "QIAGN" : "AMBN2";	  
	  my $rgID = "000000".($n+1);
	  $rgID = substr($rgID,-7);
	  $rgID = $prfx.$rgID;
	  my $libID = ( $supl eq "15" || $supl eq "18") ? 1 : ( $supl eq 23 ) ? 2 : 2;
	  $supl = (!$supl) ? 1 : ( $supl eq "15" ) ? 1 : ( $supl eq 23 ) ? 1 : ( $supl eq "18" ) ? 2 : 0;
	  $rgnts->insert( {
	    rgID => $rgID,
	    prefix => $prfx,
	    probeID => $eid,
	    supID => $supl,
	    libID => $libID,
	    seq1 => uc($seq1),
	    seq2 => uc($seq2),
	    tagfor => $itarg,
	    type => "dsRNA",
	    tagin => [@trnsc],
	    t_mapfreq=> $frq+1,
	    genes=> [@ugenes],
	    g_mapfreq=> scalar @ugenes
	}) if (scalar @trnsc > 0 &&  $eid);
	   unless (scalar @trnsc > 0) { # not targeting reagent
			   $rgnts->insert({
			  rgID => $rgID,
			  prefix => $prfx,
			  probeID => $eid,
			  supID => $supl,
			  libID => $libID,
			  seq1 => uc($seq1),
			  seq2 => uc($seq2),
			  tagfor => $itarg,
			  type => "dsRNA",
			  tagin => [],
			  t_mapfreq=> 0,
			  genes=> [],
			  g_mapfreq=> scalar @ugenes
		   }) if ($eid);	
		$nn++ if ($eid);
		}
	$n++ if ($eid);
	print "$n oligos loaded: ".showtime()."\n" if ($n%10000 == 0);	  
}
close LOG;

print "$n oligos (with $nn not targeting) loaded to RNAs\n";
print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}