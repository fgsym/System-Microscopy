package Sym::Controller::Export;
use strict;
use warnings;
# use v5.10;
use base 'Mojolicious::Controller';
# No template to render
# url from     : /search/tsvpheno/
# collections  : PRC - ProcessedData & Reags - Reagents (see Sym::Model::MongoQ) 
sub tsvpheno {
  my $self = shift;
  my ($params,$f) = split(/\./,(reverse @{$self->req->url->path->parts})[0]);
  my ($sphenoprint, $phenochoosen, $trm, $set, $genome) = split(/\:/,$params);
  my @phIDs = split(/\-/,$phenochoosen);
  my %ph_by_ScrID;
  my %screens;
  foreach (@phIDs) {
     my ($phID,$ScrID) = split(/__/,$_); 
     push @{$ph_by_ScrID { $ScrID } }, $phID;
     $screens{$ScrID}++;
  }
  my $tsv;
  my $phstr = join(",",@phIDs);
  my ($phenos, $phenotypes, $allphenos, $allgenes, $allreags, $ph2onts);
  my %ph2onts;  
  if (scalar @phIDs != 1) { # means phintersect;
    $tsv = "№\tGene symbol\tEnsembl ID\n\tSyM ReagentID\tSupplier ReagentID\tSeq1\tSeq2";    
    ($phenotypes, $allphenos, $allgenes, $ph2onts) = Sym::Controller::Search->phintersect(\@phIDs,1,$set,$trm,$genome);
    %ph2onts = %{$ph2onts};
    # warn scalar %ph2onts; 
  } else { # means 1 phenotypes
    $tsv = "№\tGene symbol\tEnsembl ID\tSyM ReagentID\tSupplier ReagentID\tSeq1\tSeq2\tAvarage evidence";
    my $ScrID = (keys %screens)[0];
    my @allcrs = @{Sym::Model::MongoQ->get_phenotypes_by_their_set_and_ScrID($ScrID,\@phIDs)}; 
    ($phenos, $allgenes,  $allreags, $allphenos) = Sym::Controller::Phenotypes->phenoparams(\@allcrs,\@phIDs,$trm);
  }  
  my %allphenos = %{$allphenos};
  scalar (keys %allphenos);
  my %cphIDs;
  foreach my $p (@phIDs) {
    grep { $cphIDs{ $_ } = $p if $allphenos{ $_ } eq $p; } keys %allphenos; # to highlight choosen phenotypes
  }
  foreach my $name (sort keys %allphenos) { 
      $tsv .= $cphIDs{ $name } eq $allphenos { $name } ? "\t ".ucfirst($name)."(*)" : "\t ".ucfirst($name);
  }
  $tsv .= "\n";
  my %allgenes = %{$allgenes};
  my %allreags = (defined $allreags) ? %{$allreags} : ();
  my $n=0;
  my %phenos =  (defined $phenos) ? %{$phenos} : ();
  my @rgIDs;
  my $ontnm = (scalar keys %ph2onts > 0) ? 1 : 0;
  foreach my $gene ( (sort keys %allgenes), keys %allreags ) { 
    if (scalar @phIDs != 1) {
      my ($symbol, $ensgid) = split(/\|/, $gene);
      my %phenotypes = %{$phenotypes};      
      my %iphenos = %{$phenotypes{ $ensgid } };
      foreach my $re (sort keys %iphenos) {
          my ($rgID,$gmatch) = split(/__/,$re);
          push @rgIDs,$rgID;
      }
    } else {
      my %hash = $gene !~/^\#/ ? %{ $allgenes{$gene} } : %{ $allreags{$gene} };
      push @rgIDs,$hash{rgID}
    }
  }
  my @dataReags = @{Sym::Model::MongoQ->get_reagents_data_by_IDs_array(\@rgIDs)};
  my %dataReags;
  foreach my $obj (@dataReags) {
    $dataReags { $obj->{rgID} } = $obj->{probeID}."\t".$obj->{seq1}."\t".$obj->{seq2};
  }
  foreach my $gene ( (sort keys %allgenes), keys %allreags ) { 
    $n++;
    my %show;  
    if (scalar @phIDs != 1) {
      my ($symbol, $ensgid) = split(/\|/, $gene);
      my $g = $n."\t".$symbol."\t".$ensgid;
      $tsv .= $g."\n";
      my %phenotypes = %{$phenotypes};
      my %iphenos = %{$phenotypes{ $ensgid } };
      foreach my $re (sort keys %iphenos) {
        my ($rgID,$gmatch) = split(/__/,$re);

        $tsv .= "\t".$rgID." ($gmatch)\t".$dataReags { $rgID };
        foreach my $name (keys %allphenos) {
        # phenotypes for a given row identified by rgID/symbol (for genes) or probeID (notmapping reagents)
          $show{ $allphenos{$name} } = "-";      
          my %phenotypes = %{$phenotypes};
          foreach my $d ( @{ $iphenos{$re} } ) {
            foreach my $ph (@ { $d->{phenotypes} } ) {
              my ($phID,$ScrID)= split(/__/,$allphenos{$name});
              if ($ph->{phID} == $phID) {
                my $weight = int($ph->{phWEIGHT}*100)/100;               
                $show{ $allphenos{$name} } = $weight if ($allphenos{$name} eq $ph->{phID}."__".$ph->{ScrID});
              }                          
            }        
          }
        }
        foreach (sort keys %allphenos) {
          $tsv .= " \t".$show{ $allphenos{$_} };
        }      
      $tsv .= "\n";
      }       
    } else {
      my %hash = $gene !~/^\#/ ? %{ $allgenes{$gene} } : %{ $allreags{$gene} };
      my $g = $hash{ensGID} ? $hash{symbol}." \t ".$hash{ensGID} : "- \t -";
      $tsv .= $n."\t".$g."\t".$hash{rgID}." \t".$dataReags { $hash{rgID} }." \t".substr($hash{howgood},0,5);  
      my @thisrow = $hash{symbol} ? split(/\*/,$phenos{ $hash{rgID}."|".$hash{symbol} }) : split(/\*/,$phenos{ $hash{probeID} }); # $phID__ScrID list          
      my %seen; 
      my @uthis; 
      map { $seen{$_}++ } @thisrow; 
      push (@uthis, keys %seen);
      foreach my $name (keys %allphenos) {
        $show{ $allphenos{$name} } = "-";
        foreach my $u (@uthis) {  
          foreach (@{$hash{phweights}}) {
            my ($phID,$ScrID)= split(/__/,$allphenos{$name});
            if (${$_}{phID} == $phID) {
              my $weight = int(${$_}{phWEIGHT}*100)/100;
              $show{ $allphenos{$name} } = $weight if ($allphenos{$name} eq $u && $u ne "");
            }      
          }    
        }   
      }
      foreach (sort keys %allphenos) {
        $tsv .= "\t".$show{ $allphenos{$_} };
      }
      $tsv .= "\n";  
    } 
  }
  $self->res->headers->content_type('application/csv;charset=utf-8');
  $self->res->headers->header('Cache-Control' => 'max-age=300, must-revalidate, private');
  $self->res->headers->content_disposition('attachment; filename=Ph-Exports.csv');
  $self->render(data=>$tsv,format=>"csv");
}
# Render template /output/export.html.ep
# url from     : /export/ (from /layouts/default.html.ep)
# collections  : PRC - ProcessedData & Reags - Reagents & Supl - Suppliers (see Sym::Model::MongoQ) 
sub exports {
  my $self = shift;
  my $export;
  if ($self->param('val')){
      my ($supl,$f) = split(/\:/,$self->param('val'));
      map {$_ =~s/\///gsm } ($supl,$f);
      $supl = uc($supl);
      unless ($f) {
        $export = "Reagent ID \tSupplier \tQuery Seq \tGene targeted Ensembl ID \tGene Symbol \tPhenotypes with measuring (Name:value) \tNumber of Reagents with same Phenotypes \tExperiment";
      } else {
        $export = "Reagent ID \tSupplier \tQuery Seq \tGenes targeted (Ensembl ID:symbol) \tPhenotypes with measuring (Name:value) \tNumber of Reagents with same Phenotypes \tExperiment";
      }
      my $crs =  $self->param('val') ne "all" ? Sym::Model::MongoQ->get_all_reagents_by_supplier_prefix($supl) : Sym::Model::MongoQ->get_all_reagents_by_supplier_prefix();
      my $scrs = Sym::Model::MongoQ->get_supplier_by_prefix($supl);
      my $sobj = $scrs->next;
      my $supname = $sobj->{supName};
      while (my $obj = $crs->next) {  
        my ($vphenos, $darray, $genes) = Sym::Controller::Service->phenos_by_reagent_id($obj->{rgID},0);
        my ($expID, $countgenes, $countreagent, $phenoprint, $expcode) = ("-","-","-","-","-");
        ($expID, $countgenes, $countreagent, $phenoprint, $expcode) = split(/\|/,$darray) if $darray; 
        my $phenotypes = "-";
          foreach (@{$vphenos}) {
            if ($_ =~/^\S/) {
              my ($ph,$m) = split(/\|/,$_);
              $phenotypes .= $ph .":".$m if $m;
            }
          }
        unless ($f) {
            if ($genes) {
              foreach my $g (split(/\|/,$genes)) {
                my ($ensGID, $symbol) = split(/\:/,$g);
                $symbol = $symbol ? $symbol : "-";
                $export .= $obj->{rgID}." \t".$supname." \t".$obj->{seq2}." \t$ensGID \t$symbol \t".$phenotypes." \t".$countreagent." \t".$expcode."\n";
              }
            } else {
                $export .= $obj->{rgID}." \t".$supname." \t".$obj->{seq2}." \t- \t".$phenotypes." \t".$countreagent." \t".$expcode."\n";
            }
        } else {
            my $sgenes;
            if ($genes) {
              foreach my $g (split(/\|/,$genes)) {
                my ($ensGID, $symbol) = split(/\:/,$g);
                $symbol = $symbol ? $symbol : "-";                
                my $sgenes .= "$ensGID:$symbol, " 
              }
              $sgenes = substr($sgenes,0,-2);
              $export .= $obj->{rgID}." \t".$supname." \t".$obj->{seq2}." \t$sgenes \t".$phenotypes." \t".$countreagent." \t".$expcode."\n";
            } else {
              $export .= $obj->{rgID}." \t".$supname." \t".$obj->{seq2}." \t- \t".$phenotypes." \t".$countreagent." \t".$expcode."\n";
            } 
        }
      }
    $self->res->headers->content_type('plain/text');
    $self->res->headers->header('Cache-Control' => 'max-age=1, no-cashe');  
    $self->render(data=>$export,format=>"csv");
  } else {
      $self->render();
  }    
}

1;