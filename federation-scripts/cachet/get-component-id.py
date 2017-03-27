#!/usr/bin/python
import sys, json
# TODO describe

jsonStr=str(sys.argv[1])
nameToFound=sys.argv[2]

componentId=-1
jsonObject=json.loads(jsonStr)
componentData=jsonObject['data']
for component in componentData:
    name=component['name']
    if name == nameToFound:
    	componentId=component['id']
print componentId