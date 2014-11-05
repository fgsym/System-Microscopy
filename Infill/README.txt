step BY steps — loading 3 data sets in sym collection.

Scripts working directory:
  /home/jes/Git/Infill/

Important note:
  rgID (internal sym reagent ID) are linked to experiment ID (different experiments may occasionaly have same rgIDs)
  Unique rgID is stored only as ObjectId() in Reagents collection

  These steps should be repeated after each Enseml update.
  Current Ensembl v. GRCh37.68 (get it from ftp://ftp.ensembl.org/pub/release-68/fasta/homo_sapiens/cdna/)

1.
  a) ~/BINs/NextRNAi/NEXT-RNAi_v1.4_LINUX/HomoSapiens$  ./make_Homo_sapiens.GRCh37.68.cdna.all.sh (edit for corresponding version)
  b) perl /home/jes/Git/Infill/New_Reagents_data.pl

2. Prepare reagents data from Mitocheck MySQL DB (oligo_seqT.fa) and Gerlich dataset (oligos-quagenT.fa)
++++++++++++++++++++++++
and new Reagents data see: /home/jes/Git/Infill/New_Reagents_data.pl (/home/jes/SysMicroscopy/DATAfiles/".$date."_oligo_seqT.fa)
result in of mapping: Align-best-2012-8-24_oligos.map

  /home/jes/BINs/bowtie-0.12.7/bowtie -p 4 -f -v 0 -a --chunkmbs 512 --best ~/BINs/NextRNAi/NEXT-RNAi_v1.4_LINUX/HomoSapiens/Homo_sapiens.GRCh37.68.cdna.all -f /home/jes/SysMicroscopy/DATAfiles/2012-8-24_oligo_seqT.fa /home/jes/SysMicroscopy/DATAfiles/Align-best-2012-8-24_oligos.map

# reads processed: 2342 (2533 reagents in library, more  ~/SysMicroscopy/DATAfiles/CGSR_DNA_damage/siRNAlibrary.csv | wc => 2342 new)
# reads with at least one reported alignment: 2342 (100.00%)
# reads that failed to align: 0 (0.00%)

  [[[ After checks:

    /home/jes/BINs/bowtie-0.12.7/bowtie -p 4 -f -v 0 -a --chunkmbs 512 --best ~/BINs/NextRNAi/NEXT-RNAi_v1.4_LINUX/HomoSapiens/Homo_sapiens.GRCh37.68.cdna.all -f /home/jes/SysMicroscopy/DATAfiles/2012-9-17_oligo_seqT.fa /home/jes/SysMicroscopy/DATAfiles/Align-best-2012-9-17_oligos.mapped

  ]]]

# reads processed: 18
# reads with at least one reported alignment: 18 (100.00%)
# reads that failed to align: 0 (0.00%)

