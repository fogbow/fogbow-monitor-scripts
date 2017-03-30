#!/bin/bash
DIRNAME=`dirname $0`

function doSomethingCreateOrderError {
	MESSAGE="$1"
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION $CONST_COMPUTE_PREFIX`
	createCachetIncident "Incident in create orders." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE

	garbageCollector
}

function doSomethingCreateOrderOk {
	echo
}

function doSomethingMonitoringStatusOrderFulfilled {
	echo
}

function doSomethingMonitoringStatusOrderTimeout {
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION $CONST_COMPUTE_PREFIX`
	MESSAGE="$1"
	createCachetIncident "Incident in monitoring status order." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE	

	garbageCollector
}

function doSomethingMonitoringConnectionOrderTimeout {
	## Create incident
	COMPONENT_ID=`getCachetComponentIdByManager $MANAGER_LOCATION $CONST_COMPUTE_PREFIX`
	MESSAGE="$1"
	createCachetIncident "Incident in monitoring instance connection." "$MESSAGE" "1" $COMPONENT_ID $CONST_COMPONENT_MAJOR_OUTAGE	

	garbageCollector
}

function createOrders {
	echo "Creating $COUNT_ORDERS orders ..."
	## Creating compute orders
	if [[ -z "$ORDER_REQUIREMENTS" ]]; then
		REQUIREMENTS="Glue2CloudComputeManagerID==\"$MANAGER_LOCATION\""
	else 
		REQUIREMENTS=$ORDER_REQUIREMENTS" && Glue2CloudComputeManagerID==\"$MANAGER_LOCATION\""
	fi

	CREATE_ORDER_COMMAND="$FOGBOW_CLI_PATH order --create --n $COUNT_ORDERS --url $MANAGER_URL --auth-token $MANAGER_TOKEN --requirements $REQUIREMENTS --image $ORDER_IMAGE --public-key $SSH_PUBLICKEY --resource-kind compute"
	echo "Execution create order command: "$CREATE_ORDER_COMMAND
	FOGBOW_CREATE_ORDERS_RESPONSE=`$CREATE_ORDER_COMMAND`
	CURRENT_ORDERS_PATH="/tmp/current_orders"
	echo $FOGBOW_CREATE_ORDERS_RESPONSE > $CURRENT_ORDERS_PATH	

	AMOUNT_CURRENT_ORDERS=`wc -l $CURRENT_ORDERS_PATH`
	if [[ $AMOUNT_CURRENT_ORDERS != $COUNT_ORDERS* ]]; then
		echo "Error while creating orders:"$FOGBOW_CREATE_ORDERS_RESPONSE
		doSomethingCreateOrderError $FOGBOW_CREATE_ORDERS_RESPONSE
		exit 1
	else
		echo "Orders creation ok."
		doSomethingCreateOrderOk
		cat $CURRENT_ORDERS_PATH
	fi
}

## Getting info about each order and checking if it is fulfilled
function monitoringStatusOrder {
	echo "Monitoring order status."
	ALL_FULFILLED=false
	RETRIES=$FULFIELD_ORDERS_TIMEOUT_RETRIES
	while [[ "$ALL_FULFILLED" = false ]]; do		
		echo "Trying to check all fulfield orders: Retries: $RETRIES"
		ALL_FULFILLED=true
		for LINE in $FOGBOW_CREATE_ORDERS_RESPONSE; do 
			if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
				ORDER_ID=`getOrderIdByLocationLine $LINE`
				GET_ORDER_COMMAND="$FOGBOW_CLI_PATH order --get --url $MANAGER_URL --auth-token $MANAGER_TOKEN --id $ORDER_ID"
				echo "Execution create order command: "$GET_ORDER_COMMAND
				ORDER_DETAILS=`$GET_ORDER_COMMAND`

				ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
				INSTANCE_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
				DATE=`date`
				echo "$DATE - ID: $ORDER_ID - Status: $ORDER_STATE"
				if [[ "$ORDER_STATE" = "open" || "$ORDER_STATE" = "pending" || -z "$ORDER_STATE" ]]; then
					ALL_FULFILLED=false
				fi
			fi;
		done;		
		if [[ "$ALL_FULFILLED" = false ]]; then		
			if [[ $RETRIES -eq 0 ]]; then
				MESSAGE="Monitoring status order timeout : $FULFIELD_ORDERS_TIMEOUT_RETRIES to $FULFIELD_ORDERS_TIMEOUT seconds"
				DATE=`date`
				echo "$DATE - $MESSAGE"
				doSomethingMonitoringStatusOrderTimeout "$MESSAGE"
				return 1
			fi
			echo "Some orders still open/pending. Waiting "$FULFIELD_ORDERS_TIMEOUT" seconds to verify again."
			sleep $FULFIELD_ORDERS_TIMEOUT				
			let RETRIES=RETRIES-1
		else
			echo "All orders are fulfilled."
			doSomethingMonitoringStatusOrderFulfilled
			echo "Finishing monitoring order status ..."
		fi
	done	
}

