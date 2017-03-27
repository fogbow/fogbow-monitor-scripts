#!/usr/bin/python
import sys, json
# TODO describe

jsonStr=str(sys.argv[1])
nameToFound=sys.argv[2]

groupComponentId=-1
jsonObject=json.loads(jsonStr)
groupComponentData=jsonObject['data']
for groupComponent in groupComponentData:
    name=groupComponent['name']
    if name == nameToFound:
    	groupComponentId=groupComponent['id']
print groupComponentId