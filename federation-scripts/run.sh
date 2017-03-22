#!/bin/bash
echo "....................................."
echo "Starting script. "
echo "....................................."

# Importing scripts
DIRNAME=`dirname $0`
source "$DIRNAME/settings.sh"
source "$DIRNAME/database.sh"
source "$DIRNAME/token-plugins/token-util.sh"
source "$DIRNAME/test-compute.sh"
# source "$DIRNAME/test-storage.sh"
# source "$DIRNAME/test-network.sh"

EXECUTION_UUID=`uuidgen`
echo "** Properties **"
echo "- Execution id: "$EXECUTION_UUID
echo "- Token plugin: "$TOKEN_PLUGIN
echo "** End Properties ** "

# From token-util.sh
MANAGER_TOKEN=$(getToken)
echo "Manager token: "$MANAGER_TOKEN

echo "** Starting monitoring. **"
CURRENT_MANAGER=""
for i in `cat $MANAGERS_TO_MONITOR`; do
	if [[ "$i" == *"manager"* ]]; then
		eval `echo $i`;
		echo "Running tests on manager $manager"
	else
		if [[ "$i" == "compute" ]]; then
			echo "COMPUTE: Running tests for $i on $manager"
			monitoringCompute $manager
		elif [[ "$i" == "storage" ]]; then
			echo "STORAGE: Running tests for $i on $manager"
		elif [[ "$i" == "network" ]]; then
			echo "NETWORK: Running tests for $i on $manager"
		fi
	fi
done

echo "....................................."
echo "End script. "
echo "....................................."