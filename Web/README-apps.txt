INSTALLATION

1)

All perl packages are managed localy with perlbrew, installed like this:
$ export PERLBREW_ROOT=/nfs/public/rw/homes/fg_sym/live/app/perl-libs
$ curl -L http://install.perlbrew.pl | bash
$ ./perl-libs/bin/perlbrew init

perlbrew is here:
/nfs/public/rw/homes/fg_sym/live/app/perl-libs/

2) 

$ ./perl-libs/bin/perlbrew install 5.14.2
$ ./perl-libs/bin/perlbrew install-cpanm