function monitoringConnectionOrder {
	echo "Monitoring orders with instance to get IP and try SSH connection"
	for LINE in $FOGBOW_CREATE_ORDERS_RESPONSE; do 
		if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
			ORDER_ID=`getOrderIdByLocationLine $LINE`
			ORDER_DETAILS=`$FOGBOW_CLI_PATH order --get --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $ORDER_ID`
			INSTANCE_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
			RETRIES=$INSTANCE_IP_TIMEOUT_RETRIES
			INSTANCE_HAS_IP=false
			while [[ "$RETRIES" -gt 0 && "$INSTANCE_HAS_IP" = false ]]; do 
				echo "Trying to get instance $INSTANCE_ID IP: Retries: $RETRIES"
				INSTANCE_DETAILS=`$FOGBOW_CLI_PATH instance --get --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $INSTANCE_ID`
				INSTANCE_STATE=`echo $INSTANCE_DETAILS | grep -oP "occi.compute.state=\"([a-z]*)\"" | sed 's/occi.compute.state="//' | sed 's/"//'`
				INSTANCE_IP=`echo $INSTANCE_DETAILS | grep -oP "org.fogbowcloud.order.ssh-public-address=\"([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3}):([0-9]{1,5})\"" | sed 's/org.fogbowcloud.order.ssh-public-address="//' | sed 's/"//' | sed 's/:/ -p /'`
				echo "Monitoring instance $INSTANCE_ID ($INSTANCE_IP)"
				if [[ "$INSTANCE_STATE" = "active" && "$INSTANCE_IP" != "null" && "$INSTANCE_IP" != "" ]]; then
					INSTANCE_HAS_IP=true
					DATE=`date`
					echo "$DATE - Executing SSH command"
					SSH_OUTPUT=`ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_PRIVATEKEY fogbow@$INSTANCE_IP "echo $ORDER_ID > /tmp/$ORDER_ID.output; cat /tmp/$ORDER_ID.output"`
					if [[ "$SSH_OUTPUT" = "$ORDER_ID" ]]; then
						DATE=`date`
						echo "$DATE - $INSTANCE_ID worked fine"
						DELETE_INSTANCE=`$FOGBOW_CLI_PATH instance --delete --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $INSTANCE_ID`
						if [[ "$DELETE_INSTANCE" = "Ok" ]]; then
							DATE=`date`
							echo "$DATE - $INSTANCE_ID deleted."
							DELETE_ORDER=`$FOGBOW_CLI_PATH order --delete --url "$MANAGER_URL" --auth-token $MANAGER_TOKEN --id $ORDER_ID`
							if [[ "$DELETE_ORDER" = "Ok" ]]; then
								DATE=`date`
								echo "$DATE - $ORDER_ID deleted."
							fi
						fi
					else
						echo "$DATE - Unexpected SSH output"
					fi
				fi
				if [[ "$INSTANCE_HAS_IP" = false ]]; then
					DATE=`date`
					echo "$DATE - Still waiting for the instance IP. Trying again after $INSTANCE_IP_TIMEOUT seconds."
					sleep $INSTANCE_IP_TIMEOUT
				fi
				let RETRIES=RETRIES-1
			done
			if [[ "$INSTANCE_HAS_IP" = false ]]; then
				DATE=`date`
				MESSAGE="Instance $INSTANCE_ID has reached the timeout without IP. Now deleting."
				echo "$DATE - $MESSAGE"
				DELETE_INSTANCE=`$FOGBOW_CLI_PATH instance --delete --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $INSTANCE_ID`
				DELETE_ORDER=`$FOGBOW_CLI_PATH order --delete --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $ORDER_ID`

				doSomethingMonitoringConnectionOrderTimeout "$MESSAGE"
			fi
		fi;
	done;
}

function garbageCollector {
	echo "Starting garbaeCollector"

	while [[ "$ALL_FULFILLED" = false ]]; do		
		echo "Trying to check all fulfield orders: Retries: $RETRIES"
		ALL_FULFILLED=true
		for LINE in $FOGBOW_CREATE_ORDERS_RESPONSE; do 
			if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
				ORDER_ID=`getOrderIdByLocationLine $LINE`
				GET_ORDER_COMMAND="$FOGBOW_CLI_PATH order --get --url $MANAGER_URL --auth-token $MANAGER_TOKEN --id $ORDER_ID"
				echo "Execution create order command: "$GET_ORDER_COMMAND
				ORDER_DETAILS=`$GET_ORDER_COMMAND`

				INSTANCE_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`

				DATE=`date`
				echo "$DATE - Deleting compute orders"
				$FOGBOW_CLI_PATH order --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$ORDER_ID"
				DATE=`date`
				echo "$DATE - Deleting instances"
				$FOGBOW_CLI_PATH instance --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id "$INSTANCE_ID"
			fi;
		done;		
	done
}

function monitoringCompute {
	MANAGER_LOCATION=$1
	echo "====================================================="
	echo "Monitoring manager: "$MANAGER_LOCATION
	echo "Testing compute"
	echo "====================================================="

	updateCachetComponent "$MANAGER_LOCATION" "$CONST_COMPUTE_PREFIX" "$CONST_COMPONENT_OPERATIONAL"

	createOrders
	monitoringStatusOrder
	monitoringConnectionOrder
	garbageCollector
}
