#!/bin/bash
# API from LaPoste https://developer.laposte.fr/products/suivi/latest
API="API_KEY_GOES_HERE"
IP="IP_ADDRESS_OF_YOUR_SERVER"
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
URL="https://api.laposte.fr/suivi/v2/idships/"

#Removing comment in list package file
cat $COLIS|grep -v "#" > $WORK

while read PKG; do
	#Getting package number
	CODE=$(echo $PKG|awk -F";" '{print $1}')
	#Getting package comment
	COMMENT=$(echo $PKG|awk -F";" '{print $2}')

	#Requesting API url
	curl -s -H "${URLAPI}" -H "X-Forwarded-For: ${IP}" ${URL}${CODE} > $TMP/$CODE.json
	RETURN=$(cat $TMP/$CODE.json|jq .returnCode|sed 's/"//g')
	case ${RETURN} in
		400)
			#echo "Numero invalide (ne respecte pas la syntaxe definie)"
			$PATHDIR/send_telegram.sh "${CODE} : 400 - Numero invalide (ne respecte pas la syntaxe definie)"
			exit 1
			;;
		401)
			#echo "Non-autorise (absence de la cle Okapi)"
			$PATHDIR/send_telegram.sh "401 - Non-autorise (absence de la cle Okapi)"
			exit 1
			;;
		404)
			#echo "Ressource non trouvee"
			$PATHDIR/send_telegram.sh "404 - Ressource non trouvee"
			exit 1
			;;
		500)
			#echo "Erreur systeme (message non generee par l'application)"
			$PATHDIR/send_telegram.sh "500 - Erreur systeme (message non generee par l'application)"
			exit 1
			;;
		504)
			#echo "Service indisponible (erreur technique sur service tiers)"
			$PATHDIR/send_telegram.sh "504 - Service indisponible (erreur technique sur service tiers)"
			exit 1
			;;
		200)
			echo "OK"
			;;
		207)
			echo "OK";
			;;
		*)
			echo "Code retour ${RETURN} inconnu"
			$PATHDIR/send_telegram.sh "${RETURN} - Code retour inconnu"
			exit 1
			;;
		esac

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
