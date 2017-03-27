#!/bin/bash
DIRNAME=`dirname $0`
PATH_PYTHON_SCRIP=$DIRNAME"/cachet"

CONST_GROUP_COMPONENT_PREFIX="gc_"
CONST_COMPONENT_PREFIX="c_"
CONST_COMPUTE_PREFIX="compute_"
CONST_STORAGE_PREFIX="storage_"
CONST_NETWORK_PREFIX="network_"
CONST_COMPONENT_OPERATIONAL="1"
CONST_COMPONENT_MAJOR_OUTAGE="4"

function normalizeGroupComponentName {
  MANAGER_TO_NORMALIZE=$1  
  echo "$CONST_GROUP_COMPONENT_PREFIX""$MANAGER_TO_NORMALIZE"
}

function normalizeComponentName {
  MANAGER_TO_NORMALIZE=$1  
  PREFIX_TYPE=$2
  echo "$PREFIX_TYPE""$MANAGER_TO_NORMALIZE"
}

function getCachetGroupComponentIdByManager {
  GC_JSON_STR=`getCachetGroupComponent`
  GC_MANAGER=`normalizeGroupComponentName $MANAGER`
  echo `python $PATH_PYTHON_SCRIP/get-group-component-id.py "$GC_JSON_STR" "$GC_MANAGER"`
}

function getCachetGroupComponent {
	echo `curl --request GET --url http://$CACHET_IP/api/v1/components/groups`
}

function createCachetGroupComponent {	
  MANAGER=$1
	GROUP_COMPONENTE_NAME=`normalizeGroupComponentName $MANAGER`

	echo "Creating group component: "$GROUP_COMPONENTE_NAME
	if [[ `getCachetGroupComponent` == *$GROUP_COMPONENTE_NAME* ]]; then
		echo "Group components (" $GROUP_COMPONENTE_NAME ") already exists."
	else
    echo "Executing command to create cachet group component: curl --request POST --url http://$CACHET_IP/api/v1/components/groups --data \"name=$GROUP_COMPONENTE_NAME\" -H \"X-Cachet-Token: $CACHET_APP_KEY\""
		CREATE_G_C_RESULT=`curl --request POST --url http://$CACHET_IP/api/v1/components/groups --data "name=$GROUP_COMPONENTE_NAME" -H "X-Cachet-Token: $CACHET_APP_KEY"`
    echoResponse "$CREATE_G_C_RESULT"
	fi
}

function getCachetComponentIdByManager {
  COMPONENT_JSON_STR=`getCachetComponents`
  MANAGER=$1
  PREFIX_TYPE=$2
  COMPONENT_MANAGER=`normalizeComponentName $MANAGER $PREFIX_TYPE`
  echo `python $PATH_PYTHON_SCRIP/get-component-id.py "$COMPONENT_JSON_STR" "$COMPONENT_MANAGER"`
}

function getCachetComponents {
  echo `curl --request GET --url http://$CACHET_IP/api/v1/components`
}

function createCachetComponent {
  MANAGER=$1
  COMPONENTE_NAME_PREFIX=$2
  GROUP_ID=`getCachetGroupComponentIdByManager $MANAGER`
  COMPONENTE_NAME="$COMPONENTE_NAME_PREFIX""$MANAGER"

  echo "Creating component: "$COMPONENTE_NAME
  if [[ `getCachetComponents` == *"$COMPONENTE_NAME"* ]]; then
    echo "Components (" $COMPONENTE_NAME ") already exists."
  else 
    echo "Executing command to create cachet component: curl --request POST --url http://$CACHET_IP/api/v1/components --data \"name=$COMPONENTE_NAME&status=1&group_id=$GROUP_ID\" -H \"X-Cachet-Token: $CACHET_APP_KEY\""
    CREATE_C_RESULT=`curl --request POST --url http://$CACHET_IP/api/v1/components --data "name=$COMPONENTE_NAME&status=1&group_id=$GROUP_ID" -H "X-Cachet-Token: $CACHET_APP_KEY"`
    echoResponse "$CREATE_C_RESULT"
  fi
}

function echoResponse {
  RESPONSE=$1
  if [[ -n "$RESPONSE" && $RESPONSE != *"errors"* ]]; then
    echo "Response Ok :"$RESPONSE 
  else
    echo "Error: "$RESPONSE
  fi
}

## TODO complete
function updateCachetComponent {
  MANAGER=$1
  PREFIX_TYPE=$2
  STATUS=$3  
  COMPONENT_ID=`getCachetComponentIdByManager $MANAGER $PREFIX_TYPE`
  UPDATE_C_RESULT=`echo | curl --request PUT --url http://$CACHET_IP/api/v1/components/1 --data 'status=$STATUS' -H "X-Cachet-Token: $CACHET_APP_KEY"`  

  echoResponse "$UPDATE_C_RESULT"
}

function createCachetIncident {
  NAME_INCIDENT="$1"
  MESSAGE_INCIDENT="$2"
  STATUS_INCIDENT=$3
  COMPONENTE_ID_INCIDENT=$4
  COMPONENTE_STATUS_INCIDENT="$5"
  COMMAND="url --request POST --url http://$CACHET_IP/api/v1/incidents --data \"name=$NAME_INCIDENT&message=$MESSAGE_INCIDENT&status=$STATUS_INCIDENT&visible=1&component_id=$COMPONENTE_ID_INCIDENT&component_status=$COMPONENTE_STATUS_INCIDENT\" -H \"X-Cachet-Token:$CACHET_APP_KEY\""
  echo "Executing command to create cachet incident: "$COMMAND
  CREATE_INCIDENT_RESULT=`curl --request POST --url http://$CACHET_IP/api/v1/incidents --data "name=$NAME_INCIDENT&message=$MESSAGE_INCIDENT&status=$STATUS_INCIDENT&visible=1&component_id=$COMPONENTE_ID_INCIDENT&component_status=$COMPONENTE_STATUS_INCIDENT" -H "X-Cachet-Token:$CACHET_APP_KEY"`

  echoResponse "$CREATE_INCIDENT_RESULT"
}

function getCachetMetricIdByManager {
  echo
}

function getCachetMetrics {
  echo 
}

function createCachetMetrics {
  echo
}
