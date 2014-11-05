#!/usr/bin/perl
use strict;
use warnings;
use MongoDB;
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $re = $db->get_collection( 'Reagents' );
	my $genes = $db->get_collection( 'HMSPNSgenes' ); 

my @maps = ("/home/jes/Git/infill-load-data/Phagokinetic/libraries/Dharmacon-map_without_kinase.map","/home/jes/Git/infill-load-data/JCB-metazoan-actinome/libraries/Align-new-dharmacon.map"); 

#my $no_m_map = "/home/jes/Git/infill-load-data/JCB-metazoan-actinome/Align-new-dharmacon_additional2check.map";

my $log = "/home/jes/Git/infill-logs/DharmaconUpload.log";
my %maps; # M-031192-01::D-031192-01        +       ENST00000588376 690     CGAAGGACGTGCTGTTTGA     IIIIIIIIIIIIIIIIIII     4
my $v=0;
my %d2m_checks;
my %dseen;
foreach my $m (@maps) {
	open (DF,$m || warn "$!"); 
	while (<DF>) {
		$v++;   
		my ($rid, $strand, $transc, $coord, $seq, $match, $count) = split(/\t/,$_);
		if ($_ =~/^M/) {
			my ($m_id,$d_id) = split (/\:\:/,$rid);
			# $dseen{$d_id}++;
			# push @{ $d2m_checks{$m_id} }, $d_id if $dseen{$d_id}<2;
			push @{ $maps{$m_id} }, $_ if $transc;
		} else {
			warn "the line $v is out of the format";	
		}
	}
	close DF;
}
print  showtime().": $v maps gathered into hash: ".scalar (keys %maps)." pool reagents found\n";

my $seq_gcrs =  $re->find({aligner=>"bowtie","prefix" => "DHARM", "seq_array.tagin.sbjct" => qr/\w/ },{rgID=>1, probeID=>1});
my $gcrs =  $re->find({aligner=>"bowtie","prefix" => "DHARM"});
my @all;
my %reags; # hash for reagents 
push(@all,$gcrs->all);
map { $reags{ $_->{probeID} } = $_ } @all;
print showtime().": ".scalar (keys %reags)." Dharmacon reagents in DB so far\n";
open (LOG, ">$log" || $!);
my $k;
my %r_2_update;
my %r_2_insert;
my %poolDB;
foreach my $m_id (keys %maps) {
	my @pool;
		# if ($d2m_checks{$m_id} && scalar @{$d2m_checks{$m_id}} >4) {
		# 	warn $m_id.": @{$d2m_checks{$m_id}} :".(scalar @{$d2m_checks{$m_id}});
		# }	 
		if ($reags{ $m_id }) {
			my $crs = $reags{ $m_id };
			my @seq_array = @{$crs->{seq_array}};
			my $n=0;
			foreach my $a (@seq_array) {
				$n++;
				if ($a->{g_mapfreq}) {
					if ($a->{g_mapfreq} > 0 && $a->{g_mapfreq} < 2) {
						print LOG "$m_id is in DB and has aligned well \n" if $n==1;
					} elsif ($a->{g_mapfreq} > 1) {
						print LOG "$m_id is in DB and has aligned badly \n" if $n==1;
					} 
				} else {
					print LOG "$m_id is in DB and has no align information \n" if $n==1;
					$r_2_update{$m_id}++;
				}
				if ($a->{pID}){
					push @pool, $a->{pID};
				}
			}
		} else {
			print LOG "$m_id not found in DB \n";
			$r_2_insert{$m_id}++;
		}
		$poolDB{ join(",", sort @pool) }++ if (scalar @pool)>0;
}
print showtime().": ".scalar (keys %r_2_insert)." reagents to insert and ".scalar (keys %r_2_update)." reagents to update\n";


my $crs = $genes->find({},{"ensGID" => 1, "symbol" => 1, "synonyms" => 1, "transcripts.ensTID"=> 1});
$crs->immortal(1);
my %tr2genes;
my $g;
while (my $obj = $crs->next) {
	   grep { my @g = ( $obj->{"ensGID"}, $obj->{"symbol"}, @{$obj->{"synonyms"}} ); $tr2genes{ ${$_}{"ensTID"} } = \@g } @{$obj->{"transcripts"}};
	   $g++;
}
print showtime().": $g genes read from HMSPNSgenes\n";


my $rc = $re->query({prefix => "DHARM"},{rgID =>1 ,limit => 1})->sort({rgID => -1});
my ($pr,$rIDstart) = split(/ARM/,$rc->next->{rgID});
$rIDstart = $rIDstart*1;
$rIDstart++;
print showtime().": ".$rIDstart." start ID for reagents to insert \n";

