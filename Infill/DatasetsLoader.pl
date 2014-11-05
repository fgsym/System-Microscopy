#!/usr/local/bin/perl
use MongoDB;
use MongoDB::OID;
use MongoDB::GridFS;
use MongoDB::GridFS::File;
use strict;
# use warnings; FD31951695GB
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
my $db = $conn->get_database( 'sym' );
my $data = $db->get_collection( 'Datasets' );
my $re = $db->get_collection( 'Reagents' );
my $std = $db->get_collection( 'Studies' );
my $ph = $db->get_collection( 'Phenotypes' );
my $grid = $db->get_gridfs;    
################ input
my %reags;
my $crs = $re->query({},{probeID=>1,rgID=>1});
while (my $obj = $crs->next) {
        $reags{$obj->{probeID}} = $obj->{rgID};
}
print showtime().": ".scalar (keys %reags)." reagents read from Reagents\n";
my @rubbish = ("scrambl", "EMPTY","SCRAMBL", "empty"); # by all this words to throw off the row
my $loaddir = "/home/jes/Git/infill-load-data/";
my $idf_dir = "/home/jes/Git/infill-load-data/_idf/RNAi/";

my $std_crs = $std->query({},{});
push(my @studies,$std_crs->all);
my %studies;
map { $studies{ $_->{StdID} } = $_  # if $_->{StdID} eq "M1_SyM"
    } @studies;
