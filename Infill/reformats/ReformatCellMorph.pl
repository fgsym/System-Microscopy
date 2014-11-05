#!/usr/local/bin/perl
# reformating in accord /home/jes/Git/Infill/Formats/Loader-format.tsv

use strict;
print "start: ".showtime()."\n";

my $input_loc = "/home/jes/SysMicroscopy/DATAfiles/CellMorph/phenoprints.tab";
my $input_probes = "/home/jes/SysMicroscopy/DATAfiles/CellMorph/Dharmacon_Annotation_RefSeq27+HGNC.tab";
my $output = "/home/jes/SysMicroscopy/DATAfiles/CellMorph/probes2phenoprints.tsv";
my $logfile = "../Logs/2-reformat.log";
my %phstring;
open (LOC, $input_loc || "can't open datafile: $!");
while (<LOC>) {
    $_ =~s/\n//;    
    my @arr = split(/\t/,$_);
    my $id = $arr[0];
    my $well = substr($id,2);
    my $plate = substr($id,0,-3);
    unless ($_=~/^well/) {
            splice(@arr, 0, 1);
            # print join(",",@arr)."--- $plate$well\n";
            # print scalar @arr if $well=~/F19/;
        $phstring{"$plate\t$well"} = \@arr;
    }
}
close LOC;
my %probes;
open (PRB, $input_probes || "can't open datafile: $!");
while (<PRB>) {
    $_ =~s/\n//;    
    my @arr = split(/\t/,$_);
    my $plate = $arr[0];
    $plate = ($plate !~/\S\S/) ? "0".$plate : $plate;
    my $well = $arr[1];
# throw off rows without extID and intID (like D-008486-01&D-008486-03&D-008486-04&D-008486-05) 
    unless ($arr[4]=~/NA/ || $arr[5]=~/NA/) {
        $probes{"$plate\t$well"} = $arr[4]."\t".$arr[5];
        # print $arr[4]."\n" if "$plate/$well" =~ /H18/ && "$plate/$well" =~ /^10/;
    }
}
close PRB;
my %phcluster = (1=>"BL phenotype (decrease in the number of cells and increase of metaphase cells)",
                    2=>"Bright nuclei",3=>"Large nuclei",4=>"Cells with protrusions",5=>"Elongated cells",6=>"Elongated cells with protrusions",
                    7=>"SM phenotype (abundance of large cells with protrusions and bright nuclei)",8=>"Small cells",9=>"Low eccentricity cells",
                    10=>"High actin ratio cells",11=>"Metaphase cells",12=>"Actin fiber cells",13=>"Big cells",14=>"Large cells",15=>"Lamellipodia cells",
                    16=>"Lamellipodia + high actin ratio cells",17=>"Proliferating cells",18=>"Other phenotype");

open (TSV, ">$output" || "can't open datafile: $!");
open (LOG,">$logfile" || "can't open datafile: $!");
print TSV "plate\t well\t probeID\t IntProbeID\t n\t ext\t ecc\t Ato\t Nex\t Nin\t Nto\t AF\t BC\t C\t M\t LA\t P\t Phenotype\n";
foreach my $pw (sort keys %phstring) {
    my @arr = @{$phstring{$pw}};
    my $ph = (scalar @arr == 14) ? $arr[13] : 18;
    splice(@arr,-1) if (scalar @arr == 14);
    my @phc = split(/\+/,$ph);
    my @phstr;
    foreach (@phc) {
        if ($_=~/\S/) {
            push @phstr,$phcluster{$_*1};
        } else {
            push @phstr,$phcluster{18};
        }
    }
# throw off rows without intID (like D-008486-01&D-008486-03&D-008486-04&D-008486-05)    
    if (scalar @phstr > 0 && scalar @arr>0 && $pw =~/\S/ && $probes{$pw} =~/M-/ && $probes{$pw} =~/D-/) { 
        print TSV $pw."\t".$probes{$pw}."\t".join("\t",@arr)."\t".join(",",@phstr)."\n";
    } else {
        print LOG $pw." doesn't corrrespond valid row\n";
    }
}
close LOG;
close TSV;
print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
