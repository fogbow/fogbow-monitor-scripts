#!/bin/bash
DIRNAME=`dirname $0`
source "$DIRNAME/test-compute.sh"

function doSomethingMonitoringStatusOrderNetworkTimeout {
	MESSAGE="$1"
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION_TO_NETWORK $CONST_NETWORK_PREFIX`
	createCachetIncident "Incident in create order network." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE

	garbageCollectorNetwork
}

function doSomethingMonitoringStatusOrderOneTimeout {
	MESSAGE="$1"
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION_TO_NETWORK $CONST_NETWORK_PREFIX`
	createCachetIncident "Incident in create order one." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE

	garbageCollectorNetwork
}

function doSomethingMonitoringStatusOrderTwoTimeout {
	MESSAGE="$1"
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION_TO_NETWORK $CONST_NETWORK_PREFIX`
	createCachetIncident "Incident in create order two." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE

	garbageCollectorNetwork
}

function doSomethingMonitoringConnectivity {
	MESSAGE="$1"
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION_TO_NETWORK $CONST_NETWORK_PREFIX`
	createCachetIncident "Incident in checking connectivity." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE	

	garbageCollectorNetwork
}

function doSomethingMonitoringPublicIpOrderTwoTimeout {
	MESSAGE="$1"
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION_TO_NETWORK $CONST_NETWORK_PREFIX`
	createCachetIncident "Incident in checking public ip VM 2." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE	

	garbageCollectorNetwork
}

function doSomethingMonitoringPublicIpOrderOneTimeout {
	MESSAGE="$1"
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION_TO_NETWORK $CONST_NETWORK_PREFIX`
	createCachetIncident "Incident in checking public ip VM 1." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE	

	garbageCollectorNetwork
}

function createOrderNetwork {
	## Requesting network
	## Creating network order
	echo "Creating network order."
	REQUIREMENTS="Glue2CloudComputeManagerID==\"$MANAGER_LOCATION_TO_NETWORK\""

	DATE=`date`
	CREATE_ORDER_NETWORK_COMMAND="$FOGBOW_CLI_PATH order --create --url $MANAGER_URL --auth-token $MANAGER_TOKEN --requirements $REQUIREMENTS --cidr 10.10.10.0/24 --allocation dynamic --gateway 10.10.10.1 --resource-kind network"
	echo "$DATE - Creating network with cidr 10.10.10.0/24 ... Executing command: $CREATE_ORDER_NETWORK_COMMAND"
	FOGBOW_NETWORK_ORDERS=`$CREATE_ORDER_NETWORK_COMMAND`
	echo "Order network result: "$FOGBOW_NETWORK_ORDERS
	NETWORK_ID="null"
	# test-compute method
	for LINE in $FOGBOW_NETWORK_ORDERS; do 
		if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
			NETWORK_ORDER_ID=`getOrderIdByLocationLine $LINE`
		fi;
	done;

	RETRIES=$FULFIELD_ORDERS_TIMEOUT_RETRIES
	echo "NETWORK_ID : "$NETWORK_ID
	echo "NETWORK_ORDER_ID : "$NETWORK_ORDER_ID
	while [[ "$NETWORK_ID" == "null" || -z "$NETWORK_ID" ]]; do
		DATE=`date`
		echo "$DATE - Checking order status ..."
		ORDER_DETAILS=`$FOGBOW_CLI_PATH order --get --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $NETWORK_ORDER_ID`
		echo "Order details : "$ORDER_DETAILS
		ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
		NETWORK_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
		DATE=`date`
		echo "$DATE - ORDER ID: $NETWORK_ORDER_ID - Status: $ORDER_STATE - NETWORK_ID: $NETWORK_ID"
		if [[ "$NETWORK_ID" == "null" || -z "$NETWORK_ID" ]]; then
			echo "Network order still open. Waiting $FULFIELD_ORDERS_TIMEOUT seconds to check again."
			if [[ $RETRIES -eq 0 ]]; then
				MESSAGE="Monitoring status order network timeout : $FULFIELD_ORDERS_TIMEOUT_RETRIES to $FULFIELD_ORDERS_TIMEOUT seconds"
				DATE=`date`
				echo "$DATE - $MESSAGE"
				doSomethingMonitoringStatusOrderNetworkTimeout "$MESSAGE"
				exit 1
			fi			
			sleep $FULFIELD_ORDERS_TIMEOUT
			let RETRIES=RETRIES-1
			echo "Order network still open/pending. Waiting "$FULFIELD_ORDERS_TIMEOUT" seconds to verify again. $RETRIES attempts remaining."
		fi
	done		
}

