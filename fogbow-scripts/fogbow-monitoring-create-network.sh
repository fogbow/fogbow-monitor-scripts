#!/bin/bash
. settings.sh

echo "====================================================="
echo "Monitoring manager $MANAGER_URL with user $USER_LOGIN"
echo "Testing network"
echo "====================================================="

## Requesting network
## Creating network order
DATE=`date`
echo "$DATE - Creating network with cidr 10.10.10.0/24 ..."
FOGBOW_NETWORK_ORDERS=`fogbow-cli order --create --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --requirements "Glue2CloudComputeManagerID == \"lsd.manager.naf.lsd.ufcg.edu.br\"" --cidr "10.10.10.0/24" --allocation dynamic --gateway "10.10.10.1" --resource-kind network`
NETWORK_ID="null"
NETWORK_ORDER_ID=`echo $FOGBOW_NETWORK_ORDERS | sed 's/X-OCCI-Location: http:\/\/10.11.4.234:8182\/order\///'`
while [[ "$NETWORK_ID" = "null" ]]; do
	DATE=`date`
	echo "$DATE - Checking order status ..."
	ORDER_DETAILS=`fogbow-cli order --get --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $NETWORK_ORDER_ID`
	ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
	NETWORK_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
	DATE=`date`
	echo "$DATE - ORDER ID: $NETWORK_ORDER_ID - Status: $ORDER_STATE - NETWORK_ID: $NETWORK_ID"
	if [[ "$NETWORK_ID" = "null" ]]; then
		echo "Network order still open. Waiting 10 seconds to check again."
		sleep $INSTANCE_IP_TIMEOUT
	fi
done

## order output X-OCCI-Location: http://10.11.4.234:8182/order/IDHERE
## Requesting VM 1
DATE=`date`
echo "$DATE - Creating VM 1 with network $NETWORK_ID"
VM1_ORDER=`fogbow-cli order --create --n 1 --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --requirements "Glue2RAM >= 1024 && Glue2CloudComputeManagerID == \"lsd.manager.naf.lsd.ufcg.edu.br\"" --image fogbow-ubuntu --network $NETWORK_ID --public-key "$SSH_PUBLICKEY" --resource-kind compute`

DATE=`date`
echo "$DATE - Creating VM 2 with network $NETWORK_ID"
VM2_ORDER=`fogbow-cli order --create --n 1 --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --requirements "Glue2RAM >= 1024 && Glue2CloudComputeManagerID == \"lsd.manager.naf.lsd.ufcg.edu.br\"" --image fogbow-ubuntu --network $NETWORK_ID --public-key "$SSH_PUBLICKEY" --resource-kind compute`

DATE=`date`
echo "$DATE - Checking VM 1 with network $NETWORK_ID"
VM1_ORDER_ID=`echo $VM1_ORDER | sed 's/X-OCCI-Location: http:\/\/10.11.4.234:8182\/order\///'`
VM1_ID="null"
VM1_PUBLIC_IP="null"
VM1_PRIVATE_IP="null"
while [[ "$VM1_ID" = "null" ]]; do
	DATE=`date`
	echo "$DATE - Checking status of VM 1 order."
	ORDER_DETAILS=`fogbow-cli order --get --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $VM1_ORDER_ID`
	ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
	VM1_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
	DATE=`date`
	echo "$DATE - ORDER ID: $VM1_ORDER_ID - Status: $ORDER_STATE - VM 1 ID: $VM1_ID"
	if [[ "$VM1_ID" = "null" ]]; then
		echo "VM 1 order still open. Waiting 10 seconds to check again."
		sleep $INSTANCE_IP_TIMEOUT
	else
		while [[ "$VM1_PUBLIC_IP" = "null" || "$VM1_PUBLIC_IP" = "" ]]; do
			DATE=`date`
			echo "$DATE - Waiting for VM 1 public and private IP"
			VM1_DETAILS=`fogbow-cli instance --get --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $VM1_ID`
			VM1_PUBLIC_IP=`echo $VM1_DETAILS | grep -oP "org.fogbowcloud.order.ssh-public-address=\"([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3}):([0-9]{1,5})\"" | sed 's/org.fogbowcloud.order.ssh-public-address="//' | sed 's/"//' | sed 's/:/ -p /'`
			VM1_PRIVATE_IP=`echo $VM1_DETAILS | grep -oP "org.fogbowcloud.order.local-ip-address=\"([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\"" | sed 's/org.fogbowcloud.order.local-ip-address="//' | sed 's/"//' | sed 's/:/ -p /'`
			DATE=`date`
			echo "$DATE - VM 1 - Public IP: $VM1_PUBLIC_IP - Private IP: $VM1_PRIVATE_IP"
			if [[ "$VM1_PUBLIC_IP" = "null" || "$VM1_PUBLIC_IP" = "" ]]; then
				sleep $INSTANCE_IP_TIMEOUT
			fi
		done
	fi