Reported 11444 alignments to 1 output stream(s)
++++++++++++++++++++++++
      Mitocheck reagents:

  /home/jes/BINs/bowtie-0.12.7/bowtie -p 4 -f -v 0 -a --chunkmbs 512 --best --fullref ~/BINs/NextRNAi/NEXT-RNAi_v1.4_LINUX/HomoSapiens/Homo_sapiens.GRCh37.68.cdna.all -f /home/jes/SysMicroscopy/DATAfiles/oligo_seqT.fa /home/jes/SysMicroscopy/DATAfiles/Align-best-mitocheck.map
  result :
    # reads processed: 56821
    # reads with at least one reported alignment: 53112 (93.47%)
    # reads that failed to align: 3709 (6.53%)
    Reported 272863 alignments to 1 output stream(s) (65th release)

    # reads processed: 56821
    # reads with at least one reported alignment: 53505 (94.16%)
    # reads that failed to align: 3316 (5.84%)
    Reported 284343 alignments to 1 output stream(s) (66th release)

    # reads processed: 56821
    # reads with at least one reported alignment: 53162 (93.56%)
    # reads that failed to align: 3659 (6.44%)
    Reported 283934 alignments to 1 output stream(s) (68th release)

      Gerlich reagents:
  a) more /home/jes/SysMicroscopy/DATAfiles/Gerlich/oligos-quagen.fa | sed 's/U/T/g' > /home/jes/SysMicroscopy/DATAfiles/Gerlich/oligos-quagenT.fa (the same was done for Mitocheck before)
  b) /home/jes/BINs/bowtie-0.12.7/bowtie -p 4 -f -v 0 -a --chunkmbs 512 --best --fullref ~/BINs/NextRNAi/NEXT-RNAi_v1.4_LINUX/HomoSapiens/Homo_sapiens.GRCh37.64.cdna.all -f /home/jes/SysMicroscopy/DATAfiles/Gerlich/oligos-quagenT.fa /home/jes/SysMicroscopy/DATAfiles/Gerlich/Align-best-quagen.map
    # reads processed: 626
    # reads with at least one reported alignment: 616 (98.40%)
    # reads that failed to align: 10 (1.60%)
    Reported 2985 alignments to 1 output stream(s) (65th release)

    # reads processed: 626
    # reads with at least one reported alignment: 616 (98.40%)
    # reads that failed to align: 10 (1.60%)
    Reported 3041 alignments to 1 output stream(s) (66th release)

    # reads processed: 626
    # reads with at least one reported alignment: 614 (98.08%)
    # reads that failed to align: 12 (1.92%)
    Reported 2993 alignments to 1 output stream(s) (68th release)

  next :
    result is used in p.6 — see below

3. perl LoadGenes_n.pl 	— loading of all non-redundant genes with transcripts sequences from Ensembl through Ensembl API

  collection :
    HMSPNSgenes
    Species
  result :
    51911 genes loaded — 65 release (54304 — with redundant)
    53712 genes loaded — 66 release
    55202 genes loaded — 68 release
      165436 transcripts loaded (162518 transcripts loaded — release 63) (db.HMSPNSgenes.distinct("transcripts.ensTID").length)
      180234 transcripts loaded — 66 release
      182938 transcripts loaded — 68 release
  time :
    ~2h46min ... ~6h15min with InterPro description (?)\
    ~4h17min — 68th release
4. perl ExperimentsLoad.pl 	— loading Experiments metadata

  collection :
    Experiments
  result :
    3 experiments loaded


5. perl Suppliers.pl 	— loading Suppliers data

  collection :
    Suppliers
  result :
    3 suppliers loaded
  time :
    1s


6. perl LoadOligos_n.pl 	— loading Ambion & Qiagen reagents from Mitocheck DB (see p.1)
http://cid:3000/search/pheno/1:1 — 17. — MCO_0042152
  collection :
    Reagents
  datafiles :
    my $log = "/home/jes/Git/Logs/RNAs.log";
    my $mitos = "/home/jes/SysMicroscopy/DATAfiles/oligos_amb_quag.tsv";
    my $fasta = "/home/jes/SysMicroscopy/DATAfiles/oligo_seqT.fa"; (U -> T)
    my $bowtie = "/home/jes/SysMicroscopy/DATAfiles/Align-best-mitocheck.map";
  result :
    56821 oligos (+ 3734 not targeting) loaded to RNAs — 65th release
    56821 oligos (+ 3342 not targeting) loaded to RNAs — 66th release
    56820 oligos (+ 3725 not targeting) loaded to RNAs — 68th release

    56821 oligos loaded from Mitochek loaded, mapped to genes Ambion & Qiagen reagents
    + 3734 with t_mapfreq=0
    db.Reagents.find({"supID":2}).count()
    2736
    db.Reagents.find({"supID":1}).count()
    54084
	db.Reagents.find({"supID":1,"libID":1}).count()
	51809
	db.Reagents.find({"supID":1,"libID":2}).count()
	2275
    db.Reagents.find({"supID":0}).count() (see db.Reagents.findOne({"supID":0}) and remove it)
    1
    } = 56821 = db.Reagents.find({}).count() — Actualy
    55511 - 2264 (FIRST ID=2265 : see line 63 in script) = 53247
  time :
    ~35s

