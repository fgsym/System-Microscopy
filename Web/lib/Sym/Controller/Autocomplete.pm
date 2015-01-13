package Sym::Controller::Autocomplete;
use strict;
use base 'Mojolicious::Controller'; 
use JSON;
use vars qw(%GLV);
*GLV = \%Sym::GLV;
# for genes search (see jquery.autocomplete.css / jquery.autocomplete.js & id="#g" in layout/default.html.ep + search/search_form.html.ep)
# call from	: search/search_form.html.ep
# methods 	: Sym::Model::MongoQ->get_gene	
# collections	: HMSPNSgenes
sub genefilter {
  my $self = shift;
  my $q = $self->param('string');
  # map {warn $self->param($_)} $self->param();
  # my $crs = $genes->query({"symbol" => qr/^$q/},{"symbol" => 1});
  my @cookies = $self->cookie('genome');
  my $cookie = $cookies[0];  
  $GLV{G} = $self->param('genome') ? $self->param('genome') : $cookie ? $cookie : "HMSPNSgenes";  
  my $coo;
  ($GLV{G},$coo) = split(/\-\-/,$GLV{G});   
  my $crs = Sym::Model::MongoQ->get_gene($q,$GLV{G},100);
  my @symbols; 
  my @json;
  my $lcq = lc($q);
  my $ucq = uc($q);
  my $ucfq = ucfirst($lcq);
  my $lcfq = lcfirst($ucq);   
  while (my $obj = $crs->next) {
    if ($obj->{"symbol"}=~/($q|$lcq|$ucq|$ucfq|$lcfq)/ || $obj->{"ensGID"}=~/($q|$lcq|$ucq|$ucfq|$lcfq)/) {
      my %loc;
      $loc{name} = $obj->{"symbol"} ? $obj->{"symbol"} : " - ";
      $loc{title} = "name";
      $loc{id} = $obj->{"ensGID"};
      push @json,\%loc;
    }
    foreach (@{$obj->{"synonyms"}}) {
      if ($_=~/($q|$lcq|$ucq|$ucfq|$lcfq)/) {
        my %loc;
        $loc{name} = $_ ? $_ : " - ";
        $loc{title} = "synonym";
        $loc{id} = $obj->{"ensGID"};
        push @json,\%loc;
      } 
    }
  }
  my $j = \@json;
  my $json_text = encode_json $j;
  $self->render(json => \@json); 
  # $self->render(text => $resp, format => 'txt');
}

sub phenofilter {
  my $self = shift;
  my $q = uc($self->param('string'));
  my $StdID = $self->param('StdID');
  my $phstr = $self->param('phn');
  my @phenos = split(/\,/,$phstr) if $phstr;
  my $crs;
  my $ThisStdID;
  my %ph_by_ScrID;  
  my $genes =0;
  if (scalar @phenos > 0) {
    my $ScrID;
    my @phNAMEs;
    map { 
        my $phID; ($phID,$ScrID) = split(/__/,$_); 
        push @{$ph_by_ScrID { $ScrID } }, $phID;        
        $ThisStdID = substr($ScrID, 0,-2);
        push @phNAMEs,$phID if ($ThisStdID eq $StdID);
        } @phenos;
    $ThisStdID = substr($ScrID, 0,-2);
    if ($ThisStdID eq $StdID) {
      $crs = Sym::Model::MongoQ->get_phenotypes_by_their_set_and_ScrID_by_NAME($ScrID,\@phNAMEs,$q);
    } else {
# StdID = 0 here;      
     # my @cgenes =  @{Sym::Controller::Genes->genesdistPHC(\%ph_by_ScrID)};
     $crs = Sym::Model::MongoQ->get_phenotype_by_NAME($q,$StdID,100);
    }
  } else {  
    $crs = Sym::Model::MongoQ->get_phenotype_by_NAME($q,$StdID,100);  
  }

  my @json;
  my %found;
  while (my $obj = $crs->next) {
    my ($phNAME,$phID,$ScrID); 
    if (scalar @phenos > 0 && $ThisStdID eq $StdID) {
      foreach (@{$obj->{phenotypes}}) {
          $ {$found { $obj->{ScrID}."|".$obj->{ScrType} } } { ${$_}{phNAME} } = ${$_}{phID};
      }
    } else {
      $ {$found { $obj->{ScrID}."|".$obj->{ScrType} } } { $obj->{phNAME} } = $obj->{phID};
    }  
  } 
  foreach my $scr (keys %found) {
    foreach my $phNAME ( sort keys %{ $found{ $scr } } ) {
      my ($ScrID,$ScrType) = split(/\|/,$scr);  
      my %loc; 
      $loc{name} = $phNAME;
      $loc{id} = ${ $found{ $scr } } {$phNAME}."__".$ScrID;
      $loc{value} = ${ $found{ $scr } } {$phNAME}."__".$ScrID;      
      $loc{screen} = $ScrType;
      $loc{genes} = $genes;
      push @json,\%loc;
    }
  } 
  my $j = \@json;
  my $json_text = encode_json $j;
  # $self->res->headers->content_type('application/json'); 
  $self->render(json => \@json); 
}