function createOrdersCompute {
	REQUIREMENTS="Glue2CloudComputeManagerID==\"$MANAGER_LOCATION_TO_NETWORK\""
	DATE=`date`
	COMAND_CREATE_ORDER_COMPUTE_ONE="$FOGBOW_CLI_PATH order --create --n 1 --url $MANAGER_URL --auth-token $MANAGER_TOKEN --requirements $REQUIREMENTS --image $ORDER_IMAGE --network $NETWORK_ID --public-key $SSH_PUBLICKEY --resource-kind compute"
	echo "$DATE - Creating VM 1 with network $NETWORK_ID. Executing command : "$COMAND_CREATE_ORDER_COMPUTE_ONE
	VM1_ORDER=`$COMAND_CREATE_ORDER_COMPUTE_ONE`
	echo $VM1_ORDER

	DATE=`date`
	COMAND_CREATE_ORDER_COMPUTE_TWO="$FOGBOW_CLI_PATH order --create --n 1 --url $MANAGER_URL --auth-token $MANAGER_TOKEN --requirements $REQUIREMENTS --image $ORDER_IMAGE --network $NETWORK_ID --public-key $SSH_PUBLICKEY --resource-kind compute"
	echo "$DATE - Creating VM 2 with network $NETWORK_ID. Executing command: $COMAND_CREATE_ORDER_COMPUTE_TWO"
	VM2_ORDER=`$COMAND_CREATE_ORDER_COMPUTE_TWO`
	echo $VM2_ORDER	

}

function checkVMOne {
	## Requesting VM 1

	for LINE in $VM1_ORDER; do 
		if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
			VM1_ORDER_ID=`getOrderIdByLocationLine $LINE`	
		fi;
	done;		

	DATE=`date`
	echo "$DATE - Checking VM 1 with network $NETWORK_ID"	
	VM1_ID="null"
	VM1_PUBLIC_IP="null"
	VM1_PRIVATE_IP="null"	
	RETRIES_VM1=$FULFIELD_ORDERS_TIMEOUT_RETRIES
	while [[ "$VM1_ID" = "null" ]]; do
		DATE=`date`
		echo "$DATE - Checking status of VM 1 order."
		ORDER_DETAILS=`$FOGBOW_CLI_PATH order --get --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $VM1_ORDER_ID`
		ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
		VM1_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
		DATE=`date`
		echo "$DATE - ORDER ID: $VM1_ORDER_ID - Status: $ORDER_STATE - VM 1 ID: $VM1_ID"
		if [[ "$VM1_ID" = "null" ]]; then
			if [[ $RETRIES_VM1 -eq 0 ]]; then
				MESSAGE="Monitoring status order 1 timeout : $FULFIELD_ORDERS_TIMEOUT_RETRIES to $FULFIELD_ORDERS_TIMEOUT seconds"
				DATE=`date`
				echo "$DATE - $MESSAGE"
				doSomethingMonitoringStatusOrderOneTimeout "$MESSAGE"
				garbageCollectorNetwork
				exit 1
			fi					
			echo "Order 1 still open/pending. Waiting "$FULFIELD_ORDERS_TIMEOUT" seconds to verify again. $RETRIES_VM1 attempts remaining."
			sleep $INSTANCE_IP_TIMEOUT
			let RETRIES_VM1=RETRIES_VM1-1
		else
			RETRIES=$FULFIELD_ORDERS_TIMEOUT_RETRIES
			while [[ "$VM1_PUBLIC_IP" = "null" || "$VM1_PUBLIC_IP" = "" ]]; do
				DATE=`date`
				echo "$DATE - Waiting for VM 1 public and private IP"
				VM1_DETAILS=`$FOGBOW_CLI_PATH instance --get --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $VM1_ID`
				echo "VM1_DETAILS :"$VM1_DETAILS
				VM1_PUBLIC_IP=`echo $VM1_DETAILS | grep -oP "org.fogbowcloud.order.ssh-public-address=\"([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3}):([0-9]{1,5})\"" | sed 's/org.fogbowcloud.order.ssh-public-address="//' | sed 's/"//' | sed 's/:/ -p /'`
				VM1_PRIVATE_IP=`echo $VM1_DETAILS | grep -oP "org.fogbowcloud.order.local-ip-address=\"([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\"" | sed 's/org.fogbowcloud.order.local-ip-address="//' | sed 's/"//' | sed 's/:/ -p /'`
				DATE=`date`
				echo "$DATE - VM 1 - Public IP: $VM1_PUBLIC_IP - Private IP: $VM1_PRIVATE_IP"
				if [[ "$VM1_PUBLIC_IP" = "null" || "$VM1_PUBLIC_IP" = "" ]]; then
					if [[ $RETRIES -eq 0 ]]; then
						MESSAGE="Monitoring public ip order 1 timeout : $FULFIELD_ORDERS_TIMEOUT_RETRIES to $FULFIELD_ORDERS_TIMEOUT seconds"
						DATE=`date`
						echo "$DATE - $MESSAGE"
						doSomethingMonitoringPublicIpOrderOneTimeout "$MESSAGE"
						garbageCollectorNetwork
						exit 1
					fi					
					echo "Order 1 still withou public ip. Waiting "$FULFIELD_ORDERS_TIMEOUT" seconds to verify again. $RETRIES attempts remaining."
					sleep $INSTANCE_IP_TIMEOUT
					let RETRIES=RETRIES-1
				fi
			done
		fi
	done
}

