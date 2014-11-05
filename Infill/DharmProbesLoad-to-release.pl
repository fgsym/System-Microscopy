#!/usr/bin/perl

use MongoDB;
use MongoDB::OID;
use strict;
use warnings;
my $log = "$0.log";
my $bowtie_dh = "/home/jes/Git/infill-load-data/Dharmacon_remap_to_release_77.map";

print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $re = $db->get_collection( 'Reagents' );
	my $genes = $db->get_collection( 'HMSPNSgenes' );   

my %aligns;
open (BW, $bowtie_dh || "can't open $bowtie_dh: $!");
# DHARM0018868::D-003020-11       +       ENST00000396611 1766    GACGAGAGACCAATACTTG     IIIIIIIIIIIIIIIIIII     9
while(<BW>) {
	$_ =~s/\n//gsm;	
	my ($ID, $strand, $tr, $coord, $subj, $q, $frq) = split(/\t/,$_); # @params = ($mID, $strand, $tr, $coord, $subj, $q, $frq);
	my ($rgID,$pID) = split(/\:\:/,$ID);
	$aligns{$rgID} .= "$pID,$strand,$tr,$coord,$subj,$q,$frq\n";
}
close BW;
print showtime()." ".scalar (keys %aligns)." : reagents mapped in $bowtie_dh\n";

### repair code (recovery after Dharmacon reagents smashing)
my %rg_pids;
open (RGS, "/home/jes/Git/infill-load-data/DharmaconIDs_from_release.pl.tab" || "can't open $_: $!");
# DHARM0000065    D-016560-01,D-016560-04,D-016560-03,D-016560-02
while(<RGS>) {
	$_ =~s/\n//gsm;
	my ($rgID, $pIDs) = split(/\t/,$_); 
	$rg_pids{$rgID} = $pIDs;
}
close RGS;
###

my $gcrs =  $re->find({aligner=>"bowtie","prefix" => "DHARM" },{rgID=>1, probeID=>1});
my @all;
my %reags; # hash for reagents for extID => seq2
push(@all,$gcrs->all);
#map { $reags{ $_->{probeID} } = \@{$_->{seq_array}} if scalar @{$_->{seq_array}} > 0 } @all;
map { $reags{ $_->{rgID} } = $_->{probeID} } @all;
print showtime().": ".scalar (keys %reags)." reagents read from Reagents\n";

#..... Getting all genes into hash to work with them faster
my $crs = $genes->find({},{"ensGID" => 1, "symbol" => 1, "synonyms" => 1, "transcripts.ensTID"=> 1});
$crs->immortal(1);
my %tr2genes;
my $g;
while (my $obj = $crs->next) {
	   grep { my @g = ( $obj->{"ensGID"}, $obj->{"symbol"}, @{$obj->{"synonyms"}} ); $tr2genes{ ${$_}{"ensTID"} } = \@g } @{$obj->{"transcripts"}};
	   $g++;
}
print showtime().": $g genes read from HMSPNSgenes\n";
open (LOG, ">$log" || "can't open $log: $!");
my $n=0;  my $nn=0;
foreach my $rgID (reverse sort keys %reags) {
	my @seq_array;
	my @tgenes;	
	my %gseen;
	if ($aligns{ $rgID }) {
		my @pids_array = split(/\n/,$aligns{$rgID});
		# warn scalar @pids_array;
		my %tgseen;
		my %p_aligns;		
		foreach my $r (@pids_array) {
			my ($pID, $strand, $tr, $coord, $subj, $q, $frq) = split(/\,/,$r);
			# warn $pID;
			$p_aligns{$pID} .= 	"$strand,$tr,$coord,$subj,$q,$frq\n";
		}
		my @tagin;
		foreach my $pID (keys %p_aligns) {
			my @trnsc;
			my @ugenes;
			# my %gseen;
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
					 	$tgseen{ $ensGID }++;					 	
					 	push(@tgenes,$ensGID) if $tgseen{$ensGID} == 1;
					 	my %tagin = (
								"ensGID" => $ensGID,
								"synonyms" => [@synonyms],
								"symbol" => $symbol	
					 	);
					 	push(@tagin,\%tagin);
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
		$n++;
		warn scalar @tagin if $rgID eq "DHARM0001051";
			eval {
				$re->update( { rgID => $rgID }, {'$pushAll' =>
						{ tagin => [@tagin] }
						}) or warn "$!";
			};
			if ( $@ =~ /can't get db response, not connected/ ) {
				eval {
				$re->update( { rgID => $rgID }, {'$pushAll' =>
						{ tagin => [@tagin] }
						}) or warn "$!";
				};
			}
	} else {
		my @pIDs = split(/\,/,$rg_pids{$rgID}) if $rg_pids{$rgID};
		foreach (@pIDs) {
			my %dataseq = (
				pID =>$_,
			);
			print LOG "bowtie returned NULL for ".$_." in $rgID pool !\n";			
			push (@seq_array, \%dataseq);
		}
		$nn++;		
	}
	# sleep(1) if $n%2 == 0;
	if ($aligns{ $rgID }) {
		eval {
			$re->update( { rgID => $rgID }, {'$pushAll' =>
					{ genes => [@tgenes] }
					}) or warn "$!";
		};
		if ( $@ =~ /can't get db response, not connected/ ) {
			eval {
				$re->update( { rgID => $rgID }, {'$pushAll' =>
						{  genes => [@tgenes] }
						}) or warn "$!";
			};
		}
		eval {
		$re->update( { rgID => $rgID }, {'$set' =>
					{ g_mapfreq => scalar @tgenes }
					}) or warn "$!";
		};
		if ( $@ =~ /can't get db response, not connected/ ) {
			eval {
				$re->update( { rgID => $rgID }, {'$set' =>
							{ g_mapfreq => scalar @tgenes }
							}) or warn "$!";
			};
		}
	}
	eval {
		$re->update( { rgID => $rgID }, {'$pushAll' =>
				{ seq_array => [@seq_array] }
				}) or warn "$!";
	};
	if ( $@ =~ /can't get db response, not connected/ ) {
		eval {
			$re->update( { rgID => $rgID }, {'$pushAll' =>
					{ seq_array => [@seq_array] }
					}) or warn "$!";
		};
	}	

	print $n+$nn." reagents updated, $n are targeting: ".showtime()."\n" if (($n+$nn)%1000 == 0);
	
}
print $n+$nn." reagents updated, $n are targeting, $nn are not\n";
close LOG;

print "end: ".showtime()."\n";
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}