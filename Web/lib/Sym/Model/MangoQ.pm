package Sym::Model::MongoQ;
use strict;
#
# All queries to MongoDB are here! Controller method(s) is(are) given before corresponding Model methods	
#
#1 

sub get_all_screens {
	my ($self,$StdID) = @_;
	my $crs = $StdID ? $GLV{Std}->find({StdID=>$StdID}) : $GLV{Std}->find({})->sort({StdID => 1});
	if ($StdID) {
	 	return $crs;
	} else {
		return $crs->all;	
	}	
}
#2 
sub get_phenotypes_slicecount_by_ScrID {
	my ($self,$ScrID) = @_;
	return $GLV{DB}->command([ distinct=>"ProcessedData",key=>"slicecount", find => {StdID => $ScrID}  ]);
}
#3 
sub get_phenotypes_countreagent_by_ScrID {
	my ($self,$ScrID) = @_;
	return $GLV{DB}->command([ distinct=>"ProcessedData",key=>"countreagent", find => {StdID => $ScrID}  ]);
}
#4 
sub get_Study_by_ScrID {
	my ($self,$ScrID) = @_;
	$ScrID ? return Mango::Cursor->new(collection => $GLV{Std})->query({"ScreenData.ScrID"=>$ScrID}) : 
			return Mango::Cursor->new(collection => $GLV{Std})->query({});
}
#5 
sub get_Study_by_StdID {
	my ($self,$StdID) = @_;
	return Mango::Cursor->new(collection => $GLV{Std})->query({StdID => $StdID});
}
#6 
sub get_phenotypes_by_ScrID {
	my ($self,$ScrID) = @_;
	my $crs = Mango::Cursor->new(collection => $GLV{PRC});
	# my $ph = $ScrID ? 
	# 		$GLV{DB}->command(distinct=>"ProcessedData",key=>"phenotypes", find =>{ScrID => $ScrID} ): 
	#  		$GLV{DB}->command(distinct=>"ProcessedData",key=>"phenotypes", find => { phcluster=>{'$nin'=>["0"]} } );
	my $ph = $crs->distinct("phenotypes"); 

	my @phs;
	foreach (@{$ph}) {
		if ($ScrID) {
			push @phs, $_  if (${$_}{ScrID} eq $ScrID);
		} else {
			push @phs, $_ 
		}
	}
	return \@phs;
}
#7 
sub get_phenotypes_by_slicecount_and_ScrID {
	my ($self,$ph,$ScrID) = @_;
	return Mango::Cursor->new(collection => $GLV{PRC})->query({slicecount => $ph,"cases.goodmatch"=>1, ScrID=>$ScrID})->sort({acountgenes => -1})
}
#8 
sub get_phenotypes_by_countreagent_and_ScrID {
	my ($self,$oln,$ScrID) = @_;
	return Mango::Cursor->new(collection => $GLV{PRC})->query({countreagent => $oln,"cases.goodmatch"=>1,ScrID=>$ScrID});
}
#9 
sub get_phenotypes_set_by_id {
	my ($self,$id) = @_;	
	# my $phd = MongoDB::OID->new(value => $id);
	return Mango::Cursor->new(collection => $GLV{PRC})->query({"_id" => $id });	
}
#10 
sub get_all_reagents_by_supplier_prefix {
	my ($self,$supl) = @_;
	$supl ? return $Mango::Cursor->new(collection => $GLV{Reags})->query({prefix => qr/^$supl/}) : return $Mango::Cursor->new(collection => $GLV{Reags})->query({})
}
#11
sub get_supplier_by_prefix {
	my ($self,$supl) = @_;
	return Mango::Cursor->new(collection => $GLV{Supl})->query({prefix => qr/^$supl/});
}
#12 
sub get_supplier_by_id {
	my ($self,$supID) = @_;
	return Mango::Cursor->new(collection => $GLV{Supl})->query({SupID => $supID});
}
#13 
sub get_phenotypes_by_rgID {
	my ($self,$id) = @_;
	warn $id;
	my $crs = Mango::Cursor->new(collection => $GLV{PRC})->query({"cases.rgID" => $id});
	warn $crs;
	warn $crs->next;
	return $crs;
}
#14
sub get_reagent_by_gene_symbol {
	my ($self,$gene) = @_;
	return $Mango::Cursor->new(collection => $GLV{Reags})->query({"tagin.symbol" => "$gene"});
}
#15
sub get_reagent_by_gene_synonyms {
	my ($self,$gene) = @_;
	return Mango::Cursor->new(collection => $GLV{Reags})->query({"tagin.synonyms" => "$gene"});
}         
#16
sub get_reagent_by_gene_ensGID {
	my ($self,$gene) = @_;
	return Mango::Cursor->new(collection => $GLV{Reags})->query({"tagin.ensGID" => "$gene"});
} 
#17
sub get_reagent_by_probeID {
	my ($self,$re) = @_;	
	return Mango::Cursor->new(collection => $GLV{Reags})->query({'$or' => [{probeID => "$re"},{rgID => "$re"}] });
}
#18
sub get_reagent_by_rgID {
	my ($self,$re) = @_;
	return Mango::Cursor->new(collection => $GLV{Reags})->query({rgID => "$re"});
}
#19
sub get_gene {
	my ($self,$gene,$limit) = @_;
	my $sort = {symbol => 1,synonyms=> 1};
	( $limit  > 0 ) ? 
	return $GLV{Genes}->find({'$or' => [{synonyms => qr/^$gene/},{symbol => qr/^$gene/},{ensGID => qr/^$gene/} ]},{symbol=>1,synonyms=>1,ensGID=>1,limit => $limit})->sort($sort)
	: return $GLV{Genes}->find({'$or' => [{synonyms => "$gene"},{symbol => "$gene"},{ensGID => "$gene"} ]},{symbol => 1,synonyms => 1,ensGID=>1})
}
#20
sub get_gene_by_ensGID {
	my ($self,$ensgid) = @_;
	return Mango::Cursor->new(collection => $GLV{Genes})->query->find({ensGID => $ensgid});
}
#21
sub get_phenotypes_by_their_set_and_ScrID {
	my ($self,$ScrID,$phIDs) = @_;
	map {$_ = $_*1} @{$phIDs};
	my $phcluster = join("-", sort { $a <=> $b} @{$phIDs});
	my $crs = $GLV{PRC}->find({ScrID=>$ScrID,"phenotypes.phID"=> { '$all' => [@{$phIDs}] } });
	return $crs->all;

}
#21.1
sub get_phenotypes_by_cluster_and_ScrID {
	my ($self,$ScrID,$phIDs) = @_;
	map {$_ = $_*1} @{$phIDs};
	my $phcluster = join("-", sort { $a <=> $b} @{$phIDs});
	my $crs = $GLV{PRC}->find({ScrID=>$ScrID,phcluster=> $phcluster });	
	return $crs->all;
}
#22
sub get_all_phenotypes_observed {
	my $self = shift;
	return Mango::Cursor->new(collection => $GLV{PRC})->query({},{phenotypes => 1,ScrID=> 1});   
}
#23
sub get_phenotypes_by_gene_and_reagent_probeID {
	my ($self,$probeID,$ensgid,$full) = @_;	
	return Mango::Cursor->new(collection => $GLV{PRC})->query({"cases.probeID" => $probeID,"cases.genes.ensGID" => $ensgid})  
}
sub get_phenotypes_by_gene {
	my ($self,$ensgid) = @_;
	return Mango::Cursor->new(collection => $GLV{PRC})->query({"cases.genes.ensGID" => $ensgid});
}
#24
sub get_reagent_mapping {
	my $self = shift;
	return Mango::Cursor->new(collection => $GLV{Reags})->query({g_mapfreq => {'$gt' => 0}},{g_mapfreq=>1,rgID=>1});
}
#25
sub get_ontologies {
	my ($self) = shift;
	return Mango::Cursor->new(collection => $GLV{Onto})->query({});
}
#26
sub get_gene_by_attribute {
	my ($self,$desc,$skip,$limit) = @_;
	return Mango::Cursor->new(collection => $GLV{Genes})->query({"transcripts.GO.GOdesc" => qr/^$desc/, "phenolist.rgID" => qr/\S/, "phenolist.phenodata.phcluster" => qr/\S/},{symbol=>1,transcripts=>1,ensGID=>1})->skip($skip)->limit($limit);
}
#27
sub count_gene_by_attribute {
	my ($self,$desc) = @_;
	return Mango::Cursor->new(collection => $GLV{Genes})->count({"transcripts.GO.GOdesc" => qr/^$desc/, "phenolist.phenodata.phcluster" => qr/\S/});
}
#28
sub get_ontologies_by_genes {
	my ($self) = @_;
	return Mango::Cursor->new(collection => $GLV{Onto})->query({},{GOdesc=>1,countgenes=>1})->sort({countgenes => 1})
}
1;
#29
sub get_ontologies_by_genes_and_namespace {
	my ($self,$namespace) = @_;
	return Mango::Cursor->new(collection => $GLV{Onto})->query({GOnamespace=>$namespace},{GOdesc=>1,countgenes=>1})->sort({countgenes => 1})
}
#30
sub get_phenotypes_by_gene_and_phenotypes {
	my ($self,$ensgid,$phIDs,$ScrID) = @_;
	my $crs = Mango::Cursor->new(collection => $GLV{Genes})->query({"ensGID" => $ensgid, "phenolist.phenodata.phenotypes.phID"=> { '$all' => [@{$phIDs}] }, 
				"phenolist.phenodata.ScrID"=>$ScrID,"phenolist.goodmatch" => 1});	
	return $crs->all;
}
sub get_genes_by_phenotypes_set_and_ScrID {
	my ($self,$phIDs,$ScrID) = @_;
	my $cluster = join("-", sort {$a <=> $b} @{$phIDs} );
	my $crs = Mango::Cursor->new(collection => $GLV{Genes})->query({"phenolist.phenodata.phenotypes.phID"=> { '$all' => [@{$phIDs}] },"phenolist.phenodata.ScrID"=>$ScrID,"phenolist.goodmatch" => 1});
	return $crs->all;
}
#31
sub get_phenotype_by_NAME {
	my ($self,$q,$StdID) = @_;
	my $lcq = lc($q);
	my $ucq = uc($q);
	my $ucfq = ucfirst($q);
	my $lcfq = lcfirst($q);
	# return $GLV{Phn}->find({'$or'=> [{phNAME=>qr/$q/},{phNAME=>qr/$lcq/},{phNAME=>qr/$ucq/},{phNAME=>qr/$ucfq/},{phNAME=>qr/$lcfq/}],
				# phID=>{'$nin'=>[0]} })->limit(20);
	return $StdID ? 
			Mango::Cursor->new(collection => $GLV{Phn})->query({phID=>{'$nin'=>[0]},StdID=>$StdID,phNAME=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/})->limit(20) :
			Mango::Cursor->new(collection => $GLV{Phn})->query({phID=>{'$nin'=>[0]},phNAME=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/})->limit(20)
}
#32
sub get_phenotypes_by_their_set_and_ScrID_by_NAME {
	my ($self,$ScrID,$phIDs,$q) = @_;
	map {$_ = $_*1} @{$phIDs};
	my $lcq = lc($q);
	my $ucq = uc($q);
	my $ucfq = ucfirst($q);
	my $lcfq = lcfirst($q);
	return Mango::Cursor->new(collection => $GLV{PRC})->query({ScrID=>$ScrID,"phenotypes.phID"=> { '$all' => [@{$phIDs}] }, "phenotypes.phNAME"=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/})->limit(20);
}
#33
sub get_study_by_kwds {
	my ($self,$q) = @_;	
	my $lcq = lc($q);
	my $ucq = uc($q);
	my $ucfq = ucfirst($q);
	my $lcfq = lcfirst($q);	
	return Mango::Cursor->new(collection => $GLV{Std})->query({'$or'=> [{StdTitle=>qr/$q|$lcq|$ucq|$ucfq|$lcfq/},
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
return Mango::Cursor->new(collection => $GLV{Data})->query({rgID=>$rgID, ScrID=>$ScrID});
}
#40
sub get_messages {
	my $self = @_;
	my $crs = $GLV{Msgs}->find({})->limit(10)->sort({_id => 1});
	return $crs->all;
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
	my $crs = Mango::Cursor->new(collection => $GLV{Reags})->query({"rgID"=> { '$in' => [@{$arr}] }});
	return $crs->all;
}
#45
sub get_stats {
	my ($self) = @_;
	my $crs = $GLV{Stts}->find();
	my $obj = $crs->next;
}
#46
sub get_genes_by_countedreags {
	my ($self,$type,$st_maps) = @_;
	my $crs = ($type eq "all") ? Mango::Cursor->new(collection => $GLV{Genes})->query({"matches" => $st_maps*1}) : 
					Mango::Cursor->new(collection => $GLV{Genes})->query({"goodmatches" => $st_maps*1});
	return $crs->all;
}
1;