function checkVMTwo {
	## Checking VM 2
	DATE=`date`
	echo "$DATE - Checking VM 2 with network $NETWORK_ID"

	for LINE in $VM1_ORDER; do 
		if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
			VM2_ORDER_ID=`getOrderIdByLocationLine $LINE`
		fi;
	done;	
	
	VM2_ID="null"
	VM2_PUBLIC_IP="null"
	VM2_PRIVATE_IP="null"	
	RETRIES_VM2=$FULFIELD_ORDERS_TIMEOUT_RETRIES
	while [[ "$VM2_ID" = "null" ]]; do
		DATE=`date`
		echo "$DATE - Checking status of VM 2 order."
		ORDER_DETAILS=`$FOGBOW_CLI_PATH order --get --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $VM2_ORDER_ID`
		ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
		VM2_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
		DATE=`date`
		echo "$DATE - ORDER ID: $VM2_ORDER_ID - Status: $ORDER_STATE - VM 2 ID: $VM2_ID"
		if [[ "$VM2_ID" = "null" ]]; then
			if [[ $RETRIES_VM2 -eq 0 ]]; then
				MESSAGE="Monitoring status order 2 timeout : $FULFIELD_ORDERS_TIMEOUT_RETRIES to $FULFIELD_ORDERS_TIMEOUT seconds"
				DATE=`date`
				echo "$DATE - $MESSAGE"
				doSomethingMonitoringStatusOrderOneTimeout "$MESSAGE"
				garbageCollectorNetwork
				exit 1
			fi					
			echo "Order 2 still open/pending. Waiting "$FULFIELD_ORDERS_TIMEOUT" seconds to verify again. $RETRIES_VM2 attempts remaining."
			sleep $INSTANCE_IP_TIMEOUT
			let RETRIES_VM2=RETRIES_VM2-1
		else
			RETRIES=$FULFIELD_ORDERS_TIMEOUT_RETRIES
			while [[ "$VM2_PUBLIC_IP" = "null" || "$VM2_PUBLIC_IP" = "" ]]; do
				DATE=`date`
				echo "$DATE - Waiting for VM 2 public and private IP"
				VM2_DETAILS=`$FOGBOW_CLI_PATH instance --get --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $VM2_ID`
				echo "VMw_DETAILS :"$VM2_DETAILS
				VM2_PUBLIC_IP=`echo $VM2_DETAILS | grep -oP "org.fogbowcloud.order.ssh-public-address=\"([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3}):([0-9]{1,5})\"" | sed 's/org.fogbowcloud.order.ssh-public-address="//' | sed 's/"//' | sed 's/:/ -p /'`
				VM2_PRIVATE_IP=`echo $VM2_DETAILS | grep -oP "org.fogbowcloud.order.local-ip-address=\"([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\"" | sed 's/org.fogbowcloud.order.local-ip-address="//' | sed 's/"//' | sed 's/:/ -p /'`
				DATE=`date`
				echo "$DATE - VM 2 - Public IP: $VM2_PUBLIC_IP - Private IP: $VM2_PRIVATE_IP"
				if [[ "$VM2_PUBLIC_IP" = "null" || "$VM2_PUBLIC_IP" = "" ]]; then
					if [[ $RETRIES -eq 0 ]]; then
						MESSAGE="Monitoring public ip order 2 timeout : $FULFIELD_ORDERS_TIMEOUT_RETRIES to $FULFIELD_ORDERS_TIMEOUT seconds"
						DATE=`date`
						echo "$DATE - $MESSAGE"
						doSomethingMonitoringPublicIpOrderTwoTimeout "$MESSAGE"
						exit 1
					fi							
					echo "Order 2 still without public ip. Waiting "$FULFIELD_ORDERS_TIMEOUT" seconds to verify again. $RETRIES attempts remaining."
					sleep $INSTANCE_IP_TIMEOUT
					let RETRIES=RETRIES-1
				fi
			done
		fi
	done	
}

