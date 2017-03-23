#!/bin/bash

function createDatabase {
	echo "Creating database..."
}

function initDatabase {
	# Setting password to access db
	file="$HOME/.pgpass"
	if [ -f "$file" ]
	then
	echo "Replacing $file now."
	rm -f $file
	else
	echo "$file not found. Creating one now"
	fi

	# Writing password in .pgpass and changing permissions
	echo "$DATABASE_IP:$DATABASE_PORT:$DATABASE_NAME:$DATABASE_USER:$DATABASE_PASSWORD" >> $file
	chmod 0600 "$file"
}

## for test ##
DIRNAME=`dirname $0`
source "$DIRNAME/settings.sh"

initDatabase