package Sym::Controller::Studies;
use strict;
use warnings;

sub studies {
  my $self = shift;
  my @scr_obj = @{Sym::Model::MongoQ->get_all_screens()};
  my %scr_data;  
  	foreach my $obj (@scr_obj) {
		foreach (@{$obj->{ScreenData}}) {
    			$scr_data{ $_->{ScrID} } = $obj->{StdTitle}."__".$_->{ScrType};
		}
  	}
return \%scr_data;  	
}	
1;