#!/usr/local/bin/perl
#
use MongoDB;
use strict;
use warnings;
print "start: ".showtime()."\n";
	my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 1000000) or warn $!;  
	my $db = $conn->get_database( 'sym' );
# collections connectors:
	my $prc = $db->get_collection( 'ProcessedData' );  
#..... Getting all genes into hash to work with them faster
warn "<< ".$ARGV[0]." >> collection populating (if empty it will be HMSPNSgenes!)";
my $genes = $ARGV[0] ? $db->get_collection( $ARGV[0] ) : $db->get_collection( 'HMSPNSgenes' );

my $gcrs = $genes->find({},{ensGID => 1, symbol => 1, synonyms => 1, "transcripts.ensTID" => 1});
$gcrs->immortal(1);
my @all = $gcrs->all;
my @genes;
my $gn;
foreach (@all) {
	push (@genes, $_->{"ensGID"});
	$gn++;
}
print showtime().": $gn genes read from $ARGV[0]\n";
my $pcrs = $prc->find({});
my %phcases;
my @p_all = $pcrs->all;
foreach my $obj (@p_all) {
	if ($obj->{phcluster} ne "0") {
		foreach my $c (@{$obj->{agenes}}) {
			push @{ $phcases{ ${$c}{ensGID}} },$obj;
		}
	}
}
print showtime()." : ".(scalar (keys %phcases))." genes with assigned phenotypes read from Processed Data\n";
foreach my $g (keys %phcases) {
	# $genes->update({ensGID => $g}, {'$unset' => {'phenolist' => 1} });
	my %rgphs;
	my %phs;
	my %goodmatch;	
	my %reags;		
	foreach my $obj (@{$phcases{$g}}) {
		foreach my $m (@{$obj->{cases}} ) {
			foreach (@{ ${$m}{genes} }) {
				if (${$_}{ensGID} eq $g) {
					my $bestgenes = $obj->{bestgenes} ? $obj->{bestgenes} : $obj->{ucountgenes};
					$rgphs{${$m}{rgID}."#".$obj->{ScrID}} = ${$m}{howgood}."|".$bestgenes."|".$obj->{phcluster};
					$phs{${$m}{rgID}."#".$obj->{ScrID}} = ${$m}{phweights};
					$goodmatch{${$m}{rgID}} = ${$m}{goodmatch};
					$reags{${$m}{rgID}} = ${$m}{probeID};					
					# warn ${$m}{rgID}."#".$obj->{ScrID} if $g eq "ENSG00000162757";
				}
			}
		}
	}
	my %rghash;
	foreach my $ID (keys %rgphs) {
		if ($ID ne "") {
			my ($howgood,$bestgenes,$phcluster) = split(/\|/,$rgphs{$ID});			
			my @phs = @{$phs{$ID}};
			my @locphens;
			my ($rgID,$ScrID) = split(/\#/,$ID);			
			map { push(@locphens, {phID => ${$_}{phID}*1, phNAME => ${$_}{phNAME}, ScrID=>$ScrID, phWEIGHT=>${$_}{phWEIGHT} } ) } @phs;
			# warn $ID if $g eq "ENSG00000132383";
			# push (@rgIDs, $rgID);
			my %phenohash = (
					ScrID => $ScrID,
					phcluster => $phcluster,
					phenotypes => [@locphens],
					bestgenes => $bestgenes,
					howgood => $howgood
					);
			push @{$rghash{$rgID}}, \%phenohash if (scalar @locphens > 0);	
			# map {warn $_." : $g : ".join(",", @{$phenohash{phenotypes}} ) } keys %phenohash;
			
		}
	}
	foreach my $rgID (keys %rghash) {
		my @pharray;
		eval {
			$genes->update({ensGID => $g}, {'$push' => 
					{'phenolist' => {  
						rgID=>$rgID, 
						probeID => $reags{$rgID}, 
						goodmatch => $goodmatch{$rgID}, 
						phenodata => [@{$rghash{$rgID}}] 
						}
					} 
				});
		};
		if ( $@ =~ /can't get db response, not connected/ ) {
			eval {
				$genes->update({ensGID => $g}, {'$push' => 
						{'phenolist' => {  
							rgID=>$rgID, 
							probeID => $reags{$rgID}, 
							goodmatch => $goodmatch{$rgID}, 
							phenodata => [@{$rghash{$rgID}}] 
							}
						} 
					});
			};
		}	
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