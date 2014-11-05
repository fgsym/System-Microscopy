=====================
REFORMAT the NEW Reagents
=====================
perl reformats/NewDharmReformats.pl (for JCB-metazoan-actinome)
perl LibraryFiles_processing.pl (for Phagokinetic)

=====================
DOWNLOAD the Reagents from DB:
=====================
perl Reagents_2_FASTA.pl
(see options!)

U—>T:
		more Reagents.fa | sed 's/U/T/g' > /home/jes/Git/infill-load-data/Reagents_T.fa
=====================
MAP the Reagents:
=====================
= BOWTIE
=========
=== BUILD INDEX: see and correct ~/BINs/GENOMES/HomoSapiens/make_Homo_sapiens.GRCh37.75.cdna.all.sh

=== ALIGH:
== RELEASE:
bowtie -p 4 -f -v 0 -a --chunkmbs 512 --best ~/BINs/GENOMES/HomoSapiens/Homo_sapiens.GRCh37.75.cdna.all -f /home/jes/Git/infill-load-data/CompoundReagents_2013-6-10.fa /home/jes/Git/infill-load-data/Dharmacon_remap_to_release_73.map

bowtie -p 4 -f -v 0 -a --chunkmbs 512 --best ~/BINs/GENOMES/HomoSapiens/Homo_sapiens.GRCh37.75.cdna.all -f /home/jes/Git/infill-load-data/Reagents_2013-6-3_T.fa /home/jes/Git/infill-load-data/Align-best-existing-reagents-73.map

== NEW:
~/Git/infill-load-data/JCB-metazoan-actinome$ /home/jes/BINs/bowtie-0.12.7/bowtie -p 4 -f -v 0 -a --chunkmbs 512 --best ~/BINs/GENOMES/HomoSapiens/Homo_sapiens.GRCh37.73.cdna.all -f /home/jes/Git/infill-load-data/JCB-metazoan-actinome/libraries/DHARM_T.fa /home/jes/Git/infill-load-data/JCB-metazoan-actinome/Align-new-dharmacon.map


~/Git/infill-load-data/JCB-metazoan-actinome$ /home/jes/BINs/bowtie-0.12.7/bowtie -p 4 -f -v 0 -a --chunkmbs 512 --best ~/BINs/GENOMES/HomoSapiens/Homo_sapiens.GRCh37.73.cdna.all -f /home/jes/Git/infill-load-data/JCB-metazoan-actinome/libraries/Dharmacon_T.fa /home/jes/Git/infill-load-data/JCB-metazoan-actinome/Align-new-dharmacon_additional2check.map
# reads that failed to align: 33 (1.45%)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ NB: we have NO probeIDs here

/home/jes/BINs/bowtie-0.12.7/bowtie -p 4 -f -v 0 -a --chunkmbs 512 --best ~/BINs/GENOMES/HomoSapiens/Homo_sapiens.GRCh37.73.cdna.all -f /home/jes/Git/infill-load-data/Phagokinetic/libraries/Dharmacon.fa /home/jes/Git/infill-load-data/Phagokinetic/libraries/Dharmacon-map_without_kinase.map

= BOWTIE2
=========
http://bowtie-bio.sourceforge.net/bowtie2/manual.shtml#getting-started-with-bowtie-2-lambda-phage-example
http://www.flyrnai.org/
=== BUILD INDEX:
in ~/BINs/GENOMES/DrosophilaMelanogaster/
/home/jes/BINs/bowtie2-2.1.0/bowtie2-build -f /opt/FASTA/Drosophila_melanogaster.BDGP5.71.cdna.all.fa Drosophila_melanogaster-71

=== ALIGH:
73:
/home/jes/BINs/bowtie2-2.1.0/bowtie2 -x Drosophila_melanogaster-71 -f /home/jes/Git/infill-load-data/JCB-metazoan-actinome/Drosophila_library.fa -S Drosophila-bowtie2-10-6-2013.map
75:
$ bowtie2 -x Drosophila_melanogaster-75 -f /home/jes/Git/infill-load-data/Droso_2014-5-20.fa -S Drosophila-bowtie2-75.map

=====================
LOAD the Reagents:
=====================
NEW DHARMACON:
/home/jes/Git/infill-load-data/JCB-metazoan-actinome/Align-new-dharmacon.map

OLD from DB:
/home/jes/Git/infill-load-data/Align-best-existing-reagents-73.map
~/Git/Infill$ perl ProbesLoad-to-release.pl
2013-6-11 17:35:50: 60259 reagents read from Reagents
2013-6-12 9:28:8: 57066 reagents (with 3193 not targeting) updated to Reagents collection

OLD DHARMACON from DB
~/Git/Infill$ 
DharmaconIDs_from_release.pl
perl DharmProbesLoad-to-release.pl

NEW DROSOPHILA:
/home/jes/Git/infill-load-data/Align-best-drosophila-71.map
~/Git/Infill$ perl ReagentsLoad-bowtie2.pl
TODO: write update Reagents collection here for bowtie2 (but can be deleted/created because this is only the one library so far for Drosophila)

========
DATASETS
========
iconv -f UTF-16 -t UTF-8 /home/jes/FG/SysMicroscopy/DATAfiles/Wies_screen/Wies_IDF_UTF16.csv > /home/jes/FG/SysMicroscopy/DATAfiles/Wies_screen/Wies_IDF_UTF.csv


========
EXPORTS
========
../mongodb-2.4.8/bin/mongoexport  -d sym -c Reagents -f probeID,rgID,seq1,seq2,prefix --csv -o export-Reagents.csv
../mongodb-2.4.8/bin/mongoexport  -d sym -c HMSPNSgenes -f phenolist,ensGID --csv -o export-HMSPNSgenes.csv
../mongodb-2.4.8/bin/mongoexport  -d sym -c FruitFLYgenes -f phenolist,ensGID --csv -o export-FruitFLYgenes.csv
../mongodb-2.4.8/bin/mongoexport  -d sym -c HMSPNSgenes -q "{'phenolist.phenodata.ScrID':/\S/},{ensGID:1,phenolist:1}" -f ensGID,phenolist -o export-HMSPNSgenes.json
../mongodb-2.4.8/bin/mongoexport  -d sym -c FruitFLYgenes -q "{'phenolist.phenodata.ScrID':/\S/},{ensGID:1,phenolist:1}" -f ensGID,phenolist -o export-FruitFLYgenes.json
../mongodb-2.4.8/bin/mongoexport  -d sym -c Ontology -o export-CMPO_2_Phenotype-terms.json

to connect:
./live/mongodb-2.4.8/bin/mongo -u usym -p i5b4SvmN --host mongodb-pgvm-sym-001.ebi.ac.uk --port 27017 sym

===
FTP
===
/nfs/ftp/pub/databases/microarray/data/cellph/
url:
ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/cellph/



