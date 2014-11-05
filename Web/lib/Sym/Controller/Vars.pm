package Sym::Controller::Vars;
use strict;
use warnings;
use base 'Mojolicious::Controller';
# call from    : /search/reagent.html.ep
# methods      : Sym::Model::MongoQ->get_supplier_by_id
# collections	: Suppliers
sub supplier_data {
  my ($self,$obj) = @_;  
  my $des = $obj->{libID};
  my $scrs = Sym::Model::MongoQ->get_supplier_by_id($obj->{supID});
  my ($sname, $descr);
  while (my $sobj = $scrs->next) {
    $sname = $sobj->{SupName};
    my %hash = %{$sobj->{Libraries}};
    $descr = $hash{ $obj->{libID} };
  }  
  return ($sname, $descr); 
}

1;
