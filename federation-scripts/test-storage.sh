#!/bin/bash
DIRNAME=`dirname $0`

function doSomethingMonitoringStatusOrderStorageTimeout {
	MESSAGE="$1"
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION_TO_STORAGE $CONST_STORAGE_PREFIX`
	createCachetIncident "Incident in create order storage." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE

	garbageCollector
}

function doSomethingMonitoringStatusOrderComputeTimeout {
	MESSAGE="$1"
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION_TO_STORAGE $CONST_STORAGE_PREFIX`
	createCachetIncident "Incident in create order compute." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE

	garbageCollector
}

function doSomethingMonitoringStatusInstanceIpTimeout {
	MESSAGE="$1"
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION_TO_STORAGE $CONST_STORAGE_PREFIX`
	createCachetIncident "Incident in checking instance IP." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE	

	garbageCollector
}

function doSomethingMonitoringNumberDiskTimeout {
	MESSAGE="$1"
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION_TO_STORAGE $CONST_STORAGE_PREFIX`
	createCachetIncident "Incident in amount disk." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE	

	garbageCollector
}

function createOrderCompute {
	## Creating order compute

	if [[ -z "$ORDER_REQUIREMENTS" ]]; then
		REQUIREMENTS="Glue2CloudComputeManagerID==\"$MANAGER_LOCATION_TO_STORAGE\""
	else 
		REQUIREMENTS=$ORDER_REQUIREMENTS" && Glue2CloudComputeManagerID==\"$MANAGER_LOCATION_TO_STORAGE\""
	fi

	DATE=`date`
	echo "$DATE - Creating the compute order"
	FOGBOW_ORDERS=`$FOGBOW_CLI_PATH order --create --n 1 --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --requirements $REQUIREMENTS --image $ORDER_IMAGE --public-key "$SSH_PUBLICKEY" --resource-kind compute`
	echo "Order compute result : " $FOGBOW_ORDERS
}

function createOrderStorage {
	## Requesting storage
	## Creating storage order
	DATE=`date`
	echo "$DATE - Creating storage disk with 2GB ..."
	REQUIREMENTS="Glue2CloudComputeManagerID==\"$MANAGER_LOCATION_TO_STORAGE\""
	COMMAND_CREATE_STORAGE_ORGER="$FOGBOW_CLI_PATH order --create --url $MANAGER_URL --auth-token $MANAGER_TOKEN --requirements $REQUIREMENTS --size 2 --resource-kind storage"
	FOGBOW_STORAGE_ORDERS=`$COMMAND_CREATE_STORAGE_ORGER`
	STORAGE_ID="null"
	STORAGE_ORDER_ID="null"
	RETRIES=$FULFIELD_ORDERS_TIMEOUT_RETRIES
	while [[ "$STORAGE_ID" = "null" ]]; do
		DATE=`date`
		echo "$DATE - Checking order status ..."
		for LINE in $FOGBOW_STORAGE_ORDERS; do 
			if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
				STORAGE_ORDER_ID=`getOrderIdByLocationLine $LINE`
				ORDER_DETAILS=`$FOGBOW_CLI_PATH order --get --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $STORAGE_ORDER_ID`
				ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
				STORAGE_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
				DATE=`date`
				echo "$DATE - ORDER ID: $STORAGE_ORDER_ID - Status: $ORDER_STATE - STORAGE_ID: $STORAGE_ID"
				if [[ "$STORAGE_ID" = "null" ]]; then
					if [[ $RETRIES -eq 0 ]]; then
						MESSAGE="Monitoring status order 1 timeout : $FULFIELD_ORDERS_TIMEOUT_RETRIES to $FULFIELD_ORDERS_TIMEOUT seconds"
						DATE=`date`
						echo "$DATE - $MESSAGE"
						doSomethingMonitoringStatusOrderStorageTimeout "$MESSAGE"
						exit 1
					fi							
					echo "Order still open/pending. Waiting "$FULFIELD_ORDERS_TIMEOUT" seconds to verify again."
					sleep $INSTANCE_IP_TIMEOUT
					let RETRIES=RETRIES-1					
				fi
			fi;
		done;
	done
}

