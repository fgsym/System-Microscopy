#!/usr/local/bin/perl
# reformating in accord /home/jes/Git/Infill/Formats/Loader-format.tsv

use strict;
use warnings;
print "start: ".showtime()."\n";

my %phstrings;

my $input = "/home/jes/SysMicroscopy/DATAfiles/Mitocheck/complete_id_view.txt";
my $phenotypes = "Increased Proliferation:3.6966|Mitotic Delay:0.04|Binuclear:0.092|Polylobed:0.11|Grape:0.03|Large:0.0676|Dynamic:0.06197|Cell Death:0.072";
my $rcount = 160025;
my $output = "/home/jes/SysMicroscopy/DATAfiles/Mitocheck/reformated-primary.tsv";

my $inner = "/home/jes/SysMicroscopy/DATAfiles/Mitocheck/mitocheck_siRNAs_phenotypes.tsv";

my %reags;
my %mreags;
open (INNER, $inner  || "can't open datafile: $!");
while (<INNER>) {
    $_ =~s/\n//;
    next if ($_ =~/Mitocheck/);   
    my @arr = split(/\t/,$_);
    $reags{$arr[1]} = $arr[0];
}

open (MITO, $input  || "can't open datafile: $!");
my $prolif=0;
while (<MITO>) {
    $_ =~s/\n//;
    next if ($_ =~/Mitocheck/);   
    my @arr = split(/\t/,$_);
    $mreags{$arr[0]} = $arr[2];
}

close MITO;
close INNER;
open (LOG, ">../Logs/ReformatMitocheck.log" || "can't open datafile: $!");
map {
    foreach my $r (keys %reags) {
        print LOG "no scoring for $r\n" if ( $reags{$mreags{$_}} ne $_ );
    }
} keys %mreags; 

open (MITO, $input  || "can't open datafile: $!");
while (<MITO>) {
    $_ =~s/\n//; 
    next if ($_ =~/initCellCount/);   
    my @arr = split(/\t/,$_);
    my $id = $arr[0];
    $phstrings{$id} = \@arr;
    $prolif = $prolif+$arr[5];
}
close MITO;

open (RMITO, ">$output" || "can't open datafile: $!");
foreach (keys %phstrings) {
    my ($plate,$well) = split(/\-\-/,$_);
    my @arr = @{$phstrings{$_}};
    my ($ic,$ec,$ip,$md,$bn,$pl,$gr,$l,$dc,$cd) = ($arr[3],$arr[4],$arr[5],$arr[6],$arr[7],$arr[8],$arr[9],$arr[10],$arr[11],$arr[12]);
    next if ($_ =~/initCellCount/);
    my $probe = $arr[2];
    print RMITO "$plate\t$well\t$probe\t$reags{$probe}\t$arr[3]\t$arr[4]\t$arr[5]\t$arr[6]\t$arr[7]\t$arr[8]\t$arr[9]\t$arr[10]\t$arr[11]\t$arr[12]\n" if $reags{$probe};
    print LOG "$probe not found with inner MCO_*** ID\n" unless $reags{$probe};
}
close RMITO;
close LOG;

print scalar (keys %phstrings)."\n";
$prolif = $prolif/$rcount;
print "$prolif \n";
print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
