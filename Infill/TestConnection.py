from pymongo import MongoReplicaSetClient, ReadPreference
site='OY'
client = MongoReplicaSetClient("mongodb-oyvm-sym-001.ebi.ac.uk:27017",replicaSet='symrs01'),
client.sym.authenticate('usym','i5b4SvmN')
db=client.sym
print db.system.indexes.find().explain()['server']

#replicaSet='symrs01', tag_sets=[{ "dc" : site }],
#read_preference=ReadPreference.SECONDARY)
