#!/usr/bin/perl
# adding reagents to Ambion libID=2 prefix="AMBN2"
use MongoDB;
use MongoDB::OID;
use strict;
# use warnings;
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->sym;
    my $rgnts = $db->Reagents;
#................. INPUTS
my $log = "../infill-logs/newRNAs.log";
# column numbers with probeID and seq1, seq2
# my %datafiles = ("../infill-load-data/siRNAlibrary.csv" => "4,5,6");
# my $bowtie = "../infill-load-data/Align-best-2012-10-03_oligos.map"; # s19454  -       ENST00000468831 282     GAGAACTATGAGCAGAGAATA   IIIIIIIIIIIIIIIIIIIII   14
my %datafiles = ("../infill-load-data/BZH_SH4-mCherry-GFP/Ritzerfeld_BZH_SH4_domain_targeting_validation_screen_data.csv" => "8,9,10");
my $bowtie = "../infill-load-data/Align-best-2012-10-16_oligos.map";
my $load = "update-10-16";
my $libID = 2;
my $libprefix = "AMBN2";

#.................
# rgID incremention calc:
	   my $rcrs = $rgnts ->find({prefix=>$libprefix},{rgID=>1})->sort({rgID => -1});
	   my $rgID = $rcrs->next->{rgID};
	   print $rgID."\n";
	   my ($l,$num) = split(/MBN2/,$rgID);
	   $num = $num*1+1;
	   print $num."\n";	   
#######################    
#    $rgnts->drop;
#######################     
# db.Reagents.remove({"supID":/1/}); db.Reagents.remove({"supID":2});
#..... Getting oligos sequences and extIDs from Mitocheck's oligo_pair
my %oligos;
foreach my $f (keys %datafiles) {
	open (OL, $f || "can't open $f: $!");
	# NM_016238       ANAPC7  anaphase...    51434   s28133  CGAGAUAACGUGGACCUAUtt   AUAGGUCCACGUUAUCUCGca
	while(<OL>) {
		$_=~s/\n//gsm;
		my @params = split(/\t/,$_);
		my ($probeID, $seq1, $seq2) = split(/\,/,$datafiles{$f});
		($probeID, $seq1, $seq2) = ($params[$probeID],$params[$seq1],$params[$seq2]);
		$oligos{$probeID} = "$seq1|$seq2";
	}
	close OL;
}
#..... Getting BOWTIE oligos to Human transcriptome alignment
my %aligns;
open (BW, $bowtie || "can't open $bowtie: $!");
# s19454  -       ENST00000468831 282     GAGAACTATGAGCAGAGAATA   IIIIIIIIIIIIIIIIIIIII   14
while(<BW>) {
	my ($extID, $strand, $tr, $coord, $subj, $q, $frq) = split(/\t/,$_); # @params = ($mID, $strand, $tr, $coord, $subj, $q, $frq);
	# my ($mID, $strand, $tr, $coord, $subj, $q, $frq) = @aparams;
	$aligns{$extID} .= "$strand,$tr,$coord,$subj,$q,$frq\n";
}
close BW;
# scalar keys %oligos = 2534, scalar keys %aligns = 2342, 
#..... Getting all genes into hash to work with them faster
my $genes = $db->HMSPNSgenes;
my $crs = $genes->find({},{"ensGID" => 1, "symbol" => 1, "synonyms" => 1, "transcripts.ensTID"=> 1});
$crs->immortal(1);
my %tr2genes;
my $g;
while (my $obj = $crs->next) {
	   grep { 
			 my @g = ( $obj->{"ensGID"}, $obj->{"symbol"}, @{$obj->{"synonyms"}} ); 
			 $tr2genes{ ${$_}{"ensTID"} } = \@g 
	   } @{$obj->{"transcripts"}};
	   $g++;
}
print showtime().": $g genes read from HMSPNSgenes\n";

my $n=1; my $nn=1;
open (LOG, ">$log" || "can't open $log: $!");
foreach my $extID (sort keys %oligos) {
	  my @trnsc;
	  my ($seq1,$seq2) = split(/\|/,$oligos{$extID} );
	  my ($strand, $tr, $coord, $subj, $q, $frq);
	  my @ugenes;
	  if ($aligns{$extID}) {
	  	my %gseen;
		foreach my $str (split(/\n/,$aligns{$extID})) {
			($strand, $tr, $coord, $subj, $q, $frq) = split(/\,/,$str);
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
	  print LOG "bowtie returned NULL for $extID! (i.e. reagent should be in DB already)\n" unless $aligns{$extID};
	  my $prfx = "AMBN2";	  
	  my $rgID = "000000".($num+$n);
	  $rgID = substr($rgID,-7);
	  $rgID = $prfx.$rgID;
	  my $supl = 1;
	  if (scalar @trnsc > 0) {
		  $rgnts->insert( {
		    "rgID" => $rgID,
		    "prefix" => $prfx,
		    "probeID" => $extID,
		    "supID" => $supl,
		    "libID" => $libID,
		    "seq1" => uc($seq1),
		    "seq2" => uc($seq2),
		    "type" => "siRNA",
		    "tagin" => [@trnsc],
		    "t_mapfreq"=> $frq+1,
		    "genes"=> [@ugenes],
		    "g_mapfreq"=> scalar @ugenes,
		    "load" => $load
		});
	} else { # we do not insert reagent unless it maps gene because now we have 100% mapping: see README.txt here
	# not targeting reagent || no reagent in the experiment's spreadsheet
			   $rgnts->insert({
			  "rgID" => $rgID,
			  "prefix" => $prfx,
			  "probeID" => $extID,
			  "supID" => $supl,
			  "libID" => $libID,
			  "seq1" => $seq1,
			  "seq2" => $seq2,
			  "type" => "siRNA",
			  "tagin" => [],
			  "t_mapfreq"=> 0,
			  "genes"=> [],
			  "load" => $load,			  
			  "g_mapfreq"=> scalar @ugenes
		   });	
	$nn++;
	}
	$n++;
	print "$n oligos loaded with $nn not targeting: ".showtime()."\n" if ($n%10000 == 0);	  
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