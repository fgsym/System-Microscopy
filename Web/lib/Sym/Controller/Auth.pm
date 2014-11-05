package Sym::Controller::Auth;
use strict;
use warnings;
# use v5.10;
use base 'Mojolicious::Controller';

# Login user otherwise redirect to registration page
sub login {
  my $self = shift;
  my $login = $self->param('login'); 
  my $pass  = $self->param('pass');
    if ( $GLV{AUTH}->check($login, $pass) ) {  
warn ($login, $pass);
        # save to session and redirect user back, with transmitting welcome or error messages to template
        $self->session(
            # user_id => $user->{user_id},
            # login   => $user->{login}
            user  => $GLV{AUTH}->check($login, $pass),
            login => $login
        )->flash( welcome => "welcome!" )->redirect_to($self->req->headers->referrer); # go back if succeded
    } else {
        $self->flash( error => "Wrong password or user does not exist!" )->redirect_to($self->req->headers->referrer);
    }
}

# Logout user
sub delete {
    my $self = shift;
    $self->session( user => '', login => '' )->flash( bye => "now you are out")->redirect_to($self->req->headers->referrer); 
}

1;