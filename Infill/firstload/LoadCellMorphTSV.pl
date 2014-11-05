#!/usr/local/bin/perl

use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->sym;
    my $data = $db->Datasets; 
    $data->remove({"expID"=>2});

my @phenos;
my %phstring;
my %phcodes = (n=>"number of cells", ext=>"median cell size", ecc=>"median cell eccentricity", Ato=>"median actin-to-tubulin int. ratio", 
    Nex=>"median nucleus size", Nin=>"median nucleus intensity", Nto=>"median nucleus-to-cell size ratio", AF=>"fraction of actin fiber cells", 
    BC=>"fraction of big Cells", C=>"fraction of condensed cells", M=>"fraction of metaphase cells", LA=>"fraction of lamellipodia cells", 
    P=>"fraction of cells with protrusions", cluster=>"");
my %phcluster = (1=>"BL phenotype (decrease in the number of cells and increase of metaphase cells)",
                    2=>"Bright nuclei",3=>"Large nuclei",4=>"Cells with protrusions",5=>"Elongated cells",6=>"Elongated cells with protrusions",
                    7=>"SM phenotype (abundance of large cells with protrusions and bright nuclei)",8=>"Small cells",9=>"Low eccentricity cells",
                    10=>"High actin ratio cells",11=>"Metaphase cells",12=>"Actin ﬁber cells",13=>"Big cells",14=>"Large cells",15=>"Lamellipodia cells",
                    16=>"Lamellipodia + high actin ratio cells",17=>"Proliferating cells");
    foreach (sort {$a<=>$b} keys %phcluster) {
        push (@phenos, {"phID"=> $_, "phName"=> $phcluster{$_} } );
    }

open (BOUT, "/home/jes/SysMicroscopy/DATAfiles/CellMorph/phenoprints.tab"  || "can't open datafile: $!");
while (<BOUT>) {
    $_ =~s/\n//;    
    my @arr = split(/\t/,$_);
    my $id = $arr[0];
    splice(@arr, 0, 1);
    $phstring{$id} = \@arr;
}
close BOUT;
my %reags;
my %hgenes;
my %igenes;
my %ints;
my %entrez;
my %ncbi;
open (DHABOU, "/home/jes/SysMicroscopy/DATAfiles/CellMorph/Dharmacon_Annotation_RefSeq27+HGNC.tab"  || "can't open datafile: $!");
while (<DHABOU>) {
    $_ =~s/\n//;    
    my @arr = split(/\t/,$_);
    my $id = (length($arr[0])<2) ? "0".$arr[0].$arr[1] : $arr[0].$arr[1];
    $ints{$id} = $arr[4] if ($arr[4] && $arr[4] ne "empty");
    $reags{$id} = $arr[5] if ($arr[5] && $arr[5] ne "NA");
    $ncbi{$id} = $arr[8] if ($arr[8] && $arr[8] ne "NA");
    $hgenes{$id} = $arr[6] if ($arr[6] && $arr[6] ne "NA");         # OriginalGeneTarget
    $igenes{$id} = $arr[10] if ($arr[10] && $arr[10] ne "NA");      # CalculatedGeneTarget >> We do not take it, we'll do our own annotation for siRNAs to genome !
    $entrez{ $arr[6] } = $arr[7] if ($arr[6] && $arr[7]);
}
close DHABOU;
my $genes = $db->HMSPNSgenes;	    
my $rgnts = $db->Reagents;
$rgnts->remove({libID=>"siRNA"});
my $r=1; # db.Reagents.find({"supID":"2"}).count()+db.Reagents.find({"supID":"2"}).count()+db.Reagents.find({"supID":"1,1"}).count()
#db.Reagents.find({"rgID": {"$lt" : 100000000000}},{"rgID":1}).limit(1).sort({rgID:-1})
my $sort = {"rgID" => -1};
my $rcnt = $db->run_command([ count=>"Reagents",query => {"supID"=> 3} ]);
    $r = $rcnt->{"n"}+1;