my $prfx = "DHARM";
my $u=0;
my $i=0;
foreach my $m_id (keys %maps) {
	my @am = @{$maps{$m_id}};
	my @seq_array;
	my @tgenes;
	my %tgseen;		
	my %p_aligns;
	my @pool;
	my @tagin;
		foreach my $r ( @{$maps{$m_id}} ) {	
			my ($rid, $strand, $tr, $coord, $subj, $q, $frq) = split(/\t/,$r);
			my ($m,$pID) = split(/\:\:/,$rid);
			$p_aligns{$pID} .= 	"$strand,$tr,$coord,$subj,$q,$frq\n";
		}
		foreach my $pID (sort keys %p_aligns) {
			push @pool, $pID;
			my @trnsc;
			my @ugenes;
			my %gseen;
			foreach my $str ( split(/\n/,$p_aligns{$pID}) ) {
				my ($strand, $tr, $coord, $subj, $q, $frq) = split(/\,/,$str);
				# warn $tr;
				my ($ensGID, $symbol, @synonyms);
				if ($tr2genes{ $tr }) {
					($ensGID, $symbol, @synonyms) = @{$tr2genes{ $tr } };
					# warn $ensGID;
							my %tdt = (
								"ensTID" => $tr,
								"ensGID" => $ensGID,
								"symbol" => $symbol,
								"synonyms" => [@synonyms],
								"length" => 21,
								"mismatch" => 0,
								"strand" => $strand,
								"sbjct" => $subj,
								"s_begin" => $coord,
								"s_end" => $coord+20
								);
					 push(@trnsc,\%tdt);
					 push(@ugenes,$ensGID) if $gseen{$ensGID}++ ==0;
					 unless (defined $tgseen{$ensGID}) {
					 	push(@tgenes,$ensGID);
					 	my %tagin = (
								"ensGID" => $ensGID,
								"synonyms" => [@synonyms],
								"symbol" => $symbol	
					 	);
					 	push(@tagin,\%tagin);
						$tgseen{$ensGID}++;					 	
					}
				} else {
					 print LOG $tr." not found in HMSPNSgenes collection\n" # some transcripts are in haplotypes genes
				}
			}
			my %dataseq = (
				pID =>$pID,
				genes => [@ugenes],
				tagin => [@trnsc],
				t_mapfreq => scalar @trnsc,
				g_mapfreq => scalar @ugenes
			);
			push (@seq_array, \%dataseq) if $tgseen{ $pID }++ ==0;
	}
	if (scalar @pool>0) {
		print LOG join(",", sort @pool)." pool for $m_id looks different compared with the coresponding DB record \n" unless $poolDB{ join(",", sort @pool) }		
	}	
	if ($r_2_update{$m_id}) {
# updates for %r_2_update		
		sleep(1);
		$re->update( {probeID => $m_id}, {'$unset' => { genes => 1 }});		
		$re->update( {probeID => $m_id}, {'$unset' => { seq_array => 1 }});
		$re->update( {probeID => $m_id}, {'$unset' => { g_mapfreq => 1 }});
		sleep(1);
		eval {
			$re->update( { probeID => $m_id }, {'$pushAll' =>
					{ genes => [@tgenes] }
					}) or warn "$!";
		};
		if ( $@ =~ /can't get db response, not connected/ ) {
			eval {
				$re->update( { probeID => $m_id }, {'$pushAll' =>
						{  genes => [@tgenes] }
						}) or warn "$!";
			};
		}
		eval {
			$re->update( { probeID => $m_id }, {'$pushAll' =>
					{ seq_array => [@seq_array] }
					}) or warn "$!";
		};
		if ( $@ =~ /can't get db response, not connected/ ) {
			eval {
				$re->update( { probeID => $m_id }, {'$pushAll' =>
						{ seq_array => [@seq_array] }
						}) or warn "$!";
			};
		}	
		eval {
		$re->update( { probeID => $m_id }, {'$set' =>
					{ g_mapfreq => scalar @tgenes }
					}) or warn "$!";
		};
		if ( $@ =~ /can't get db response, not connected/ ) {
			eval {
				$re->update( { probeID => $m_id }, {'$set' =>
							{ g_mapfreq => scalar @tgenes }
							}) or warn "$!";
			};
		}
			eval {
				$re->update( { probeID => $m_id }, {'$pushAll' =>
						{ tagin => [@tagin] }
						}) or warn "$!";
			};
			if ( $@ =~ /can't get db response, not connected/ ) {
				eval {
				$re->update( { probeID => $m_id }, {'$pushAll' =>
						{ tagin => [@tagin] }
						}) or warn "$!";
				};
			}

		$u++;
	} elsif ($r_2_insert{$m_id}) {
# inserts for %r_2_insert
		my $rgID = "000000".$rIDstart;
 		$rgID = substr($rgID,-7);
 		$rgID = $prfx.$rgID;
		$re->insert( {
			rgID => $rgID,
			prefix => $prfx,
			probeID => $m_id,
			seq_array => [@seq_array],
			libID => "siGENOME",			  
			supID => 3,
			type => "siRNA",
			genes => [@tgenes],
			g_mapfreq => scalar @tgenes,
			tagin => [@tagin],			
			aligner => "bowtie"
		});
		$rIDstart++;
		$i++;
	} else {
		print LOG $m_id." is nowhere! \n" # some transcripts are in haplotypes genes
	}
}
close LOG;
print  showtime().": $u reagents updated and $i inserted\n";
# print "end: ".showtime()." ".scalar(keys %regmap)." reagents loaded with Dharmacon ids and libID=siGENOME\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}