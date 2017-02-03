#!/bin/bash
DIRNAME=`dirname $0`
. "$DIRNAME/settings.sh"

echo "====================================================="
echo "Monitoring manager $MANAGER_URL with user $USER_LOGIN"
echo "Testing storage"
echo "====================================================="

## Requesting VM
DATE=`date`
echo "$DATE - Creating the compute order"
FOGBOW_ORDERS=`fogbow-cli order --create --n 1 --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --requirements "Glue2RAM >= 1024 && Glue2CloudComputeManagerID == \"lsd.manager.naf.lsd.ufcg.edu.br\"" --image fogbow-ubuntu --public-key "$SSH_PUBLICKEY" --resource-kind compute`

## Requesting storage
## Creating storage order
DATE=`date`
echo "$DATE - Creating storage disk with 3GB ..."
FOGBOW_STORAGE_ORDERS=`fogbow-cli order --create --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --requirements "Glue2CloudComputeManagerID == \"lsd.manager.naf.lsd.ufcg.edu.br\"" --size 3 --resource-kind storage`
STORAGE_ID="null"
STORAGE_ORDER_ID="null"
while [[ "$STORAGE_ID" = "null" ]]; do
	DATE=`date`
	echo "$DATE - Checking order status ..."
	for LINE in $FOGBOW_STORAGE_ORDERS; do 
		if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
			STORAGE_ORDER_ID=`echo $LINE | sed 's/http:\/\/10.11.4.234:8182\/order\///'`
			ORDER_DETAILS=`fogbow-cli order --get --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $STORAGE_ORDER_ID`
			ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
			STORAGE_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
			DATE=`date`
			echo "$DATE - ORDER ID: $STORAGE_ORDER_ID - Status: $ORDER_STATE - STORAGE_ID: $STORAGE_ID"
			if [[ "$STORAGE_ID" = "null" ]]; then
				echo "Storage order still open. Waiting 10 seconds to check again."
				sleep $INSTANCE_IP_TIMEOUT
			fi
		fi;
	done;
done

COMPUTE_ORDER_ID="null"
COMPUTE_ID="null"
COMPUTE_IP="null"

while [[ "$COMPUTE_ID" = "null" ]]; do
	DATE=`date`
	echo "$DATE - Checking order status ..."
	for LINE in $FOGBOW_ORDERS; do 
		if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
			COMPUTE_ORDER_ID=`echo $LINE | sed 's/http:\/\/10.11.4.234:8182\/order\///'`
			ORDER_DETAILS=`fogbow-cli order --get --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $COMPUTE_ORDER_ID`
			ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
			COMPUTE_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
			DATE=`date`
			echo "$DATE - ORDER ID: $COMPUTE_ORDER_ID - Status: $ORDER_STATE - COMPUTE_ID: $COMPUTE_ID"
			if [[ "$COMPUTE_ID" = "null" ]]; then
				echo "Compute order still open. Waiting 10 seconds to check again."
				sleep $INSTANCE_IP_TIMEOUT
			else
				INSTANCE_HAS_IP=false
				while [[ "$INSTANCE_HAS_IP" = false ]]; do 
					DATE=`date`
					echo "$DATE - Trying to get instance $INSTANCE_ID IP"
					INSTANCE_DETAILS=`fogbow-cli instance --get --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $COMPUTE_ID`
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
						ATTACH_DISK=`fogbow-cli attachment --create --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --computeId $COMPUTE_ID --storageId $STORAGE_ID`
						while [[ "$CURRENT_DISKS_NUMBER" -lt "$EXPECTED_DISKS_NUMBER" ]]; do
							DATE=`date`
							echo "$DATE - Checking number of disks. Before check: Expected: $EXPECTED_DISKS_NUMBER Current: $CURRENT_DISKS_NUMBER"
							CURRENT_DISKS_NUMBER=`ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_PRIVATEKEY fogbow@$INSTANCE_IP "sudo fdisk -l | grep \"Disk /dev\" | wc -l"`
							DATE=`date`
							echo "$DATE - Checking number of disks. After check: Expected: $EXPECTED_DISKS_NUMBER Current: $CURRENT_DISKS_NUMBER"
							if [[ "$CURRENT_DISKS_NUMBER" != "$EXPECTED_DISKS_NUMBER" ]]; then
								sleep $INSTANCE_IP_TIMEOUT
							fi
						done

						for LINE in $ATTACH_DISK; do 
							if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
								ATTACHMENT_ID=`echo $LINE | sed 's/http:\/\/10.11.4.234:8182\/storage\/link\/\///'`
								DATE=`date`
								echo "$DATE - Deleting attachment with ID $ATTACHMENT_ID"
								DELETE_ATTACHMENT=`fogbow-cli attachment --delete --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $ATTACHMENT_ID`
							fi;
						done;

						while [[ "$CURRENT_DISKS_NUMBER" -gt "$INITIAL_DISKS_NUMBER" ]]; do
							DATE=`date`
							echo "$DATE - Checking number of disks. Before check: Expected: $INITIAL_DISKS_NUMBER Current: $CURRENT_DISKS_NUMBER"
							CURRENT_DISKS_NUMBER=`ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_PRIVATEKEY fogbow@$INSTANCE_IP "sudo fdisk -l | grep \"Disk /dev\" | wc -l"`
							DATE=`date`
							echo "$DATE - Checking number of disks. After check: Expected: $INITIAL_DISKS_NUMBER Current: $CURRENT_DISKS_NUMBER"
							if [[ "$CURRENT_DISKS_NUMBER" != "$INITIAL_DISKS_NUMBER" ]]; then
								sleep $INSTANCE_IP_TIMEOUT
							fi
						done

						DATE=`date`
						echo "$DATE - $COMPUTE_ID is up, now deleting it"
						DELETE_INSTANCE=`fogbow-cli instance --delete --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $COMPUTE_ID`
						echo "Delete instance output: $DELETE_INSTANCE"
						if [[ "$DELETE_INSTANCE" = "Ok" ]]; then
							DATE=`date`
							echo "$DATE - $COMPUTE_ID deleted."
							DELETE_ORDER=`fogbow-cli order --delete --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $COMPUTE_ORDER_ID`
							echo "Delete order output: $DELETE_ORDER"
							if [[ "$DELETE_ORDER" = "Ok" ]]; then
								DATE=`date`
								echo "$DATE - $COMPUTE_ORDER_ID deleted."
							fi
						fi

						DATE=`date`
						echo "$DATE - $STORAGE_ID is available, now deleting it"
						DELETE_INSTANCE=`fogbow-cli storage --delete --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $STORAGE_ID`
						echo "Delete storage output: $DELETE_INSTANCE"
						if [[ "$DELETE_INSTANCE" = "Ok" ]]; then
							DATE=`date`
							echo "$DATE - $STORAGE_ID deleted."
							DELETE_ORDER=`fogbow-cli order --delete --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $STORAGE_ORDER_ID`
							echo "Delete order output: $DELETE_ORDER"
							if [[ "$DELETE_ORDER" = "Ok" ]]; then
								DATE=`date`
								echo "$DATE - $STORAGE_ORDER_ID deleted."
							fi
						fi
					fi
					if [[ "$INSTANCE_HAS_IP" = false ]]; then
						DATE=`date`
						echo "$DATE - Still waiting for the instance IP. Trying again after $INSTANCE_IP_TIMEOUT seconds."
						sleep $INSTANCE_IP_TIMEOUT
					fi
				done
			fi
		fi;
	done;
done
