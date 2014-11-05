package Sym::Controller::Includes;
use strict;
# use v5.10;
use base 'Mojolicious::Controller';
use vars qw($relpath);
*relpath = \%Sym::relpath;
sub ph_renew {
  my $self = shift;
  $self->render();
}

sub search_form {
  my $self = shift;
  my $genome = $self->param('genome');
  $self->signed_cookie(genome=>$genome, {path=>'$relpath/'});
  $self->render();
}
1;