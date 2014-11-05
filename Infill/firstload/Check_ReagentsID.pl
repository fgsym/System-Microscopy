#/usr/bin/perl
use MongoDB;
use strict;
use warnings;
my $daytime = showtime();
print "start: ".$daytime."\n";
my ($date,$t) = split(/\s/,$daytime);
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->sym;
    my $re = $db->Reagents; 
# inputs:
my $path = "/home/jes/SysMicroscopy/DATAfiles/";
my %datafiles = ("EMBL_secretion_screen/ncb2510-s1.csv" => "1,2", "EMBL_secretion_screen/ncb2510-s3.csv" => "1,2",
				    "CGSR_DNA_damage/siRNAlibrary.csv" => "1,4"); # "1,2" - are the column numbers with ensGID/(gene symbol) and siRNA

my @all; # all existing in DB AMBN reagents
my $crs =  $re->find({},{extID=>1, genes=>1, rgID=>1});				
my %reags; # hash for reagents for genes => extID
push(@all,$crs->all);
foreach my $obj (@all) {
	$reags{ $obj->{extID} } = $obj->{rgID};
}
my %seen;
map {	$seen{ $_ }++	} keys %reags;
print "checking hash... ".$reags{"38899"}."\n";
open (LOG, ">/home/jes/Git/Logs/Check_ReagentsID.log" || "cannot open $!");
foreach my $f (keys %datafiles) {
	my %hash; # new reagents to compare
	my ($p1,$p2) = split(/\,/,$datafiles{$f});
	open (F, $path.$f || "cannot open ".$path.$f.": $!");
	while (<F>) {
		unless ($_=~/siRNA/ || $_=~/scrambl/) {
			   my @arr = split(/\t/,$_);
			   map {$_=~s/\n//} @arr;
			   $hash{$arr[$p2]} = $arr[$p1];
		}
	}
	close F;   
	foreach my $re (keys %hash) {
		my $g = $hash{$re};
		# my @genes = @{$reags{ $re }};
		unless ( $seen{$re} ) {
			 print LOG "$f: new reagent ID: ".$re."\n";
			 
		}
		# map { 
			# print LOG "$f: reagent mapping changed for ".$re."\n" if ($g ne $_ and $reags{$_} ne $re);
			# } keys %reags;
	}
}
close LOG;

print "end: ".showtime()."\n";
# => 2343 new reagents from more siRNAlibrary.csv | wc = 2535
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