my %all_phenotypes;
my %PhWeights;
foreach my $StdID (keys %studies) {
    my %study_phenos;
    my $obj = $studies{$StdID};
    my @screens = @{ $obj->{ScreenData} };
    foreach my $scr (@screens) {
        my $ScrID = $scr->{ScrID};
        my $logfile = "../infill-logs/$ScrID-loading.log";        
        $data->remove({ ScrID=>$ScrID });
        my $datafile = $loaddir.$scr->{ScrFile};
        my $md5sum = $scr->{ScrMD5};

        my @phenonames;
        my @phenorules;
        map {push @phenonames, ${$_}{ScrPhName}; push @phenorules, ${$_}{ScrPhScRules} if ${$_}{ScrPhScRules} =~/\S+/ } @{$scr->{ScrPhenotypes}}; 
        saveGRID($datafile,$idf_dir,$ScrID,$StdID);
        my %fieldnames;
        my $title;
        my $locname;
        foreach (@{$scr->{ScrColmns}}) {
           $fieldnames { ${$_}{ScrColmnNum} } = (${$_}{ScrColmnT} eq "ProbeID" || ${$_}{ScrColmnT} eq "TargetGeneEnsembl_ID" || ${$_}{ScrColmnT} eq "IntProbeID") ? 
                                ${$_}{ScrColmnT} : ${$_}{ScrColmnShrt} ? ${$_}{ScrColmnShrt} : ${$_}{ScrColmnN};
           $locname .= (${$_}{ScrColmnT} eq "Location") ? ${$_}{ScrColmnN}."-" : ""; 
        } 
        chop $locname;
        print "Loading DATA from $datafile: \n(StdID=$StdID, ScrID=$ScrID)... \n";        
        open (DF, "$datafile"  || "can't open datafile: $!");
        my %data; # put all rows from the file $datafile here (key = $row); 
        # map {print "f: ".$_." :: $fieldnames{$_} \n"} keys %fieldnames;
        my $n=0;
        open (LOG, ">$logfile" || "$!");
        my $discarded =0;        
        while (<DF>) {
            my %inserts;        
            $_ =~s/\n//;  
            my $row = $_;  
            my @arr = split(/\t/,$row);
            my $filter = 1;
            map {$filter = 0 if ($row =~/$_/) } @rubbish;
            foreach my $c (keys %fieldnames) {
                if ($filter) {
                    # print $fieldnames{ $c }."::".$arr[$c]."\n"; 
                    $inserts { $fieldnames{$c} } = $arr[$c]
                } else {
                    print LOG "line $n with rubbish data, discarded\n";
                    $discarded++;
                }
            }

            if ($locname) {                
                my $location;
                map { $location .= $arr[$_]."-" if $locname =~ /$fieldnames{$_}/  } (0 .. $#arr-1);
                # warn $location if $inserts{ProbeID} eq "142188";
                chop $location if $location;                
                $inserts{$locname} = $location ? $location : "" if ($filter); # unless it's a column !! otherwise discard this line
            }
            warn $inserts{ProbeID} if $inserts{ProbeID} eq "s12276";
            $data{ $row.$n } = \%inserts if ($inserts{ProbeID} && $n>0);
            $n++; 
        }
        close DF;
        print "Total number of datarows to process in this screen (StdID=$StdID, ScrID=$ScrID): ".scalar (keys %data)."\n";
# replicas count        
        my %replicas;
        my %rindexes;
        foreach my $dk (keys %data) {
            my %inserts = %{ $data{$dk} };
            $inserts{"IntProbeID"} ? $replicas{ $inserts{"IntProbeID"} }++ : $replicas{ $inserts{"ProbeID"} }++;
        }
        print "Replicas counted, total number of reagents in this screen (StdID=$StdID, ScrID=$ScrID): ".scalar (keys %replicas)."\n";
        my $i=1;
        foreach my $rg (keys %replicas) {
            $rindexes{$rg} = $i;
            $i++;
        }
# writing %data i Datasets collection

        my @scoresNAMES;
        map { push @scoresNAMES,${$_}{ScrColmnShrt} if ${$_}{ScrColmnT} eq "Score" } @{$scr->{ScrColmns}};   
        foreach my $dk (keys %data) {
            my %inserts = %{ $data{$dk} };
            my $probeID = $inserts{"ProbeID"};
            my $testProbe=0;
            $testProbe = 1 if $reags{$probeID};     # integrity with the Reagents collection check
            unless ($testProbe) {
                print LOG "missed $probeID\n";
                $discarded++;
                next;
            }
            my %printseen;
            my $testValid = $testProbe;
            for (@scoresNAMES) {
                $_ =~s/(^\s|\s$)//gsm;
                $testValid = 0 if ($inserts{$_} !~/\w/ || $inserts{$_} !~/\d/);
                $printseen{$_} = $inserts{$_}*1 if $testValid;
                # print "$inserts{ProbeID} >> $scoresNAMES[$_] : $inserts{ $scoresNAMES[$_] }\n";
            }
            my $location = $inserts{$locname} ? $inserts{$locname} : "";
            unless ($testValid) {
                print LOG $inserts{"ProbeID"}." >> $location : scoring's not valid!\n";
                $discarded++;
                next;
            }
            my $replica = $inserts{"ReplicaCount"} ? $inserts{"ReplicaCount"} : $replicas{ $inserts{"ProbeID"} } ? $replicas{ $inserts{"ProbeID"} } : 
                            $replicas{ $inserts{"IntProbeID"} } ? $replicas{ $inserts{"IntProbeID"} } : 1;
            # ordinal number for reagent in the dataset (merging by replicas)
            my $rindex = $rindexes{ $inserts{"ProbeID"} } ? $rindexes{ $inserts{"ProbeID"} } : $rindexes{ $inserts{"IntProbeID"} } ; 
            my ($phenoseen,$phenocount,$phcluster) = def_phenotypes(\@phenonames, \@phenorules, \%printseen, $inserts{Phenotype}?$inserts{Phenotype}:0, $inserts{ProbeID});
            my @phenoseen = @{$phenoseen};
            map { $ { $study_phenos  { $ScrID."|".$scr->{ScrType} }  } { ${$_}{phID} } = ${$_}{phNAME}} @phenoseen;
#             # image fields     

            my @arr = split(/\t/,$dk);
            my @imgf;
            if ($scr->{ScrImgExtURL}) {
                my @imgord;
                foreach my $n (sort {$a<=>$b} keys %fieldnames) {
                    map { $_=~s/\s+//gsm; push @imgord, $n if $fieldnames{$n} eq $_ } split(/\;/,$scr->{ScrImgIDs})
                }
                map {
                    push @imgf,$arr[$_];
                } @imgord;
            }
            my $tagfor = $inserts{"TargetGeneEnsembl_ID"} ? $inserts{"TargetGeneEnsembl_ID"} : "";
            my %libs = %{$scr->{ScrLib}};
            $data->insert({
                StdID => $StdID,
                ScrID => $ScrID,
                ScrType => $scr->{ScrType},
                probeData => {%libs},
                # cellTYPE => $cellTYPE,
                location => $location,
                locname => $locname,
                probeID => $probeID,
                rgID => $reags{$probeID},
                IprobeID => $inserts{"IntProbeID"} ? $inserts{"IntProbeID"} : $probeID,
                control=>$inserts{"control"} ? $inserts{"control"} : "",
                replica=>$replica,
                rindex=>$rindex,
                tagfor=> $tagfor,
                imgURL => ($scr->{ScrImgExtURL}) ? $scr->{ScrImgExtURL}.join("",@imgf) : "",
                printseen => {%printseen},
                phenoseen => [@phenoseen],
                phenocount => $phenocount,
                phcluster => $phcluster
           });
           foreach (@phenoseen) {
                $PhWeights{$probeID.",".$ScrID.",".${$_}{phID}}++;
                $PhWeights{${$_}{phID}."-".$ScrID} += $PhWeights{$probeID.",".$ScrID.",".${$_}{phID}}/$replica if ($PhWeights{$probeID.",".$ScrID.",".${$_}{phID}}/$replica >=0.5);
           }
        }
        close LOG;
        print "Screen (StdID=$StdID, ScrID=$ScrID) is loaded. Discarded rows in this screen: $discarded (see $logfile)\n\n";
    } 
    $all_phenotypes{$StdID} = \%study_phenos;
    # end of ScrID
} # end of StdID

foreach my $StdID (keys %all_phenotypes) {
    $ph->remove({StdID => $StdID});
    sleep(2);
    my %study_phenos = %{ $all_phenotypes{ $StdID }};
    foreach my $scr (keys %study_phenos) {
         my ($ScrID,$ScrType) = split(/\|/,$scr);  
         my %phns =  %{ $study_phenos{ $scr }};
         map {  
                    my $id = 1*$_; $ph->insert({
                    StdID => $StdID,
                    ScrID => $ScrID,
                    ScrType => $ScrType,
                    phID => $id,
                    phNAME => $phns{$_},
                    phWeight => sprintf("%.2f",$PhWeights{$id."-".$ScrID})*1
                })
         }  keys %phns;
         # map { warn $std.">>>>".$scr.">>>".$_.">>".$phns{$_} } keys %phns;
    }
}    

warn "end: ".showtime();
#########################
# define phenotypes here
sub def_phenotypes {
    my ($phenonames,$phenorules,$printseen,$this,$probe) = @_;
    # \@phenonames, \@phenorules, \%printseen, $inserts{phenotype}?$inserts{phenotype}:0, $inserts{ProbeID} 
    my %printseen = %{$printseen};
    my @phenos;     # phenotypes with assigned IDs for this screen
    my $phID = 1;
    foreach my $p ( @{$phenonames} ) {
        $phID = 0 if $p=~/No phenotype/;
        push (@phenos, {phID => $phID, phNAME => $p});
        $phID++;
    }
    # map {warn ${$_}{phID}." :: ".${$_}{phNAME} } @phenos if ($probe eq "M-003237-01");
    my @phenoseen;
    if (scalar @{$phenorules} == 0) {      # define phenotype as it's writen in a row ($this)
        foreach my $p (0 .. $#phenos) {
            my %ph = %{$phenos[$p]};
            map { push @phenoseen, $phenos[$p] if ucfirst($_) eq ucfirst( $ph{phNAME} ) } split(/\,/,$this);
        }
    } else {                       # define phenotype from scoring with the help of the corresponding boolean function ($phenorules)
        my @phenorules = @{$phenorules};
        # map {warn $_ } @phenorules if ($probe eq "142188");
        my @phenonames = @{$phenonames};        
        my $phID = 1;
        foreach my $p (0 .. $#phenorules) {
            my $bool_rule = $phenorules[$p];
            $bool_rule =~s/(^\s|\s$)//gsm;
            $bool_rule =~s/or/\|\|/gsm;
            $bool_rule =~s/and/\&\&/gsm;
            $bool_rule =~s/(\w+)\=/$1\=\=/gsm;
            (my $perl_expr = $bool_rule) =~ s/([a-zA-Z]\w*)/\$printseen{$1}/g;
            # warn $bool_rule if ($probe eq "M-019590-01");
            # warn $perl_expr if ($probe eq "M-019590-01");
            if (eval $perl_expr && $probe) {
                # warn $perl_expr if ($probe eq "M-019590-01");                
                my $phID;
                # map {warn $phenonames[$p]."=========".${$_}{phNAME}  if ($probe eq "M-019590-01") } @phenos;
                map {$phID = ${$_}{phID} if ucfirst($phenonames[$p]) eq ucfirst( ${$_}{phNAME} ) } @phenos;
                $phID = 0 if $phenonames[$p]=~/No phenotype/;
                push @phenoseen, {phID => $phID, phNAME => $phenonames[$p]}
            } 
        }
    }   
    unless (scalar @phenoseen > 0) {
        push @phenoseen, {phID => 0, phNAME => "No phenotype assigned"}
    }    
    my @phcluster;
    foreach my $p (0 .. $#phenoseen) {
            my %ph = %{$phenoseen[$p]};
            push @phcluster, $ph{phID};
    }
    my $cluster = join("-",sort {$a <=> $b} @phcluster);
    $cluster = "0" if $cluster =~/^0/;
    return (\@phenoseen, scalar @phenoseen, $cluster)
}
##############################
# save to MongoDB GRID FS here
sub saveGRID {
    my ($datafile,$idf_dir,$ScrID,$StdID) = @_;
    my $grid = $db->get_gridfs;
    my $dir = $datafile;
    my $file = $datafile;
    $dir =~s/(.*)\/\S+$/$1/gsm;
    $file =~ s/\S+\/(\S+$)/$1/gsm;
    `cd $dir; zip -9j $datafile.zip $file`;
    my $fh = IO::File->new("$datafile.zip", "r");
    my $ifh = IO::File->new($idf_dir.$StdID.".idf.csv", "r");
    my $md5sum = (split(/\s/,`md5sum $datafile.zip`))[0];
    print $md5sum.": md5sum of the next loaded file's zip-archive\n";
    $grid->remove({StdID=>$StdID,type=>"idf"});
    $grid->remove({ScrID=>$ScrID,type=>"zip"});

    $grid->insert($fh, {ScrID=>$ScrID,StdID=>$StdID,type=>"zip"});

    my $file = $grid->find_one({StdID=>$StdID,type=>"idf"});

    $grid->insert($ifh, {StdID=>$StdID,type=>"idf"}) unless ($file);
}
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}
