#!/usr/bin/perl

use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
warn $0;
my $log = "$0.log";
my $bowtie = "/home/jes/Git/infill-load-data/Align-best-existing-reagents-75.map";

print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("socket" => "/tmp/mongodb-27017.sock",query_timeout => -1) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $re = $db->get_collection( 'Reagents' );
	my $genes = $db->get_collection( 'HMSPNSgenes' );   

my $gcrs =  $re->find({aligner=>"bowtie","prefix" => {'$ne' => "DHARM"},g_mapfreq=>0},{rgID=>1, probeID=>1});
my @all;
my %reags; # hash for reagents 
push(@all,$gcrs->all);
map { $reags{ $_->{rgID} } = $_->{probeID} } @all;
print showtime().": ".scalar (keys %reags)." reagents with 0 maps read from Reagents\n";
#..... Getting BOWTIE oligos to Human transcriptome alignment
my %aligns;
open (BW, $bowtie || "can't open $bowtie: $!");
#AMBN10015265    -       ENST00000521628 cdna:putative chromosome:GRCh37:8:48962140:48973875:1 gene:ENSG00000169139 gene_biotype:protein_coding transcript_biotype:protein_coding        999     AAGCAATGTGGGTGCTGACTA   IIIIIIIIIIIIIIIIIIIII 5
while(<BW>) {
	my ($rgID, $strand, $tr, $coord, $subj, $q, $frq) = split(/\t/,$_); # @params = ($mID, $strand, $tr, $coord, $subj, $q, $frq);
	# my ($mID, $strand, $tr, $coord, $subj, $q, $frq) = @aparams;
	$aligns{$rgID} .= "$strand,$tr,$coord,$subj,$q,$frq\n";
}
close BW;
print showtime()." ".scalar (keys %aligns)." : reagents mapped in $bowtie\n";
# > db.Reagents.update({aligner:"bowtie","prefix":{$ne : "DHARM"}},{$unset:{tagin:1,genes:1,t_mapfreq:1,g_mapfreq:1}},false,true);
# $re->update( {aligner=>"bowtie"}, {'$unset' => { genes => 1 }},{multiple => 1});
# $re->update( {aligner=>"bowtie"}, {'$unset' => { tagin => 1 }},{multiple => 1});

#..... Getting all genes into hash to work with them faster
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
my %haplos;
# $conn->query_timeout(90000);
foreach my $rgID (sort keys %reags) {
	if ($aligns{$rgID}) {
		foreach my $str (split(/\n/,$aligns{$rgID})) {
			my ($strand, $loc, $coord, $subj, $q, $frq) = split(/\,/,$str);
			my ($tr,@loc) = split(/\s/,$loc);
			my ($ensGID, $symbol, @synonyms);
			if ($tr2genes{ $tr }) {

			} else {
				 print LOG $loc." for $rgID not found in HMSPNSgenes collection (haplotypes genes etc)\n"; # some transcripts are in haplotypes genes
				 $haplos{$rgID}++;
			}
		}		
		$n++;
		print LOG "bowtie found mapping for $rgID!\n"; 
	} else {
		print LOG "bowtie returned NULL for $rgID!\n";
		$nn++;
	}
}
close LOG;

print "$n reagents (with $nn not targeting) to update in Reagents collection\n";
print scalar (keys %haplos). " reagents turned out to map kind of haplogenes too\n";
print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}