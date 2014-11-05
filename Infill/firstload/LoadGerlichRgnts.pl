#!/usr/local/bin/perl
# adding reagents to Qiagen prefix="QIAGN"
use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->sym;
    my $re = $db->Reagents; 
my @phenos;
my %phstring;
my %phcodes = ();
my %phcluster = ();
my %reags;
my $hcrs =  $re->find({supID=>2},{probeID=>1, seq2=>1}); # or prefix=>"QIAGN"
my %hreags; # hash for reagents for extID => seq2
my @all;
push(@all,$hcrs->all);
foreach my $obj (@all) {
	$hreags{ $obj->{probeID} } = $obj->{seq2};
}
print scalar(keys %hreags)." QIAGN reagents counted\n";
open (NR, "../infill-load-data/Gerlich/PPase_screen_with_phenotypes.tsv"  || "can't open datafile: $!");
# $re->remove({supID=>2}); # i.e., "Qiagen" to exclude duplicates
while (<NR>) {
    $_ =~s/\n//;    
    my @arr = split(/\t/,$_);
    my $gene = $arr[3];
    my $qid = $arr[14];
    my $q = $arr[16];
    my $seq2 = $arr[17];
    my $seq1 = $arr[18];
    my $phen = $arr[20];
# PPase01 5       1       exp655  ACP2    13      56.46038462     23.84545369     8.815961538     15.90522757     144     1.346373623     
# acid phosphatase 2, lysosomal   Hs_ACP2_7       NM_001610       SI03063319    53      CAGAATGAGAGTTCTCGGAAT   AUUCCGAGAACUCUCAUUCtg   GAAUGAGAGUUCUCGGAAUtt   normal 
# 14: extID, 18: seq1, 17: seq2, 3: tagfor, 20: phenotype, 4: MitoticEvents 5: NB2ANA_mean 6: NB2ANA_sd 7: ANA2NR_mean 8: ANA2NR_sd 9: CellCountStart 10: Proliferation
    if ($arr[15] =~/\S+$/) {
        $reags{$arr[15]} = $arr[18]."\t".$arr[19]."\t".$arr[4]."\t".$arr[20]."\t".$arr[5]."\t".$arr[6]."\t".$arr[7]."\t".$arr[8]."\t".$arr[9]."\t".$arr[10]."\t".$arr[11]."\n";
    }    
# warn "$gene-$qid-$q-$seq2-$seq1-$phen" if $gene =~/PPP2R2/;
}
close NR;
print scalar (keys %reags)." reagents grabbed from input file\n";
open (LOG,">../infill-logs/LoadGerlichRgnts.log" || "can't open datafile: $!");


my %aligns;
open (MAP,"../infill-load-data/Align-best-quagen.map" || "can't open datafile: $!");
while(<MAP>) {
	my ($mID, $strand, $tr, $coord, $subj, $q, $frq) = split(/\t/,$_); # @params = ($mID, $strand, $tr, $coord, $subj, $q, $frq);
	$aligns{$mID} .= "$strand,$tr,$coord,$subj,$q,$frq\n";
}
close MAP;
#..... Getting all genes into hash to work with them faster
my $genes = $db->HMSPNSgenes;
my $crs = $genes->find({},{"ensGID" => 1, "symbol" => 1, "synonyms" => 1, "transcripts.ensTID"=> 1});
$crs->immortal(1);
my %tr2genes;
my $g;
while (my $obj = $crs->next) {
	   grep { my @g = ( $obj->{"ensGID"}, $obj->{"symbol"}, @{$obj->{"synonyms"}} ); $tr2genes{ ${$_}{"ensTID"} } = \@g } @{$obj->{"transcripts"}};
	   $g++;
}
print showtime().": $g genes read from HMSPNSgenes\n";
my $sort={"rgID"=>-1};
my $rcrs = $re->query({"prefix"=>"QIAGN"},{"rgID" => 1, limit => 1})->sort($sort);
my $robj = $rcrs->next;
my $rgID = $robj->{rgID};
warn $rgID.": last rgID";
my ($c,$n) = split(/N/,$rgID);
$n =~s/^0+//gsm; # QIAGEN ID to begin
warn $n.": last rgID";
$re->remove({load=>"qiagen4P1-SyM"});
my $rgnts = $db->Reagents;
foreach my $extID (keys %reags) {
    my @trnsc;
    # 14: extID, 18: seq1, 17: seq2, 3: tagfor, 20: phenotype, 4: MitoticEvents 5: NB2ANA_mean 6: NB2ANA_sd 7: ANA2NR_mean 8: ANA2NR_sd 9: CellCountStart 10: Proliferation
    my ($seq1,$seq2,$itarg,$pheno,@params) = split(/\t/,$reags{$extID});
    if ($hreags{ $extID } && $hreags{ $extID } eq $seq2) {
       print LOG "found $extID\t".$seq2."\n";
    } else {
       print LOG "missed $extID\n";
	  my ($strand, $loc, $coord, $subj, $q, $frq);
	  my @ugenes;
	  if ($aligns{$extID}) {
		my %gseen;
	     foreach my $str (split(/\n/,$aligns{$extID})) {
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
				 print LOG $tr." not found in HMSPNSgenes collection\n" # some transcripts are in haplotypes genes
			}
		}
	  }
	  print LOG "bowtie returned NULL for $extID!\n" unless $aligns{$extID};
	  my $prfx = "QIAGN";
	  my $rgID = "000000".($n+1);
	  $rgID = substr($rgID,-7);
	  $rgID = $prfx.$rgID;
	  $rgnts->insert( {
	    "rgID" => $rgID,
	    "prefix" => $prfx,
	    "probeID" => $extID,
	    "supID" => 2,
	    "libID" => 0,
	    "load" => "qiagen4P1-SyM",
	    "seq1" => $seq1,
	    "seq2" => $seq2,
	    "tagfor" => $itarg,
	    "type" => "dsRNA",
	    "tagin" => [@trnsc],
	    "t_mapfreq"=> $frq+1,
	    "genes"=> [@ugenes],
	    "g_mapfreq"=> scalar @ugenes
         }) if scalar @trnsc > 0 ;
         unless (scalar @trnsc > 0) { # not targeting reagents
              $rgnts->insert( {
             "rgID" => $rgID,
             "prefix" => $prfx,
             "probeID" => $extID,
             "supID" => 2,
             "libID" => 0,
             "load" => "qiagen4P1-SyM",             
             "seq1" => $seq1,
             "seq2" => $seq2,
             "tagfor" => $itarg,
             "type" => "dsRNA",
             "tagin" => [],
             "t_mapfreq"=> 0,
             "genes"=> [],
             "g_mapfreq"=> scalar @ugenes
         }); 
       }
       $n++;       
    }
}
close LOG;
print "$n reagents loaded\n";

print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}

