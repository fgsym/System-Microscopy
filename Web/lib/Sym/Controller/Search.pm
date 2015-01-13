package Sym::Controller::Search;
use strict;
use base 'Mojolicious::Controller';
use vars qw($relpath);
*relpath = \%Sym::relpath;
# Phenotypes by gene / genes by phenotypes / reagent by phenotypes
# Render template "search/result.html.ep"
# call from	: /search/search_form.html.ep
# url from     : /search/result/
sub result {
  my $self = shift;
  my @cookies = $self->cookie('genome');
  my $cookie = $cookies[0];
  my $genome = $self->param('genome') ? $self->param('genome') : $cookie ? $cookie : "HMSPNSgenes"; # choosen genome
  my $coo;
  ($genome,$coo) = split(/\-\-/,$genome);
  if ( $self->param('reag') =~/DRSC/ || (reverse @{$self->req->url->path->parts})[0] =~/FruitFLYgenes/ ) {
    $genome = "FruitFLYgenes";
  }
  if ( (reverse @{$self->req->url->path->parts})[0] =~/HMSPNSgenes/ ) {
    $genome = "HMSPNSgenes";
  }
  my %scr_data = %{Sym::Controller::Studies->studies};
  my %eph_vars = (ScrID => "", StdTitle => "", phenoprint=>"", extend=>"",ScMethod=>"", ph_by_ScrID=>"");
  my %e_vars = (hcrs =>"",scr_data=>\%scr_data);
  my $stds_q = $self->param('stds');
  $stds_q = $stds_q !~/\S/ ? $stds_q eq "-" : $stds_q;
  $self->cookie(genome => $genome, {path=>'$relpath'}) unless $self->cookie('genome');
  # map {warn $_." : ".$self->param($_)} $self->param();
  if ($self->param('gene') ne "" && $self->param('gene') !~/name/) {  
    my $gene = $self->param('gene');
    $gene =~s/(\s|\n|\t|\z|\r)//gsm;
    if ($gene) {
        my $crs;        
        if ($self->param('stype') eq "gn") {
           $crs = Sym::Model::MongoQ->get_reagent_by_gene_ensGID($gene);
        } else {
          $crs = Sym::Model::MongoQ->get_reagent_by_gene_symbol($gene);
          unless ($crs->next) {
             $crs = Sym::Model::MongoQ->get_reagent_by_gene_synonyms($gene);
          }
        } 
        my $hcrs = Sym::Model::MongoQ->get_gene($gene,$genome);
        $self->render(crs => $crs, q => $gene, hcrs => $hcrs, stype => "gn", allgenes => "", genome=>$genome, scr_data=>\%scr_data, %eph_vars, face=>"");
     } else {
        $self->render(crs => "", q => "",stype => "gn", %e_vars, allgenes => "", genome=>"", %eph_vars, face=>""); 
     }
     
  } elsif ($self->param('reag') ne "" && $self->param('reag') !~/Supplier/) {
    
      my $re = $self->param('reag');
      my $crs = Sym::Model::MongoQ->get_reagent_by_probeID($re);    
      $self->render(crs => $crs, q => $re,stype => "re",%e_vars, allgenes => "", %eph_vars, face=>"");
                
  } elsif ($self->param('goon') ne "" && $self->param('goon') !~/attribute keywords/) {
      my $cnt = $self->param('goon') ? Sym::Model::MongoQ->count_gene_by_attribute($self->param('goon'),$genome) : 0;
      my $skip = $self->param('skip') ? $self->param('skip') : 0;
      my $limit = 50;
      my $crs = $self->param('goon') ? Sym::Model::MongoQ->get_gene_by_attribute($self->param('goon'),$genome,$skip,$limit) : "";
      my $go = $self->param('goon');
      $self->render(crs => $crs, q => $go, stype => "go", allgenes => $cnt, %e_vars,  %eph_vars, face=>"");
                
  } elsif ($self->param('phn') ne "" || $self->param('ohn')  ne "") {
      # map {warn $_." : ".$self->param($_)} $self->param();
      my $StdID = $self->param('study');
      my $phstr = $self->param('phn') ? $self->param('phn') : $self->param('ohn');
      my ($allcrs,$ph_by_ScrID,$ScrID,$StdTitle,$phenoprint,$ScMethod,$face) = $self->respheno($phstr,$StdID);

      $self->render(crs => $allcrs, ph_by_ScrID=> $ph_by_ScrID, ScrID => $ScrID, StdTitle => $StdTitle, phenoprint=>$phenoprint,
                  ScMethod=>$ScMethod, q => $phstr, stype => "phn", allgenes => "",%e_vars,face=>$face); 

  } elsif ($self->param('stds') !~/or Accession/ && $self->param('stds') ne "")  {
      my $kwds = $self->param('stds');
      my $crs = Sym::Model::MongoQ->get_study_by_kwds($kwds);
      $self->render(crs => $crs, q => $kwds, stype => "stds", allgenes => "", %e_vars,  %eph_vars, face=>"");
                
  } else {
      $self->render(crs => "", q => "", stype => "gn", allgenes => "", face=>"", %e_vars,  %eph_vars);
  }

}
# url from     : /search/respheno
# methods      : Sym::Controller::Genes->genesdist
#                Sym::Model::MongoQ->get_phenotypes_by_gene_and_phenotypes
#                Sym::Model::MongoQ->get_all_screens
# collections	: HMSPNSgenes, Experiments, PhenoAnalysis, AllPhenoAnalysis
sub respheno {
  my ($self,$phstr,$StdID) = @_;
  my ($ScrID,$phenoprint,$face,$exact,$terms); # $face — for phenotype or ontologies load
  my %ph_by_ScrID;
  my %screens;
  my $phids = (reverse @{$self->req->url->path->parts})[0]; # phenotypes set come from link
  my @phenos;
  if ($phstr || $phids) {
    if ($phids =~/\;/) {
        ($phenoprint,$exact,$face,$terms) = split(/\;/,$phids);
        @phenos = split(/\-/,$phenoprint);
    } else {                                                  # phenotypes set come from search form
      @phenos = split(/\,/,$phstr);
      $face = "true";
    }
  }
  # map { warn $_} @phenos;
  $terms = $terms ? $terms : ($self->param('study') ne "" && $self->param('study') ne "0") ? "p" : "o";
  # warn @phenos;
    if (scalar @phenos > 0) {
      map {
          my $phID;
          ($phID,$ScrID) = split(/\__/,$_);
          $screens{$ScrID}++;
          push @{$ph_by_ScrID { $ScrID } }, $phID; 
      } @phenos;
    }  
  $ScrID = ($StdID || $ScrID) ? $ScrID : 0;
  my ($allcrs,$StdTitle,$ScMethod,$genome);
  if (scalar (keys %screens) == 1 && $face eq "true") {    # one screen && phenoshow for one screen
   ($allcrs,$StdTitle,$ScMethod,$genome) = Sym::Controller::Phenotypes->phenosearch_by_ScrID($ScrID, \@{$ph_by_ScrID { $ScrID } }, $terms);
    $phenoprint = join("-",@{$ph_by_ScrID { $ScrID } });
  } else {
      my @phcrs;
      foreach my $ScrID (keys %ph_by_ScrID ) {
        my @allcrs = @{Sym::Model::MongoQ->get_phenotypes_by_their_set_and_ScrID($ScrID,\@{$ph_by_ScrID { $ScrID } }) };
        push @phcrs, @allcrs;
      }  
      $allcrs = \@phcrs;
      $ScrID = 0 if (scalar (keys %screens) > 1);   # many screen || phintersect
      $face = "false";
  }
  if ($phids =~/\;/) {
    my %scr_data = %{Sym::Controller::Studies->studies};
    my %e_vars = (hcrs =>"",scr_data=>\%scr_data);
    my @phIDs =  split(/\-/,$phenoprint);
    # warn keys %ph_by_ScrID;
    $self->render(crs => $allcrs, ph_by_ScrID=> \%ph_by_ScrID, ScrID => $ScrID, StdTitle => $StdTitle, phenoprint=>$phenoprint, genome=>$genome, face=>$face,terms=>$terms,
                  ScMethod=>$ScMethod, q => $phstr, stype => "phs", allgenes => "", phIDs => \@phIDs, %e_vars);    
  } else { 
    # $allcrs is empty if phintersect (search throught different screens)
    # map { warn $_ } keys %ph_by_ScrID;
    return ($allcrs,\%ph_by_ScrID,$ScrID,$StdTitle,$phenoprint,$ScMethod,$face);
  }  
}
# Render template "include/resgene_pheno.html.ep"
# url from     : /include/resgene_pheno
# call from	: /include/resgene.html.ep
# methods 	: Sym::Controller::Genes->phenotypes_to_gene
# collections	: Reagents, PhenoAnalysis
sub resgene_pheno {
  my $self = shift;
  my $ensgid = $self->param('gene');
  my $full = $self->param('extend'); 
  my ($ids,$uids,$sids,$zids) = Sym::Controller::Genes->phenotypes_to_gene($ensgid,$full);
  my %scr_data = %{Sym::Controller::Studies->studies}; 
  $self->render(ids => $ids, uids => $uids, sids => $sids, zids => $zids, ensgid => $ensgid, scr_data => \%scr_data);
}
# Grep Phenotypes for Search form
# call from	: Sym::Search::phenofilter
# methods      : Sym::Controller::Genes->genesdist
#                Sym::Model::MongoQ->get_phenotypes_by_their_set_and_ScrID >> PhenoAnalysis, AllPhenoAnalysis
#                Sym::Model::MongoQ->get_all_screens                           >> Experiments  
# collection	: Experiments, PhenoAnalysis, AllPhenoAnalysis
sub phenogrep {
  my $self = shift;
  my %phenos;
  my @ephID;
  push @ephID, $self->param('phc'); # parameter from ontofilter & phenofilter templates
  my %ph_by_ScrID;
  foreach (@ephID) {
     my ($phID,$ScrID) = split(/__/,$_); 
     push @{$ph_by_ScrID { $ScrID } }, $phID;
     # warn "($phID,$ScrID)";
  }  
  my @cgenes;
  # warn @ephID;
  if (scalar @ephID > 1) {
    @cgenes =  @{ Sym::Controller::Genes->genesdistPRC(\%ph_by_ScrID) };
  }
  return (\@cgenes, \@ephID);
}
# Grab Phenotypes for search together in Ontology & Phenotype pages
#
sub grabpheno {
  my $self = shift; 
  my ($cgenes,$ephID) = $self->phenogrep();
  my @cookies = $self->cookie('genome');
  my $cookie = $cookies[0];
  my $genome = $self->param('genome') ? $self->param('genome') : $cookie ? $cookie : "HMSPNSgenes"; # choosen genome
  my $terms = $self->param('terms');
  my $coo;
  ($genome,$coo) = split(/\-\-/,$genome);  
  # warn $terms;
  $self->render(cgenes=>$cgenes, choice=>$ephID, genome=>$genome, terms=>$terms);  
}

