#!/usr/local/bin/perl
use MongoDB;
use MongoDB::OID;

use strict;
# use warnings;
use File::Find;
my $path = "../infill-load-data/_idf/RNAi/";
use Encode;
my @files;	
opendir(D,$path || $!);
while (readdir(D)) {
	if ($_ !~ /^\./ && $_!~/reload/) {
		push @files,$path.$_ unless (-d $_ );
	}
}
closedir(D);
my $fields = "formats/fields.txt";
$MongoDB::BSON::utf8_flag_on = 0;
my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
my $db   = $conn->get_database( 'sym' ) ;

my $std = $db->get_collection( 'Studies');
my $sup = $db->get_collection( 'Suppliers');
my $sp = $db->get_collection( 'Species');
my $crs = $sup->query({});
my @supps;
push(@supps,$crs->all);

my %fields;
open (FL, $fields || "can't open datafile: $!");
	while(<FL>) {
		next if ($_ =~/#/ || $_ !~/\S/);
		$_ =~s/\n//;
		my ($k,$v) = split(/\t/,$_);
		map {$_ =~s/^\"|\"$|^\'|\'$|^\s|\s$// if $_ } ($k,$v);
		$fields{$v} = $k;
	}
close FL;

foreach my $format (@files) {
	print "Reading $format\n";
	my %study;
	open (FO, $format || "can't open datafile: $!");
		while(<FO>) {
			next if ($_ =~/#/ || $_ !~/\S/);
			$_ =~s/\n//;
			utf8::decode($_);			
			my $ord=1;
			my @arr = split(/\t/,$_);
			map {$_ =~s/^\"|\"$|^\'|\'$|^\s|\s$// if $_ } @arr;
			if ($fields{$arr[0] } =~/Std/) {
				$study{ $fields{$arr[0]} } = \@arr;

			} elsif ($fields{$arr[0] } =~/Scr/) {
				unless ($study{ $fields{$arr[0]}."-$ord" }) {
					$study{ $fields{$arr[0]}."-$ord" } = \@arr;
				} else {
					$ord++;
					$study{ $fields{$arr[0]}."-$ord" } = \@arr;
				}
			}
		}
		warn @{$study{StdID}}[1].": reading Study's IDF file";
	# map { my @arr = @{$study{$_}}; print $_." : ".$arr[1]." | ".$arr[2]."\n" if (($arr[1] || $arr[2]) && $_ =~/Scr/); } sort keys %study;	
		
	close FO;
	my @screens;
	my @sn = @{$study{StdScrns}};
	$std->remove( { StdID=> @{$study{StdID}}[1] } );

	foreach my $n (1..$sn[1]*1) {
		my $scrID = @{$study{StdID}}[1]."_$n";
		my %screendata;
		my @protocols;
		my @phenotypes;
		my @scores;
		my @prnames; 	my @prdescr;
		my @phenonames;	my @phenodescrs; my @phenosctypes; my @phenoscparameters; my @phenoscvalues;
		my @clmnames; 	my @clmntypes;	 my @clmnunits;	my @clmndescrs;
		my %libdata;
		foreach my $s ( sort keys %study ) {
			if ($s =~/\-$n/ && $s =~/Scr/) {
				my @arr = @{$study{$s}};
				my $k = $s;
				$k =~ s/\-$n//gsm;
				my $ord = $n-1;
				my %ldata = (); 
				%ldata = %{$screens[$ord-1]} if $screens[$ord-1];
				unless ($s =~ /ScrProtocol/ || $s =~ /ScrPh/ || $s =~ /ScrColmn/ || $s =~ /ScrLib/) {
					if ($screens[$ord-1] && $arr[1] =~/screen\s$ord/) {
						$screendata{$k} = $ldata{$k};
					} else {
						$screendata{$k} = $arr[1];
					}	
				}
				if ($s =~ /ScrProtocol/) {
					@prnames = @{mapVal($ord, "ScrProtocolN", \@arr, \@screens,\@{$ldata{ScrProtocol}}) } if ($s =~/ScrProtocolN/);
					@prdescr = @{mapVal($ord, "ScrProtocolDescr", \@arr, \@screens, \@{$ldata{ScrProtocol}}) } if ($s =~/ScrProtocolDescr/);
				}
				if ($s =~ /ScrPh/) {
					@phenonames = @{mapVal($ord, "ScrPhName", \@arr, \@screens, \@{$ldata{ScrPhenotypes}}) } if ($s =~/ScrPhName/);
					@phenodescrs = @{mapVal($ord, "ScrPhDescr", \@arr, \@screens, \@{$ldata{ScrPhenotypes}}) } if ($s =~/ScrPhDescr/);
					@phenosctypes = @{mapVal($ord, "ScrPhScType", \@arr, \@screens, \@{$ldata{ScrPhenotypes}}) } if ($s =~/ScrPhScType/);
					@phenoscparameters = @{mapVal($ord, "ScrPhScParams", \@arr,\@screens, \@{$ldata{ScrPhenotypes}}) } if ($s =~/ScrPhScParams/);
					@phenoscvalues = @{mapVal($ord, "ScrPhScRules", \@arr,\@screens, \@{$ldata{ScrPhenotypes}}) } if ($s =~/ScrPhScRules/);
				}
				if ($s =~ /ScrColmn/) {
					@clmnames =  @{mapVal($ord, "ScrColmnN", \@arr, \@screens, \@{$ldata{ScrColmns}}) } if ($s =~/ScrColmnN/);
					@clmntypes =  @{mapVal($ord, "ScrColmnT", \@arr, \@screens, \@{$ldata{ScrColmns}}) } if ($s =~/ScrColmnT/);
					@clmnunits =  @{mapVal($ord, "ScrColmnU", \@arr, \@screens, \@{$ldata{ScrColmns}}) } if ($s =~/ScrColmnU/);
					@clmndescrs=  @{mapVal($ord, "ScrColmnD", \@arr, \@screens, \@{$ldata{ScrColmns}}) } if ($s =~/ScrColmnD/);
				}
				if ($s =~ /ScrLib/) {
					if ($screens[$ord-1] && $arr[1] =~/screen\s$ord/) {
						my %arlib = %{$ldata{ScrLib}};
						$libdata{$k} = $arlib{$k};
					} else {
						$libdata{$k} = $arr[1];
					}
					
				}
			}
		}
				# $screendata{ScrLibV}, $screendata{ScrLibT}, $screendata{ScrLibM}
		foreach my $s (@supps) {
			$libdata{SupID} = $s->{SupID} if ($libdata{ScrLibM} eq $s->{SupName});
			my %libs = %{$s->{Libraries}};
			map { $libdata{LibID} = $_*1 if ($libdata{ScrLibT} eq $libs{$_}) } keys %libs;
		}
		
		foreach ( 0 ..  $#prnames) {
			my %hash = ("ScrProtocolN"=>$prnames[$_], "ScrProtocolDescr"=>$prdescr[$_]);
			push @protocols, \%hash;
		}
		foreach ( 0 ..  $#phenonames) {
			$phenoscvalues[$_] =~s/\s//gsm;
			$phenoscvalues[$_] =~s/or/\|\|/gsm;
			$phenoscvalues[$_] =~s/and/\&\&/gsm;
			$phenoscparameters[$_] =~s/\s//gsm;
			my %hash = ("ScrPhName"=>ucfirst($phenonames[$_]), "ScrPhDescr"=>$phenodescrs[$_], 
					"ScrPhScType"=>$phenosctypes[$_], "ScrPhScParams"=>lc($phenoscparameters[$_]), "ScrPhScRules"=>lc($phenoscvalues[$_]));
			push @phenotypes, \%hash;
		}
		$screendata{ScrScAbbrev} =~s/(\;$)//gsm;
		$screendata{ScrScAbbrev} =~s/\s+\=/\=/gsm;
		$screendata{ScrScAbbrev} =~s/\=\s+/\=/gsm;
		$screendata{ScrScAbbrev} =~s/\s+\;/\;/gsm;
		$screendata{ScrScAbbrev} =~s/\;\s+/\;/gsm;
		my @columns = (0 ..  $#clmnames);
			my $vals = lc($screendata{ScrScAbbrev});
			my @abbrev = split(/\;/,$vals);
			my %vabbrev;
			foreach my $ab (@abbrev) {
				my ($ab,$name) = split(/\=/,$ab);
				$ab =~s/\s//gsm;
				$name =~s/\s//gsm;
				$vabbrev{$name} = $ab;
			}
		my @abbrev;	
		foreach ( 0 ..  $#clmnames) {
			$clmnames[$_] =~s/\s//gsm;
			my %hash = (ScrColmnN=>($clmntypes[$_] eq "Score") ? lc($clmnames[$_]) : $clmnames[$_],
					ScrColmnT=>$clmntypes[$_],ScrColmnU=>$clmnunits[$_],ScrColmnD=>$clmndescrs[$_],ScrColmnNum=>$columns[$_],
					ScrColmnShrt=>$screendata{ScrScAbbrev} ? $vabbrev{ lc($clmnames[$_])} : ($clmntypes[$_] eq "Score") ? lc($clmnames[$_]) : "" 
					);
			push @scores, \%hash;
			push @abbrev, "$hash{ScrColmnShrt}=$hash{ScrColmnN}" if $clmntypes[$_] eq "Score";
		}
		$screendata{ScrScAbbrev} = join(";",@abbrev);
		$screendata{ScrProtocol} = \@protocols;
		$screendata{ScrPhenotypes} = \@phenotypes;
		$screendata{ScrColmns} = \@scores;
		$screendata{ScrID} = $scrID;
		$screendata{ScrLib} = \%libdata;
		my $scrs = $sp->find({'$or'=> [{aliases=>qr/$screendata{ScrTrgOrganism}/},{name=>$screendata{ScrTrgOrganism}}] });
		my $obj = $scrs->next;
		$screendata{ScrCollection} = $obj->{collection};
		push @screens, \%screendata;
	}
	my %studydata;
	foreach (sort keys %study) {
		if ($_ =~/Std/) {
			my @arr = @{$study{$_}};
			$studydata{$_} = $arr[1];
		}
	}
	$MongoDB::BSON::utf8_flag_on = 1;
	$studydata{ScreenData} = \@screens;
	# map {  utf8::encode($studydata{$_}) } keys %studydata;
	if ($studydata{ScreenData} ne "" && $studydata{StdSpc} =~/\w+/ && $studydata{StdPubTitle} =~/\w+/ && $studydata{StdTitle} =~/\w+/) {
		$std->insert( { %studydata });
		print "Study from $format is loaded\n";
	} else {
		print "Study from $format isn't loaded: check format!\n";
	}
}
#............ map the repeating values in columns

sub mapVal {
my ($ord,$key, $arr, $screens, $data) = @_;
	my @screens = @{$screens};
	my @arr = @{$arr};
	my @final = ();	
	map { 
		if ($screens[$ord-1] && $arr[$_+1] =~/see\sscreen\s$ord/) {
			my @lnames = @{$data};
			# warn $lnames[$_]{"$key"};
			push @final,$lnames[$_]{$key};
		} else {
			push @final,$arr[$_+1];
		}
	} (0 .. $#arr-1);
return \@final;
}