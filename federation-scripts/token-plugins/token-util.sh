#!/bin/bash
DIRNAME=`dirname $0`
TOKEN_PLUGINS_PATH=$DIRNAME"/token-plugins"

function getToken {
	TOKEN="Invalid token."
    if [[ "$TOKEN_PLUGIN" -eq "ldap" ]]; then
       TOKEN=$(source "$TOKEN_PLUGINS_PATH/ldap-plugin.sh")
    elif [[ "$TOKEN_PLUGIN" -eq "raw-token" ]]; then
       TOKEN=$(source "$TOKEN_PLUGINS_PATH/raw-token-plugin.sh")
    else 
	   echo "Invalid token plugin."
    fi

    echo $TOKEN
}