function monitoringOrderStatus {
	COMPUTE_ORDER_ID="null"
	COMPUTE_ID="null"
	COMPUTE_IP="null"

	RETRIES=$FULFIELD_ORDERS_TIMEOUT_RETRIES
	while [[ "$COMPUTE_ID" = "null" ]]; do
		DATE=`date`
		echo "$DATE - Checking order status ..."
		for LINE in $FOGBOW_ORDERS; do 
			if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
				COMPUTE_ORDER_ID=`getOrderIdByLocationLine $LINE`
				ORDER_DETAILS=`$FOGBOW_CLI_PATH order --get --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $COMPUTE_ORDER_ID`
				ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
				COMPUTE_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
				DATE=`date`
				echo "$DATE - ORDER ID: $COMPUTE_ORDER_ID - Status: $ORDER_STATE - COMPUTE_ID: $COMPUTE_ID"
				if [[ "$COMPUTE_ID" = "null" ]]; then
					if [[ $RETRIES -eq 0 ]]; then
						MESSAGE="Monitoring status order compute timeout : $FULFIELD_ORDERS_TIMEOUT_RETRIES to $FULFIELD_ORDERS_TIMEOUT seconds"
						DATE=`date`
						echo "$DATE - $MESSAGE"
						doSomethingMonitoringStatusOrderComputeTimeout "$MESSAGE"
						exit 1
					fi							
					echo "Order still open/pending. Waiting "$FULFIELD_ORDERS_TIMEOUT" seconds to verify again."
					sleep $INSTANCE_IP_TIMEOUT
					let RETRIES=RETRIES-1								
				else
					INSTANCE_HAS_IP=false
					RETRIES_INSTANCE=$INSTANCE_IP_TIMEOUT_RETRIES
					while [[ "$INSTANCE_HAS_IP" = false ]]; do 
						DATE=`date`
						echo "$DATE - Trying to get instance $INSTANCE_ID IP"
						INSTANCE_DETAILS=`$FOGBOW_CLI_PATH instance --get --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $COMPUTE_ID`
						INSTANCE_STATE=`echo $INSTANCE_DETAILS | grep -oP "occi.compute.state=\"([a-z]*)\"" | sed 's/occi.compute.state="//' | sed 's/"//'`
						INSTANCE_IP=`echo $INSTANCE_DETAILS | grep -oP "org.fogbowcloud.order.ssh-public-address=\"([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3}):([0-9]{1,5})\"" | sed 's/org.fogbowcloud.order.ssh-public-address="//' | sed 's/"//' | sed 's/:/ -p /'`
						echo "Monitoring instance $COMPUTE_ID ($INSTANCE_IP)"
						if [[ "$INSTANCE_STATE" = "active" && "$INSTANCE_IP" != "null" && "$INSTANCE_IP" != "" ]]; then
							INSTANCE_HAS_IP=true
							DATE=`date`
							echo "$DATE - Requesting attachment of the new storage disk"
							INITIAL_DISKS_NUMBER=`ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_PRIVATEKEY fogbow@$INSTANCE_IP "sudo fdisk -l | grep \"Disk /dev\" | wc -l"`
							CURRENT_DISKS_NUMBER=$INITIAL_DISKS_NUMBER
							let EXPECTED_DISKS_NUMBER=INITIAL_DISKS_NUMBER+1
							ATTACH_DISK=`$FOGBOW_CLI_PATH attachment --create --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --computeId $COMPUTE_ID --storageId $STORAGE_ID`
							echo "Attachment result: "$ATTACH_DISK
							RETRIES_DISK_ATTEMPS=$INSTANCE_IP_TIMEOUT_RETRIES
							while [[ "$CURRENT_DISKS_NUMBER" -lt "$EXPECTED_DISKS_NUMBER" ]]; do
								DATE=`date`
								echo "$DATE - Checking number of disks. Before check: Expected: $EXPECTED_DISKS_NUMBER Current: $CURRENT_DISKS_NUMBER"
								CURRENT_DISKS_NUMBER=`ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_PRIVATEKEY fogbow@$INSTANCE_IP "sudo fdisk -l | grep \"Disk /dev\" | wc -l"`
								DATE=`date`
								echo "$DATE - Checking number of disks. After check: Expected: $EXPECTED_DISKS_NUMBER Current: $CURRENT_DISKS_NUMBER"
								if [[ "$CURRENT_DISKS_NUMBER" != "$EXPECTED_DISKS_NUMBER" ]]; then
									if [[ $RETRIES_DISK_ATTEMPS -eq 0 ]]; then
										MESSAGE="Invalid number disk timeout : $FULFIELD_ORDERS_TIMEOUT_RETRIES to $FULFIELD_ORDERS_TIMEOUT seconds"
										DATE=`date`
										echo "$DATE - $MESSAGE"
										doSomethingMonitoringNumberDiskTimeout "$MESSAGE"
										exit 1
									fi							
									echo "Invalid number disks. Waiting "$INSTANCE_IP_TIMEOUT" seconds to verify again."
									sleep $INSTANCE_IP_TIMEOUT
									let RETRIES_DISK_ATTEMPS=RETRIES_DISK_ATTEMPS-1											
								fi
							done

							for LINE in $ATTACH_DISK; do 
								if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
									ATTACHMENT_ID=`getAttachmentIdByLocationLineCreateSintax $LINE`	
									DATE=`date`
									echo "$DATE - Deleting attachment with ID $ATTACHMENT_ID"
									DELETE_ATTACHMENT=`$FOGBOW_CLI_PATH attachment --delete --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $ATTACHMENT_ID`
								fi;
							done;

							RETRIES_DISK_ATTEMPS=$INSTANCE_IP_TIMEOUT_RETRIES
							while [[ "$CURRENT_DISKS_NUMBER" -lt "$EXPECTED_DISKS_NUMBER" ]]; do
								DATE=`date`
								echo "$DATE - Checking number of disks. Before check: Expected: $EXPECTED_DISKS_NUMBER Current: $CURRENT_DISKS_NUMBER"
								CURRENT_DISKS_NUMBER=`ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_PRIVATEKEY fogbow@$INSTANCE_IP "sudo fdisk -l | grep \"Disk /dev\" | wc -l"`
								DATE=`date`
								echo "$DATE - Checking number of disks. After check: Expected: $EXPECTED_DISKS_NUMBER Current: $CURRENT_DISKS_NUMBER"
								if [[ "$CURRENT_DISKS_NUMBER" != "$EXPECTED_DISKS_NUMBER" ]]; then
									if [[ $RETRIES_DISK_ATTEMPS -eq 0 ]]; then
										MESSAGE="Invalid number disk timeout : $FULFIELD_ORDERS_TIMEOUT_RETRIES to $FULFIELD_ORDERS_TIMEOUT seconds"
										DATE=`date`
										echo "$DATE - $MESSAGE"
										doSomethingMonitoringNumberDiskTimeout "$MESSAGE"
										exit 1
									fi							
									echo "Invalid number disks. Waiting "$INSTANCE_IP_TIMEOUT" seconds to verify again."
									sleep $INSTANCE_IP_TIMEOUT
									let RETRIES_DISK_ATTEMPS=RETRIES_DISK_ATTEMPS-1											
								fi
							done

							DATE=`date`
							echo "$DATE - $COMPUTE_ID is up, now deleting it"
							DELETE_INSTANCE=`$FOGBOW_CLI_PATH instance --delete --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $COMPUTE_ID`
							echo "Delete instance output: $DELETE_INSTANCE"
							if [[ "$DELETE_INSTANCE" = "Ok" ]]; then
								DATE=`date`
								echo "$DATE - $COMPUTE_ID deleted."
								DELETE_ORDER=`$FOGBOW_CLI_PATH order --delete --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $COMPUTE_ORDER_ID`
								echo "Delete order output: $DELETE_ORDER"
								if [[ "$DELETE_ORDER" = "Ok" ]]; then
									DATE=`date`
									echo "$DATE - $COMPUTE_ORDER_ID deleted."
								fi
							fi

							DATE=`date`
							echo "$DATE - $STORAGE_ID is available, now deleting it"
							DELETE_INSTANCE=`$FOGBOW_CLI_PATH storage --delete --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $STORAGE_ID`
							echo "Delete storage output: $DELETE_INSTANCE"
							if [[ "$DELETE_INSTANCE" = "Ok" ]]; then
								DATE=`date`
								echo "$DATE - $STORAGE_ID deleted."
								DELETE_ORDER=`$FOGBOW_CLI_PATH order --delete --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $STORAGE_ORDER_ID`
								echo "Delete order output: $DELETE_ORDER"
								if [[ "$DELETE_ORDER" = "Ok" ]]; then
									DATE=`date`
									echo "$DATE - $STORAGE_ORDER_ID deleted."
								fi
							fi
						fi
						if [[ "$INSTANCE_HAS_IP" = false ]]; then
							DATE=`date`
							if [[ $RETRIES_INSTANCE -eq 0 ]]; then
								MESSAGE="Instance id timeout : $INSTANCE_IP_TIMEOUT_RETRIES to $INSTANCE_IP_TIMEOUT seconds"
								DATE=`date`
								echo "$DATE - $MESSAGE"
								doSomethingMonitoringStatusInstanceIpTimeout "$MESSAGE"
								exit 1
							fi			
							sleep $INSTANCE_IP_TIMEOUT
							let RETRIES_INSTANCE=RETRIES_INSTANCE-1
							echo "$DATE - Still waiting for the instance IP. Trying again after $INSTANCE_IP_TIMEOUT seconds. $RETRIES_INSTANCE attempts remaining."
						fi
					done
				fi
			fi;
		done;
	done
}