done


## Checking VM 2
DATE=`date`
echo "$DATE - Checking VM 2 with network $NETWORK_ID"
VM2_ORDER_ID=`echo $VM2_ORDER | sed 's/X-OCCI-Location: http:\/\/10.11.4.234:8182\/order\///'`
VM2_ID="null"
VM2_PUBLIC_IP="null"
VM2_PRIVATE_IP="null"
while [[ "$VM2_ID" = "null" ]]; do
	DATE=`date`
	echo "$DATE - Checking status of VM 2 order."
	ORDER_DETAILS=`fogbow-cli order --get --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $VM2_ORDER_ID`
	ORDER_STATE=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.state=\"([a-z]*)\"" | sed 's/org.fogbowcloud.order.state="//' | sed 's/"//'`
	VM2_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`
	DATE=`date`
	echo "$DATE - ORDER ID: $VM2_ORDER_ID - Status: $ORDER_STATE - VM 2 ID: $VM2_ID"
	if [[ "$VM2_ID" = "null" ]]; then
		echo "VM 2 order still open. Waiting 10 seconds to check again."
		sleep $INSTANCE_IP_TIMEOUT
	else
		while [[ "$VM2_PUBLIC_IP" = "null" || "$VM2_PUBLIC_IP" = "" ]]; do
			DATE=`date`
			echo "$DATE - Waiting for VM 2 public and private IP"
			VM2_DETAILS=`fogbow-cli instance --get --url "$MANAGER_URL" --auth-token $LDAP_TOKEN --id $VM2_ID`
			VM2_PUBLIC_IP=`echo $VM2_DETAILS | grep -oP "org.fogbowcloud.order.ssh-public-address=\"([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3}):([0-9]{1,5})\"" | sed 's/org.fogbowcloud.order.ssh-public-address="//' | sed 's/"//' | sed 's/:/ -p /'`
			VM2_PRIVATE_IP=`echo $VM2_DETAILS | grep -oP "org.fogbowcloud.order.local-ip-address=\"([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\"" | sed 's/org.fogbowcloud.order.local-ip-address="//' | sed 's/"//' | sed 's/:/ -p /'`
			DATE=`date`
			echo "$DATE - VM 2 - Public IP: $VM2_PUBLIC_IP - Private IP: $VM2_PRIVATE_IP"
			if [[ "$VM2_PUBLIC_IP" = "null" || "$VM2_PUBLIC_IP" = "" ]]; then
				sleep $INSTANCE_IP_TIMEOUT
			fi
		done
	fi
done

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
	echo "$DATE - Could not connect using telnet, something is wrong with network on fogbow."
fi

DATE=`date`
echo "$DATE - Deleting compute orders"
fogbow-cli order --delete --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --id $VM1_ORDER_ID
fogbow-cli order --delete --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --id $VM2_ORDER_ID

DATE=`date`
echo "$DATE - Deleting instances"
fogbow-cli instance --delete --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --id $VM1_ID
fogbow-cli instance --delete --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --id $VM2_ID

DATE=`date`
echo "$DATE - Deleting network order"
fogbow-cli order --delete --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --id $NETWORK_ORDER_ID

DATE=`date`
echo "$DATE - Deleting network"
fogbow-cli network --delete --url "$MANAGER_URL" --auth-token "$LDAP_TOKEN" --id $NETWORK_ID