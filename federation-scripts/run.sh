#!/bin/bash
echo "....................................."
echo "Starting script. "
echo "....................................."

# Importing scripts
DIRNAME=`dirname $0`
source "$DIRNAME/settings.sh"
source "$DIRNAME/database.sh"
source "$DIRNAME/token-plugins/token-util.sh"
source "$DIRNAME/cachet/cachet.sh"
source "$DIRNAME/test-compute.sh"
source "$DIRNAME/test-storage.sh"
source "$DIRNAME/test-network.sh"

EXECUTION_UUID=`uuidgen`
echo "** Properties **"
echo "- Execution id: "$EXECUTION_UUID
echo "- Token plugin: "$TOKEN_PLUGIN
echo "** End Properties ** "

# From token-util.sh
MANAGER_TOKEN=$(getToken)
echo "Manager token: "$MANAGER_TOKEN

## logs
echo "Creating logs folder."
LOGS_PATH="$DIRNAME/logs/$EXECUTION_UUID"
mkdir $LOGS_PATH
LOG_MONITORING_COMPUTE_PATH_PREFIX="$LOGS_PATH/monitoringCompute-"
LOG_MONITORING_NETWORK_PATH_PREFIX="$LOGS_PATH/tmp/monitoringNetwork-"
LOG_MONITORING_STORAGE_PATH_PREFIX="$LOGS_PATH/tmp/monitoringStorage-"
echo "Logs path : "$LOGS_PATH

echo "** Starting monitoring. **"
for i in `cat $MANAGERS_TO_MONITOR`; do
	if [[ "$i" == *"manager"* ]]; then
		eval `echo $i`;
		echo "Running tests on manager $manager"
		createCachetGroupComponent $manager
	else
		if [[ "$i" == "compute" ]]; then
			echo "COMPUTE: Running tests for $i on $manager"
			createCachetComponent $MANAGER $CONST_COMPUTE_PREFIXs
			monitoringCompute $manager >> "$LOG_MONITORING_COMPUTE_PATH_PREFIX"$manager".log"

		elif [[ "$i" == "storage" ]]; then
			echo "STORAGE: Running tests for $i on $manager"
			monitoringStorage $manager >> "$LOG_MONITORING_STORAGE_PATH_PREFIX"$manager".log"
			createCachetComponent $MANAGER $CONST_STORAGE_PREFIX
			
		elif [[ "$i" == "network" ]]; then
			echo "NETWORK: Running tests for $i on $manager"
			monitoringNetwork $manager >> "$LOG_MONITORING_NETWORK_PATH_PREFIX"$manager".log"
			createCachetComponent $MANAGER $CONST_NETWORK_PREFIX
			
		fi
	fi
done

echo "....................................."
echo "End main script."
echo "Wait others scripts (monitoringCompute, monitoringStorage and monitoringNetwork. "
echo "Check logs in $LOGS_PATH."
echo "....................................."