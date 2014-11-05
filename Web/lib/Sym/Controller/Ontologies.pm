package Sym::Controller::Ontologies;
use strict;
use vars qw(%GLV);
*GLV = \%Sym::GLV;
sub get_oterms {
  my ($self, $phID, $ScrID, $genome) = @_;
  my @terms = @{Sym::Model::MongoQ->get_oterms_by_phenotype_id($phID,$ScrID)};
  my %onts;
	foreach my $obj (@terms) {
		my @synonyms;
	    foreach (@{ $obj->{synonyms} }) {
	    	push @synonyms, $_->{OntAlias};
	    } 		
    	foreach (@{ $obj->{phenolist} }) {
    		my $id_n_names = (scalar @synonyms > 0) ? $obj->{OntID}."__".$obj->{OntNAME}."__".join("__",@synonyms) : $obj->{OntID}."__".$obj->{OntNAME};
      		push @{ $onts{ $_->{phID}."__".$_->{ScrID} } }, $id_n_names;
    	}		
	}
return \%onts;
}
sub ontotree {
  my ($self, $query, $genome) = @_;
  $genome =~s/genes//gsm;
  # warn $genome;
  my %prnts;
  my %kids;
  my %onames;   # Terms by ids  
  my %q_names;  # Terms found by query
  my %phenos;
  my %othreads;
  my %ontos;
  my %phcodes;
  my %ophcodes; # phenotypes to the given OntID
  my %synonyms;
  foreach my $obj ( @{Sym::Model::MongoQ->get_oterms_tree()} ) {
    my @ocodes; 
    my @synonyms;
    foreach (@{ $obj->{synonyms} }) {
      push @synonyms, $_->{OntAlias} if $_->{OntAlias};
    }
    $synonyms{$obj->{OntID}} = \@synonyms if (scalar @synonyms > 0);
    foreach (@{ $obj->{synonyms} }) {
      $q_names{ $obj->{OntID} } = $_->{OntAlias} if ( $query && $_->{OntAlias} =~/$query/ );     
    }  
    foreach (@{ $obj->{kids} }) {
      $q_names{ $obj->{OntID} } = $obj->{OntNAME} if ( $query && $_->{OntNAME} =~/$query/ );
    }  

    if ($obj->{is_a} && scalar @{$obj->{is_a}} >0) {
      foreach (@{$obj->{is_a}}) {
        push @{ $prnts{$obj->{OntID}} },$_->{OntID};
        push @{ $kids{$_->{OntID}} },$obj->{OntID};
      }
    }
    $onames{ $obj->{OntID} } = $obj->{OntNAME};
    $q_names{ $obj->{OntID} } = $obj->{OntNAME} if ( $query && $obj->{OntNAME} =~/$query/ );  
    foreach (@{ $obj->{phenolist} }) {
      my @phlist = {phID=>$_->{phID}, phNAME=>$_->{phNAME}, ScrID=>$_->{ScrID}, genome=>$_->{genome}};
      if ($_->{genome} eq $genome) {
        push @{ $phcodes{ $obj->{OntID} } }, $_->{phID}."__".$_->{ScrID};
        push @{$phenos{ $obj->{OntID} }}, @phlist;
      }
    }
  } 
# warn scalar (keys %q_names);
# make branches
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
  $all_utree{$ci} = "CMPO:0000003" if ($all_in_tree{$ci} eq "CMPO:0000003");
}
my %threads;
my %othcodes; # phenotypes in a given thread
# warn $query;
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
    my @ids = reverse (split(/\>/,$thrd));
    my $id = substr($ids[0],0,-2);    
    push @{$threads{$n}}, $thrd;
  }  
}
my $deep = scalar (keys %threads); 

