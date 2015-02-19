package Sym::Controller::Genes;
use strict;
use base 'Mojolicious::Controller';
use vars qw(%GLV);
*GLV = \%Sym::GLV;
sub genebrowse {
  my ($self) = @_;
  my $st_maps = (reverse @{$self->req->url->path->parts})[0];
  my $type = (reverse @{$self->req->url->path->parts})[1];
  my ($genome,$count) = split(/\:/,$st_maps);
  my $obj;
  my @genes;
  if ($st_maps && $st_maps =~/genebrowse/) {
    $obj = Sym::Model::MongoQ->get_stats($GLV{release});
  } else {
    @genes = @{Sym::Model::MongoQ->get_genes_by_countedreags($type,$genome,$count)};
  }
  $self->render(obj => $obj ? $obj : \@genes, matches => $count, type => $type, genome=>$genome);
}
# call from	: Sym::Controller::Vars
# methods 	: Sym::Model::MongoQ->get_phenotypes_by_their_set_and_ScrID	
# collections	: ProcessedData
sub genesdist {
	my ($self,$ph_by_ScrID) = @_;
	my %ph_by_ScrID = %{$ph_by_ScrID};	
	my %agenes; # all genes by the given screens and phenoprint
	my %screens; 
	foreach my $ScrID (keys %ph_by_ScrID) {
                $screens{$ScrID}++;
        }          
        my @all;
	foreach my $ScrID (keys %ph_by_ScrID) {
                map {$_ = $_*1} @{$ph_by_ScrID{ $ScrID }};
                my @allcrs = @{Sym::Model::MongoQ->get_genes_by_phenotypes_set_and_ScrID(\@{$ph_by_ScrID{ $ScrID } },$ScrID ) }; 
                push(@all,@allcrs);
        }                  
        my @agenes;
        foreach my $obj (@all) {
          foreach my $l (@{$obj->{phenolist}}) {
            my $here = 0;
            foreach my $d (@{${$l}{phenodata}}) {
              foreach my $ScrID (keys %ph_by_ScrID ) {
                my $cluster = join("-", sort {$a <=> $b} @{$ph_by_ScrID { $ScrID } });
                $here++ if (${$d}{phcluster} =~/$cluster/ && ${$d}{ScrID} eq $ScrID);
              }
              $here++ if (${$l}{goodmatch} == 1);
              if ($here >= ((scalar (keys %screens)))) {
                push @agenes, $obj->{ensGID}
              }  
            }
          }   
        } 
        my %seen;
        map {$seen{$_}++} @agenes;
        my @ugenes = keys %seen;
	return (\@ugenes);
}

