#!/usr/local/bin/perl
# reformating in accord to /home/jes/Git/Infill/Formats/Loader-format.tsv
use strict;
use warnings;
print "start: ".showtime()."\n";

my %phstrings;
my $input = "/home/jes/SysMicroscopy/DATAfiles/Mitocheck/validation_screen.tsv";
my $phenotypes = "Mitotic Delay:0.04|Binuclear:0.092|Polylobed:0.11|Grape:0.03|Large:0.0676|Dynamic:0.06197|Cell Death:0.072|Metaphase arrest/delay:1|Metaphase alignment problems/including no metaphase:1|Segregation problems/chromatin bridges/lagging chromosomes/multiple dna masses:1";
my $output = "/home/jes/SysMicroscopy/DATAfiles/Mitocheck/reformated-validation.tsv";

my $inner = "/home/jes/SysMicroscopy/DATAfiles/Mitocheck/mitocheck_siRNAs_phenotypes.tsv";
# sirna|plate|spot| NoPheno|Stren|prometaphase|	metaphase arrest/delay|	metaphase alignment|segregation|strange nuclear shape|nuclei stay together|large nucleus|Small nucleus|reduced mitotic index|cell migration |Cell death |sirna_maxSum_MitosisPhenotype|sirna_max_Metaphase|sirna_max_Shape1 |sirna_max_Shape3 |sirna_max_Grape|	sirna_max_Apoptosis
#     0|    1|   2|       3|    4|           5|                      6|                   7|          8|                    9|                  10|           11|           12|                 13  |            14 |         15|                           16|                 17|               18|           19    |             20|                 21 
#17: mitotic delay
#18: Shape1 = binuclear
#19: Shape3 = Polylobed
#20: Grape = grape
#21: Apoptosis = cell death

my %reags;
my %mreags;
open (INNER, $inner  || "can't open datafile: $!");
while (<INNER>) {
    $_ =~s/\n//;
    next if ($_ =~/Mitocheck/);   
    my @arr = split(/\t/,$_);
    $reags{$arr[1]} = $arr[0];
} close INNER;

open (MITO, $input  || "can't open datafile: $!");
my $prolif=0;
my %replicas;
while (<MITO>) {
    $_ =~s/\n//;
    next if ($_ =~/Stren/);   
    my @arr = split(/\t/,$_);
    $replicas{$arr[0]}++;
    $mreags{$arr[0].",".$replicas{$arr[0]}} = "$arr[1],$arr[2],$arr[3],$arr[5],$arr[6],$arr[7],$arr[8],$arr[9],$arr[10],$arr[11],$arr[12],$arr[13],$arr[14],$arr[15]";
} close MITO;

print scalar (keys %replicas)." reagents in validation scoring spreadsheet\n";

open (LOG, ">../infill-logs/ReformatMitocheck-validation.log" || "can't open datafile: $!");
open (RMITO, ">$output" || "can't open datafile: $!");
print RMITO "siRNA\t plate\t spot\t noph\t promet\t med\t ma\t seg\t str\t nutog \t largenuc \t smnuc\t redmit\t cellmig\t cd\n";
foreach (sort keys %mreags) {
    my ($plate,$spot,$noph,$promet,$med,$ma,$seg,$str,$nutog,$largenuc,$smnuc,$redmit,$cellmig,$cd,$replicas) = split(/\,/,$mreags{$_});
    # grep { $ = ($_ =~/x/) ? ($_ = 1) : ($_ = 0) } @four;
    my ($reag,$replica) = split(/\,/,$_);
    foreach ($noph,$promet,$med,$ma,$seg,$str,$nutog,$largenuc,$smnuc,$redmit,$cellmig,$cd) {
        $_ = ($_ =~/x/) ? ($_ = 1) : ($_ = 0);    
    }
    print RMITO "$reag\t$plate\t$spot\t$noph\t$promet\t$med\t$ma\t$seg\t$str\t$nutog\t$largenuc\t$smnuc\t$redmit\t$cellmig\t$cd\n";
    print LOG "$reag not found with inner MCO_*** ID (no reproducibility count)\n" unless $reags{$reag};
}
close RMITO;
close LOG;

print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
