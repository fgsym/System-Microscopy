use strict;
use MongoDB;
use warnings;
print "start: ".showtime()."\n";
my $log = "$0.log";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $onto = $db->get_collection( 'Ontology' );

my %prnts;
my %kids;

my %othreads;
my %ontos;
my %phcodes;
my $crs = $onto->query({},{});
while (my $obj = $crs->next) {
	$ontos{ $obj->{OntID} } = $obj->{OntNAME};
    if (scalar @{$obj->{is_a}} >0) {
      foreach (@{$obj->{is_a}}) {
        push @{ $prnts{$obj->{OntID}} },$_->{OntID};
        push @{ $kids{$_->{OntID}} },$obj->{OntID};
      }
    }
    if (scalar @{$obj->{phenolist}} >0) {
    	foreach (@{$obj->{phenolist}}) {
        	push @{ $phcodes{$obj->{OntID}} }, $_->{phID}."__".$_->{ScrID};
    	}
    }	
}

foreach my $id (keys %ontos) {
	my $cid = $id;
	my $code;
	$code = join("|", @{ $phcodes{ $cid} }) if (scalar @{ $phcodes{ $cid} } > 0);
	loop:
	foreach my $pid (@{ $prnts{$cid} }) {
		$code .= "|".join("|", @{ $phcodes{ $pid} }) if (scalar @{ $phcodes{ $pid} } > 0);
		push @{ $othreads{$pid} }, $code;		
		if ($prnts{$pid}) {
			$cid = $pid;
			goto loop;
		} else {
			last;	
		}
	}
}


my %all_in_tree;
foreach my $c (sort keys %prnts) {  
  my $i =1;
  my @is_a = @{$prnts{$c}};
  for my $i (0 .. $#is_a) {
    $all_in_tree{$c."-".$i} = $is_a[$i];
  }
}
# tree ids with unified ids in %all_utree
my %all_utree; 
foreach my $ci (keys %all_in_tree) {
  my ($c, $i) = split(/\-/,$ci);  
  foreach my $xi (sort keys %all_in_tree) {
    $all_utree{$xi} = $ci if ($all_in_tree{$xi} eq $c);
  }
  $all_utree{$ci} = "CMPO:0000003" if ($all_in_tree{$ci} eq "CMPO:0000003")
}


##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}