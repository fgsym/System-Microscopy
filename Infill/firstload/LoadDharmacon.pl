#!/usr/bin/perl
use strict;
use warnings;
use MongoDB;
# targeting Dharmacon reagents
print "start: ".showtime()."\n";
	   my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
	   my $db   = $conn->sym;
	   my $dbt   = $conn->sym_t;	   
	   my $rgnts = $dbt->Reagents;
	   my $genes = $db->HMSPNSgenes;
my @ar;
my $log = "../infill-logs/LoadDharmacon.log";
open (DF,"../infill-load-data/CellMorph/dharmacon_w_ensembl_ids.txt") or warn "$!"; 
my %g_m;
my %g_fm;
my %g_d;
my $v=0;
while (<DF>) {
	$v++;   
	my ($rid, $c, $syn, $ens) = split(/\t/,$_);
	$ens =~s/\n|\s//gsm;
	if ($_ =~/^M/) {
		$g_m{$ens} .= $rid."*" if $ens;
	} elsif ($_ =~/^D/) {
		$g_d{$ens} .= $rid."*" if $ens;
	}
}
close DF;
my %ncbi;
my %regmap;
my $k;
foreach my $e (keys %g_m) {
	my @am = split (/\*/,$g_m{$e});
	foreach my $m (@am) {
		my ($prm, $im, $nm) = split(/\-/,$m);
		my $compnd = "";
		foreach my $g (keys %g_d) {
			if ($g eq $e and $g_d{$g} =~/$im/) {
				   next unless $m;
				   my @ad = split (/\*/,$g_d{$g});
				   foreach my $d (sort @ad) {
					   next unless $d;
					   my ($prd, $id, $nd) = split(/\-/,$d);
					   $compnd .= $d."&" if ($id eq $im and $g_m{$e} =~/$im/ and $g_d{$e} =~/$im/);
				   }
				   if ($compnd =~/$im/ and $g_d{$e} =~/$im/ and $g_m{$e} =~/$im/) {
						  $compnd = substr($compnd,0,-1);
						  $regmap{"$m#$compnd"} .= $e."|";
				   }
			}
		}
	}
	$k++;
	print "$k reads at $e \n" if ($k%10000 == 0);
}
print "file with data read, check fo hash: ".$regmap{"ENSG00000182083"}."\n";

$rgnts->remove({libID=>"siGENOME"});
my %hgenes;
my $crs = $genes->query({},{"symbol" => 1,"synonyms" => 1, "ensGID" => 1});
while (my $obj = $crs->next) {
	   $hgenes{ $obj->{"ensGID"}} = $obj->{"symbol"}."|";
	   $hgenes{ $obj->{"ensGID"}} .= join(",",@{$obj->{"synonyms"}} ) if (@{$obj->{"synonyms"}});
}
print "genes hash load\n";
my %areags;
my $prfx = "DHARM";

open (LOG, ">$log") or warn "$!";
my $r=0;
foreach my $m (keys %regmap) {
	my @cids = split(/\|/, $regmap{$m});
	my ($extID,$intID) = split (/\#/, $m);
	my @trnsc;
	foreach my $i (@cids) {
		warn "($extID,$intID,$hgenes{$i})" if $i eq "ENSG00000095981";
		my ($symbol, $synonims) = split (/\|/, $hgenes{$i}) if $hgenes{$i} =~/\|/;
		my @synonyms = split (/\,/, $synonims) if $synonims;
		my %tdt = ("ensGID" => $i,
		    "symbol" => $symbol,
		    "synonyms" => [@synonyms]);
		push(@trnsc,\%tdt);
	}	
		$r++;   
		my $rgID = "000000".$r;
		$rgID = substr($rgID,-7);
		$rgID = $prfx.$rgID;
		my @ids = split(/\&/,$intID);
		$rgnts->insert( {
			  "rgID" => $rgID,
			  "prefix" => $prfx,
			  "probeID" => $extID,
			  "libID" => "siGENOME",			  
			  "supID" => 3,
			  "arrayID" => [@ids],
			  "type" => "siRNA",
			  "tagin" => [@trnsc],
			  "g_mapfreq"=>1
		});
}
close LOG;
print "end: ".showtime()." ".scalar(keys %regmap)." reagents loaded with Dharmacon ids and libID=siGENOME\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}