my $br = $r;    
warn $r;	
open (LOG, ">/home/jes/Git/Logs/LoadCellMorphTSV.log" || "$_");
my $c=0;
foreach my $id (keys %phstring) {
   my $nr;
   if ($hgenes{$id}) {
	my $g = $hgenes{$id};
	# $crs->immortal(1);
	my $gene;
	warn $id unless ($reags{$id}); #
	my @ids = split(/\&/,$reags{$id}) if $reags{$id};
	my $nstr = `grep $ncbi{$id} /home/jes/SysMicroscopy/DATAfiles/mart_export_NCBI_IDs.txt`;
	my ($ensGID,$accNum) = split(/\t/, $nstr);	
	my $crs = $genes->query({"ensGID" => $ensGID},{"ensGID" => 1,"synonyms" => 1,"symbol" => 1});
	my @synonyms;
	my $symbol;
	if (my $obj = $crs->next) {
	    $gene = $obj->{"ensGID"};
	    $symbol = $obj->{"symbol"};
	    @synonyms = @{$obj->{"synonyms"}};
	} else {
	    $crs = $genes->query({'$or' => [{"synonyms" => uc($g)},{"symbol" => uc($g)}]},{"ensGID" => 1,"synonyms" => 1,"symbol" => 1});
	    if (my $obj = $crs->next) {
		    $gene = $obj->{"ensGID"};
		    $symbol = $obj->{"symbol"};
		    @synonyms = @{$obj->{"synonyms"}};	
	    } else {
		    my $eid = $entrez{$g};
		    my $gstr = `grep -m 1 -w $eid /home/jes/SysMicroscopy/DATAfiles/nonredundant_mart_export_ccds_entrez.txt` if $eid;
		    warn $eid unless $eid;
		    my @lines = split(/\n/, $gstr); # because before that was without grep with -m 1 and included haplotypes result
		    if (@lines) {
			foreach (@lines) {
			    my ($ensGID,$cidn,$idn) = split(/\t/, $_);
			    # print LOG "ens: $ensGID\n" if $ensGID =~/^ENS/;
			    my $ecrs = $genes->find({"ensGID"=>$ensGID},{"ensGID" => 1,"symbol" => 1,"synonyms" => 1});
			    if (my $obj = $ecrs->next) {
				$gene = $obj->{"ensGID"};
				$symbol = $obj->{"symbol"};
				@synonyms = @{$obj->{"synonyms"}};
			    } else {
				print LOG "notfound in Ensembl by ENTREZ: $ensGID : $g >> $idn \n" if $ensGID =~/^ENS/;
			    }
			}
		    } else {		    
				my $gstr = `grep -m 1 -w CCDS$eid /home/jes/SysMicroscopy/DATAfiles/nonredundant_mart_export_ccds_entrez.txt`;
				my @lines = split(/\n/, $gstr);
				if (@lines) {
				   foreach (@lines) {
					   my ($ensGID,$cidn,$idn) = split(/\t/, $_);
					   # print LOG "ens: $ensGID\n" if $ensGID =~/^ENS/;
					   my $ncrs = $genes->find({"ensGID"=>$ensGID},{"ensGID" => 1,"symbol" => 1,"synonyms" => 1});
					   if (my $obj = $ncrs->next) {
						  $gene = $obj->{"ensGID"};
						  $symbol = $obj->{"symbol"};
						  @synonyms = @{$obj->{"synonyms"}};
					   } else {
						  print LOG "notfound in Ensembl by CCDS: $ensGID : $g >> $cidn \n" if $ensGID =~/^ENS/;
					   }
				   }
			} else {
			    print LOG "notfound in nonredundant_mart_export_ccds_entrez: $g >> $eid \n";
			}    
		   }
		 }
	    }            # if absent in this Ensemble DB release
	    $ncbi{$id} =~s/\n//gsm;
	    my $prfx = "DHARM";
	    my $rgID = "000000".$r;
	    $rgID = substr($rgID,-7);
	    $rgID = $prfx.$rgID;
	    my $recrs = $rgnts->find({ "intID"=>$reags{$id}, "supID"=>3 }) if $reags{$id};
	    print LOG "int ID not found for $id\n" unless $ints{$id};
	    if ($reags{$id} && $ints{$id}) {
			 my $obj = $recrs->next;
			 if ($obj && $obj->{"intID"} eq $reags{$id}) {
				  $rgnts->update({extID => $ints{$id}}, {'$inc' => {'accNum' => $ncbi{$id}} }, {"upsert" => 1, "multiple" => 1});
				  $c++;
			 } else {
				  print LOG "$id: NOT FOUND intID: $reags{$id} with $ints{$id}\n";
				  $rgnts->insert({
				  "rgID" => $rgID,
				  "prefix" => $prfx,
				  "extID" => $ints{$id},
				  "intID" => $reags{$id},
				  "accNum" => $ncbi{$id},
				  "libID" => "siRNA",
				  "supID" => 3,
				  "tagfor" => $hgenes{$id},
				  "type" => "siRNA",
				  "arrayID" => [@ids],
				  "tagin" => [{ "symbol"=>$symbol, "ensGID"=>$gene, "synonyms" => [@synonyms] }]
				  }) if @ids; # see line 70: my @ids = split(/\&/,$reags{$id})
			 }
		}
		print LOG "$c updated\n";		  
		$r++;
		$nr = ($r-$br);
		print "$nr (re)loaded  \n" if ($nr%100 == 0);
		# my @phprint = @{$phstring{$id}};
		# my %printseen;
		# my @codes =("n","ext","ecc","Ato","Nex","Nin","Nto","AF","BC","C","M","LA","P"); 
		# for (0..12) {
		    # $printseen{ $codes[$_] } = $phprint[$_] unless ($phprint[$_] eq "0");
		# }
		# my $phcluster = $phprint[13] ? $phprint[13] : "0"; # last column in /home/jes/SysMicroscopy/DATAfiles/CellMorph/phenoprints.tab
		# my @ph = split(/\+/,$phcluster);
		# my %phenoseen;
		# foreach (@ph) {
		  # $phenoseen{$_} = $phcluster{$_}
		# }
		# $data->insert({
		    # "expID" => 2,
		    # "intID" => $reags{$id},
		    # "extID" => $ints{$id},
		    # "imgURL" => "http://www.ebi.ac.uk/huber-srv/cellmorph/query.php?search=$id",		    
		    # "libID" => "siGENOME",
		    # "supID" => 3,		    
		    # "printseen" => {%printseen},
		    # "phenoseen" => {%phenoseen},
		    # "phenocount" => $phcluster =~/\+/ ? scalar @ph : 1,
		    # "phcluster" => $phcluster
		    # }); 
    $crs = "";
    }
    print "$nr loaded  \n" if ($r%1000 == 0);
}
warn "$c reagents updated \n";
warn $r-1; # 55458
close LOG;
print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
# db.Reagents.remove({"supID":"3"});
# db.Datasets.remove({"expID":2});
