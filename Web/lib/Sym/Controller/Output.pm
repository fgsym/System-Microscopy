package Sym::Controller::Output;
use strict;
use base 'Mojolicious::Controller';
# Render template "/output/main.html.ep"
# url from     : /
#                Sym::Model::MongoQ->get_all_screens
# collections	: Experiments, PhenoAnalysis
sub main {
  my $self = shift; 
  $self->render();
}
sub stats {
  my $self = shift;
  my $r="75";
  my $obj = Sym::Model::MongoQ->get_stats($r);
  $self->render(obj => $obj);
}
# url from     : /phenotypes/
# collections	: Studies, ProcessedData
# phenotypes hash by $title."|".$ScrID."|".$type key and inner $phname."__".$phID key (to sort by phenotypes name)
sub phenotypes {
  my ($self,$genome, $class) = @_;
  my @cookies = $self->cookie('genome');
  my $cookie = $cookies[0] ? $cookies[0] : "";
  $genome = $self->param('genome') ? $self->param('genome') : $cookie ? $cookie : "HMSPNSgenes";
  ($genome,$cookie) = split(/\-\-/,$genome);
  my %phenohash = %{ Sym::Controller::Phenotypes->get_all_phenotypes($genome) }; #  $phenohash{"${$_}{phID}__$ScrID"} = ${$_}{"phNAME"}."|".$ScrID."|".$ScrType."|".$StdTitle
  my %namephenos;
  foreach ( keys %phenohash ) {
    my ($phname, $ScrID, $type, $title, $key) = split(/\|/,$phenohash{$_});
    my ($phID,$ScrID_) = split(/__/,$_);
    ${$namephenos {$title."|".$ScrID."|".$type}}{$phname."__".$phID} = $phname;
  } 
  unless ($class) {
    $self->render(phenotypes=>\%namephenos, genome=>$genome);
  } else {
    return \%namephenos;
  }
}  
# url from     : /oterms/
# collections : Studies, ProcessedData
sub oterms {
  my ($self,$genome, $class) = @_;
  my @cookies = $self->cookie('genome');
  my $cookie = $cookies[0] ? $cookies[0] : "";
  $genome = $self->param('genome') ? $self->param('genome') : $cookie ? $cookie : $genome ? $genome : "HMSPNSgenes";
  my $coo;
  ($genome,$coo) = split(/\-\-/,$genome);
  my $q="";
  my ($tree, $onames, $phenos, $kids, $synonyms, $ophcodes, $id_kids) = Sym::Controller::Ontologies->ontotree($q,$genome);
  unless ($class) {
    $self->render(tree=>$tree, onames=>$onames, phenos=>$phenos, kids=>$kids, synonyms=>$synonyms, ophcodes=>$ophcodes, genome=>$genome);
  } else {
    return $tree;
  }
}
# Render template "/output/oligos.html.ep"
# methods 	: Sym::Model::MongoQ->get_phenotypes_by_countreagent_and_ScrID
# collections	: PhenoAnalysis
sub oligos {
  my $self = shift;
  my $oparam = $self->param('id');
  my ($expID,$oln) = split(/\:/,$oparam);
  if ($oln) {
     my $crs = ($oln > 0) ? Sym::Model::MongoQ->get_phenotypes_by_countreagent_and_ScrID($oln,$expID) : "";
     $self->render(crs => $crs, oln => $oln,  "expr" => $expID);
  } else {    $self->render(crs => "", oln => "", "expr" => "") }
}
# Render template "/output/phenoshow.html.ep"
# url from     : /phenoshow/ (from /output/pheno.html.ep)
# methods 	: Sym::Controller::Service->gene_to_phenoprint
# collections	: PhenoAnalysis
sub phenoshow { 
  my $self = shift;
  my $phd = $self->param('did');
  my $crs; my $obj;
  if ($phd) {
    $crs = Sym::Model::MongoQ->get_phenotypes_set_by_id($phd);
    $obj = $crs->next;    
  }
  my $extend = ($self->param('extend') eq "true") ? "true" : "false";
  if ($obj) {
    my ($withgenes, $nogenes) = Sym::Controller::Service->gene_to_phenoprint($obj);
    $self->render(withgenes => $withgenes, nogenes => $nogenes, obj => $obj,phIDs=>"", extnd=>$extend);
  } else {
    $self->render(withgenes => "", nogenes => "", obj => "",phIDs=>"", extnd=>"");
  }
}  
# Render template /output/screen.html.ep
# url from     : /screen
# methods 	: Sym::Model::MongoQ->get_experiment_by_code
# collections	: Experiments
sub study {
  my $self = shift;
  my $StdID = @{$self->req->url->path->parts}[1];
  my $crs = Sym::Model::MongoQ->get_Study_by_StdID($StdID);
  my $zip_crs = Sym::Model::MongoQ->get_grid_metas($StdID,"zip");
  my $idf_crs = Sym::Model::MongoQ->get_grid_metas($StdID,"idf");
  my ($StdTitle,$cases);
  my $obj = $crs->next;
  my $idf_obj = $idf_crs->next;
  my %std_zip;
  while (my $o = $zip_crs->next ) {
    $std_zip{ $o-> {ScrID} } = $o;
  }
  $self->render( obj=>$obj, idf_obj=>$idf_obj, std_zip=>\%std_zip);
}
#
sub replica {
  my $self = shift;
  my ($rgID,$ScrID,$ensgid,$symbol) = split (/\:/,@{$self->req->url->path->parts}[1]);
  my $crs = Sym::Model::MongoQ->get_replica_by_rgID_and_ScrID($rgID,$ScrID);
  my $scrs = Sym::Model::MongoQ->get_Study_by_ScrID($ScrID);
  if ($ScrID) {
    my $sobj = $scrs->next;
    my %mkeys;  # measurements
    my $ScrScMethod;
    my $ScrType;
    my %ScrPhRules;
    my $genome;
      if ($sobj) {
        foreach my $sd (@{$sobj->{ScreenData}}) {
          if (${$sd}{ScrID} eq $ScrID) {
              foreach (@{${$sd}{ScrColmns}}) {
                  $mkeys{ ${$_}{ScrColmnShrt} } = ${$_}{ScrColmnD} ? ${$_}{ScrColmnD} : ${$_}{ScrColmnN} if ${$_}{ScrColmnT} eq "Score";
              }
              $ScrScMethod = ${$sd}{ScrScMethod};
              $ScrType = ${$sd}{ScrType};
              $genome = ${$sd}{ScrCollection};
              foreach (@{${$sd}{ScrPhenotypes}}) {
                $ScrPhRules{ ${$_}{ScrPhName}  } = ${$_}{ScrPhScRules}; 
              }  
          }  
        }
      }
      my @all = $crs->all;
      warn scalar @all;
      $self->render(rgID=>$rgID, all=>\@all, ScrID=>$ScrID, StdTitle=>$sobj->{StdTitle}, mkeys=>\%mkeys, ScrType=>$ScrType,
              ScrScMethod=>$ScrScMethod, ScrPhRules=>\%ScrPhRules,ensgid=>$ensgid,symbol=>$symbol,genome=>$genome);
      } else {
      $self->render(rgID=>"", all=>"", ScrID=>"", StdTitle=>"", mkeys=>"", ScrType=>"", ScrScMethod=>"", ScrPhRules=>"",ensgid=>"",symbol=>"", genome=>"");
      }    
}

