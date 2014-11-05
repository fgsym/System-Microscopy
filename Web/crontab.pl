#!/usr/local/bin/perl
use strict;
my $cmd = "/nfs/public/rw/homes/fg_sym/live/mongodb-2.4.3/bin/mongod --dbpath /nfs/public/rw/homes/fg_sym/live/data/ & hypnotoad /nfs/public/rw/homes/fg_sym/live/app/script/sym";
exec($cmd) || warn "$!";