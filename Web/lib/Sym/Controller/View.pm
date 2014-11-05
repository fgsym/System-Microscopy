package Sym::Controller::View;
use strict;
use GD;
use GD::Graph::linespoints;
use vars qw(%GLV $sessions);
*GLV = \%Sym::GLV;
# use v5.10;
use base 'Mojolicious::Controller';
# url from     : /transcripts/ (from /search/reagent.html.ep)
# methods 	: Sym::Model::MongoQ->get_gene_by_ensGID
# collections	: HMSPNSgenes
sub transcript {
  my $self = shift;  # $tb,$te : begin/end siRNA coords 
  my ($rgID,$genome,$ensGID) = split (/\:/,@{$self->req->url->path->parts}[1]);
  my $hcrs = Sym::Model::MongoQ->get_gene_by_ensGID($genome,$ensGID);
  my $obj = $hcrs->next; 
  my $iwidth = 830;
  my %tags = %{$self->tags_by_transcript($rgID)};
  my %exons = %{$self->exons_by_gene($obj)};
  my %translations; 
  map {$translations{$_->{ensTID}} = $_->{translation}} @{ $obj->{transcripts} };
  my $height = scalar(keys %exons);
  $height = $height*27+35;
  # invoke image  #                                                  IMAGE INVOKE  
  my $img = new GD::Image($iwidth+30,$height);
  # colours

  my $white = $img->colorAllocate(255,255,255);
  my $black = $img->colorAllocate(0, 0, 0);
  my $darkgrey = $img->colorAllocate(150, 150, 150);
  my $grey = $img->colorAllocate(200, 200, 200);
  my $lightgrey = $img->colorAllocate(220, 220, 220);  
  my $blue = $img->colorAllocate(80, 125, 185);
  my $trgreen = $img->colorAllocate(110, 155, 215);  # perl -e 'use GD::Graph::colour; print GD::Graph::colour::rgb2hex(90, 215, 140)."\n"'
  my $darkblue = $img->colorAllocate(15, 55, 100);
  my $red = $img->colorAllocate(255,0,0);

  # coordinates  #                                                   LINE
  my $font = $GLV{CONFIG}->{font};
  # $img->dashedLine(0, 9, 600, 0, $black);

  my $y = 25;
  my $is = 180;  # indent for transcripts

  # coord. line
  $img->line($is,$y+3,$iwidth+15,$y+3,$black);
  $img->line($is,$y,$is,$height,$grey); # first vertical grid line  
  $img->line($is,$y,$is,$y+6,$black);   # first tick
  # arrow
  my $arrow = new GD::Polygon;
        $arrow->addPt($iwidth+7,$y);
        $arrow->addPt($iwidth+14,$y+3);
        $arrow->addPt($iwidth+7,$y+6);
  #
  $img->filledPolygon($arrow,$black);
  my (@starts,@ends);
  foreach my $tr (sort keys %exons) {
      my @exs = @{ $exons{$tr} };
      foreach my $ex (@exs) { 
        my ($s,$e,$d,$rs,$re) = split(/\|/,$ex);
        push (@starts,$s);
        push (@ends,$e);        
      }  
  }
  #  coordinates and grid  >>>
  my $kstart = $obj->{start};
  my $kend = $obj->{end};
  my $start= $kstart > 1000000 ? $kstart/1000000 : $kstart/1000;
  my $end = $kend > 1000000 ? $kend /1000000 : $kend/1000;
  my $unit = $kend > 1000000 ? "Mb" : "Kb";
  my $klength = ($kend - $kstart)/1000;
  my $scale = ($iwidth - $is)/($kend - $kstart);
  
  my $ticks = int(10000*($end-$start));
  my $first = sprintf("%.5f",$start);
  
  # my $back = ($klength < 10) ? 52 : ($klength > 10 && $klength < 100) ? 44 : 
                                        # ($klength > 100 && $klength < 1000) ? 36 : ($klength > 1000 && $klength < 10000) ? 28 : 20;
                                        
  $img->stringFT($black, $font, 8, 0, $is-60, 41, $first.":");
  my $lunit = $klength > 1000 ? "Mb" : "Kb";
  $img->stringFT($black, $font, 9, 0, 5, 15, "gene length : $klength ".$lunit);

  my $rlength = ($klength*$scale*1000); # length of the transcript on the genomic coordinates
  # coordinate scale
  # NB: $klength = ($kend-$kstart)/1000
  my $spow = $klength/10; 
  my $step = $spow*0.001;
  
  # $step = sprintf("%.1f",$step);
  # my $add = ($spow*0.001 - sprintf("%.1f",$step));
   
  my $inten = $klength < 1 ? $klength*100 : ($klength < 10 && $klength >= 1) ? $klength*10 : $klength;
  my $pow = $inten <= 10 ? 1 : $inten/10;     
  $inten = $inten/$pow;
  my $wstep = sprintf("%.0f",$rlength/($inten));
  # warn "inten = $inten, step=$step, wstep=$wstep, klength=$klength, pow=$pow/$spow";
    for my $n (0 .. sprintf("%.0f",$inten) ) {
      my $x = ($wstep < 10) ? $is+10*$n*$wstep : $is+$n*$wstep;
      if ( $x < ($iwidth+10) && $x > $is-1) {
        for my $k ( 0 .. 10 ) {
          my $xi = ($wstep < 10) ? $x + $k*$wstep: $x + $k*$wstep/10;
          $img->line($xi,$y+5,$xi,$height,$lightgrey) if ($xi < $iwidth+10 && $xi > $is);
          if ( $k%10 != 0 ) {
            if ($k%5 == 0) {
              $img->line($xi,$y,$xi,$y+5,$black) if ($xi < $iwidth+10  && $xi > $is);
            } else {        
              $img->line($xi,$y+2,$xi,$y+4,$black) if ($xi < $iwidth+10 && $xi > $is);
            }  
          }
        }
        my $coord = $n*$step+$first;
        $coord = ($klength < 1) ? sprintf("%.5f",$coord) : ($klength < 10 && $klength >= 1) ? sprintf("%.4f",$coord) : sprintf("%.3f",$coord);
        $img->line($x,$y+5,$x,$height,$grey);
        $img->line($x,$y-1,$x,$y+6,$black);           
        $img->stringFT($black, $font, 8, 0, $x-20, 21, $coord) if $n>0;
      }
    }
  $img->stringFT($black, $font, 8, 0, $iwidth+5, 43, $unit); 
  # <<< 
  $img->transparent($white);
  $img->interlaced('true');
  my $t=1;
  my $exseq = 0;

  foreach my $tr (sort keys %exons) {
      my @exs = @{ $exons{$tr} };
      my $y = 25*$t+25;
      my ($e1, $s1) = ($kstart, 0);
      my ($lengthT,$strandT,$startT,$endT);
      foreach (@{$obj->{transcripts}}) {
        if ($_->{ensTID} eq $tr) {
          $strandT = $_->{strandT};
          $startT = $_->{startT};
          $endT = $_->{endT};
          $lengthT = $_->{lengthT};
        }
      }
      my ($st,$et,$dt) = split(/\|/,$tags{$tr}) if $tags{$tr}; # REAGENT: relative start, relative end, strand, evalue
      $exseq++ if $et;
      my ($strand,$st1,$et1); # scaled absolute REAGENT's coordinates 
      $img->rectangle($is,$y,$is+$rlength+1,($y+10),$blue); # gene borders 
    
      foreach my $ex (@exs) { 
        my ($s,$e,$d,$rs,$re) = split(/\|/,$ex); # EXON: start, end, strand, relative start, relative end 
#        warn "($s,$e,$d,$rs,$re)";
        $strand = $d;
        my $s1 = sprintf("%.0f",$scale*(($s - $kstart)));
        my $e1 = sprintf("%.0f",$scale*(($e - $kstart)));
        $img->filledRectangle(($is+$s1),($y+1),($is+$e1),($y+10),$trgreen);      
        if ($tags{$tr}) {
#          warn $tags{$tr};
          # warn "($st >= $rs && $st < $re) || ($et <= $re && $et > $rs)";
          my ($stn, $etn); # absolute reagent location on exon
          if (($st >= $rs && $st < $re) || ($et <= $re && $et > $rs) )   {
              # non-scaled absolute REAGENT's coordinates 
              if ($strandT == 1) {
                $stn = $s + ($st - $rs);
                $etn = $s + ($et - $rs);
              }  else {
                my $l = $e - $s; # EXON's length
                $stn = $s + ($re - $st);
                $etn = $s + ($re - $et);
              }
              $st1 = sprintf("%.0f",($scale*($stn - $kstart)) );
              $et1 = sprintf("%.0f",($scale*($etn - $kstart)) ); 
              # $st1 = $scale*($kend - $st);
              # $et1 = $scale*($kend - $et);
              $et1 = (($et1-$st1) <= 0) ? $st1+1 : $et1;
              $img->filledRectangle(($is+$st1),($y+1),($is+$et1),($y+9),$darkblue) if ( ($stn >= $s  && $stn <= $e ) || ($etn <=$e && $etn >=$s) );             
              # tag
              my $arrow = new GD::Polygon;
              $arrow->addPt(($is+$st1-3),($y+1)-9);
              $arrow->addPt(($is+$st1+3),($y+1)-9);
              $arrow->addPt(($is+$st1),($y+1)-2);      
              $img->filledPolygon($arrow,$red) if ( ($stn >= $s  && $stn <= $e ) || ($etn <=$e && $etn >=$s) );
              # reagent strand : 
              if ($st1>0) {
                  $img->line($is+$st1+4,($y-8), $is+$st1+10,($y-8),$darkblue) if ( ($stn >= $s  && $stn <= $e ) || ($etn <=$e && $etn >=$s) );
                  my $tarrow = new GD::Polygon;
                  if ($dt eq "+") {  
                    $tarrow->addPt($is+$st1+8,$y-10);
                    $tarrow->addPt($is+$st1+12,$y-8);
                    $tarrow->addPt($is+$st1+8,$y-6);
                  } else {
                    $tarrow->addPt($is+$st1+7,$y-10);
                    $tarrow->addPt($is+$st1+3,$y-8);
                    $tarrow->addPt($is+$st1+7,$y-6);
                  }   
                  $img->filledPolygon($tarrow,$darkblue) if ( ($stn >= $s  && $stn <= $e ) || ($etn <=$e && $etn >=$s) );        
              }
          }
        }  
      }
      # transcript strand : 
      $img->line($is,($y-3),($is+15),($y-3),$darkgrey);
      my $tarrow = new GD::Polygon;
      if ($strand > 0) {  
        $tarrow->addPt($is+10,$y-5);
        $tarrow->addPt($is+14,$y-3);
        $tarrow->addPt($is+10,$y-1);
      } else {
        $tarrow->addPt($is+4,$y-5);
        $tarrow->addPt($is-1,$y-3);
        $tarrow->addPt($is+4,$y-1);
      }   
      $img->filledPolygon($tarrow,$darkgrey);      
      $img->filledRectangle(1,($y-1),180,($y+11),$lightgrey);
      my $translation = $translations{$tr} ? "→" : "";
      $img->stringFT($black, $font, 9, 0, 5, ($y+10), $tr);
      unless ($translations{$tr}) {
              $img->stringFT($darkblue, $font, 14, 0, 131, ($y+17), "°");
      } else {
              $img->stringFT($darkblue, $font, 15, 0, 130, ($y+13), "•");
      }
      $t++;
  }
  $img->stringFT($red, $font, 10, 0, $is, 9, "Sequence is not public!") unless $exseq;
  $self->res->headers->content_type('image/png');
  $self->res->headers->header('Cache-Control' => 'max-age=300, must-revalidate, private');
  $self->render(data => $img->png, format => 'png');
}
# call from    : $self->transcripts
# collections	: HMSPNSgenes
sub exons_by_gene {
    my ($self,$obj) = @_;
    my %exons;
    foreach my $tr (@{ $obj->{transcripts} }) {
      my @exs;
      my ($st,$end) = (0,0);
      foreach my $exon (@{ $tr->{exons} }) {
        push (@exs, $exon->{startE}."|".$exon->{endE}."|".$exon->{strandE}."|".$exon->{startRE}."|".$exon->{endRE});
      }
      @exs = sort @exs;
      $exons{$tr->{ensTID}} = \@exs;
    }
    return \%exons;
}
# call from    : $self->transcripts
# methods 	: Sym::Model::MongoQ->get_reagent_by_rgID
# collections	: HMSPNSgenes
sub tags_by_transcript {
    my ($self,$rgID) = @_;
    my $rcrs = Sym::Model::MongoQ->get_reagent_by_rgID($rgID);
    my %tags;
    while (my $obj = $rcrs->next) {
        foreach my $t (@{$obj->{tagin}}) {
            $tags{ $t->{ensTID} } = $t->{s_begin}."|".$t->{s_end}."|".$t->{strand};
        }
    }
    return \%tags;
}
# just for fun
# url from     : /ontostats/
# methods      : Sym::Model::MongoQ->get_ontologies_by_genes
#                Sym::Model::MongoQ->get_ontologies_by_genes_and_namespace
#                $self->data_points
# collections  : HMSPNSgenes
sub ontology_stats {
  my $self = shift;
  open (LOG, ">>log/ips.log") or warn "$!";
  print LOG scalar localtime()." - GO stats :: \t".$self->tx->remote_address."\n";
  close LOG;
  my $ocrs = Sym::Model::MongoQ->get_ontologies_by_genes;
  my $ocrs_bp = Sym::Model::MongoQ->get_ontologies_by_genes_and_namespace("biological_process");
  my $ocrs_mf = Sym::Model::MongoQ->get_ontologies_by_genes_and_namespace("molecular_function");
  my $ocrs_cc = Sym::Model::MongoQ->get_ontologies_by_genes_and_namespace("cellular_component");
  use GD::Graph::Data;
    my ($data_x,$data_y) = $self->data_points($ocrs);
    my ($data_x_bp,$data_y_bp) = $self->data_points($ocrs_bp);
    my ($data_x_mf,$data_y_mf) = $self->data_points($ocrs_mf);
    my ($data_x_cc,$data_y_cc) = $self->data_points($ocrs_cc);
    my @data = ([@{$data_x}],[@{$data_y}],[@{$data_y_bp}],[@{$data_y_mf}],[@{$data_y_cc}]);
    # push (@data,@data_x);
    # push (@data,@data_y);
    # push (@data,@{$data_y_bp});    
    my $graph = GD::Graph::linespoints->new(1500, 1000);	
    $graph->set_values_font($GLV{CONFIG}->{font},8);	
    $graph->set_x_axis_font($GLV{CONFIG}->{font},9);
    $graph->set_y_axis_font($GLV{CONFIG}->{font},9);
    $graph->set_x_label_font($GLV{CONFIG}->{font},10);
    $graph->set_y_label_font($GLV{CONFIG}->{font},10);
    $graph->set_title_font($GLV{CONFIG}->{font}, 10); 
    $graph->set_legend_font($GLV{CONFIG}->{font}, 10);
    my $skip = int ((@{$data_x}* 8)/(1500-50) + 1); # a function of # of data points, each label 5px.
	my $url = ($self->param('by') eq "n") ? "http://wwwdev.ebi.ac.uk/fg/sym/ontostats" : "http://wwwdev.ebi.ac.uk/fg/sym/ontostats?by=n";
	my @legend = ("All genes with ontologies term: 18211 (of 52449), all ontology terms: 12259. See also ".$url,
                    "biological_process","molecular_function","cellular_component");
    $graph->set_legend(@legend);
    $graph-> set (
    		legend_placement=>'TL',b_margin=>5, t_margin=>10, l_margin=>5, r_margin=>5,
          shadowclr	=> 'gray',
          labelclr => 'dgray',
          fgclr => '#AAAAAA',
          dclrs => ['#FFFFFF','#7676FF','#B5CC50','#AC4EAA'],
          textclr=> 'dgray',
		tick_length =>6, long_ticks=>1,
		x_label => "N — number of genes with a given ontology term",
		y_label => ($self->param('by') eq "n") ? "Ontology terms amount, corresponding to a given number of genes" : "Ontology terms ID, ordered by the number of corresponding genes",
		x_label_skip => 10,
		y_tick_number => 20,
          text_space=>20,
          marker_size=>3,
          markers=>[5],
          legend_spacing=>15,
          correct_width=>1, skip_undef=>0,
          y_max_value => ($self->param('by') eq "n") ? 3700 : 12800,
          # y_min_value => ($self->param('by') eq "n") ? 0 : 3600,
          x_tick_offset     => @{$data_x} % $skip,
		box_axis=>0,
		transparent => 0,
          interlaced => 1,
	    );
    my $img = $graph->plot(\@data);
  $self->res->headers->content_type('image/png');
  $self->res->headers->header('Cache-Control' => 'max-age=300, must-revalidate, private');
  $self->render(data => $img->png, format => 'png');
}
# call from    : ontology_stats
sub data_points {
  my ($self,$ocrs) = @_;
  my %points = ();
  my $n=0; 
    while (my $obj = $ocrs->next) {
        unless ($self->param('by') eq "n") {
		$points{ $obj->{countgenes} } = $n++;
	} else {
		$points{ $obj->{countgenes} }++;
	}			
    }
    my @data_x=(); my @data_y=();
    foreach (sort {$a <=> $b} keys %points) { 
      # if ($_ < 10) {
          push(@data_x,$_);
          push(@data_y,$points{$_});
      # }
    }  
    return (\@data_x,\@data_y);
}
# url from     : /statmapping/
# methods      : Sym::Model::MongoQ->get_reagent_mapping
# collections  : Reagents
sub mapping_statistics {
    my $self = shift; 
    my $scale = $self->param("scale");
    my $rcrs = Sym::Model::MongoQ->get_reagent_mapping;
    my %points;
    while (my $obj = $rcrs->next) {
      $points{ $obj->{g_mapfreq} }++; 
    }
    my @data_x; my @data_y;
    foreach (sort {$a <=> $b} keys %points) { 
       if ($points{$_}>=10 && $_ !=0 && !$scale) {
          push(@data_x,$_);
          push(@data_y,$points{$_});
       } 
       if ($points{$_}<10 && $_ !=0 && $scale eq "1") {
          push(@data_x,$_);
          push(@data_y,$points{$_});
       } 
       if ($_ !=0 && $scale eq "2") {
          push(@data_x,$_);
          push(@data_y,$points{$_});
       } 
    } 
    # @data_x = splice (@data_x,0,-1) if $scale;
    my @data=([@data_x], [@data_y]);
    # warn join(",",@data_x);
    # warn join(",",@data_y);
    my $graph = GD::Graph::linespoints->new(650, 460);	
    $graph->set_values_font($GLV{CONFIG}->{font},8);	
    $graph->set_x_axis_font($GLV{CONFIG}->{font},9);
    $graph->set_y_axis_font($GLV{CONFIG}->{font},9);
    $graph->set_x_label_font($GLV{CONFIG}->{font},10);
    $graph->set_y_label_font($GLV{CONFIG}->{font},10);
    $graph->set_title_font($GLV{CONFIG}->{font}, 12);
    my $x_label_skip = $scale ? int(($#data_x)/10) : 1;
    my $show_values = $scale ? 0 : 1;
    $graph-> set (
    		legend_placement=>'TL',b_margin=>5, t_margin=>20, l_margin=>5, r_margin=>5,
          shadowclr	=> 'gray',
          labelclr => 'dgray',
          fgclr => '#AAAAAA',
          dclrs => ['#6e9bd7'],
          textclr=> 'dgray',
		tick_length =>6,
		x_label => "Number of genes mapped by a single reagent",
		y_label => "Reagent's count",
		show_values => $show_values,
		x_label_skip => $x_label_skip,
    text_space=>5,
    marker_size=>3,
    markers=>[5],
    legend_spacing=>10,
    correct_width=>1, 
#    skip_undef=>0,
    y_max_value       => ($scale eq "1") ? 10 : 85000,
    x_max_value       => 1700,  
    x_tick_offset     => @data_x % $x_label_skip,
		box_axis=>0
	    );
    my $img = $graph->plot(\@data);
  $self->res->headers->content_type('image/png');
  $self->res->headers->header('Cache-Control' => 'max-age=300, must-revalidate, private');
  $self->render(data => $img->png, format => 'png');
}
sub show {
    my $self = shift;
    return;
}
1;

