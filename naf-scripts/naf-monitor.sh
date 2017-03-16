#!/bin/bash
DIRNAME=`dirname $0`
. "$DIRNAME/naf-settings.sh"

CURRENT_MANAGER=""
for i in `cat $MANAGERS_TO_MONITOR`; do
	if [[ "$i" == *"manager"* ]]; then
		eval `echo $i`;
		echo "Running tests on manager $manager"
	else
		if [[ "$i" == "compute" ]]; then
			echo "COMPUTE: Running tests for $i on $manager"
		elif [[ "$i" == "storage" ]]; then
			echo "STORAGE: Running tests for $i on $manager"
		elif [[ "$i" == "network" ]]; then
			echo "NETWORK: Running tests for $i on $manager"
		fi
	fi
done