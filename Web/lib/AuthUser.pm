package AuthUser;

use strict;
use warnings;
use base 'Mojolicious::Controller';

my $USERS = {
    qq    => 'zz'
};

sub new {
	my $class = shift;
	# my ($SQL) = @_;
	my $self={};
	# $self->{sql} = $SQL;
	bless($self,$class);
	return $self;
}

# Check if user is logined
sub check {
    my ($self, $user, $pass) = @_;

    # Success
    return $user if $USERS->{$user} && $USERS->{$user} eq $pass;

    # Fail
    return;
}
