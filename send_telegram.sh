#!/bin/bash
#Telegram API key
API=""
#Telegram chat ID
CHATID=""

URL="https://api.telegram.org"

if [ x"$1" == "x" ]; then
	echo "Error, no message"
	exit 0
else
	/usr/bin/curl -s "$URL/bot$API/sendMessage?chat_id=$CHATID&text=$1" > /dev/null 2>&1
fi