function connectivity {
	DATE=`date`
	echo "$DATE - Executing telnet from VM 1 $VM1_PRIVATE_IP to VM 2 $VM2_PRIVATE_IP to check connectivity"
	TELNET_OUTPUT=`ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_PRIVATEKEY fogbow@$VM1_PUBLIC_IP "telnet $VM2_PRIVATE_IP 22 &"`
	## check if the output has the string "Connected to $VM2_PRIVATEIP"
	DATE=`date`
	echo "$DATE - Checking if the command telnet worked successfully."
	TELNET_WORKED=`echo $TELNET_OUTPUT | grep -c "Connected to $VM2_PRIVATE_IP"`
	DATE=`date`
	if [[ "$TELNET_WORKED" -eq "1" ]]; then
		echo "$DATE - Telnet worked fine. Network is working well on fogbow."
	else
		MESSAGE="$DATE - Could not connect using telnet, something is wrong with network on fogbow."
		echo "$MESSAGE"
		doSomethingMonitoringConnectivity "$MESSAGE"
	fi
}

function garbageCollectorNetwork {
	echo "Starting garbageCollectorNetwork"
	DATE=`date`
	echo "$DATE - Deleting compute orders"
	$FOGBOW_CLI_PATH order --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$VM1_ORDER_ID"
	$FOGBOW_CLI_PATH order --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$VM2_ORDER_ID"

	DATE=`date`
	echo "$DATE - Deleting instances"

	echo "Command delete VM1: $FOGBOW_CLI_PATH instance --delete --url \"$MANAGER_URL\" --auth-token \"$MANAGER_TOKEN\" --id \"$VM1_ID\""
	$FOGBOW_CLI_PATH instance --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$VM1_ID"
	echo "Command delete VM2: $FOGBOW_CLI_PATH instance --delete --url \"$MANAGER_URL\" --auth-token \"$MANAGER_TOKEN\" --id \"$VM2_ID\""
	$FOGBOW_CLI_PATH instance --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$VM2_ID"

	DATE=`date`
	echo "$DATE - Deleting network order"
	$FOGBOW_CLI_PATH order --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$NETWORK_ORDER_ID"

	DATE=`date`
	echo "$DATE - Deleting network"
	echo "Command delete VM1: $FOGBOW_CLI_PATH network --delete --url \"$MANAGER_URL\" --auth-token \"$MANAGER_TOKEN\" --id \"$NETWORK_ID\""
	$FOGBOW_CLI_PATH network --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$NETWORK_ID"
}


function monitoringNetwork {
	MANAGER_LOCATION_TO_NETWORK=$1
	echo "====================================================="
	echo "Monitoring manager: "$MANAGER_LOCATION_TO_NETWORK
	echo "Testing network"
	echo "====================================================="

	updateCachetComponent "$MANAGER_LOCATION_TO_NETWORK" "$CONST_NETWORK_PREFIX" "$CONST_COMPONENT_OPERATIONAL"

	createOrderNetwork
	createOrdersCompute
	checkVMOne
	checkVMTwo
	connectivity
	garbageCollectorNetwork
}
