#!/ bin/bash

# ------------------ #
# Plugin name: ldap
# ------------------ #
DIRNAME=`dirname $0`

source $DIRNAME"/token-plugins/ldap-plugin-settings.sh"

## Creating LDAP token
LDAP_TOKEN=`$FOGBOW_CLI_PATH token --create --type ldap -Dusername=$USER_LOGIN -Dpassword=$USER_PASS -DauthUrl=$LDAP_URL -Dbase=$LDAP_BASE -DprivateKey=$LDAP_PRIVATE_KEY -DpublicKey=$LDAP_PUBLIC_KEY`

echo $LDAP_TOKEN
