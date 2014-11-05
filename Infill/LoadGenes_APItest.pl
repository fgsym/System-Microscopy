#!/usr/local/bin/perl
# load gene and transcripts data 
# Ensemble release 04-2011 GRCh37.70
use lib "../BioPerl/ensembl/modules/";
use lib "../BioPerl/bioperl-live/";
use Bio::EnsEMBL::Registry;
use Bio::SeqIO;
my $version = 75;
my $reg = 'Bio::EnsEMBL::Registry';
$reg->no_version_check(1);
$reg-> load_registry_from_db(
                 -host=>'ensembldb.ensembl.org', -user=>'anonymous',-port=>'5306', -db_version=>$version
);
my $ga = $reg-> get_adaptor('Human', 'Core', 'Gene');
my $ontology_term_adaptor = $reg->get_adaptor('Multi','Ontology','OntologyTerm');

    my $ensGID = "ENSG00000105146";
    my $gene = $ga->fetch_by_stable_id($ensGID);
    my %exons;
    my @transcripts;
    foreach my $tr (sort @{ $gene-> get_all_Transcripts }) {
      my @GO;
      my @InterPro;
	  foreach my $link (@{$tr->get_all_DBLinks('GO')}) {
         # map {print $_."\n" } keys %{$link};
         my $go_term = $ontology_term_adaptor->fetch_by_accession($link->display_id);
         #map {print $_."\n" } keys %{$go_term};
         if ($go_term->name) {
           print $go_term->name;
         }  
      }
	}