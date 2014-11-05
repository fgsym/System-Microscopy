#!/usr/local/bin/perl
# reformating in accord /home/jes/Git/Infill/formats/Loader-format_string.tsv

use strict;
print "start: ".showtime()."\n";

my $input_loc = "/home/jes/Git/infill-load-data/NF-kB/NF-kB_preformated.csv";
my $input_probes = "/home/jes/Git/infill-load-data/NF-kB/Dharmacon_IDs_and_SEQs.csv";
my $output = "/home/jes/Git/infill-load-data/NF-kB/NF-kB.csv";
my $seqs_output = "/home/jes/Git/infill-load-data/NF-kB/SEQs_NF-kB.csv";
my $fasta_output = "/home/jes/Git/infill-load-data/NF-kB/FASTA_NF-kB.fa";
my $logfile = "../infill-logs/NF-kB-reformat.log";
my $idfile = "/home/jes/Git/infill-load-data/gene2ensembl";

my %ids;
open (IDS, $idfile || "can't open datafile: $!");
while (<IDS>) {
    $_ =~s/\n//;    
    my @arr = split(/\t/,$_);
    $ids{$arr[1]} = $arr[2];
}
close IDS;

my %phstring;
open (LOC, $input_loc || "can't open datafile: $!");
while (<LOC>) {
    $_ =~s/\n//;    
    my @arr = split(/\t/,$_);
    my $well = $arr[2];
    my $plate = $arr[3];
    if ($plate && $well) {
        $phstring{"$plate\t$well"} = \@arr unless ($arr[0] =~/Number/);
    }
}
close LOC;
my %probes;
open (LOG,">$logfile" || "can't open datafile: $!");
open (PRB, $input_probes || "can't open datafile: $!");
while (<PRB>) {
    $_ =~s/\n//;
    my @arr = split(/\t/,$_);       
    my $well = $arr[1];
    my $plate = $arr[2];
    my $geneID = $arr[9]; # NCBI ID
    if ($geneID && $plate && $well && $arr[15] =~/\S+/) { # there is explicit probeID associated with loction and gene
        $probes{"$plate\t$well"} = \@arr unless ($arr[0] =~/Gene/);
    } else {
        print LOG $arr[0]." skipped : there is no NCBI id for $geneID in $plate && $well\n";
    }
}
close PRB;

my %phcluster = (1=>"no oscillation",2=>"decreased oscillation",3=>"increased oscillation",4=>"different oscillation pattern",5=>"normal oscillation");

open (TSV, ">$output" || "can't open datafile: $!");
open (SEQ, ">$seqs_output" || "can't open datafile: $!");
print TSV "Plate\tWell\tProbeID\tN\tHoechst_image_Nuclei\tGFP-p65_image_Cyto\tp-value_DOP\tp-value_DO\tp-value_IO\tp-value_NO\tlowest p-value\tPhenotype\n";
print SEQ "Ensembl ID\t NCBI ID\t probe ID\t p_ID_1\t seq_1\t p_ID_1\t seq_1\t p_ID_1\t seq_1\t p_ID_1\t seq_1\t p_ID_1\t seq_1\n";
open (FASTA, ">$fasta_output" || "can't open datafile: $!");
# to exclude replicas 
my %sqs;
foreach my $pw (sort keys %phstring) {
    my @ph_arr = @{$phstring{$pw}};
    if ($probes{$pw}) {
        my @pr_arr = @{$probes{$pw}};
        my $probeID = $pr_arr[15];
        if ($probeID) { 
#Plate   Well    ProbeID N   Hoechst_image_Nuclei    GFP-p65_image_Cyto  p-value_DOP p-value_DO  p-value_IO  p-value_NO  lowest p-value  Phenotype
            my $lw = $ph_arr[82]?$ph_arr[82]:"-";
            print TSV $pw."\t".$probeID."\t".$ph_arr[4]."\t".$ph_arr[40]."\t".$ph_arr[41]."\t".$ph_arr[78]."\t".$ph_arr[79]."\t".$ph_arr[80]."\t".$ph_arr[81]."\t".$lw."\t".ucfirst($ph_arr[84])."\n";
        } else {
            print LOG $pw." doesn't correspond to a probeID, thus discarded (for $ph_arr[0])\n";
        }
        if ($probeID) {
            my $seq = $ids{$pr_arr[9]}."\t".$pr_arr[9]."\t".$probeID."\t".$pr_arr[16]."\t".$pr_arr[17]."\t".$pr_arr[18]."\t".$pr_arr[19]."\t".$pr_arr[20]."\t".$pr_arr[21]."\t".$pr_arr[22]."\t".$pr_arr[23]."\n";
            $sqs{$seq}++;
            print SEQ $seq if ($sqs{$seq} == 1 && $pr_arr[16]);
            my $s1 = ">".$probeID."::".$pr_arr[16]."\n".$pr_arr[17]."\n";
            $sqs{$s1}++;
            print FASTA $s1 if ($pr_arr[16] && $pr_arr[17] && $sqs{$s1} == 1);
            my $s2 = ">".$probeID."::".$pr_arr[18]."\n".$pr_arr[19]."\n";
            $sqs{$s2}++;
            print FASTA $s2 if ($pr_arr[18] && $pr_arr[19] && $sqs{$s2} == 1);
            my $s3 = ">".$probeID."::".$pr_arr[20]."\n".$pr_arr[21]."\n";
            $sqs{$s3}++;
            print FASTA $s3 if ($pr_arr[20] && $pr_arr[21] && $sqs{$s3} == 1);
            my $s4 = ">".$probeID."::".$pr_arr[22]."\n".$pr_arr[23]."\n";
            $sqs{$s4}++;
            print FASTA $s4 if ($pr_arr[22] && $pr_arr[23] && $sqs{$s4} == 1);
        }
    } else {
        print LOG "smth wrong with $pw\n";
    }
}
close LOG;
close SEQ;
close TSV;
close FASTA;

print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
