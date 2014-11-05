1. Download and unpack a new reference genome from ftp://ftp.ensembl.org/pub/
=============================================================================
  I.e. get it from ftp://ftp.ensembl.org/pub/release-[release numder]/fasta/[species]/cdna/)

2. Prepare genome sequences index
=================================
  you should have NEXT-RNAi_v1.4_LINUX.zip from http://rnai-screening-wiki.dkfz.de/confluence/display/nextrnai/Installing+NEXT-RNAi
  mkdir in ~/BINs/NEXT-RNAi_v1.4_LINUX/ for Homosapiens
  edit make_Homo_sapiens.[release numder].cdna.all.sh
  or:
    sudo apt-get install bowtie 
    bowtie-build file.fa index_name  # index_name = Homo_sapiens.[release numder].cdna.all
  build index with it
  put all *.ebwt files in [release number] dir
  
  the same for Drosophila (in /opt/FASTA/Drosophila):
  bowtie2-build -f ../Drosophila_melanogaster.BDGP5.cdna.all.fa Drosophila_melanogaster-77
  
3. Take reagent sequences from DB to remap them
===============================================
  perl Reagents_2_FASTA.pl 
  27/10/2014:
  13997 non-compound reagents are in DB (for FruitFLY) at Reagents_2_FASTA.pl line 48.
  60260 non-compound reagents are in DB (for Human Genome) at Reagents_2_FASTA.pl line 34.
  19040 compound reagents are in DB at Reagents_2_FASTA.pl line 62.
  
  U—>T:
  more Reagents.fa | sed 's/U/T/g' > /home/jes/Git/infill-load-data/Reagents_T.fa

4. Map with bowtie
==================
  bowtie -p 4 -f -v 0 -a --chunkmbs 512 --best ~/BINs/NEXT-RNAi_v1.4_LINUX/Homosapiens/77/Homo_sapiens.77.cdna.all -f /home/jes/Git/infill-load-data/CompoundReagents_2014-10-27_T.fa /home/jes/Git/infill-load-data/Dharmacon_remap_to_release_77.map
  # reads processed: 5194                                                                                                                                                                                                                                                        
  # reads with at least one reported alignment: 5193 (99.98%)
  # reads that failed to align: 1 (0.02%)
  Reported 28180 alignments to 1 output stream(s)
  
  bowtie -p 4 -f -v 0 -a --chunkmbs 512 --best ~/BINs/NEXT-RNAi_v1.4_LINUX/Homosapiens/77/Homo_sapiens.77.cdna.all -f /home/jes/Git/infill-load-data/Reagents_2014-10-27_T.fa /home/jes/Git/infill-load-data/Align-best-existing-reagents-77.map
  # reads processed: 60260
  # reads with at least one reported alignment: 56200 (93.26%)
  # reads that failed to align: 4060 (6.74%)
  Reported 300658 alignments to 1 output stream(s)
  
5. Map with bowtie2
===================
  (in /opt/FASTA/Drosophila)
  bowtie2 -x Drosophila_melanogaster-77 -f /home/jes/Git/infill-load-data/Droso_2014-10-27.fa -S Drosophila-bowtie2-77.map
  13997 reads; of these:
  13997 (100.00%) were unpaired; of these:
    0 (0.00%) aligned 0 times
    7824 (55.90%) aligned exactly 1 time
    6173 (44.10%) aligned >1 times
  100.00% overall alignment rate
  
3. Reagents update and load into DB
===================================
PREPARE:
	1) before loading Reagents aligned with bowtie2 check that db.Reagents.find({aligner:"bowtie"}).count() = current number of Reagents
	2) Infill/DharmProbesLoad-to-release.pl — edit $bowtie_dh filename to load the mapping of the current release
	3) the same for Infill/ProbesLoad-to-release.pl ($bowtie)

