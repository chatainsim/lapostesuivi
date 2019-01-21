#!/bin/bash
# API from LaPoste https://developer.laposte.fr/products/suivi/latest
API=""

#Nothng else to edit below

#Define path
PATHDIR=$(dirname $0)
ME=$(basename $0)
TMP="$PATHDIR/tmp"
DATA="$PATHDIR/data"

#Files with package number and comment
COLIS="$PATHDIR/list_colis.cfg"
#Temporary working files
WORK="$PATHDIR/list_colis.cfg.work"

#Checking if directory exist
if [ ! -d $TMP ]; then
	mkdir $TMP
fi
if [ ! -d $DATA ]; then
        mkdir $DATA
fi

#API auth Header for curl
URLAPI="X-Okapi-Key: $API"
#API url
URL="https://api.laposte.fr/suivi/v1/"

#Removing comment in list package file
cat $COLIS|grep -v "#" > $WORK

while read PKG; do
	#Getting package number
	CODE=$(echo $PKG|awk -F";" '{print $1}')
	#Getting package comment
	COMMENT=$(echo $PKG|awk -F";" '{print $2}')

	#Requesting API url
	curl -s -H "$URLAPI" ${URL}${CODE} > $TMP/$CODE.json

	CHECK=$(cat $TMP/$CODE.json|jq .code|sed 's/"//g')
	STATUS=$(cat $TMP/$CODE.json |jq .status|sed 's/"//g')
	#If checking package number for the first time
	if [ ! -f $DATA/$CODE.json ]; then
		#If package number is unknown for now
		if [ "$CHECK" == "RESOURCE_NOT_FOUND" ]; then
               		MSG=$(cat $TMP/$CODE.json|jq .message|sed 's/"//g')
               		$PATHDIR/send_telegram.sh "$MSG - $CODE - $COMMENT"
			cp $TMP/$CODE.json $DATA/$CODE.json
       		else
			cp $TMP/$CODE.json $DATA/$CODE.json
			DATE=$(cat $TMP/$CODE.json|jq .date|sed 's/"//g')
		        MSG=$(cat $TMP/$CODE.json|jq .message|sed 's/"//g')
	        	LINK=$(cat $TMP/$CODE.json|jq .link|sed 's/"//g')
			if [ "$STATUS" != "INCONNU" ]; then
				$PATHDIR/send_telegram.sh "$DATE - $COMMENT - $MSG - $LINK"
			fi
		fi
	else
		#checking difference between old tracking message and the last one
		diff $TMP/$CODE.json $DATA/$CODE.json > /dev/null 2>&1
                if [ $? -eq 1 ]; then
			cp $TMP/$CODE.json $DATA/$CODE.json
			DATE=$(cat $TMP/$CODE.json|jq .date|sed 's/"//g')
			MSG=$(cat $TMP/$CODE.json|jq .message|sed 's/"//g')
			LINK=$(cat $TMP/$CODE.json|jq .link|sed 's/"//g')
			STATUS=$(cat $TMP/$CODE.json|jq .status|sed 's/"//g')
			if [ "$STATUS" != "INCONNU" ]; then
				$PATHDIR/send_telegram.sh "$DATE - $COMMENT - $MSG - $LINK"
			fi
			#If package is set to delivred comment it in file
			if [ "$STATUS" == "LIVRE" ] || [ "$STATUS" == "DISTRIBUE" ]; then
				sed -e "/$CODE/ s/^#*/#/" -i $COLIS
			fi
		fi
	fi
done < $WORK