# for attributes search (see jquery.autocomplete.css / jquery.autocomplete.js & id="#o" in layout/default.html.ep + search/search_form.html.ep)
# call from	: search/search_form.html.ep
# methods 	: Sym::Model::MongoQ->get_gene_by_attribute	
# collections	: HMSPNSgenes
sub attribute {
  my $self = shift;
  my $attr = $self->param('goon');
  my $q = $self->param('string');
  my @cookies = $self->cookie('genome');
  my $cookie = $cookies[0];  
  $GLV{G} = $self->param('genome') ? $self->param('genome') : $cookie ? $cookie : "HMSPNSgenes";   
  my $coo;
  ($GLV{G},$coo) = split(/\-\-/,$GLV{G});  
  my @json;
  # my $crs = $genes->query({"symbol" => qr/^$q/},{"symbol" => 1});
  my $crs = Sym::Model::MongoQ->get_gene_by_attribute($q,$GLV{G},0,50);
  my @symbols; 
  my %goterm;
  while (my $obj = $crs->next) {
    foreach my $t ( @{ $obj->{transcripts} } ) {
      my $lcq = lc($q);
      my $ucq = uc($q);
      my $ucfq = ucfirst($lcq);
      my $lcfq = lcfirst($ucq);     
      map { $goterm{$_->{GOdesc}} .= $t->{ensTID}.", " if ($q && $_->{GOdesc} =~/($q|$lcq|$ucq|$ucfq|$lcfq)/ ) } @{ $t->{GO} };
    }
  }
  @symbols = sort keys %goterm;
  map { my %loc; $loc{name} = $_; $loc{id} = $_; push @json,\%loc; } @symbols;
  my $j = \@json;
  my $json_text = encode_json $j;
  $self->render(json => \@json);   
}

sub ontofilter {
  my $self = shift;
  my $qp = $self->param('string');
  my $ostr = $self->param('ont');
  my @cookies = $self->cookie('genome');
  my $cookie = $cookies[0];  
  $GLV{G} = $self->param('genome') ? $self->param('genome') : $cookie ? $cookie : "HMSPNSgenes";  
  my $coo;
  ($GLV{G},$coo) = split(/\-\-/,$GLV{G}); 
# warn $self->param();
  my @jsonhash = @{$self->html_tree($qp,$GLV{G})};
  my $j = \@jsonhash;
  my $json_text = encode_json $j;
  $self->render(json => \@jsonhash); 
}


sub html_tree {
  my ($self, $qp, $genome) = @_;
  my ($tree,$onames,$phenos,$kids,$synonyms,$ophcodes,$id_kids) = Sym::Controller::Ontologies->ontotree($qp,$genome);
  my %onames = %{$onames};
  my %ophcodes = %{$ophcodes};
  my %phenos = %{$phenos};
  my %kids = %{$kids};
  my %id_kids = %{$id_kids};  
  my @json;  
  # push @jsonhash,$html;
  $tree=~s/\nbul\neul/NNNN/gsm;     # no children for this item of DAG
  my $id;
  my $uid;
  my $div_class;
  my %phnames;
  my $oph; 
  my %seen_id;
  # warn $tree;
  my $deep = "z";
  my %offrepeats;
  foreach my $l (split(/\n/,$tree)) {
    my %loc; 
    my $code = $ophcodes{$id};      #### because cycle begin with <li> and we must have next <ul> open that corresponds to this <li>! thus $code must be assigned here.
    if ($l =~/li/) {
      $l =~s/(li|\s)//gsm;
      $id = ($l=~/NNNN/) ? substr($l,0,-6) : substr($l,0,-2);
      $uid = ($l=~/NNNN/) ? substr($l,0,-4) : $l;
      $oph = $onames{$id};
      $oph =~s/phenotype$//gsm;
      $id = ($l=~/NNNN/) ? substr($l,0,-6) : substr($l,0,-2);
      $code = $ophcodes { $id }; 
      $div_class = $code ? "o" : "e";  
        if ($kids{$id} && $l!~/NNNN/) { 
          $loc{div} = $div_class;
        } else {
          $l=~s/NNNN//gsm;
          $loc{div} = "";
        }
      my $phcode;
      my @phs;
      foreach (@{$phenos{$id}}) {
          push @phs, $_->{phID}."__".$_->{ScrID};
      }
      $phcode = scalar @phs ? join(",",@phs) : "";
      # warn $phcode if ( $id eq "CMPO:0000051");       
      $loc{name} = $oph;
      $offrepeats{$oph}++;
      $loc{value} = $phcode;
      $loc{class} = $deep;
      $loc{kids} = $id_kids{$uid} ? scalar $id_kids{$uid} : 0;
      $loc{id} = $phcode;
    } elsif ($l =~/bul/) {
        $l =~s/bul//gsm;
        my $display = $code ? "block" : "none";
        # $loc{name} = qq|<ul style="display: $display">$l|;
        $loc{name} = "BUL";
          $loc{div} = "BUL"; 
        $loc{id} = "-";      
        $deep .= "z";
    } elsif ($l =~/eul/) {
        $l =~s/eul//gsm;
        $loc{name} = "EUL";
          $loc{div} = "EUL"; 
        $loc{id} = "-";
        $deep = substr($deep,0,-1);
    } 
    push @json,\%loc if ($loc{name} && $offrepeats{$loc{name}} && $offrepeats{$loc{name}} ==1);
  }  
  return (\@json);
}