# >> marking threads with phenotypes fingerprints inside >>
my @ar = sort {$a<=>$b} keys %threads;
my %ar_kids; # all kids in the branch
my %id_kids; # number of kids in the branch 
foreach (1 .. $#ar) {
  if ($threads{$_} && @{$threads{$_}}) {
    foreach my $l (@{$threads{$_}}) {
      my @ids = split(/\>/,$l);
      my $k=0;
      foreach my $i (0 .. $#ids) {
          my ($id,$n) = split(/\-/,$ids[$i]);
          unless ($ids[$i] eq $ids[$#ids]) {
            map { push @{$ar_kids{ $ids[$i] }}, $ids[$_] } ($i+1 .. $#ids);          
          }
          if ($phcodes{$id}) {
            # warn @{ $phcodes{ $id }} if $id eq "CMPO:0000050";
            map { 
                my ($i1,$n) = split(/\-/,$ids[$_]);
                push @{ $othreads{ $i1 } }, @{ $phcodes{ $id } } 
            } (0 .. $k);
          }
          $k++;
      }
    }
    # print "$_: \n".join ("\n", @{$threads{$_}} )."\n";
  } 
}

# map { warn $_ } @{$ar_kids{"CMPO:0000054-0"}};
my %uothreads; # remove double entries
foreach my $i (keys %othreads) {
  my @ar;
  my %seen;
  if ($othreads{ $i }) {
    map { push @ar,$_ if $seen{$_}++ == 0 } @{ $othreads{ $i } };

  }
  push @{ $uothreads{ $i } }, sort @ar;
}
  if ($query) { 
    %onames = %q_names;
  }  
foreach my $ci (keys %all_utree) { 
  if ( $ar_kids{ $ci } ) {
    my %seen;
    map {
      my ($id,$n) = split(/\-/,$_);
      # warn "$onames{ $id }" if ( $onames{ $id } =~/ncreased cell numbers/ );      
      $id_kids{$ci}++ if ($onames{ $id } && $seen{$_}++ == 0)
    } @{$ar_kids{ $ci }}; # in case there is a $query
  }
}  
# important for openning threa
  foreach my $id (keys %onames) { 
    if ($uothreads{ $id }) {
      my $code = join(",", @{ $uothreads{ $id } });
      $ophcodes{$id} = $code;
    } else {
      $ophcodes{$id} = "";
    }
 
  }
# warn $id_kids{"CMPO:0000054-0"};

$GLV{TREE}="";   # must be global!  
foreach my $f1 (sort  @{$threads{$ar[0]}} ) {
  my @fa = split(/\>/,$f1);
  # $f1 = $fa[$#fa];
  my $i = substr($fa[$#fa],0,-2);
  $GLV{TREE} .= $onames{$i} ? "li ".$fa[$#fa]."\n" : "";
  $GLV{TREE} .= $onames{$i} ? "bul\n" : "";
  $GLV{TREE} = $self->same_parent_kids($ar[0]+1, $f1, \@{$threads{$ar[0]+1}}, $deep, \%threads, \%kids, \%onames); 
  $GLV{TREE} .= $onames{$i} ? "eul\n" : ""; 
}
# warn scalar (keys %onames);
return ($GLV{TREE},\%onames, \%phenos, \%kids, \%synonyms, \%ophcodes, \%id_kids);
} 
sub same_parent_kids {
  my ($self, $level, $branch, $treads, $deep, $threads, $kids, $onames) = @_;
    my %onames = %{$onames};
    my %threads = %{$threads};
    my %kids = %{$kids};
    # my %phenos = %{$kids};    
    foreach my $f ( sort @{$treads} ) {
      my $r = substr($f,0,-15); # branch
      my $id = substr($f,-14);  # item id
      my $pid = substr($id,0,-2); # real id 
      if ($r eq $branch) {
        $GLV{TREE} .= $onames{$pid} ? "li ".$id."\n" : "";
        if ($level <= $deep) {    
  #       $GLV{TREE} .= "\n";
          $GLV{TREE} .= $onames{$pid} ? "bul\n" : "" if $kids{$pid};
          $self->same_parent_kids($level+1, $f, \@{$threads{$level+1}}, $deep, \%{$threads}, \%kids, \%onames);
          $GLV{TREE} .= $onames{$pid} ? "eul\n" : "" if $kids{$pid};
        }   
      }      
    }
return $GLV{TREE}; 
}
1;