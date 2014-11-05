#!/usr/local/bin/perl
use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
print "start: ".showtime()."\n";
  my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 1000000) or warn $!;

my $db = $conn->get_database( 'sym' );
my $sup = $db->get_collection( 'Suppliers' );
my $data = $db->get_collection( 'Datasets');
# my $genes = $db->get_collection( 'HMSPNSgenes' );
my $re = $db->get_collection( 'Reagents' );
my $pd = $db->get_collection( 'ProcessedData' );
my $std = $db->get_collection( 'Studies' );

################ input
my %reags;
my $crs = $re->query({},{probeID=>1,rgID=>1});
while (my $obj = $crs->next) {
        $reags{$obj->{probeID}} = $obj;
}
print showtime().": ".scalar (keys %reags)." reagents read from Reagents\n";
my $std_crs = $std->query({},{});
push(my @studies,$std_crs->all);
my %studies;
# IF UPDATE WITH NEW DATA SET 
# uncomment here if $_->{StdID} ...
map { $studies{ $_->{StdID} } = $_  # if $_->{StdID} eq "J1_SyM"
    } @studies;


foreach my $StdID (keys %studies) {
    my $obj = $studies{$StdID};
    foreach my $scr (@{ $obj->{ScreenData} }) {
        my $ScrID = $scr->{ScrID};
        my $ScrType = $scr->{ScrType};        
        warn "Data from $ScrID ($ScrType screen) being loaded…";
        my $logfile = "../infill-logs/$ScrID-processing.log";
        my $d_crs = $data->query({ScrID=>$ScrID},{});
        push(my @dataset,$d_crs->all);
        warn "Data from $ScrID ($ScrType screen) are taken into array of ".(scalar @dataset)." records";        
        my %datasets;
        map { $datasets{ $_->{_id} } = $_ } @dataset;
        my %ph_to_probe;                # all phenotypes observed for a probe
        my %clusters_to_probe;          # all phenotype clusters in a probe
        my %ph_weights_to_probe;        # phenotype weights in a probe
        my %reproduceds;
        my %hash_cl_to_probe;      
        foreach (keys %datasets) {
            my $obj = $datasets{ $_ };
            # $to_probe{$obj->{probeID} } = $obj->{replica};
            map { push @{$ph_to_probe{ $obj->{probeID} } }, ${$_}{phID} ? ${$_}{phID} : "0"  } @{$obj->{phenoseen}};
            push @{$clusters_to_probe{ $obj->{probeID} } }, $obj->{phcluster};
            $ {$hash_cl_to_probe{ $obj->{probeID} }} {$obj->{phcluster}}++; # count replicas for a given probe in a given cluster (!= replica for a given probe !);
            # warn $ {$hash_cl_to_probe{ $obj->{probeID} }} {$obj->{phcluster}}."|| cluster: ".$obj->{phcluster} if ($obj->{probeID} eq "425")
        }
# all evidence (0..1) for a given cluster calculation:
        # foreach my $probeID (keys %hash_cl_to_probe) {
            # # my %h = %{ $hash_cl_to_probe{ $probeID }};
            # foreach my $cluster ( keys %{ $hash_cl_to_probe{ $probeID }} ) {
                # warn "cluster: ".$cluster."| evidence: ".$ { $hash_cl_to_probe{ $probeID } } {$cluster} if ($probeID eq "425");
            # }
        # }
        
        
        my %cl_to_probe;        # hash of hash on probeID by clusters
        foreach my $probeID (keys %clusters_to_probe) {
            my %repls;
            foreach my $ph (@{$ph_to_probe{ $probeID } } ) { 
                # count reproducibility for each ph:
                $repls{"$ph"}++; 
            }
            $ph_weights_to_probe{$probeID} = \%repls;
            # map {warn "$_,$repls{$_ }" } keys %repls if ($probeID eq "8361" || $probeID eq "282");
            # grep { warn "$_," } @{$clusters_to_probe{ $probeID } } if  ($probeID eq "213277" || $probeID eq "107981");
            my $replicas = scalar @{$clusters_to_probe{ $probeID } };   

            # push here clusters containing ph with evidence = $repls{$ph}/$replicas >= 0.5 :
            my %localgoodcls;                # push here cluster containing ph with $repls{$ph}/$replicas >= 0.5
            my %localbadcls;
            foreach my $cl (@{$clusters_to_probe{ $probeID } } ) { 
                if ($cl =~/\S/) {
                    my @phs = split(/\-/,$cl);
                    map { 
                            if ( ($repls{$_}/$replicas >=0.5  && $_ ne "0") || ($repls{$_}/$replicas >0.5  && $_ eq "0") ) {
                                $localgoodcls{$_}++ ;
                            } else {
                                $localbadcls{$_}++ ;
                            }
                        } @phs; 
                }
            }
            my $jointcluster = join("-",sort {$a <=> $b} keys %localgoodcls);
            my $badcluster = join("-",sort {$a <=> $b} keys %localbadcls);
            # localgoodcls = "0" if ($cl =~/^0/); # no phenotype cluster if at least one ph = 0 (no phenotype) in cluster
            $cl_to_probe{ $probeID } = $jointcluster."#".$badcluster;
            # warn $probeID." >> ".$jointcluster if ($probeID eq "103729" || $probeID eq "103721" || $probeID eq "103737" || $probeID eq "132620" || $probeID eq "9958"
                                                    # || $probeID eq "105286" || $probeID eq "143947" || $probeID eq "s36217" || $probeID eq "425");             

        }
        my %profiles;
        my %allphenos;                
        my $k =0;
        my %ones;
        foreach (keys %datasets) {
            my $obj = $datasets{ $_ };
            foreach (@{$obj->{"phenoseen"}} ) {
                $allphenos{ ${$_}{phID } }= ${$_}{phNAME};
            }
         }   
         foreach (keys %datasets) {       
            # foreach my $cluster (keys %{ $cl_to_probe{ $obj->{probeID} } } ) { 
                # count only clusters that are not inside the other
                my $obj = $datasets{ $_ };
                my ($cl,$bcl) = split(/\#/,$cl_to_probe{ $obj->{probeID} } );
                $cl = ($cl && $cl !~/^0/) ? $cl : "0";
                        if ($cl eq "0") { # if "no phenotype was detected for a given replica, all other phenotypes are discarded for it"
                            $ {$profiles{"0"}} { $obj->{probeID}."#".$bcl }++;
                        } else {
                            $ {$profiles{$cl}} { $obj->{probeID}."#".$bcl }++;
                        }
            $k++;
            # print "$k replicas counted by ".(scalar keys %profiles )." clusters in ".showtime()."\n" if ($k%1000 == 0);            
        }
        $pd->remove({ScrID=>$ScrID});
        my $n=0;
        foreach my $cl (keys %profiles) {
            my %allgenes;       # genes per cluster
            my %uallgenes;      # genes per cluster that has been targeted alone by a given reagent
            my @cases;          # reagent cases per phenotype's cluster
            my $ureagents;      # number of uniquely targeting reagents
            foreach my $key (keys %{$profiles{$cl}}) {
                my ($probeID,$bcl) = split(/\#/,$key ); # probe and bad cluster
                # genes per case
                # if ($evidence >=0.5) {  # take all probes with good evidence in this cluster 
                my $robj = $reags{ $probeID };
                my $rgID = $robj->{rgID};
                my @arr;
                my %ugenes;                 
                foreach (@{$robj->{"tagin"}}) {
                    if (${$_}{ensGID}) {
                        $ugenes{ ${$_}{ensGID} } = ${$_}{symbol};
                        $allgenes{ ${$_}{ensGID} } = ${$_}{symbol};  
                        $uallgenes{ ${$_}{ensGID} } = ${$_}{symbol} if ($robj->{"g_mapfreq"} == 1);
                    }                       
                }
                my @ugenes;
                map {   push @ugenes, { "ensGID"=>$_,"symbol"=> $ugenes{$_} } } keys %ugenes;                 
                my $goodmatch = ($robj->{"g_mapfreq"} == 1) ? 1 : 0;   # consider only those reagents that tag a single gene or see $robj->{"g_mapfreq"}
                my $g_mapfreq;
                my $imgURL;
                $ureagents++ if ($robj->{"g_mapfreq"} == 1);
                my @phweights;
                    # ${ $ph_weights_to_probe{$probeID} }{$_}/$replicas } — evidence for each phenotypes observed
                    my $nohalf =0;
                my $replicas = scalar @{$clusters_to_probe{ $probeID } };
                my $evidence=0;
                my @wts = ($cl ne "0" || $bcl eq "") ? split(/\-/,$cl) : split(/\-/,$bcl);                
                map { $evidence += ${ $ph_weights_to_probe{$probeID} }{$_}/$replicas } @wts;
                # map { warn  ${ $ph_weights_to_probe{$probeID} }{$_}."*****$_******".$probeID unless ${ $ph_weights_to_probe{$probeID} }{$_} } sort {$a <=> $b} (split(/\-/,$cl));                
                $evidence = $evidence/(scalar @wts);
                                  
                # warn "$ScrID >> $cl, $probeID, $evidence  ".$replicas if ($probeID eq "425");
                # warn $cl."################ $bcl" if ($probeID eq "112243" || $probeID eq "282" || $probeID eq "8361" );

              
                    if ($cl ne "0" || $bcl ne "") {
                        # warn "$probeID >> $cl, $evidence  :: ".$replicas if ($rgID eq "AMBN10001792" || $probeID eq "112243" || $probeID eq "282" || 
                        # $probeID eq "8361" || $probeID eq "103729" || $probeID eq "103721" || $probeID eq "103737" || $probeID eq "132620" || $probeID eq "9958"
                                                    # || $probeID eq "105286" || $probeID eq "143947" || $probeID eq "s36217");
                        map { push @phweights, {phID=>$_, phNAME=>$allphenos{$_}, phWEIGHT=>${ $ph_weights_to_probe{$probeID} }{$_}/$replicas }
                            } sort {$a <=> $b} @wts;
                    } else {
                        $nohalf =1 if ($evidence ==0.5 );
                        # warn "$probeID >.> $cl, $evidence  :: ".$replicas if ($rgID eq "AMBN10001792" || $probeID eq "112243" || $probeID eq "282" || $probeID eq "8361");
                    }
                    
                    # don't  as "no phenotype" if it has 0.5 evidence whereas other 0.5 is for particular phenotype
                    push (@cases, {rgID => $rgID, genes=>[@ugenes], countgenes=>scalar(keys %ugenes) ? scalar(keys %ugenes) : 0,
                                      howgood=> $evidence, goodmatch=>$goodmatch, probeID=>$probeID, g_mapfreq => $robj->{"g_mapfreq"}, imgURL=>$imgURL,
                                      replica=>$replicas, phweights=>[@phweights]
                                      }) unless $nohalf;
                # }
            }
            my @agenes;
            map {   push @agenes, { "ensGID"=>$_  } } keys %allgenes;
            my @uagenes;
            map {   push @uagenes, { "ensGID"=>$_ } } keys %uallgenes;
            my @phenos;
            map { push @phenos, {phID=>$_, phNAME=>$allphenos{$_}, ScrID => $ScrID} } sort {$a <=> $b} (split(/\-/,$cl));
            # rgID is only one per ScrID and per phcluster !                     
            my $slicecount = scalar (split(/\-/,$cl));                  
                    $pd->insert( { 
                        ScrID => $ScrID,
                        StdID => $StdID,
                        ScrType=>$ScrType,
                        slicecount => $slicecount,
                        agenes => [@agenes],                                     # @allgenes = all genes with a given "phenoprint"
                        uagenes => [@uagenes],                                    # @uallgenes= all genes that has been targeted alone by a given reagent in "measuring"
                        acountgenes => scalar @agenes, # amount of @allgenes
                        ucountgenes => scalar @uagenes, # amount of @uallgenes
                        cases => [@cases],
                        countreagent => scalar @cases,
                        bestreags => $ureagents,
                        phenotypes=>[@phenos],
                        phcluster => ($cl !~/^0/) ? $cl : "0",
                    } ) if scalar @cases > 0;
            # print "cluster $cl for $ScrID in $StdID is loaded: ".showtime()."\n";
            sleep(1);        
        }
        $n++;
        print "$n clusters loaded with not targeting: ".showtime()."\n" if ($n%2 == 0);
        # map { warn $_ } @{ $reproduceds{"s36217"}  } # 105286 143947
    }    
}   


print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}