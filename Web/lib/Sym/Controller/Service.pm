package Sym::Controller::Service;
use strict;
use GD;
use vars qw(%GLV);
*GLV = \%Sym::GLV;
use base 'Mojolicious::Controller';

# use v5.10;
# call from	: Output::phenoshow
#                Search::phenoparams 
#                search/loadpheno.html.ep
#                search/respheno.html.ep
# collections	: PhenoAnalysis
sub gene_to_phenoprint {
  my ($self,$obj) = @_;
      my %withgenes; my %nogenes;
      my %sorted;
      my $g=0;
      foreach (@{$obj->{"cases"}} ) {
        my %hash = %{$_};
        # if ($extend==1) {
          $sorted{ $hash{howgood}.$g } = \%hash; # if $hash{goodmatch}==1;
        # } else {
          # $sorted{ $hash{howgood}.$g } = \%hash if ($hash{goodmatch}==1 && $hash{howgood} >= 0.5);
        # }  
        $g++;
      }
      foreach ( sort {$b <=> $a} keys %sorted) {
        my %hash = %{ $sorted{$_} };
        my $genes = "";
        my @agenes; 
        # actualy here scalar @{$hash{genes}} = 1||0 because $hash{goodmatch}==1;
        if (scalar @{$hash{genes}} == 1) {
          map { $hash{symbol} = ${$_}{symbol} ? ${$_}{symbol} : ${$_}{ensGID};  $hash{ensGID} = ${$_}{ensGID} } @{$hash{genes}};
        }
        if ($hash{symbol}) {
          $withgenes{ $hash{symbol}."#".$hash{probeID} } = \%hash;
        } else {	
          # warn $hash{probeID}."|".$hash{probeID}."|".$hash{rgID};
          $nogenes{ "#".$hash{probeID} } = \%hash; 	
        }
      }
  return (\%withgenes, \%nogenes);
}
# call from	: Output::export
# methods 	: Sym::Model::MongoQ->get_phenotypes_by_rgID
#                Sym::Model::MongoQ->get_Study_by_ScrID
# collections	: Experiments, PhenoAnalysis
sub phenos_by_reagent_id {
  
#### see  Sym::Controller::Phenotypes->phenotypes_by_rgID !!
  my ($self,$id) = @_;
  my $mcrs = Sym::Model::MongoQ->get_phenotypes_by_rgID($id);
  my $mobj = $mcrs->next;
  my @phenos;
  my $meas;
  my $expID = $mobj->{expID};
  my $ecrs = Sym::Model::MongoQ->get_Study_by_ScrID($expID);
  my $eobj = $ecrs->next;
  my $darray = $mobj->{expID}."|".$mobj->{ucountgenes}."|".$mobj->{countreagent}."|".$mobj->{phenoprint}."|".$eobj->{expCode} if $expID;
  my $genes;
  foreach (@{$mobj->{"cases"}} ) {
    if (${$_}{rgID} eq $id) {
        my @genes = @{ ${$_}{genes} };
        foreach (0 .. $#genes) {
          my %g = %{ $genes[$_] };
          $genes .= $g{ensGID}."=".$g{ensGID}."|";
        }
        $meas = ${$_}{reproduced} ? ${$_}{reproduced} : ${$_}{scores};
    } 
  }
  $genes = $genes ? substr($genes,0,-1) : "";
  foreach (0 .. $#{$mobj->{"phenotypes"}}) { 
      my %hash = %{ @{$mobj->{"phenotypes"}}[$_] };
      push (@phenos,ucfirst($hash{phNAME}));
  }
  my @vphenos;
  for (0 .. $#phenos) {
      push (@vphenos,$phenos[$_]."|".@$meas[$_]);
  }  
  return (\@phenos, $darray, $genes);
}
# generate phenotypes title for /search/pheno pages
# call from	: output/phenoAshow.html.ep
#                search/attributes.html.ep  
#                search/phintersect.html.ep
# methods 	: Sym::Model::MongoQ->get_Study_by_ScrID
# collections	: Experiments
sub generate_list {
    my ($self,$phenos) = @_;
    # whether the are ontology terms (0) or phenotype terms (1) here for the view;
    my ($phenoprint,$phenochosen,$terms) = split (/\:/,@{$self->req->url->path->parts}[1]);
    # warn ($phenoprint,$phenochosen,$ScrID);
    my @phIDs = split(/\-/,$phenoprint);
    my @cphIDs = ();
    @cphIDs = split(/\-/,$phenochosen) if ($phenochosen && $phenochosen ne "_");
    my (%phIDs,%cphIDs);
    my %pheno_in_screen;
    
    map { my ($pID,$ScrID) = split(/__/,$_); $pheno_in_screen{$ScrID} .= $pID."-" } @phIDs;

    my @db_phenos = @{ Sym::Model::MongoQ->get_phenotypes_by_ScrID() }; # we have ${$p}{phID}, ${$p}{ScrID}, ${$p}{phNAME} as results here
    my %onts = ($terms eq "p") ? () : %{Sym::Controller::Ontologies->get_oterms()};
    foreach my $p (@db_phenos) {
      my $name = ${$p}{phNAME};
      my ($phID, $sID) = (${$p}{phID}, ${$p}{ScrID});
      $name = $self->ontname($phID, $sID, \%onts) if ($terms eq "o");
      foreach my $s (keys %pheno_in_screen) {
          my $ph = substr($pheno_in_screen{$s},0,-1); # ${$_}{phID}
          grep { $phIDs{ $name."__".$phID."__".$s } = $phID."__".$s if ($_ eq $phID && $sID eq $s) } split(/\-/,$ph);
      }
    } 
    my $width =26*(scalar keys %phIDs)+100;
    my $img = new GD::Image($width,95);
    my $white = $img->colorAllocate(247,247,247);
    my $black = $img->colorAllocate(0, 0, 0);
    my $green = $img->colorAllocate(50, 114, 100);
    my $lightgrey = $img->colorAllocate(255, 255, 255);
    my $grey = $img->colorAllocate(180, 180, 180);
    my $font = $GLV{CONFIG}->{boldfont};
    my $n = 0;
    foreach my $p (sort keys %phIDs) {
      my ($name,$ph,$s);
        ($name,$ph,$s) = split(/__/,$p);
        # warn $name;
        $name = (length($name) > 20) ? ucfirst(substr($name,0,20))."…" : ucfirst($name);
      my $x= 10 + 26*$n;
      my $color = $black;
      grep { $color = $green if ($phIDs{$p} eq $_);  } @cphIDs;
      $img->stringFT($color, $font, 8, 0.785, $x+2, 92, $name); # font-size, angle, x, y, $_
      $img->line($x+15,94,$x+15,85,$grey);
      $img->line($x+15,85,$x+95,5,$grey);
      $n++;
    }
  # $img->transparent($white);
  $img->interlaced('true');  
  # $self->res->headers->content_type('image/png');
  # $self->res->headers->header('Cache-Control' => 'max-age=300, must-revalidate, private');
  $self->render(data => $img->png, format => 'png');    
}
sub getfile {
  my ($self) = @_;
  my ($type,$desc,$ID) = split (/\:/,@{$self->req->url->path->parts}[1]);
  if ($type eq "zip") {
    my $file = Sym::Model::MongoQ->get_zip($ID);
    $file = $file->slurp();
    $self->res->headers->content_type('application/zip');
    $self->res->headers->header('Cache-Control' => 'max-age=300, must-revalidate, private');
    $self->res->headers->content_disposition('attachment; filename='.$desc.'_'.$ID.'.zip');
    $self->render(data => $file); 
  } elsif ($type eq "idf") {
    my $file = Sym::Model::MongoQ->get_idf($ID);
    $file = $file->slurp();
    $self->res->headers->content_type('application/csv');
    $self->res->headers->header('Cache-Control' => 'max-age=300, must-revalidate, private');
    $self->res->headers->content_disposition('attachment; filename='.$desc.'_'.$ID.'.csv');
    $self->render(data => $file); 
  } elsif ($type eq "template") {
    my $file = Sym::Model::MongoQ->get_study_template($desc);
    $file = $file->slurp();
    $self->res->headers->content_type('application/csv');
    $self->res->headers->header('Cache-Control' => 'max-age=300, must-revalidate, private');
    $self->res->headers->content_disposition('attachment; filename='.$desc.'.csv');
    $self->render(data => $file); 
  }
} 
sub ontname {
  my ($self, $pID, $sID, $onts) = @_;
  my $name;
  my %onts = %{$onts};
  # warn $pID."__".$sID;
  my @ont_array = $onts{ $pID."__".$sID } ? @{ $onts{ $pID."__".$sID } } : ();
  my @onames;
  # warn scalar @ont_array;
    if (scalar @ont_array>0) {
        foreach my $oi (@ont_array) {
          my ($OntID,$oname,@syns) = split(/__/,$oi);
          $oname =~s/phenotype$//gsm if $oname;
          push @onames, $oname;
          if (@syns) {
            map { $_ = ucfirst($_) } @syns; 
            # push @onames, " synonyms: ".join(",",@syns).")";
          }
        }
      $name = join(", ",@onames);
      # warn  $name.">>".$pID."__".$sID if $sID eq "B1_SyM_2";
    }    
  $name =~s/\s$//gsm if $name;  
  return $name ? $name : ": Terms is not assigned";      
} 
1;
