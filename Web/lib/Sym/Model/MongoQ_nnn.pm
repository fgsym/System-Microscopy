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
