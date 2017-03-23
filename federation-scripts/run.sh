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

# constants
LOG_MONITORING_COMPUTE_PATH="/tmp/monitoringCompute.log"
LOG_MONITORING_NETWORK_PATH="/tmp/monitoringNetwork.log"
LOG_MONITORING_STORAGE_PATH="/tmp/monitoringStorage.log"

EXECUTION_UUID=`uuidgen`
echo "** Properties **"
echo "- Execution id: "$EXECUTION_UUID
echo "- Token plugin: "$TOKEN_PLUGIN
echo "** End Properties ** "

# From token-util.sh
MANAGER_TOKEN=$(getToken)
echo "Manager token: "$MANAGER_TOKEN

#### BD add monitoring $EXECUTION_UUID

echo "** Starting monitoring. **"
for i in `cat $MANAGERS_TO_MONITOR`; do
	if [[ "$i" == *"manager"* ]]; then
		eval `echo $i`;
		echo "Running tests on manager $manager"
	else
		if [[ "$i" == "compute" ]]; then
			echo "COMPUTE: Running tests for $i on $manager"
			monitoringCompute $manager >> $LOG_MONITORING_COMPUTE_PATH
		elif [[ "$i" == "storage" ]]; then
			# monitoringStorage $manager >>
			echo "STORAGE: Running tests for $i on $manager"
		elif [[ "$i" == "network" ]]; then
			# monitoringNetwork $manager >>
			echo "NETWORK: Running tests for $i on $manager"
		fi
	fi
done

echo "Log monitoring compute: "$LOG_MONITORING_COMPUTE_PATH
echo "Log monitoring network: "$LOG_MONITORING_NETWORK_PATH
echo "Log monitoring storage: "$LOG_MONITORING_STORAGE_PATH

echo "....................................."
echo "End script. "
echo "....................................."