sub phenofilter {
# Render template "search/phenofilter.html.ep" (AJAX respond)
# url from     : /search/phenofilter
# collections	: Experiments, PhenoAnalysis, AllPhenoAnalysis
  my $self = shift;
  my ($cgenes,$ephID) = $self->phenogrep();
  my @cookies = $self->cookie('genome');
  my $cookie = $cookies[0];
  my $genome = $cookie;
  my $coo;
  ($genome,$coo) = split(/\-\-/,$genome);   
  my $phenos = Sym::Controller::Output->phenotypes( $genome, 'filter' );
  $self->render(phenotypes=>$phenos,cgenes=>$cgenes, choice=>$ephID);
}
# Render template "search/phintersect.html.ep"
# url from     : /search/phintersect (in search/phenofilter.html.ep)
# methods      : Sym::Controller::Genes->genesdist
#                Sym::Model::MongoQ->get_phenotypes_by_gene_and_phenotypes
#                Sym::Model::MongoQ->get_all_screens
# collections	: HMSPNSgenes, Experiments, PhenoAnalysis, AllPhenoAnalysis
sub phintersect {
  my ($self,$ephIDs,$goodmatch,$select,$trm,$genome) = @_;
  my @ephID = $ephIDs ? @{$ephIDs} : $self->param('phset');
  # warn $ephIDs;
  # my @cookies = $self->cookie('genome');
  # my $cookie = $cookies[0];
  $genome = $genome ? $genome : $self->param('genome') ? $self->param('genome') : "HMSPNSgenes";
  # warn "($ephIDs,$goodmatch,$select,$trm,$genome)";  
  my %ph_by_ScrID;
  my %screens;
  # warn @ephID;
  foreach (@ephID) {
     my ($phID,$ScrID) = split(/__/,$_); 
     push @{$ph_by_ScrID { $ScrID } }, $phID;
     $screens{$ScrID}++;
  }
  my @all; # all objects from queries by screen
     my @cgenes =  @{Sym::Controller::Genes->genesdistPRC(\%ph_by_ScrID,$select)};
     # warn "$genome, $select";
     foreach my $ScrID (keys %ph_by_ScrID ) {
        # my @arcrs = @{ Sym::Model::MongoQ->get_genes_by_phenotypes_set_and_ScrID(\@{$ph_by_ScrID { $ScrID } },$ScrID) };
        # push(@all,@arcrs);
        foreach my $g (@cgenes) {
            my @arcrs = @{ Sym::Model::MongoQ->get_phenotypes_by_gene_and_phenotypes($g, \@{$ph_by_ScrID { $ScrID } }, $ScrID, $genome, $select )};  # HMSPNSgenes || other genome
            push(@all,@arcrs);
        }  
      }
  # warn scalar @all;        
  my %scr_data = %{Sym::Controller::Studies->studies};  
  my %phenotypes;
  my %allphenos;
  my %namephenos;
  my %allgenes;
  # map {warn $_." : ".$self->param($_)} $self->param();
  my $terms = $trm ? $trm : $self->param('terms') ? $self->param('terms') : "p";
  my %onts = ($terms eq "p") ? () : %{Sym::Controller::Ontologies->get_oterms()}; 
  foreach my $obj (@all) {
        my $here = 0;
        # foreach my $l (@{$obj->{phenolist}}) {
            # foreach my $d (@{${$l}{phenodata}}) {
              # foreach my $ScrID (keys %ph_by_ScrID ) {
                  # my $cluster = join("-", sort {$a <=> $b} @{$ph_by_ScrID { $ScrID } });
                  # $here++ if (${$d}{phcluster} =~/$cluster/ && ${$d}{ScrID} eq $ScrID);
                  # # warn $here."::".${$d}{phcluster}."::".${$d}{ScrID}."::".scalar keys %screens;
              # }
                # $here++ if (${$l}{goodmatch} == 1 && $here >= ((scalar (keys %screens)) ) );
                # if ($here > 0) {
                my %phlist;
                my $g = $obj->{symbol}."|".$obj->{ensGID};
                # warn $g;            
                my ($allphenos, $phlist) = Sym::Controller::Phenotypes->hash_phenos($obj, \%allphenos, \%phlist, $goodmatch, \%onts ,$select);
                %allphenos = %{$allphenos};     # $allphenos{ lc($_->{phNAME})."__".$_->{phID}."__".$_->{ScrID} } = $_->{phID}."__".$_->{ScrID}
                if ($select eq "ex") {
                  my @oc_scr;
                  foreach my $ref (keys %phlist) {
                    my @ar = @{$phlist{$ref}};
                  } 
                  foreach my $ref (keys %allphenos) {
                    my ($nm,$p,$scr) = split(/__/,$ref);
                    foreach my $s (keys %ph_by_ScrID) {
                      if ($scr eq $s) {
                        %phlist = %{$phlist};           # $phlist{ $p->{rgID}."__".$p->{goodmatch} } = \@{ $p->{phenodata} }                                        
                        $allgenes{ $g } = \%phlist;
                        $phenotypes{ $obj->{ensGID} } = \%phlist;
                      } else {
                        $ref == 0;
                      }
                    }
                  }                   
                } else {
                  %phlist = %{$phlist};           # $phlist{ $p->{rgID}."__".$p->{goodmatch} } = \@{ $p->{phenodata} }
                  $allgenes{ $g } = \%phlist;
                  $phenotypes{ $obj->{ensGID} } = \%phlist;                  
                }
              # }  
            # }
        # }   
  }
  # warn keys %phenotypes;
  if ($ephIDs) {
    return (\%phenotypes, \%allphenos, \%allgenes, \%onts);
  } else {
    $self->render(phenotypes=>\%phenotypes, allphenos=>\%allphenos, allgenes=>\%allgenes, phchosen => \@ephID, scr_data => \%scr_data, genome=>$genome, onts=>\%onts);
  }
}
# url from     : /search/loadpheno (from layouts/default.html.ep)
# methods      : Sym::Model::MongoQ->get_phenotypes_by_their_set_and_ScrID
# collections	: PhenoAnalysis, AllPhenoAnalysis
sub loadpheno {
  # Render template "search/loadpheno.html.ep"
  my $self = shift;
  my $phenoprint = $self->param('phenoprint') ? $self->param('phenoprint') : 0;
  my $ScrID = $self->param('study') ? $self->param('study') : "";
  # warn "$ScrID, $phenoprint";
  my $face = ($self->param('face') eq "true") ? "true" : "false";
  my $phenos="";
  my @phIDs = split(/\-/,$phenoprint);
  my $crs = Sym::Model::MongoQ->get_phenotypes_by_their_set_and_ScrID($ScrID,\@phIDs);
  $self->render(crs => $crs, ScrID => $ScrID, phIDs=>\@phIDs, face=>$face, phenoprint=>$phenoprint);  
}
# url from     : /reagent (from layouts/default.html.ep)
# methods      : Sym::Model::MongoQ->get_reagent_by_rgID
# collections	: Reagents
sub reagent {
  my $self = shift;
  my ($id,$genome,$ensgid) = split (/\:/,@{$self->req->url->path->parts}[1]);
  my $crs = Sym::Model::MongoQ->get_reagent_by_rgID($id);
  $self->cookie(genome=>$genome, {path=>'$relpath'}) unless $self->cookie('genome');  
  $self->render(crs => $crs, genome => $genome, tmpl => 0);
}
# url from     : /gene (from layouts/default.html.ep)
# methods      : Sym::Model::MongoQ->get_gene
# collections : Genes
sub gene {
  my $self = shift;
  my ($genome,$gene) = split (/\:/,@{$self->req->url->path->parts}[1]);
  $self->cookie(genome=>$genome, {path=>'$relpath'}) unless $self->cookie('genome');

  my $crs = Sym::Model::MongoQ->get_reagent_by_gene_ensGID($gene);  
  my $hcrs = Sym::Model::MongoQ->get_gene($gene,$genome);
  $self->render(crs=>$crs, gene => $gene, hcrs => $hcrs, tmpl => 0, genome=>$genome);
}
1;
