package Sym::Model::MongoQ;
use strict;
use vars qw(%GLV);
*GLV = \%Sym::GLV;
#
# All queries to MongoDB are here! Controller method(s) is(are) given before corresponding Model methods	
#
sub get_all_screens {
	my ($self,$genome,$StdID) = @_;
  	$genome = $genome ? $genome : "HMSPNSgenes";
	my $crs = $StdID ? $GLV{Std}->find({StdID=>$StdID,"ScreenData.ScrCollection"=>$genome}) : $GLV{Std}->find({"ScreenData.ScrCollection"=>$genome})->sort({StdID => 1});
	if ($StdID) {
		 return $crs;
	} else {
		my @all = $crs->all;
		return \@all;
	}	
}
#2 
sub get_phenotypes_slicecount_by_ScrID {
	my ($self,$ScrID) = @_;
	return $GLV{DB}->run_command([ distinct=>"ProcessedData",key=>"slicecount", query => {StdID => $ScrID}  ]);
}
#3 
sub get_phenotypes_countreagent_by_ScrID {
	my ($self,$ScrID) = @_;
	return $GLV{DB}->run_command([ distinct=>"ProcessedData",key=>"countreagent", query => {StdID => $ScrID}  ]);
}
#4 
sub get_Study_by_ScrID {
	my ($self,$ScrID) = @_;
	$ScrID ? return $GLV{Std}->find({"ScreenData.ScrID"=>$ScrID}) : return $GLV{Std}->find({});
}
#5 
sub get_Study_by_StdID {
	my ($self,$StdID) = @_;
	return $GLV{Std}->query({StdID => $StdID});
}
#6 
sub get_phenotypes_by_ScrID {
	my ($self,$ScrID) = @_;
	my $phenos = $ScrID ? $GLV{DB}->run_command([ distinct=>"ProcessedData",key=>"phenotypes", query =>{ScrID => $ScrID} ]) : 
			$GLV{DB}->run_command([ distinct=>"ProcessedData",key=>"phenotypes", query => { phcluster=>{'$nin'=>["0"]} }  ]); 
	return $phenos->{values};
}
#7 
sub get_phenotypes_by_slicecount_and_ScrID {
	my ($self,$ph,$ScrID) = @_;
	return $GLV{PRC}->find({slicecount => $ph,"cases.goodmatch"=>1, ScrID=>$ScrID})->sort({acountgenes => -1})
}
#8 
sub get_phenotypes_by_countreagent_and_ScrID {
	my ($self,$oln,$ScrID) = @_;
	return $GLV{PRC}->find({countreagent => $oln,"cases.goodmatch"=>1,ScrID=>$ScrID});
}
#9 
sub get_phenotypes_set_by_id {
	my ($self,$id) = @_;	
	my $phd = MongoDB::OID->new(value => $id);
	return $GLV{PRC}->find({"_id" => $phd });	
}
#10 
sub get_all_reagents_by_supplier_prefix {
	my ($self,$supl) = @_;
	$supl ? return $GLV{Reags}->find({prefix => qr/^$supl/}) : return $GLV{Reags}->find({})
}
#11
sub get_supplier_by_prefix {
	my ($self,$supl) = @_;
	return $GLV{Supl}->find({prefix => qr/^$supl/});
}
#12 
sub get_supplier_by_id {
	my ($self,$supID) = @_;
	return $GLV{Supl}->find({SupID => $supID});
}
#13 
sub get_phenotypes_by_rgID {
	my ($self,$id) = @_;
	return $GLV{PRC}->find({"cases.rgID" => $id});
}
#14
sub get_reagent_by_gene_symbol {
	my ($self,$gene) = @_;
	return $GLV{Reags}->query({"tagin.symbol" => "$gene"});
}
#15
sub get_reagent_by_gene_synonyms {
	my ($self,$gene) = @_;
	return $GLV{Reags}->query({"tagin.synonyms" => "$gene"});
}         
#16
sub get_reagent_by_gene_ensGID {
	my ($self,$gene) = @_;
	return $GLV{Reags}->query({"tagin.ensGID" => "$gene"});
} 
#17
sub get_reagent_by_probeID {
	my ($self,$re) = @_;	
	return $GLV{Reags}->query({'$or' => [{probeID => "$re"},{rgID => "$re"}] });
}
#18
sub get_reagent_by_rgID {
	my ($self,$re) = @_;	
	return $GLV{Reags}->query({rgID => "$re"});
}
#19
sub get_gene {
	my ($self,$q,$genome,$limit) = @_;
	my $sort = {symbol => 1,synonyms=> 1};
	$genome = $genome ? $GLV{DB}->get_collection( $genome ) : $GLV{DB}->get_collection( 'HMSPNSgenes' );	
	my $lcq = lc($q);
	my $ucq = uc($q);
	my $ucfq = ucfirst($lcq);
	my $lcfq = lcfirst($ucq);

	( $limit  > 0 ) ? 
	return $genome->query({'$or' => [{synonyms => qr/^($q|$lcq|$ucq|$ucfq|$lcfq)/},{symbol => qr/^($q|$lcq|$ucq|$ucfq|$lcfq)/},{ensGID => qr/($q|$lcq|$ucq|$ucfq|$lcfq)/} ]},
		{symbol=>1,synonyms=>1,ensGID=>1,limit => $limit})->sort($sort)
	: return $genome->query({'$or' => [{synonyms => $q},{symbol => $q},{ensGID => $q } ]},{symbol => 1,synonyms => 1,ensGID=>1})
}
#20
sub get_gene_by_ensGID {
	my ($self,$genome,$ensgid) = @_;
	$genome = $genome ? $GLV{DB}->get_collection( $genome ) : $GLV{DB}->get_collection( 'HMSPNSgenes' );	
	return $genome->query({ensGID => $ensgid});
}
#21
sub get_phenotypes_by_their_set_and_ScrID {
	my ($self,$ScrID,$phIDs,$term) = @_;
	map {$_ = $_*1} @{$phIDs};
	my $phcluster = join("-", sort { $a <=> $b} @{$phIDs});
	my $crs = ($term eq "o") ? $GLV{PRC}->find({ScrID=>$ScrID, "phenotypes.phID"=> { '$in' => [@{$phIDs}] } } ) : 
								$GLV{PRC}->find({ScrID=>$ScrID,"phenotypes.phID"=> { '$all' => [@{$phIDs}] } });
	my @all = $crs->all;
	return \@all;
}
#21.1
sub get_phenotypes_by_cluster_and_ScrID {
	my ($self,$ScrID,$phIDs) = @_;
	map {$_ = $_*1} @{$phIDs};
	my $phcluster = join("-", sort { $a <=> $b} @{$phIDs});	
	my $crs = $GLV{PRC}->find({ScrID=>$ScrID,phcluster=> $phcluster });	
	my @all = $crs->all;
	return \@all;
}
#22
sub get_all_phenotypes_observed {
	my $self = shift;
	return $GLV{PRC}->find({},{phenotypes => 1,ScrID=> 1});   
}
#23
sub get_phenotypes_by_gene_and_reagent_probeID {
	my ($self,$probeID,$ensgid,$full) = @_;	
	return $GLV{PRC}->find({"cases.probeID" => $probeID,"cases.genes.ensGID" => $ensgid})  
}
sub get_phenotypes_by_gene {
	my ($self,$ensgid) = @_;
	return $GLV{PRC}->find({"cases.genes.ensGID" => $ensgid});
}
#24
sub get_reagent_mapping {
	my $self = shift;
	return $GLV{Reags}->query({g_mapfreq => {'$gt' => 0}},{g_mapfreq=>1,rgID=>1});
}
#25
sub get_ontologies {
	my ($self) = shift;
	return $GLV{Onto}->query({});
}
#26
sub get_gene_by_attribute {
	my ($self,$q,$genome,$skip,$limit) = @_;
	my $lcq = lc($q);
	my $ucq = uc($q);
	my $ucfq = ucfirst($lcq);
	my $lcfq = lcfirst($ucq);	
	$genome = $genome ? $GLV{DB}->get_collection( $genome ) : $GLV{DB}->get_collection( 'HMSPNSgenes' );
	return $genome->query({"transcripts.GO.GOdesc" => qr/($q|$lcq|$ucq|$ucfq|$lcfq)/, "phenolist.rgID" => qr/\S/, "phenolist.phenodata.phcluster" => qr/\S/},{symbol=>1,transcripts=>1,ensGID=>1})->skip($skip)->limit($limit);
}
#27
sub count_gene_by_attribute {
	my ($self,$desc,$genome) = @_;
	$genome = $genome ? $GLV{DB}->get_collection( $genome ) : $GLV{DB}->get_collection( 'HMSPNSgenes' );		
	return $genome->count({"transcripts.GO.GOdesc" => qr/$desc/, "phenolist.phenodata.phcluster" => qr/\S/});
}
#28
sub get_ontologies_by_genes {
	my ($self) = @_;
	return $GLV{Onto}->find({},{GOdesc=>1,countgenes=>1})->sort({countgenes => 1})
}
1;
#29
sub get_ontologies_by_genes_and_namespace {
	my ($self,$namespace) = @_;
	return $GLV{Onto}->find({GOnamespace=>$namespace},{GOdesc=>1,countgenes=>1})->sort({countgenes => 1})
}
#30
sub get_phenotypes_by_gene_and_phenotypes {
	my ($self,$ensgid,$phIDs,$ScrID,$genome,$exact) = @_;
	# $exact = ex ? query by exact set of chosen phenotypes : query by the phenotype set as ; 
	$genome = $genome ? $GLV{DB}->get_collection( $genome ) : $GLV{DB}->get_collection( 'HMSPNSgenes' );
	my $crs = ($exact eq "ex") ? 
			# $genome->query({"ensGID" => $ensgid, "phenolist.phenodata.phenotypes.phID"=> { '$in' => [@{$phIDs}] }, "phenolist.phenodata.ScrID"=>$ScrID,"phenolist.goodmatch" => 1}) :
			# $genome->query({"ensGID" => $ensgid, "phenolist.phenodata.phenotypes.phID"=> { '$all' => [@{$phIDs}] }, "phenolist.phenodata.ScrID"=>$ScrID,"phenolist.goodmatch" => 1});

			$genome->query({"ensGID" => { '$in' => [@{$ensgid}] }}):
			$genome->query({"ensGID" => { '$in' => [@{$ensgid}] }});


	# my $crs = $GLV{PRC}

	my @all = $crs->all;
	return \@all;
}
sub get_genes_by_phenotypes_set_and_ScrID {
	my ($self,$phIDs,$ScrID) = @_;
	my $cluster = join("-", sort {$a <=> $b} @{$phIDs} );
	my $crs = $GLV{Genes}->query({"phenolist.phenodata.phenotypes.phID"=> { '$all' => [@{$phIDs}] }, 
			"phenolist.phenodata.ScrID"=>$ScrID,"phenolist.goodmatch" => 1});
	my @all = $crs->all;
	return \@all;
}
#31
sub get_phenotype_by_NAME {
	my ($self,$q,$StdID) = @_;
	my $lcq = lc($q);
	my $ucq = uc($q);
	my $ucfq = ucfirst($lcq);
	my $lcfq = lcfirst($q);
	# return $GLV{Phn}->find({'$or'=> [{phNAME=>qr/$q/},{phNAME=>qr/$lcq/},{phNAME=>qr/$ucq/},{phNAME=>qr/$ucfq/},{phNAME=>qr/$lcfq/}],
				# phID=>{'$nin'=>[0]} })->limit(20);
	return ( $StdID && $StdID ne "-" ) ? $GLV{Phn}->find({phID=>{'$nin'=>[0]},StdID=>$StdID,phNAME=>qr/($q|$lcq|$ucq|$ucfq|$lcfq)/,phWeight=> {'$gte'=> 0.5} })->limit(20) :
			$GLV{Phn}->find({phID=>{'$nin'=>[0]},phNAME=>qr/($q|$lcq|$ucq|$ucfq|$lcfq)/,phWeight=> {'$gte'=> 0.5} })->limit(20)
}
#32
sub get_phenotypes_by_their_set_and_ScrID_by_NAME {
	my ($self,$ScrID,$phIDs,$q) = @_;
	map {$_ = $_*1} @{$phIDs};
	my $lcq = lc($q);
	my $ucq = uc($q);
	my $ucfq = ucfirst($q);
	my $lcfq = lcfirst($q);
	return $GLV{PRC}->find({ScrID=>$ScrID,"phenotypes.phID"=> { '$all' => [@{$phIDs}] }, "phenotypes.phNAME"=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/})->limit(20);
}
#33
sub get_study_by_kwds {
	my ($self,$q) = @_;	
	my $lcq = lc($q);
	my $ucq = uc($q);
	my $ucfq = ucfirst($q);
	my $lcfq = lcfirst($q);	
	return $GLV{Std}->find({'$or'=> [{StdTitle=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
						  {StdPubTitle=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
						  {StdComments=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
						  {"ScreenData.ScrID"=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
						  {"ScreenData.ScrProtocolN"=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
						  {"ScreenData.ScrProtocolDescr"=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
						  {"ScreenData.ScrScMethod"=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
						  {"ScreenData.ScrPhenotypes.ScrPhName"=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},						  						  						  						  
						  {StdID=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
						  {StdDescr=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
						  {StdAuthors=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
						  {StdPrsFirstN=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
						  {StdPrsLastN=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/}]
		});

}
#34
sub get_phenotypes_by_their_set_and_by_ScrIDs {
	my ($self,$ph_by_ScrID) = @_;
	my %ph_by_ScrID = %{$ph_by_ScrID};
	my @allcrs;
	foreach my $ScrID (keys %ph_by_ScrID) {
		my @phIDs = @{ $ph_by_ScrID{$ScrID} };
		push @allcrs, @{$self->get_phenotypes_by_their_set_and_ScrID($ScrID,\@phIDs)};
	}
	return \@allcrs;
}
#35
sub get_idf {
	my ($self, $StdID) = @_;
	# $StdID ? return $GLV{Grid}->find({StdID=>$StdID,type=>"idf"}) : return $GLV{Files}->find({type=>"idf"});
	my $crs = $GLV{Files}->find({StdID=>$StdID, type=>"idf"});
	return $GLV{Grid}->find_one({StdID=>$StdID,type=>"idf"});
}
#36 
sub get_zip {
	my ($self, $ScrID) = @_;
	# $ScrID ? return $GLV{Files}->find({ScrID=>$ScrID,type=>"zip"}) : return $GLV{Files}->find({type=>"idf"});
	return $GLV{Grid}->find_one({ScrID=>$ScrID,type=>"zip"});
}
#37
sub get_grid_metas {
	my ($self, $StdID, $type) = @_;
	return $GLV{Files}->find({StdID=>$StdID, type=>$type});
}
#38
sub get_replica_by_rgID_and_ScrID {
		my ($self, $rgID, $ScrID) = @_;
return $GLV{Data}->find({rgID=>$rgID, ScrID=>$ScrID});
}
#40
sub get_messages {
	my $self = @_;
	my $crs = $GLV{Msgs}->find({})->limit(10)->sort({_id => 1});
	my @all = $crs->all;
	return \@all;
}
#41
sub insert_msg {
	my ($self,$name,$inst,$email,$msg) = @_;
    warn $name;
    my $date = localtime;
          $GLV{Msgs}->insert( { 
            name => $name,
            inst => $inst,
            email => $email,            
            msg  => $msg,
            date => $date
          });
} 
#42
sub delete_message {
	my ($self,$id) = @_;
	my $oid = MongoDB::OID->new(value => $id);
	$GLV{Msgs}->remove({"_id" => $oid});
	$GLV{DB}->log->insert({"removed_post" => $id});
	return 1;
}
#43 
sub get_study_template {
	my ($self, $tmpl) = @_;
	# $ScrID ? return $GLV{Files}->find({ScrID=>$ScrID,type=>"zip"}) : return $GLV{Files}->find({type=>"idf"});
	return $GLV{Grid}->find_one({name=>$tmpl,type=>"template"});
}
#44
sub get_reagents_data_by_IDs_array {
	my ($self,$arr) = @_;
	my $crs = $GLV{Reags}->query({"rgID"=> { '$in' => [@{$arr}] }});
	my @all = $crs->all;
	return \@all;
}
#45
sub get_stats {
	my ($self,$release) = @_;
	my $crs = $GLV{Stts}->query({release=>$release});
	my $obj = $crs->next;
}
#46
sub get_genes_by_countedreags {
	my ($self,$type,$genome,$st_maps) = @_;
	# warn $type;
	$genome = $genome ? $GLV{DB}->get_collection( $genome ) : $GLV{DB}->get_collection( 'HMSPNSgenes' );	
	my $crs = ($type eq "all") ? $genome->query({phenolist=>{'$size'=>$st_maps*1}}) : $genome->query({phenolist=>{'$size'=>$st_maps*1},"phenolist.goodmatch"=>{'$ne'=>0}});
	my @all = $crs->all;
	return \@all;
}
#47
sub get_oterms_tree {
	my ($self,$term) = @_;	
	my $crs = $term  ? $GLV{Oterms}->query({'$or'=>[{OntNAME=>qr/$term/},{"kids.OntNAME"=>qr/$term/}]}) : $GLV{Oterms}->query({});
	my @all = $crs->all;
	return \@all;	#'$or' => [{probeID => "$re"},{rgID => "$re"}]
}
#48
sub get_oterms_by_phenotype_id {
	my ($self,$phID,$ScrID) = @_;
	my $crs = ($phID && $ScrID) ? $GLV{Oterms}->query({"phenolist.phID"=>$phID,"phenolist.ScrID"=>$ScrID}) : $GLV{Oterms}->query({});
	my @all = $crs->all;
	return \@all;
}
1;