= NON-COMPOUND REAGENTS:
  PREPARE:
      don't forget to edit $bowtie in ProbesLoad-to-release.pl
  CLEANING:	
	> db.Reagents.update({aligner:"bowtie","prefix":{$ne : "DHARM"}},{$unset:{tagin:1,genes:1,t_mapfreq:1,g_mapfreq:1}},false,true);
	WriteResult({ "nMatched" : 60260, "nUpserted" : 0, "nModified" : 60260 })
  LOAD:	
	$ perl ~/Git/Infill/ProbesLoad-to-release.pl
		2013-10-9 14:9:48: 57528 genes read from HMSPNSgenes (75)
		2014-11-3 15:48:22 56200 : reagents mapped in /home/jes/Git/infill-load-data/Align-best-existing-reagents-77.map
		2014-11-3 15:48:43: 57905 genes read from HMSPNSgenes (77)
		57002 reagents (with 3259 not targeting) updated to Reagents collection (75)
		56200 reagents (with 4060 not targeting) updated to Reagents collection (77)
		9514 reagents turned out to map kind of haplogenes too
  CHECKS:
	> db.Reagents.find({aligner:"bowtie",g_mapfreq:{$gt:0},"prefix":{$ne : "DHARM"}}).count()
		56954
	> db.Reagents.find({aligner:"bowtie",g_mapfreq:0,"prefix":{$ne : "DHARM"}}).count()
		3307
	> db.Reagents.update({aligner:"bowtie","prefix":{$ne : "DHARM"}},{$set:{release:73,remap:new Date("Oct 10, 2013")}},false,true);
			— Remapping update date print into Reagents collection;

= COMPOUND REAGENTS (DHARMACON):
  PREPARE:
		perl DharmaconIDs_from_release.pl
		— backup all pID from seq_array for DharmProbesLoad-to-release.pl 
		don't forget to edit $bowtie_dh in DharmProbesLoad-to-release.pl
  CHECKS:
		> 
		> db.Reagents.find({aligner:"bowtie","seq_array.tagin.sbjct":/\S/,"prefix": "DHARM"}).count();
		1300
		— Reagents with mapping sequences
		> db.Reagents.find({aligner:"bowtie","seq_array.pID":{$not:/D/},"prefix": "DHARM"}).count();
		281
		— Dharmacon reagents without specified probes in compound
  CLEANING (don't change the step sequence here!):
		1.
		> db.Reagents.update({aligner:"bowtie","seq_array.tagin.sbjct":/\w/i,"prefix": "DHARM"},{$unset:{tagin:1}},false,true);
			— remove old mapping data from Dharmacon reagents
			(NB: "tagin" field is still exist in the Dharmacon reagents without sequences!! (without "seq_array.tagin.*" data) )
		2.
		> db.Reagents.update({aligner:"bowtie","prefix": "DHARM"},{$unset:{genes:1}},false,true);
		3.
		> db.Reagents.update({aligner:"bowtie","prefix": "DHARM"},{$unset:{seq_array:1}},false,true);
		  — pIDs in seq_array to be restored from DharmaconIDs_from_release.pl.tab 
  LOAD:
		perl DharmProbesLoad-to-release.pl
		19321 reagents updated, 1311 are targeting, 18010 are not

		
= Drosophila REAGENTS:
  PREPARE:
	    edit $fasta & $bowtie2 files
  CHECKS:
	  > db.Reagents.find({aligner:"bowtie2"}).count()
	  13997
  LOAD:
	  perl ReagentsLoad-bowtie2.pl

CHANGE release value:
db.Reagents.update({aligner:"bowtie"},{$set:{release:77,remap:new Date("Nov 3, 2014")}},false,true);
db.Reagents.update({aligner:"bowtie2"},{$set:{release:77,remap:new Date("Nov 3, 2014")}},false,true);





ISSUES with reagents:

> db.Reagents.find({"tagin.ensGID":"ENSG00000130158",prefix:"DHARM"},{rgID:1,"seq_array.pID":1,probeID:1})
{ "_id" : ObjectId("5136371136cde9332700041b"), "probeID" : "M-031950-00", "rgID" : "DHARM0001051", "seq_array" : [ { "pID" : "D-031950-02" }, { "pID" : "D-031950-01" }, { "pID" : "D-031950-04" }, { "pID" : "D-031950-03" } ] }
{ "_id" : ObjectId("526fe309b5ca94552a0000b1"), "probeID" : "M-031950-01", "rgID" : "DHARM0019132", "seq_array" : [ { "pID" : "D-031950-17" }, { "pID" : "D-031950-03" }, { "pID" : "D-031950-01" }, { "pID" : "D-031950-02" } ] }
— map the same gene, compound Reagent is a bit different, 1st is from libraries, no connection with studies, second didn't reveal a phenotype in Phagokinetic Track
— where did it come from?
