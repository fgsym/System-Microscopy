export PERLBREW_ROOT=./perl-libs/
\wget -O - http://install.perlbrew.pl | bash (\curl -L http://install.perlbrew.pl | bash)
./perl-libs/perlbrew/bin/perlbrew init
./perl-libs/perlbrew/bin/perlbrew  install-cpanm
./perl-libs/perlbrew/bin/cpanm -i MongoDB --local-lib ./perl-libs/

Ping DB connetion (every 5 min):
*/5 * * * * /script/pingMongoDB.pl