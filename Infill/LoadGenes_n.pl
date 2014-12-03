#!/usr/local/bin/perl
# load gene and transcripts data 
# Ensemble release 04-2011 GRCh37.70
use lib "../BioPerl/ensembl/modules/";
use lib "../BioPerl/bioperl-live/";
use Bio::EnsEMBL::Registry;
use Bio::SeqIO;
my $version = 77;
    my $reg = 'Bio::EnsEMBL::Registry';
    $reg->no_version_check(1);
    $reg-> load_registry_from_db(
	   -host=>'ensembldb.ensembl.org', -user=>'anonymous',-port=>'5306', -db_version=>$version
        # -host => 'ensembldb.ensembl.org', -user => 'anonymous'
    );

# Auto-configure the registry
use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
print "Gene Load Ensembl version $version start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017") or print "\n".$!;
    my $db   = $conn->get_database( 'sym' );
    my $genes = $db->get_collection( 'HMSPNSgenes' );
    my $spc = $db->get_collection( 'Species' );     
    $genes->drop;
    my %ensIDs;
my $ga = $reg-> get_adaptor('Homo Sapiens', 'Core', 'Gene');    
my $sa = $reg-> get_adaptor('Homo Sapiens', 'Core', 'Slice');
my $dba = $reg->get_adaptor('Homo Sapiens', 'Core', 'DBentry');
# my $go = $reg->get_adaptor('Human', 'Ontology', 'GOTerm');
my $ontology_term_adaptor = $reg->get_adaptor('Multi','Ontology','OntologyTerm');
my @genes=();
my %genes;
my %syns;
my $cntG=0;
# source;adaptor;stable_id;status;external_name;slice;dbID;is_current;display_xref;strand;version;description;biotype;end;external_status;external_db;start;

foreach my $s ( sort @{ $sa->fetch_all('toplevel') } ) {
  foreach my $g ( sort @{$s->get_all_Genes()} ) {
        # my $s = $dba->fetch_by_dbID($g->display_xref->dbID);
	   # foreach my $syn (@{$s->get_all_synonyms}) {                      NOT ALL SYNONYMS HERE FOR $g->external_db DB!
			 # print "\t".$syn."\n";
	   # }   
	my @syns;
	my $gene = $ga-> fetch_by_stable_id($g->stable_id);
		foreach my $link (@{$gene->get_all_DBEntries()}) {
		  # push(@syns,@{$link->get_all_synonyms}) if $link->dbID == $g->display_xref->dbID;        RESULT HERE the same that above
		  push(@syns,@{$link->get_all_synonyms}) if ($link->dbname eq $g->external_db);
		}
	my @transcripts = @{transcripts_and_exons_by_gene($g->stable_id())};
	my $cname = $g->slice->seq_region_name;
	
	$g = $g->transfer($sa->fetch_by_region('toplevel', 'Y')) if $cname eq "Y";
	
	print $g->start()."..".$g->end()."\n" if $g->stable_id eq "ENSG00000197038";
     my $ensGID = $g->stable_id();
     $genes->insert( { 
		"dbID" => $g->dbID(),
		"ensGID" => $g->stable_id(),
		"biotype" => $g->biotype(),
		"coordname" => $g->coord_system_name(),
		"coord" => "$cname",
		"start" => $g->start(),
		"end" => $g->end(),
		"strand" => $g->strand(),
		"status" => $g->status(),
		"symbol" => uc($g->external_name()),
		"description" => $g->description(),
		"synonyms" => [@syns],
		"transcripts" => [@transcripts]
      } );
      $cntG++;
      my $report = ($cntG%10000 == 0)?"$cntG genes loaded \n":"";
      print $report if $report;
   }
   print "Slice ".$s->name." loaded\n"; 
}      
print "$cntG genes loaded \n";
  $spc->insert( {
    name => "Homo Sapiens",
    aliases => ["Human", "Homo Sapiens"],
    collection => "HMSPNSgenes",
    genecount => $cntG,
    release => $version
  });
print "end: ".showtime()."\n";

#
#    GET transcripts
#
sub transcripts_and_exons_by_gene {
    my ($ensGID) = @_;
    my $gene = $ga-> fetch_by_stable_id($ensGID);
    my %exons;
    my @transcripts;
    foreach my $tr (sort @{ $gene-> get_all_Transcripts }) {
      my @GO;
      my @InterPro;
	    foreach my $link (@{$tr->get_all_DBLinks('GO')}) {
         my $go_term = $ontology_term_adaptor->fetch_by_accession($link->display_id);
         if ($go_term && $go_term->name) {
           my $go = {"GOid"=>$go_term->accession, "GOdesc"=>$go_term->name, "GOnamespace"=>$go_term->namespace};
           my $checkuniq =0;
           map {$checkuniq = 1 if (${$_}{"GOid"} eq $link->primary_id) } @GO;
           push @GO,$go unless ($checkuniq == 1);
         }  
      }
    if ($tr->translation) {
      foreach my $f (@{$tr->translation->get_all_DomainFeatures}) {
         if($f->interpro_ac){
             my $db_entry = $dba->fetch_by_db_accession('Interpro',$f->interpro_ac);
             my $inp = {"Iac"=>$f->interpro_ac, "Idesc"=>$f->idesc, "Desc"=>$db_entry->description};
             my $checkuniq=0;
             map {$checkuniq = 1 if (${$_}{"Iac"} eq $f->interpro_ac)} @InterPro;
             push @InterPro,$inp unless $checkuniq == 1;
         }       
      }
	  }
	 
      my @exons;
      my ($st,$end) = ($tr->strand == -1) ? ($tr->length,$tr->length) : (1,1);
      my %exons_bc; # exons to be sorted by start coordinate
      foreach my $exon (sort @{ $tr-> get_all_Exons }) {
        $exons_bc{$exon->start} = $exon;
      }  
      foreach my $e (sort {$a <=> $b} keys %exons_bc) {
        my $exon = $exons_bc{$e};
        # relative coords on merged transcript:
        if ($tr->strand == -1) {
          $end = $st != $tr->length ? $st - 1 : $tr->length;
          $st =  1+$end - $exon->length;
        } else {
          $st = $end != 1 ? $end + 1 : 1;
          $end = $st + ($exon->end - $exon->start);
        }        
        my %exon = (
          "ensEID" => $exon->stable_id,
          "startE" => $exon->start,
          "endE" => $exon->end,
          "startRE" => $st,
          "endRE" => $end,
          "strandE" => $exon->strand
        );
        push (@exons, \%exon);
      }      
      my %trscr = (
        "ensTID" => $tr->stable_id,
        "statusT" => $tr->status,
        "startT" => $tr->start,
        "endT" => $tr->end,
        "lengthT" => $tr->length,
        "strandT" => $tr->strand,
        "seqT" => $tr->seq->primary_seq->seq,
        "translation" => $tr->translation ? $tr->translate->seq : "",
        "exons" => [@exons],
        "InterPro" => [@InterPro],
        "GO" => [@GO]
        );
        push(@transcripts, \%trscr);
    }
    return \@transcripts;
}  
#
#    Timer
#
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
# create indexes for fields upon which keys are looked up (see MongoDBx::AutoDeref for DBRef & http://www.mongodb.org/display/DOCS/Database+References)
# index data db.HMSPNSgenes.ensureIndex({ID:1})
