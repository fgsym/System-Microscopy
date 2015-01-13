package Sym;
use strict;
use base 'Mojolicious';
use Mojo::Base 'Mojolicious::Controller';
# use Mojo::Server::Hypnotoad;
use Mojolicious::Sessions;
use Time::Piece; 
use MongoDB;
use Mojo::URL;
use vars qw(%GLV $relpath);
# If you need a core documentation for this code just type http://your-www-server-name/perldoc
# This method will run once at server start 

sub startup {
  my $self = shift;
  my $config = $self->plugin('JSONConfig');  
  $GLV{release} = $config->{release}; 
  $GLV{CONFIG} = $config;
  $self->res->headers->cache_control('max-age=1, no-cache');  
# connect to Mongo DB:   
      $self->attr(db => sub { 
        MongoDB::Connection->new(host => $config->{dbhost}, query_timeout => -1, find_master => 1)
            ->get_database($config->{dbname});
      });
      eval { 
        $self->helper('db' => sub { shift->app->db }) || warn $!;     
      };
      if ($@ =~ "response") {
            $GLV{DB} = "";
            warn "wth"
      } else {
        $GLV{DB} = $self->db;
        $GLV{Std} = $self->db->get_collection( 'Studies' );
        $GLV{Data}= $self->db->get_collection( 'Datasets' );
        $GLV{Genes}= $self->db->get_collection( 'HMSPNSgenes' );
        $GLV{FBgn}= $self->db->get_collection( 'FruitFLYgenes' );  
        $GLV{Reags}= $self->db->get_collection( 'Reagents' );
        $GLV{PRC}= $self->db->get_collection( 'ProcessedData' );
        $GLV{Supl}= $self->db->get_collection( 'Suppliers' );
        $GLV{Onto}= $self->db->get_collection( 'GO_Analysis' );
        $GLV{Phn}= $self->db->get_collection( 'Phenotypes' );
        $GLV{Msgs} = $self->db->get_collection( 'Messages' );
        $GLV{Stts} = $self->db->get_collection( 'Statistics' );
        $GLV{Oterms} = $self->db->get_collection( 'T_Ontology' );
        $GLV{Grid} = $self->db->get_gridfs;
        $GLV{Files} = $self->db->get_gridfs->files;
      }  
  my %vars;
  my $relpath = "/fg/sym";
  my $req = Mojo::Message::Request->new;
    $self->hook(before_dispatch => sub {
      my $self = shift;
      # my @params = @{$self->req->url->query->params};
      push @{$self->req->url->base->path->parts}, splice @{$self->req->url->path->parts}, 0, 2;
      my @uparts = @{$self->req->url->path->parts},0,2;
 
      # my @uparts = @{$self->req->url->path->parts};
      my $navbar = "";
      if (scalar @uparts >0) {
        $navbar = ucfirst($uparts[0])." > "  unless $uparts[0] =~ /(src|css|ebisearch)/;
      };
      my $q = $self->param('genename') ? $self->param('genename') : $self->param('gene');
      $q = $q ? $q : $uparts[1] ? $uparts[1] : "";
      %vars = (current => $q, navbar => $navbar);
      $self->stash(%vars);
      return 1;
    });    
  # $self->hook(before_dispatch => sub {
    # my $self = shift;
    # push @{$self->req->url->base->path->parts}, splice @{$self->req->url->path->parts}, 0, 2;
    # });

  $self->plugin('PODRenderer');
# Secret word for cookies
#  $self->secret('NobodyButYou');

# Add PLugin Mojolicious::Plugin::JsonConfig, that reads our sym.json, our config now is in $config
# Access to config is $self->stash('config')

# A hash for site's navigator (formed in default.html.ep)
  my %menu;
  my %navhash = %{$config->{navigator}};
  map { $menu{$navhash{$_}[0]} = [$_,$navhash{$_}[2]] unless $navhash{$_}[0] eq "0"} keys %navhash;

  $self->sessions->cookie_name('genome');
  $self->sessions->default_expiration(86400);

  my $r = $self->routes;
  # $r->namespace('Sym::Controller');
  if (!$GLV{DB}) {
    %vars = (%vars, namespace => 'Sym::Controller', relpath=>$relpath, ephID=>"",choice=>"", ScrID=>"");
    goto stop;
  }
# my $conn = MongoDB::Connection->new("host" => "localhost:27017",query_timeout => 100000) || $!;
  my $current;
  Mojo::Loader->load('Sym::Model');
  Mojo::Loader->load('Sym::Model::MongoQ');
  Mojo::Loader->load('Sym::Controller');
  Mojo::Loader->load('Sym::Controller::Search');
  Mojo::Loader->load('Sym::Controller::Autocomplete');
  Mojo::Loader->load('Sym::Controller::Service');
  Mojo::Loader->load('Sym::Controller::Genes');
  Mojo::Loader->load('Sym::Controller::Studies');
  Mojo::Loader->load('Sym::Controller::Phenotypes');
  Mojo::Loader->load('Sym::Controller::Vars');
  Mojo::Loader->load('Sym::Controller::View'); 
  Mojo::Loader->load('Sym::Controller::Output'); 
  Mojo::Loader->load('Sym::Controller::Ontologies');

  # Load and init Model
  # my $phenos = Sym::Controller::Phenotypes->get_all_phenotypes();
  # my @phenos = @$phenos;
  %vars = (%vars, namespace => 'Sym::Controller', relpath=>$relpath, ephID=>"",choice=>"", ScrID=>"");
  # $GLV{MODEL} = Sym::Model->init( $config->{db},$config->{queries} );
  # $GLV{AUTH} = AuthUser->new();

# TODO: check routes from sym.json and here, optimize those without parameters

# Routes to controller (see name of classes before '#' and methods there which have names as after '#' keyword in $navhash{$_})
# $r->route(status=>404)->to('output#errordb', menu => \%menu);
  map { $r->route($_)->to($navhash{$_}[1], menu => \%menu, %vars) } keys %navhash;
  $r->route('/phenotypes/:ScrID', ScrID => qr/\S+/)->name('ScrID')->to('output#phenotypes', menu => \%menu, %vars);
  $r->route('/oterms/:ScrID', ScrID => qr/\S+/)->name('ScrID')->to('output#oterms', menu => \%menu, %vars);
  # $r->route('/pheno/:id', id => qr/\S+/)->name('id')->to('output#pheno', menu => \%menu, %vars);
  $r->route('/oligos/:id', id => qr/\S+/)->name('id')->to('output#oligos', menu => \%menu, %vars);
  $r->route('/phenoshow/:did', did => qr/\S+/)->name('did')->to('output#phenoshow', menu => \%menu, %vars);
  $r->route('/replica/:rp', rp => qr/\S+/)->name('rp')->to('output#replica', menu => \%menu, %vars);  
  $r->route('/search/pheno/:pheno', pheno=> qr/\S+/)->name('pheno')->to('search#respheno', %vars);
  $r->route('/form')->to('includes#search_form', menu => \%menu, %vars);  
  $r->route('/output/tsvpheno/:pheno', pheno=> qr/\S+/)->name('pheno')->to('export#tsvpheno', %vars);
  $r->route('/search/phenotips/:ph', ph => qr/\S+/)->name('ph')->to('search#phenotips', %vars);
  $r->route('/study/:std', exp => qr/\S+/)->name('std')->to('output#study', %vars);
  $r->route('/reagent/:reagent', reagent=> qr/\S+/)->name('reagent')->to('search#reagent', %vars);
  $r->route('/gene/:gene', gene=> qr/\S+/)->name('gene')->to('search#gene', %vars);  
  $r->route('/transcript/:transcript', transcript=>qr/\S+/)->name('transcript')->to('view#transcript', %vars);
  $r->route('/statmapping/')->to('view#mapping_statistics', %vars);
  $r->route('/ontostats/')->to('view#ontology_stats', %vars);
  $r->route('/stats/')->to('output#stats', %vars);
  $r->route('/story/')->to('output#story', %vars);
  $r->route('/genebrowse/')->to('genes#genebrowse', %vars);   
  $r->route('/genebrowse/all/:count')->name('count')->to('genes#genebrowse', %vars); 
  $r->route('/genebrowse/unique/:count')->name('count')->to('genes#genebrowse', %vars);    
  $r->route('/generate_list/:phenoprint')->to('service#generate_list', %vars);
  $r->route('/getfile/:data')->to('service#getfile', %vars);  
  $r->route('/autocomplete/genefilter')->to('autocomplete#genefilter', %vars);
  $r->route('/autocomplete/attribute')->to('autocomplete#attribute', %vars);
  $r->route('/autocomplete/phenofilter')->to('autocomplete#phenofilter', %vars);
  $r->route('/autocomplete/ontofilter')->to('autocomplete#ontofilter', %vars);  
  $r->route('/(*everything)')->to('output#page', menu => \%menu, %vars);
  # $r->route('/export/:val', val => qr/\S+/)->name('val')->to('output#export', %vars);
stop:
  $r->route('/(*exception)')->to('exception', menu => \%menu, %vars); 

# sub take_session {
  # my $self = shift;
  # my $msg;
  # my $nick = $self->session('login') ?  $self->session('login') : "";
  # $msg =  $self->session('login') ? "You are in" : "";
  # return ($msg,$nick);
# }
}
1;
