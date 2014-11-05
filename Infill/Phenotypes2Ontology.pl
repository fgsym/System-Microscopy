use strict;
use MongoDB;
use warnings;
print "start: ".showtime()."\n";
my $log = "$0.log";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $onto = $db->get_collection( 'Ontology' );
    my $ph = $db->get_collection( 'Phenotypes' );
    my $mapping = "../Ontology/CMPO-export.csv";

my %ontos;
my $crs = $onto->query({},{});
my %phenos;
my $pcr = $ph->query({},{});

while (my $obj = $crs->next) {
	$ontos{ $obj->{OntID} } = $obj->{OntNAME}
}
my %chphenos;
while (my $obj = $pcr->next) {
	$phenos{ $obj->{ScrID}."|".$obj->{phID} } = ucfirst($obj->{phNAME});
	$chphenos{ucfirst($obj->{phNAME})}++;
}
warn scalar (keys %chphenos)." names of phenotypes exist\n";

open (CSV, $mapping) || die "$mapping : $!";
my @arobo;
my %maps;
my $n=1;
while(<CSV>) {
	$_ =~s/\n//gsm;
	if ($_=~/^\[/) {
		my ($t, $phname, $onto, $empt, $ann, $ids, @trash) = split(/\t/,$_);
		foreach my $ont_id (split(/\,/,$ids)) {
			$ont_id =~s/\_/\:/gsm;
			$ont_id =~s/\s//gsm;			
			$maps{$n."|".ucfirst($phname)} = $ont_id if ($ont_id =~/CMPO/);
			$n++;
		}
	}
}
warn scalar (keys %maps)." maps parced\n";
close CSV; 
open (LOG, ">$log") || die "$log : $!";
my %chupdates;
my %chontos;
foreach my $mp (keys %maps) {
	my ($n,$name) = split(/\|/,$mp);
	my $ont_id = $maps{$mp};
	if ($chphenos{$name}) {
		foreach my $ph (keys %phenos) {
			my ($ScrID,$phID) = split(/\|/,$ph);
			my $phNAME = $phenos{$ph};
			if ($phNAME eq $name && !$chupdates{$ont_id."|".$phID."|".$ScrID}) {
					$onto->update({OntID=>$ont_id}, {'$push' => 
						{'phenolist' => {
								phID=>$phID,
								phNAME=>$phNAME,
								ScrID=>$ScrID,
								genome=> ($ScrID eq "J1_SyM_2") ? "FruitFLY" : "HMSPNS"
							}
						} 
					});
				$chupdates{$ont_id."|".$phID."|".$ScrID}++;
				$chontos{$ont_id}++;
			} 
		}
	} else {
		print LOG "phenotypes <<$name>> not found in our DB!\n";
	}
}
warn scalar (keys %chupdates)." maps loaded\n";
warn scalar (keys %chontos)." ontology terms mapped\n";

foreach (keys %chupdates) {
	print LOG $_."\n";
}
close LOG;
print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}

