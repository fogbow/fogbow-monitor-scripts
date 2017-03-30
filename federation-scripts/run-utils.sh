#!/bin/bash

function execGarbageCollector {
	echo "Starting garbaeCollector"

	GET_ATTACHMENT_COMMAND="$FOGBOW_CLI_PATH attachment --get --url $MANAGER_URL --auth-token $MANAGER_TOKEN"
	FOGBOW_GET_ATTACHMENT_RESPONSE=`$GET_ATTACHMENT_COMMAND`
	echo "Get attachments result: "$FOGBOW_GET_ORDERS_RESPONSE

	RESULT=""
	for LINE in $FOGBOW_GET_ATTACHMENT_RESPONSE; do 
		if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
			ATTACHMENT_ID=`getAttachmentIdByLocationLineCreateSintax $LINE`

			DATE=`date`
			echo "$DATE - Deleting attachment : $ATTACHMENT_ID"
			RESULT=`$FOGBOW_CLI_PATH attachment --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id $ATTACHMENT_ID`
			echo "Result: "$RESULT
		fi;
	done;

	GET_ORDERS_COMMAND="$FOGBOW_CLI_PATH order --get --url $MANAGER_URL --auth-token $MANAGER_TOKEN"
	FOGBOW_GET_ORDERS_RESPONSE=`$GET_ORDERS_COMMAND`
	echo "Get orders result: "$FOGBOW_GET_ORDERS_RESPONSE

	for LINE in $FOGBOW_GET_ORDERS_RESPONSE; do 
		if [[ "$LINE" != "X-OCCI-Location:" ]]; then 
			ORDER_ID=`getOrderIdByLocationLine $LINE`
			GET_ORDER_COMMAND="$FOGBOW_CLI_PATH order --get --url $MANAGER_URL --auth-token $MANAGER_TOKEN --id $ORDER_ID"
			echo "Execution create order command: "$GET_ORDER_COMMAND
			ORDER_DETAILS=`$GET_ORDER_COMMAND`

			RESOURCE_KIND=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.resource-kind=\"(.*)\"" | sed 's/org.fogbowcloud.order.resource-kind="//' | sed 's/"//'`
			INSTANCE_ID=`echo $ORDER_DETAILS | grep -oP "org.fogbowcloud.order.instance-id=\"(.*)\"" | sed 's/org.fogbowcloud.order.instance-id="//' | sed 's/"//'`

			DATE=`date`
			echo "$DATE - Deleting compute order : $ORDER_ID"
			$FOGBOW_CLI_PATH order --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id $ORDER_ID
			DATE=`date`		
			RESULT=""
			if [[ "$RESOURCE_KIND" == "compute"* ]]; then 
				echo "$DATE - Deleting compute : $INSTANCE_ID"
				RESULT=`$FOGBOW_CLI_PATH instance --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id $INSTANCE_ID`
				echo "Result: $RESULT"
			elif [[ "$RESOURCE_KIND" == "network"* ]]; then
				echo "$DATE - Deleting network : $INSTANCE_ID"
				RESULT=`$FOGBOW_CLI_PATH network --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id $INSTANCE_ID`
				echo "Result: $RESULT"
			elif [[ "$RESOURCE_KIND" == "storage"* ]]; then
				echo "$DATE - Deleting storage : $INSTANCE_ID"
				RESULT=`$FOGBOW_CLI_PATH storage --delete --url "$MANAGER_URL" --auth-token "$MANAGER_TOKEN" --id $INSTANCE_ID`
				echo "Result: $RESULT"
			else
				echo "Irregular Sintax"
			fi
		fi;
	done;	
}

function getOrderIdByLocationLine {
	CONST_ORDER_LENGHT=36
	LINE_VALUE=$1

	LENGHT_LINE=${#LINE_VALUE}
	INIT_LINE_REPLACE=$(( $LENGHT_LINE - $CONST_ORDER_LENGHT))
	REPLACED_ORDER_ID=${LINE_VALUE:INIT_LINE_REPLACE:CONST_ORDER_LENGHT}
	echo $REPLACED_ORDER_ID
}

function getAttachmentIdByLocationLine {
	LINE_VALUE=$1

	X_OCCI_NAME="X-OCCI-Location: "
	INIT_LINE_REPLACE=${#X_OCCI_NAME}
	REPLACED_ORDER_ID=${LINE_VALUE:INIT_LINE_REPLACE}
	echo $REPLACED_ORDER_ID
}

function getAttachmentIdByLocationLineCreateSintax {
	LINE_VALUE=$1

	POINT_TO_CUT="link/"
	TO_REPLACE_EXTRA="link//"
	VALUE_CUT=`echo $LINE_VALUE | grep -o "$POINT_TO_CUT.*"`
	REPLACED="${VALUE_CUT/$TO_REPLACE_EXTRA/""}"
	REPLACED="${REPLACED/$POINT_TO_CUT/""}"
	echo $REPLACED
}

getAttachmentIdByLocationLineCreateSintax "http://10.11.4.234:8182/storage/link/7938d3d9-a7ad-44ae-89ec-e23277ee2c61@lsd.manager.naf.lsd.ufcg.edu.br"