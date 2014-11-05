package Sym::Model;
use strict;
use warnings;
# use v5.10;
use DBIx::Connector;

use Mojo::Loader;

# Reloadable Model
my $modules = Mojo::Loader->search('Sym::Model');
for my $module (@$modules) {
        Mojo::Loader->load($module)
}

# Params: hash with DB params and hash with sql-queries
# Does:   construct a class
sub init {
    my $class = shift;
    my ($db, $queries, $code) = @_;
    my $self = {};
    bless($self,$class);    
    $self->{dbh} = DBIx::Connector->connect(@$db{qw/dsn user password/}) or return 0;
    $self->{dbh}->{PrintError} = 1;

    $self->{dynamic} = {};

    $self->{queries} = $queries;
# Use $code in the case of the problems with non-utf encoding		
    if (defined $code && $code eq "utf8") {
        $self->{dbh}-> do("SET NAMES 'utf8' COLLATE 'utf8_general_ci'");
    }       
    return $self;        
}

# Params: sql template name
# Does:   loads sql to memory, and calls prepare()
sub load_sql {
        my ($self,$sql) = @_;
        return if defined $self->{sql}->{$sql};
		my $text = $self->{queries}->{$sql};
		warn "---SQL WARN !!!--- can not prepare $text of refer $sql" unless $self->{dbh}->prepare($text);
		$self->{sql}->{$sql} = $self->{dbh}->prepare($text)  || return unless $self->{sql}->{$sql};
}

# Params: name of sql query, @vars
# Does:   loads sql and executes it
sub prepare_sql {
        my ($self,$sql,@vars)=@_;
		$self-> load_sql($sql) unless defined $self->{$sql};
		unless ( $self->{sql}->{$sql}->execute(@vars) ) {
			warn "---SQL WARN !!!--- can not execute query of refer '$sql' with vars: @vars ";
			return "-"
		} else {return "+"}
}

# Params: name of sql query
# Does:   fetches row from DB
sub fetch_sql {
        my ($self,$sql)=@_;
        return $self->{sql}->{$sql}->fetchrow_hashref();
}

# Params: name of sql query, values of query
# Does:   bind a parameter to query
sub do_bind {
       my ($self,$sql,$v)=@_;
	$self-> load_sql($sql) unless defined $self->{$sql};
	$self->{sql}->{$sql}->bind_param (2,$v,4);
}

# Params: sql query
# Does:   execute sql
sub exec_sql_code {
	my ($self,$sql)=@_;
	$self->{sql}->{$sql} = $self->{dbh}->prepare($sql);
	unless ($self->{sql}->{$sql}->execute() ) {
		warn "---SQL WARN !!!--- error in query $sql ! ";
	}
        my @arr;    my $t;
        while (defined ($t=$self-> fetch_sql($sql))) {
                push(@arr,{( %{$t} )});
        }
        return @arr;
}

# Params: name of sql query, values of query
# Does:   loads sql, executes it and fetches all data
sub prepare_and_fetch_sql {
        my ($self,$sql,@vars)=@_;
        $self-> prepare_sql($sql,@vars);
        my @arr;    my $t;
        while (defined ($t=$self-> fetch_sql($sql))) {
                push(@arr,{( %{$t} )});
        }
#	$self->{dbh}-> commit;
        return @arr;
}
# Does: disconnects
sub DESTROY {
        my ($self)=@_;
        foreach (keys %{$self->{sql}}) {
                $self->{sql}->{$_}=undef;
        }
	$self->{dbh}->disconnect() if $self->{dbh};
}

1;