# make it faster!
sub genesdistPRC {
	my ($self,$ph_by_ScrID,$exact) = @_;
	my %ph_by_ScrID = %{$ph_by_ScrID};	
	my %agenes; # all genes from the given screens
	my %screens;
	foreach my $ScrID (keys %ph_by_ScrID) {
    $screens{$ScrID}++;
    my @allcrs;
    if ($exact && $exact eq "ex") {
      @allcrs = @{Sym::Model::MongoQ->get_phenotypes_by_cluster_and_ScrID($ScrID,\@{$ph_by_ScrID{ $ScrID } } ) }; 
    } else { # $exact eq "set"
      @allcrs = @{Sym::Model::MongoQ->get_phenotypes_by_their_set_and_ScrID($ScrID,\@{$ph_by_ScrID{ $ScrID } } ) };                   
    }
    my @agenes;
    my $phenoprint = join("-", sort {$a <=> $b} @{$ph_by_ScrID { $ScrID } });
		foreach my $obj (@allcrs) {
      foreach my $l (@{$obj->{cases}}) {
        my $here = 0;
        my $gm = 0;
        foreach my $ScrID (keys %ph_by_ScrID ) {
          $here++ if ($obj->{ScrID} eq $ScrID);
        }
        $gm++ if (${$l}{goodmatch} == 1 && $here);
        if ($here+$gm >=2 ) {
          map {push @agenes, ${$_}{ensGID};  } @{${$l}{genes}};
        }  
      }
		}
		$agenes{$ScrID."__".$phenoprint} = \@agenes; # group by chosen phenotypes and screen : $phenoprint != phcluster
	}
	my @cgenes; # common genes from the given screens
	my %seen;
	my %eagenes; # intersection within different experiments
	foreach my $s_p (keys %agenes) {
	   my %lseen;
	   map { $lseen{$_}++ unless $lseen{$_} } @{$agenes{$s_p}}; 
	   my @ugenes = keys %lseen;  # uniques genes here
	   $eagenes{$s_p} = \@ugenes;
	}
	foreach my $e (keys %eagenes) {
	   map { $seen{$_}++ } @{$eagenes{$e}};
	}
  my $ifseen = scalar keys %screens; 
	map { 
    push (@cgenes, $_) if $seen{$_} >= $ifseen  
  } keys %seen;
	return (\@cgenes);
}
# call from	: /search/reagent.html.ep
# methods 	: Sym::Model::MongoQ->get_gene_by_ensGID
# collections	: HMSPNSgenes
sub gene_data {
  my ($self,$ensgid,$tagin,$genome) = @_;
  my $gcrs = Sym::Model::MongoQ->get_gene_by_ensGID($genome,$ensgid);
  my %seen =(); my %transcripts; my %tags;
  my $gsym;
  map { 
    if ($_->{ensGID} eq $ensgid) {
      $gsym = $_->{symbol};	
      $seen{ $_->{ensTID} } = $_->{symbol}; 
      $transcripts{ $_->{ensTID} } = $_ if $_->{ensTID};
    } 
    $tags{ $_->{ensTID} } = $_->{symbol}."|".$_->{ensGID};
  } @{ $tagin };
  my %allgenes;
  my %alltrns;
  my %goterm;
  my $tnmb;
  while (my $gobj = $gcrs->next) { 
    $gsym = $gobj->{symbol};
    $tnmb = scalar @{ $gobj->{transcripts} };
    map {	$alltrns{ $_->{ensTID} } = $gobj->{ensGID};  } @{ $gobj->{transcripts} };
    
     foreach my $t ( @{ $gobj->{transcripts} } ) {
		map { $goterm{$_->{GOdesc}} .= $t->{ensTID}.", " } @{ $t->{GO} };
	}    
  }
  foreach my $t (sort keys %tags) {
    my ($g,$eg) = split(/\|/,$tags{ $t });
    $allgenes{ $tags{$t} }++ if $eg ne $ensgid ;
  }   
  my %sets;
  map { $sets{ substr($goterm{$_},0,-2) } .= $_.", " } (sort keys %goterm);
#  warn scalar(keys %alltrns);
  return(scalar (keys %transcripts),$tnmb,scalar(keys %alltrns),\%allgenes,$gsym,\%sets);
}
# call from 	: search/attributes.html.ep
# methods 	:  Sym::Controller::Phenotypes->hash_phenos
sub attributes {
	my ($self, $crs, $attr, $terms) = @_;	
	my %attrs;
	my %fullattrs;
	my %phenotypes;
	my %allphenos;
	my %namephenos;
  # warn $terms;
  my %onts = ($terms eq "p") ? () : %{Sym::Controller::Ontologies->get_oterms()};
  my %ph2onts;   
	while (my $obj = $crs->next) {
		my %goterm;
		my %fullgoterm;
		my %phlist;
		foreach my $t ( @{ $obj->{transcripts} } ) {
			map { $goterm{$_->{GOdesc}} .= $t->{ensTID}.", " if ($attr && $_->{GOdesc} =~/$attr/ ) } @{ $t->{GO} };
			map { $fullgoterm{$_->{GOdesc}} .= $t->{ensTID}.", " } @{ $t->{GO} };
		}
    my ($allphenos, $phlist, $ph2onts) = Sym::Controller::Phenotypes->hash_phenos($obj, \%allphenos, \%phlist, "", \%onts, \%ph2onts);
		%phlist = %{$phlist};
    %ph2onts = %{$ph2onts};    
		if (scalar (keys %phlist) > 0) {
		  my $g = $obj->{symbol}."|".$obj->{ensGID};
                  $attrs{ $g } = \%goterm;
                  $fullattrs{ $g } = \%fullgoterm;
                  $phenotypes{ $obj->{ensGID} } = \%phlist;
                  %allphenos = %{$allphenos};                 
		}
	 }
	 return (\%attrs, \%fullattrs, \%phenotypes, \%allphenos, \%onts);
}
# call from	: Search::resgene_pheno
#                search/resgene.html.ep   
# methods 	: Sym::Model::MongoQ->get_reagent_by_gene_ensGID
sub phenotypes_to_gene {
  my ($self,$ensgid) = @_;
  my %ids = (); my %uids = (); my %zids = (); 
  my %sids;
  my %filtered;
  # my $rcrs = Sym::Model::MongoQ->get_reagent_by_gene_ensGID($ensgid);
  # while (my $obj = $rcrs->next) {
    my $mcrs = Sym::Model::MongoQ->get_phenotypes_by_gene($ensgid); 
    while (my $mobj = $mcrs->next) {
      foreach (@{$mobj->{"cases"}} ) {
        my %hash = %{$_};
        foreach my $g (@{$hash{genes}}) {
          if (${$g}{ensGID} eq $ensgid) {
            if ($mobj->{"phcluster"} ne "0") {
              if ( $hash{goodmatch}==1) {
              # @ids — uniquely mapping reagents
                $ids{ $hash{rgID} } = $hash{probeID};
              } elsif ( $hash{goodmatch}==0 ) {
              # @uids — not uniquely mapping reagents
                $uids{ $hash{rgID}."#".$mobj->{"ScrID"} } = $hash{probeID};
              } 
            } else {
            # @zids — no phenotype observed/assigned
              $zids{ $hash{rgID}."#".$mobj->{"ScrID"} } = $hash{probeID};
            }
            $sids{ $hash{rgID} } = $hash{probeID};  # all probes 
          }
        }  
     }  
  }
  my @ids = (keys %ids);
  my @uids = (keys %uids);
  my @zids = (keys %zids);  
  return (\@ids,\@uids,\%sids,\@zids);
}
1;