++++++++++++++++++

  perl /home/jes/Git/Infill/LoadNewReagents.pl (!!!! see line 9,10 !!!! — and p 2. here)

7. perl LoadDharmacon.pl	— loading annotated with ensIDs Dharmacon siGENOME reagents
(mapping is provided by Ester — we should ask her to remap them for each new Ensembl release!!)

  collection :
    Reagents
  fields by default :
    libID = "siGENOME",
    supID = 3
  datafiles :
    /home/jes/SysMicroscopy/DATAfiles/CellMorph/dharmacon_w_ensembl_ids.txt
  result :
    19067 reagents loaded with Dharmacon ids and libID=siGENOME
    19069 reagents loaded with Dharmacon ids and libID=siGENOME (66 release)
    19067 reagents loaded :
    sort /home/jes/SysMicroscopy/DATAfiles/CellMorph/dharmacon_w_ensembl_ids.txt | grep "ENSG00" | grep "M-" | uniq | wc
    19952   79808  807556
    > db.Reagents.find({"libID":"siGENOME"}).count()   25 genes without synonims
    19069
  time:
    ~3min16sec


8. perl LoadMitocheckTSV.pl	— loading Mitocheck DATA

  collection ;
    Datasets
  fields by default :
    expID = 1
  datafiles :
    /home/jes/SysMicroscopy/DATAfiles/Mitocheck/mitocheck_siRNAs_phenotypes.txt (number of reagent here doesn't equal to that one from mysql DB!)
  result :
    20081 oligos->phenotypes must have been loaded from Mitochek TSV file
    db.Datasets.find({"phenocount":0}).count()
    33809
    db.Datasets.find({"expID":1}).count();
    53890
  time :
    ~5s


9. perl LoadCellMorphTSV.pl	— loading CellMorph DATA // Loading not mapped Dharmacon reagents

  collection :
    Reagents
  fields by default :
    expID = 2
  datafiles :
    /home/jes/SysMicroscopy/DATAfiles/Boutros/Dharmacon_Annotation_RefSeq27+HGNC.tab
    /home/jes/SysMicroscopy/DATAfiles/Boutros/phenoprints.tab
  files:
    /home/jes/SysMicroscopy/DATAfiles/nonredundant_mart_export_ccds_entrez.txt
    — check for nonredumdant files and print inconcistencies in ../Logs
  log :
    /home/jes/Git/Logs/LoadCellMorphTSV.log
  result :
    1820 Dharmacon's reagents loaded to Datasets (without mapping to Genome)
    256 not found genes — see $more /home/jes/Git/Logs/LoadCellMorphTSV.log | grep notfound
    > db.Datasets.find({"expID":2}).count()
    1820
  notes:
    16M05 at LoadCellMorphTSV.pl line 71.
    23D23 at LoadCellMorphTSV.pl line 71.
    20O20 at LoadCellMorphTSV.pl line 71.
    21G05 at LoadCellMorphTSV.pl line 71.
    15C22 at LoadCellMorphTSV.pl line 71
    — i.e.  "NA" for D-* IDs :
    more /home/jes/SysMicroscopy/DATAfiles/CellMorph/Dharmacon_Annotation_RefSeq27+HGNC.tab | grep D23 | grep ^23
  time :
    ~6min

	=> no 2 libraries there:
	> db.Reagents.find({"libID":"siGENOME"}).count()
	19069
	> db.Reagents.find({"libID":"siRNA"}).count()
	338
	> db.Reagents.find({"prefix":"DHARM"}).count()
	19407
	> 19069+338
	19407

10. perl LoadGerlichTSV.pl
  collection :
    Datasets
    Reagents
  fields by default :
    expID = 4
  datafiles:
    /home/jes/SysMicroscopy/DATAfiles/Gerlich/PPase_screen_with_phenotypes.tab (DATA)
    /home/jes/SysMicroscopy/DATAfiles/Gerlich/Align-best-quagen.map (BOWTIE)
  log:
    /home/jes/SysMicroscopy/DATAfiles/Gerlich/IDs_LOG.tab
  result :
    602 reagents inserted: more /home/jes/SysMicroscopy/DATAfiles/Gerlich/IDs_LOG.tab | grep missed | wc
    24 existed (from Mitocheck data): more /home/jes/SysMicroscopy/DATAfiles/Gerlich/IDs_LOG.tab | grep ^found | wc
    total : 626
  time : 1min19sec

<!--	      10. perl LoadWinogradTSV.pl	— loading Winograd DATA

		collection :
		  Datasets
		  Reagents
		fields by default :
		  expID = 3
		datafiles :
		  /home/jes/SysMicroscopy/DATAfiles/Winograd/JCB_200901105_TableS2.csv
		  /home/jes/SysMicroscopy/DATAfiles/Winograd/Simpson_etal_NCB_2008-2.csv
		  /home/jes/SysMicroscopy/DATAfiles/nonredundant_mart_export_ccds_entrez.txt
		  — check for nonredumdant files and print inconcistencies in ../Logs
		log :
		  /home/jes/Git/Logs/LoadWinograd.log
		result :
		  467 Dharmacon's reagent added (57799-57332 : db.Reagents.find({"rgID": {"$lt" : 58000}},{"rgID":1}).limit(2).sort({rgID:-1}))
		  483 Datasets loaded
		  > db.Datasets.find({"expID":3}).count()
		  483
		time :
		  ~1min 10sec
-->

11. perl LoadNewReagents.pl
  input files:
    my $reags = "/home/jes/SysMicroscopy/DATAfiles/CGSR_DNA_damage/siRNAlibrary.csv";
    my $bowtie = "/home/jes/SysMicroscopy/DATAfiles/Align-best-2012-8-24_oligos_full.map";
  collection:
    Reagents
  result:
    2342 oligos (+ 0 not targeting) loaded to RNAs
  time:

---------------------------> db.Reagents.find({}).count() = 79171
perl Load_BZH.pl
start: 2012-9-7 12:8:56
2012-9-7 12:9:1: 56426 reagents read from Reagents
Total number of valid datarows in this assay: 109765
Replicas counted, total number of reagents in this assay: 51402
end: 2012-9-7 12:23:10





------------------------------

12. perl Analysis_Mitocheck.pl (Analysis_AllMitocheck.pl, $db->AllPhenoAnalysis for ALL data with low reproducibility too!)
  collection :
    PhenoAnalysis
  result :
    294 (PhenoAnalysis) + 621 (AllPhenoAnalysis) phenotypes profile loaded
  time :
    ~12min 35sec (~48min24sec for Analysis_AllMitocheck.pl, $db->AllPhenoAnalysis)


13. perl Analysis_CellMorph.pl
  collection :
    PhenoAnalysis, AllPhenoAnalysis — both in cicle
  result :
    23 Phenotype Profiles loaded
  time :
    ~9min 3sec

<!-- 13. perl Analysis_Winograd.pl
      collection :
	PhenoAnalysis, AllPhenoAnalysis — both in cicle
      result :
	138 Phenotype Profiles loaded
      time :
	~1min 20sec (BTW: 30sec no inserts)
-->

14. perl Analysis_PP2A.pl
  collection :
    PhenoAnalysis
  result :
    2 Phenotype Profiles loaded
  time :
    ~1min 55sec (BTW: 30sec no inserts)


15. perl Genes_by_Phenotypes.pl
  collection :
    HMSPNSgenes
  result :
    phenotypes assigned to 10013 genes (all genes are 52449)
      ( > db.HMSPNSgenes.find({"phenolist.phenoprint":/\S/}).count() )
  time:
    ~1h 33min

16. perl GO_Analysis.pl