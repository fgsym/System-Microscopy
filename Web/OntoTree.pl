#!/usr/bin/perl
use strict;
use MongoDB;
use warnings;
print "start: ".showtime()."\n";
    my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) or warn $!;
    my $db   = $conn->get_database( 'sym' ) ;
    my $onto = $db->get_collection( 'Ontology' );

my $crs = $onto->query({});
my %terms;
my %prnts;
my %kids;
while (my $obj = $crs->next) { 
	my @is_a = @{$obj->{is_a}};
	if (scalar @is_a >0) {
		foreach (@is_a) {
			push @{ $prnts{$obj->{OntID}} },$_->{OntID}; #unless $branches{ $obj->{id} }; # $prnts {CMPO:0000258} = CMPO:0000003 (parent) or $prnts{id} = is_a.id
			push @{ $kids{$_->{OntID}} },$obj->{OntID};
		}
	}
	$terms{ $obj->{OntID} } = $obj->{OntID};
}
# make branches
my %all_in_tree;
foreach my $c (sort keys %prnts) {	
	my @is_a = @{$prnts{$c}};
	for my $i (0 .. $#is_a) {
		$all_in_tree{$c."-".$i} = $is_a[$i];
	}
}
warn scalar (keys %kids);
warn scalar (keys %all_in_tree);
# tree with unified ids 
my %all_utree; 
foreach my $ci (keys %all_in_tree) {
	my ($c, $i) = split(/\-/,$ci);	
	foreach my $xi (sort keys %all_in_tree) {
		$all_utree{$xi} = $ci if ($all_in_tree{$xi} eq $c);
	}
	$all_utree{$ci} = "CMPO:0000003" if ($all_in_tree{$ci} eq "CMPO:0000003")
}
my %threads;
my %ar_to_ci;
foreach my $ci (keys %all_utree) {
	my $kid;
	my $n=0;
	my $thrd="";
	$kid = $ci;
	loop:
	if ($all_utree{$kid}) {
		$thrd = $kid.">".$thrd;
		$kid = $all_utree{$kid};
		$n++;
		goto loop;
	} else {
		# root found;
		chop $thrd;
		push @{$threads{$n}}, $thrd;
	}
}
my $dp;
foreach (1 .. 10) {
	if ($threads{$_} && @{$threads{$_}}) {
		print "$_: \n".join ("\n", @{$threads{$_}} )."\n";
	} else {
		$dp = $_-1;
		last;
	}	
}
my $deep = scalar (keys %threads); 
warn $deep;
my $tree="";
foreach my $f1 (sort  @{$threads{1}} ) {
	$tree .= "+-- ".$f1."\n";  # must be global!
	$tree = same_parent_kids(2, $f1, \@{$threads{2}}, $deep, \%threads, \%kids, "");	
}
# $tree =~s{<ul></ul>\n}{}gsm;
print "\n".$tree;
print "\nend: ".showtime()."\n";

# same parent kids;
sub same_parent_kids {
	my ($level, $branch, $treads, $deep, $threads, $kids, $length) = @_;
		$length .= "---";
		foreach my $f ( sort @{$treads} ) {
			my $r = substr($f,0,-15);
			my $id = substr($f,-14);
			my $pid = substr($id,0,-2);
			if ($r eq $branch) {
				$tree .= $length."+<li> ".$id;
				if ($level <= $deep) {		
					$tree .= "\n";
					$tree .= "<ul>" if $kids{$pid};
					same_parent_kids($level+1, $f, \@{$threads{$level+1}}, $deep, \%{$threads}, $kids, $length);
					$tree .= "</ul>\n" if $kids{$pid};
				}		
			}			
		}
		$length = substr($length,0,-3);	
return $tree;	
}
##############################################################
sub showtime {
	my @arr=localtime();
	$arr[5]+=1900;$arr[4]++;$#arr=5;
	my ($year,$month,$day,$hour,$min,$sec) = reverse @arr;
	return "$year-$month-$day $hour:$min:$sec";
}