package Sym::Controller::Phenotypes;
use strict;
# call from	: Search::result, Sym::Vars::phenogrep, Search::respheno  
# methods 	: Sym::Model::MongoQ->get_all_screens
#                Sym::Model::MongoQ->get_phenotypes_by_ScrID	
# collections	: Experiments, PhenoAnalysis
sub get_all_phenotypes {
  my ($self,$genome) = @_;
  $genome = $genome ? $genome : "HMSPNSgenes";
  # warn $genome;
  my @scr_obj = @{Sym::Model::MongoQ->get_all_screens($genome)};
  my %phenohash;
  foreach my $obj (@scr_obj) {
    my $StdID = $obj->{"StdID"};
    my $StdTitle = $obj->{"StdTitle"};
    foreach ( @{$obj->{"ScreenData"}} ) {  
      if  ($_->{"ScrCollection"} eq $genome) {
        my $ScrID = $_->{"ScrID"};
        my $ScrType = $_->{"ScrType"};
        my @db_phenos = @{ Sym::Model::MongoQ->get_phenotypes_by_ScrID($ScrID) };
          grep { 
            $phenohash{${$_}{phID}."__".$ScrID} = ${$_}{"phNAME"}."|".$ScrID."|".$ScrType."|".$StdTitle unless ${$_}{"phNAME"}=~/No phenotype/;
          } @db_phenos;
      }    
        # - filtering that because not all phenotypes, mentioned in experiment are measured
    }  
  }
  return \%phenohash;
  # my @phenos; # to sort them in interface
  # foreach my $p (keys %phenos) {
  #   push(@phenos, $phenos{$p}."|".$p );
  # }
  # return $genome ? (\@phenos,\@scr_obj) : \@phenos;
  # return \@phenos;  
}
# call from	: search/phintersect.html.ep 
# collection	: HMSPNSgenes
sub hash_phenos {
	my ($self, $obj, $allphenos, $phlist, $goodmatch, $onts, $select) = @_;
	my %allphenos = %{$allphenos};
	my %phlist = %{$phlist};
	my @ph_to_rg;
  my %onts = %{$onts};
  my $ontnm = (scalar keys %onts > 0) ? 1 : 0;
	foreach my $p ( @{ $obj->{phenolist} } ) {
                my $r = $p->{rgID};
                $goodmatch = ($goodmatch && $p->{goodmatch} == 1) ? 1 : (!$goodmatch) ? 1 : 0;
                if ($p->{rgID} && $goodmatch) {
                  $phlist{ $p->{rgID}."__".$p->{goodmatch} } = \@{ $p->{phenodata} };
                }

                foreach my $d (@{ $p->{phenodata} }) {
                  foreach (@{ $d->{phenotypes} }) {
                    my $name = $_->{phNAME};
                    $name = Sym::Controller::Service->ontname($_->{phID}, $_->{ScrID}, \%onts) if ($ontnm == 1);
                    $allphenos{ $name."__".$_->{phID}."__".$_->{ScrID} } = $_->{phID}."__".$_->{ScrID} if ($p->{rgID} && $goodmatch);
                  }  
                }  
	}
	return (\%allphenos, \%phlist);
}
# call from	: Sym::Search::tsvpheno
# methods      : Sym::Controller::Service->gene_to_phenoprint
# collections	: PhenoAnalysis, AllPhenoAnalysis
sub phenoparams {
  my ($self,$crsarray,$phIDs,$terms) = @_; 
  my %phlists; 
  my %phenos; my %allgenes; my %allreags;
  my $d =1;
    foreach my $obj (@{$crsarray}) {
			$d++;
			$phlists { $obj->{slicecount}.".".$d } = $obj;	# !important: to sort arrays of phenotype sets
		}
  my %allphenos;
  my %onts = ($terms eq "p") ?  () : %{Sym::Controller::Ontologies->get_oterms()};
  my $ontnm = (scalar keys %onts > 0) ? 1 : 0;   
	foreach (sort {$a <=> $b} keys %phlists) {
	  my $obj = $phlists { $_ };
	  my ($withgenes, $nogenes) = Sym::Controller::Service->gene_to_phenoprint($obj);
	  my %withgenes = %{$withgenes};
 	  my %nogenes = %{$nogenes};
 	  my $phenoprints;
	  foreach my $p ( @{$obj->{"phenotypes"}} ) {
      my $name = ${$p}{phNAME};
      $name = Sym::Controller::Service->ontname(${$p}{phID}, $obj->{ScrID}, \%onts) if ($ontnm == 1);       
		  $allphenos { $name."__".$p->{phID}."__".$obj->{ScrID} }  = ${$p}{phID}."__".$obj->{ScrID};
		  my $howgood =0;	
		  map { $howgood = 1 if ${$_}{goodmatch} == 1 } @{$obj->{"cases"}};
		  $phenoprints .= ${$p}{phID}."__".$obj->{ScrID}."*" # if $howgood == 1; # related to %allphenos!
		}
    foreach ( (sort keys %withgenes), keys %nogenes ) {
      my %hash = $_ !~/^\#/ ? %{ $withgenes{$_} } : %{ $nogenes{$_} };
      $phenos{ $hash{probeID} } = $phenoprints;
      $phenos{ $hash{rgID}."|".$hash{symbol} }  = $phenoprints if $hash{symbol}; 
     }
	   %allgenes = (%allgenes, %{$withgenes} );
	   %allreags = (%allreags, %{$nogenes}   );
	}
  my %seen; 
  my %gseen;

  map { my ($g,$r) = split(/\#/,$_); $gseen{$g}++ } keys %allgenes;
  return (\%phenos, \%allgenes, \%allreags, \%allphenos);
}
# call from    : /search/reagent.html.ep
# methods      : Sym::Model::MongoQ->get_phenotypes_by_rgID
# collections	: PhenoAnalysis, AllPhenoAnalysis
sub phenotypes_by_rgID {
  my ($self,$id) = @_;
  warn $id;
  my $mcrs = Sym::Model::MongoQ->get_phenotypes_by_rgID($id);
  my %darray;
  my %uphenos;  # phenotypes for uniquely mapping rgID
  my %nphenos;  # phenotypes for non-uniquely mapping rgID
  my %zphenos;  # no phenotype
  my $onegene;
  my %freqs;
  # rgID is only one per ScrID and per phcluster !
  while (my $mobj = $mcrs->next) {
    foreach (@{$mobj->{"cases"}} ) {
      if (${$_}{rgID} eq $id) {
        if ($mobj->{"phcluster"} ne "0") {
          if ( ${$_}{goodmatch}==1) {
            $uphenos{ $mobj->{"ScrID"} } = ${$_}{phweights};
          } elsif ( ${$_}{goodmatch}==0 ) {
            $nphenos{ $mobj->{"ScrID"} } = ${$_}{phweights};
          } 
        } else {
          $zphenos{ $mobj->{"ScrID"} } = $mobj->{bestreags} ? $mobj->{bestreags} : $mobj->{countreagent};
        }
        my @genes = @{ ${$_}{genes} };
          if (scalar @genes >0 ) {
            my %g = %{ $genes[0] };
            $onegene = $g{ensGID};
          } else {
            $onegene = "";
          }        
      }
    my $nreags = $mobj->{countreagent};
    $freqs{ $mobj->{"ScrID"} } = $mobj->{ucountgenes}."|".$nreags."|".$mobj->{phcluster};
    }
  } 
    map {warn $_."\n"} keys %zphenos;
  return ($onegene, \%uphenos, \%nphenos, \%zphenos, \%freqs);
}
# call from	: search/resgene_pheno.html.ep
# methods 	: Sym::Model::MongoQ->get_phenotypes_by_gene_and_reagent
#                Sym::Model::MongoQ->get_Study_by_ScrID
# collections	: Experiments, PhenoAnalysis, AllPhenoAnalysis
sub phenotypes_by_gene_and_reagent {
  my ($self,$sids,$ensgid,$ids) = @_;
  my %sids = %{$sids};
  my (@allphenos,@uphenos);
  my %phash;
  my %phtoexp;
  my %phids;
  my (%ucntgenes, %ucntreagents, %expr);
  # my $mcrs = Sym::Model::MongoQ->get_phenotypes_by_gene_and_reagent_probeID($sids{$id},$ensgid,$full);
  my $mcrs = Sym::Model::MongoQ->get_phenotypes_by_gene($ensgid); # get_phenotypes_by_gene_and_reagent_probeID($obj->{"probeID"},$ensgid,$full);
  my %pw_ns;
  my %pw_ids;
  my %commongenes;
  my %commonreagents;
  my %inside;
  my %ph_by_ScrID;
  while (my $mobj = $mcrs->next) {
    foreach my $c (@{$mobj->{"cases"}} ) {
      my $here;
      foreach my $r (@{$ids}) { 
          if (${$c}{rgID} eq $r && $mobj->{phcluster} ne "0") {
            $here = 1;
          }
      }
      if ($mobj->{phcluster} ne "0") {
        ${$commongenes{ ${$c}{rgID} } } { $mobj->{ScrID} } = $mobj->{uagenes};# if (${$c}{g_mapfreq} == 1);
        ${$commonreagents{ ${$c}{rgID} } } { $mobj->{ScrID} } = $mobj->{cases};# if (${$c}{g_mapfreq} == 1);
      }
      my @phs = @{${$c}{phweights}};
      if ( $here ) {
          foreach  (@{${$c}{phweights}}) {
              ${$phash{ ${$c}{rgID} }} {ucfirst(${$_}{phNAME})."__".${$_}{phID}."__".$mobj->{"ScrID"}."__".${$_}{phWEIGHT} }++;
              ${$phids{ ${$c}{rgID} }} {${$_}{phID}."__".$mobj->{"ScrID"}}++;
              push ( @allphenos, ucfirst(${$_}{phNAME})."__".${$_}{phID}."__".$mobj->{ScrID} );
              $phtoexp{ ucfirst(${$_}{phNAME})."__".${$_}{phID}."__".$mobj->{ScrID} } = $mobj->{ScrID};              
          }
          $expr{${$c}{rgID}."#".$mobj->{ScrID}} = $mobj->{ScrID};         
       }
    }
  }
  foreach my $r (@{$ids}) {
      my %gseen = ();
      my %rseen = ();
      my %screens;
      foreach my $key (keys %{$commongenes{$r}}  ) {
        $screens{$key}++;
        if ( @{${$commongenes{$r} }{$key} } ) { 
          my @ensGIDs;
          map {   
              push (@ensGIDs, ${$_}{ensGID}); 
              } @{${$commongenes{$r} }{$key}};
          map { $gseen{$_}++ } @ensGIDs;      
        }
        if ( @{${$commonreagents{$r} }{$key} } ) { 
            map {   
              $rseen{ ${$_}{rgID} }++ if ${$_}{g_mapfreq} == 1; # we do not show on that interface non-unique mapping, therefore, don't count them here
              } @{${$commonreagents{$r} }{$key}};
        }
      }
      my $numscr = scalar (keys %screens);
      my @cgenes = ();
      my @creags = ();
      map { push @cgenes,$_ if $gseen{$_} > $numscr-1 } (keys %gseen);
      map { push @creags,$_ if $rseen{$_} > $numscr-1 } (keys %rseen);
#      map { warn $r." --- ".$_ if $gseen{$_} > $numscr-1 } (keys %gseen);
#      map { warn $r." --- ".$_ if $rseen{$_} > $numscr-1 } (keys %rseen);

      $ucntgenes{$r} = scalar @cgenes;
      $ucntreagents{$r} = scalar @creags;
    }  
    
    my %seen = ();
    map { $seen{$_}++ } @allphenos;
    map {push (@uphenos, $_)} keys %seen;
    return (\%ucntgenes, \%ucntreagents, \%expr, \@uphenos, \%phash, \%phids, \%phtoexp);
  }
  # call from : Sym::Search::respheno
#              : Sym::Search::tsvpheno
#                   
# methods      : Sym::Model::MongoQ->get_phenotypes_by_their_set_and_ScrID >> PhenoAnalysis, AllPhenoAnalysis
# collection  : ProcessedData
sub phenosearch_by_ScrID {
  my ($self,$ScrID, $phIDs, $ont) = @_;
  my @allcrs;
  # if ($ScrID) {
    my @phIDs = @{ $phIDs };
    # @phIDs = $phIDs[0] if $ont; # when several phenotypes map to one ontology term search by one phenotype to exclude 0 intersection cases
    my $phenos="";
    my $ecrs = Sym::Model::MongoQ->get_Study_by_ScrID($ScrID);
    my ($StdTitle,$cases);
    my $eobj = $ecrs->next;
    my $ScMethod;
    my $genome;
    if ($eobj) {
      foreach (@{$eobj->{ScreenData}}) {
          $ScMethod = ${$_}{ScrScMethod} if ${$_}{ScrID} eq $ScrID;
          $genome = ${$_}{ScrCollection} if ${$_}{ScrID} eq $ScrID;
      }
      $StdTitle = $eobj->{StdTitle};
    }
    # map {warn $_} @phIDs;
    @allcrs = @{Sym::Model::MongoQ->get_phenotypes_by_their_set_and_ScrID($ScrID,\@phIDs, $ont) };
    return (\@allcrs,$StdTitle,$ScMethod,$genome);
   # } else {
     # my @ScrIDs; my @phIDs;
     # foreach my $ScrID (keys %ph_by_ScrID) {
       # push @allcrs, @{Sym::Model::MongoQ->get_phenotypes_by_their_set_and_ScrID($ScrID,\@{$ph_by_ScrID{ $ScrID } }) }; 
     # }
     # $phenoprint = $phids if ($phids =~/__/);
     # return (\@allcrs,\%ph_by_ScrID,0,"",$phenoprint,"","");
   # }
}
1;