sub submit {
  my $self = shift;
  $self->render();
}

sub messages {
  my $self = shift;
  my $name = $self->param('name');
  my $inst = $self->param('inst');
  my $msg = $self->param('msg');
  my $email = $self->param('email');
  if ($self->param('delete')) {
      my @ids = $self->param('delete');
      foreach (@ids) {
        Sym::Model::MongoQ->delete_message($_);
      }  
  }  
  if ($self->checkinput($name) && $self->checkinput($inst) && $self->checkinput($msg) && $self->checkinput($email)) {
    warn $email;
    Sym::Model::MongoQ->insert_msg($name,$inst,$email,$msg);
  }
  my @msgs = @{Sym::Model::MongoQ->get_messages()};
  $self->render(msgs=>\@msgs);
}

sub checkinput {
  my ($self,$val) = @_;
  return 1 if ($val =~/(\d+|\w+|\s+|\.|\;|\,|\?|\!|\-)/);
  return 0;
}

sub about {
  my $self = shift;
  my @msgs = @{Sym::Model::MongoQ->get_messages()};
  my $ref = ($#msgs >= 0) ? \@msgs : 0;
  $self->render(msgs=>$ref);
}

sub reg {
  my $self = shift;
  my $nick= $self->session('login') ? $self->session('login') : "";
  my $msg = $self->session('login') ? ", but you are in... what are you doing here?" : "Wanna to register?.. hm-hm...";
  $self->render();
}

sub glossary {
  my $self = shift;
  # Render template "output/index.html.ep" with message
  my ($nick,$msg) = Sym::Controller->take_session(); 
  $self->render();
}

sub errordb {
    my $self = shift;
    $self->render( error => "Oh! Awfully sorry, but something wrong with DB connection" );
}
sub not_found {
    my $self = shift;
    $self->render( nothing => "Oh! sorry, but I cannot find what you ask for" );
}
1;