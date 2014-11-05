1. Gene search result: only those reagent, that map a single gene and match parameters $obj->{measuring}->{goodmatch}==1 in PhenoAnalysis collection :
      ../Infill/Analysis_[Screen name].pl :	$goodmatch = (scalar(keys %seen) > 1) ? 0 : 1;
      ./templates/search/resgene.html.ep  :	$mobj->{measuring}->{goodmatch}==1