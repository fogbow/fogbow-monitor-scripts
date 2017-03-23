#!/ bin/bash

USER_LOGIN="fogbow"
USER_PASS="nc3SRPS2"
## LDAP Public Key to generate LDAP token
LDAP_PUBLIC_KEY="/home/chicog/testes/keys/public_key.pem"
## LDAP Private Key to generate LDAP token
LDAP_PRIVATE_KEY="/home/chicog/testes/keys/private_key.pem"

# LDAP url
# example : ldap://ldap.example.com:389
LDAP_URL="ldap://ldap.lsd.ufcg.edu.br:389"
# LDAP BASE
# example : dc=DC,dc=DC,dc=DC,dc=DC
LDAP_BASE="dc=lsd,dc=ufcg,dc=edu,dc=br"