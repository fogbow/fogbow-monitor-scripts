#!/bin/bash
. settings.sh

echo "====================================================="
echo "Monitoring manager $MANAGER_URL with user $USER_LOGIN"
echo "====================================================="

## Creating compute orders
echo "Creating 3 orders ..."
FOGBOW_ORDERS=`fogbow-cli order --create --n 3 --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --requirements "Glue2RAM >= 1024" --image fogbow-ubuntu --public-key "$SSH_PUBLICKEY" --resource-kind compute`
echo $FOGBOW_ORDERS > /tmp/current_orders
#FOGBOW_ORDERS=`cat /tmp/current_orders`

## Getting information about orders
#FOGBOW_ORDERS=`fogbow-cli order --get --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN"`

## Getting info about each order

ALL_FULFILLED=false
while [[ "$ALL_FULFILLED" = false ]]; do
	echo "Starting monitoring ..."
	ALL_FULFILLED=true
	for LINE in $FOGBOW_ORDERS; do 
		if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
			ORDER_ID=`echo $LINE | sed 's/http:\/\/10.11.4.234:8182\/order\///'`
			ORDER_DETAILS=`fogbow-cli order --get --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $ORDER_ID`
			ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
			INSTANCE_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
			DATE=`date`
			echo "$DATE - ID: $ORDER_ID - Status: $ORDER_STATE"
			if [[ "$ORDER_STATE" = "open" || "$ORDER_STATE" = "pending" ]]; then
				ALL_FULFILLED=false
			fi
		fi;
	done;
	echo "Finishing monitoring ..."
	if [[ "$ALL_FULFILLED" = false ]]; then
		echo "Some orders still open/pending. Waiting 10 seconds to verify again."
		sleep 10
	else
		echo "All orders are fulfilled."
	fi
done

## Monitoring instances to get IP and try SSH connection
for LINE in $FOGBOW_ORDERS; do 
	if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
		ORDER_ID=`echo $LINE | sed 's/http:\/\/10.11.4.234:8182\/order\///'`
		ORDER_DETAILS=`fogbow-cli order --get --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $ORDER_ID`
		INSTANCE_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
		RETRIES=$INSTANCE_IP_TIMEOUT_RETRIES
		INSTANCE_HAS_IP=false
		while [[ "$RETRIES" -gt 0 && "$INSTANCE_HAS_IP" = false ]]; do 
			echo "Trying to get instance $INSTANCE_ID IP: Retries: $RETRIES"
			INSTANCE_DETAILS=`fogbow-cli instance --get --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $INSTANCE_ID`
			INSTANCE_STATE=`echo $INSTANCE_DETAILS | grep -oP "occi.compute.state=\"([a-z]*)\"" | sed 's/occi.compute.state="//' | sed 's/"//'`
			INSTANCE_IP=`echo $INSTANCE_DETAILS | grep -oP "org.fogbowcloud.order.ssh-public-address=\"([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3}):([0-9]{1,5})\"" | sed 's/org.fogbowcloud.order.ssh-public-address="//' | sed 's/"//' | sed 's/:/ -p /'`
			echo "Monitoring instance $INSTANCE_ID ($INSTANCE_IP)"
			if [[ "$INSTANCE_STATE" = "active" && "$INSTANCE_IP" != "null" && "$INSTANCE_IP" != "" ]]; then
				INSTANCE_HAS_IP=true
				echo "Executing SSH command"
				SSH_OUTPUT=`ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_PRIVATEKEY fogbow@$INSTANCE_IP "echo $ORDER_ID > /tmp/$ORDER_ID.output; cat /tmp/$ORDER_ID.output"`
				if [[ "$SSH_OUTPUT" = "$ORDER_ID" ]]; then
					echo "$INSTANCE_ID worked fine"
					DELETE_INSTANCE=`fogbow-cli instance --delete --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $INSTANCE_ID`
					if [[ "$DELETE_INSTANCE" = "Ok" ]]; then
						echo "$INSTANCE_ID deleted."
						DELETE_ORDER=`fogbow-cli order --delete --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $ORDER_ID`
						if [[ "$DELETE_ORDER" = "Ok" ]]; then
							echo "$ORDER_ID deleted."
						fi
					fi
				else
					echo "Unexpected SSH output"
				fi
			fi
			if [[ "$INSTANCE_HAS_IP" = false ]]; then
				echo "Still waiting for the instance IP. Trying again after $INSTANCE_IP_TIMEOUT seconds."
				sleep $INSTANCE_IP_TIMEOUT
			fi
			let RETRIES=RETRIES-1
		done
	fi;
done;