function garbageCollector {
	echo "Starting garbaeCollector"
	DATE=`date`
	echo "$DATE - Deleting compute orders"
	$FOGBOW_CLI_PATH order --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$STORAGE_ORDER_ID"
	$FOGBOW_CLI_PATH order --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$COMPUTE_ORDER_ID"

	DATE=`date`
	echo "$DATE - Deleting attachment"
	echo "Command delete attachment: $FOGBOW_CLI_PATH order --delete --url \"$MANAGER_URL\" --auth-token \"$MANAGER_TOKEN\" --id \"$STORAGE_ORDER_ID\""
	$FOGBOW_CLI_PATH attachment --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$ATTACHMENT_ID"

	DATE=`date`
	echo "$DATE - Deleting instances"
	echo "Command delete storage: $FOGBOW_CLI_PATH storage --delete --url \"$MANAGER_URL\" --auth-token \"$MANAGER_TOKEN\" --id \"$STORAGE_ID\""
	$FOGBOW_CLI_PATH storage --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$STORAGE_ID"
	echo "Command delete storage: $FOGBOW_CLI_PATH instance --delete --url \"$MANAGER_URL\" --auth-token \"$MANAGER_TOKEN\" --id \"$COMPUTE_ID\""
	$FOGBOW_CLI_PATH instance --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$COMPUTE_ID"
}

function monitoringStorage {
	MANAGER_LOCATION_TO_STORAGE=$1
	echo "====================================================="
	echo "Monitoring manager: "$MANAGER_LOCATION_TO_STORAGE
	echo "Testing storage"
	echo "====================================================="

	updateCachetComponent "$MANAGER_LOCATION_TO_STORAGE" "$CONST_STORAGE_PREFIX" "$CONST_COMPONENT_OPERATIONAL"

	createOrderCompute
	createOrderStorage
	monitoringOrderStatus
	garbageCollector
}
