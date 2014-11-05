use strict;
use MongoDB;
use warnings;
print "start: ".showtime()."\n";
my $log = "$0.log";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $onto = $db->get_collection( 'Ontology' );
    my $t_onto = $db->get_collection( 'T_Ontology' );

my %prnts;
my %kids;

my %othreads;
my %ontos;
my %phcodes;
my $crs = $onto->query({},{});
# collecting all parents for a kid and vice versa
while (my $obj = $crs->next) {
	$ontos{ $obj->{OntID} } = $obj->{OntNAME};
    if (scalar @{$obj->{is_a}} >0) {
      foreach (@{$obj->{is_a}}) {
        push @{ $prnts{$obj->{OntID}} },$_->{OntID};
      }
    }  
}
my %offs; # offsprings;
my %seens;
# make threads, all 
my %all_in_tree;
foreach my $c (sort keys %prnts) {  
  my @is_a = @{$prnts{$c}};
  for my $i (0 .. $#is_a) {
    $all_in_tree{$c."-".$i} = $is_a[$i];
  }
}
warn scalar (keys %all_in_tree);
# tree with unified ids 
my %all_utree; 
foreach my $ci (keys %all_in_tree) {
  my ($c, $i) = split(/\-/,$ci);  
  foreach my $xi (sort keys %all_in_tree) {
    $all_utree{$xi} = $ci if ($all_in_tree{$xi} eq $c);
  }
  $all_utree{$ci} = "CMPO:0000003" if ($all_in_tree{$ci} eq "CMPO:0000003")
}
my %threads;
my %ar_to_ci;

foreach my $ci (keys %all_utree) {
  my $kid;
  my $n=0;
  my $thrd="";
  $kid = $ci;
  loop:
  if ($all_utree{$kid}) {
    $thrd = $kid.">".$thrd;
    $kid = $all_utree{$kid};
    $n++;
    goto loop;
  } else {
    # root found;
    chop $thrd;
    push @{$threads{$n}}, $thrd;
  }
}

foreach my $l (1 .. 10) {
  if ($threads{$l} && @{$threads{$l}}) {
    foreach my $ar (@{$threads{$l}}) {
        my @thr = split(/\>/,$ar);
        my @ithr;
        map { my ($id,$k) = split(/\-/,$_); push @ithr,$id } @thr;
        foreach my $n (0 .. $#ithr) {
          foreach my $i (1.. $#ithr) {
            $seens{ $ithr[$n] }{$ithr[$n+$i]}++ if ($ithr[$n+$i]);
            push @{$offs{ $ithr[$n] }}, $ithr[$n+$i] if ($ithr[$n+$i] && $seens{ $ithr[$n] }{$ithr[$n+$i]} == 1);
            # print join (">", @thr )."\n" if ($ithr[$n] eq "CMPO:0000186");
          }
        }
    }
  } else {
    last;
  } 
}
map { warn $_ } @{$offs{"CMPO:0000002"}};
warn "\n".scalar @{$offs{"CMPO:0000002"}};
foreach my $oID (keys %offs) {
  if (scalar @{$offs{$oID}} > 0) {
    my @ins;  
    foreach my $k (@{$offs{$oID}}) {
      my %i = (OntID=>"$k", OntNAME=> $ontos{ $k });
      push (@ins, \%i);
    } 
      eval {
        # $t_onto->update( { OntID => $oID }, {'$pushAll' =>
        #     { kids => [@ins] }
        #     }) or warn "$!";
      };
      if ( $@ =~ /can't get db response, not connected/ ) {
        warn "couldn't do it first time!";
        eval {
        # $t_onto->update( { OntID => $oID }, {'$pushAll' =>
        #     { kids => [@ins] }
        #     }) or warn "$!";
        };
      }
  }
}
print "end: ".showtime()."\n";

sub find_all_kids {
  my ($kids,$is_a) = @_;


}

##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}