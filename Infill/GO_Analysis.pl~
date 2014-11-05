use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
print "start: ".showtime()."\n";

my $conn = MongoDB::Connection->new("host" => "localhost:27017") or print "\n".$!;
my $db   = $conn->get_database( 'sym' );
warn "<< ".$ARGV[0]." >> collection populating (if empty it will be HMSPNSgenes!)";
my $genes = $ARGV[0] ? $db->get_collection( $ARGV[0] ) : $db->get_collection( 'HMSPNSgenes' );
my $go = $db->get_collection( 'GO_Analysis' );
$go->remove({genome => $ARGV[0] ? $ARGV[0] : "HMSPNSgenes"});

my %hgenes;
my $crs = $genes->query({},{"symbol" => 1,"synonyms" => 1, "ensGID" => 1, "transcripts" => 1});

while (my $obj = $crs->next) {
	   $hgenes{ $obj->{"ensGID"}} = $obj->{"transcripts"};
}
print "genes hash loaded: ".showtime()."\n";
my %gos;		# all GO
my %interpro;	# all InterPro
my %trgos;	# all GOids to transcripts/genes
my %trint;	# all InterPro to transcripts/genes
foreach my $g (keys %hgenes) {
	my $tstring;
	foreach my $t ( @{ $hgenes{$g} } ) {
		map { 
			 $gos{ $_->{GOid} } =  $_->{GOdesc}."|".$_->{GOnamespace} if $_->{GOdesc}
		} @{ $t->{GO} };
		map {$trgos{ $_->{GOid} } .= $g."=".$t->{ensTID}."|" } @{ $t->{GO} };
		map { $interpro{ $_->{Iac} } =  $_->{Idesc} } @{ $t->{InterPro} };
	}
}
print "GO/InterPro and GOid/InterPro to Transcripts hashes loaded: ".showtime()."\n";
foreach my $o (keys %gos) {
	my @gtrs = split(/\|/,$trgos{$o});
	my %genes;
	my $counttrs =0;
	foreach my $t (@gtrs) {
		my ($gn, $tr) = split(/\=/,$t);
		$genes{$gn} .= $tr."-";
	}
	my @genes;
	# warn $genes{"ENSG00000242875"} if ($genes{"ENSG00000242875"} && $o eq "GO:0000003");
	foreach my $gn (keys %genes) {
		my @trs = split(/\-/,$genes{$gn});
		my %trs = ("ensGID"=>$gn, "transcripts"=>[@trs]);
		warn @trs if ($gn eq "ENSG00000242875" && $o eq "GO:0000003");
		push @genes, \%trs;
		$counttrs += scalar @trs;
	}
	my $countgenes = scalar keys %genes;
	my ($desc,$namespace) = split(/\|/,$gos{$o});
# fill Collection GO_Analysis
     $go->insert( { 
     	"genome" => $ARGV[0] ? $ARGV[0] : "HMSPNSgenes",
		"GOid" => $o,
		"GOdesc" => $desc,
		"GOnamespace" => $namespace,
		"genes" => [@genes],
		"countgenes"=>$countgenes,
		"counttrs"=>$counttrs
      } );
 }




print "end: ".showtime()."\n";
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}