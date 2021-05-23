#!/bin/bash

SYNC_WINDOW=10
# 2700 sec = 45 min
MIN_UPTIME=2700
# telegram bot token
TG_TOKEN=$1
# telegram user ID
TG_CHAT_ID=$2
CONTAINER_NAME=$3
if [[ ${CONTAINER_NAME} == "" ]]
  then
    CONTAINER_NAME="mina"
fi


GREEN="\e[92m"
RED="\e[91m"
NORMAL="\e[39m"

EXPLORER_HEIGTH=$(curl -s https://api.minaexplorer.com/summary | jq -r .blockchainLength)
STATUS_DATA=$(docker exec mina mina client status --json | grep -v "Using password from")
LOCAL_HEIGHT=$(jq .highest_unvalidated_block_length_received <<< $STATUS_DATA)
UPTIME=$(jq .uptime_secs <<< $STATUS_DATA)
SYNC_STATUS=$(jq .sync_status <<< $STATUS_DATA)


echo -e "\n-------------------------"
echo -e $(date)
echo -e "Local/Explorer: ${LOCAL_HEIGHT}\\${EXPLORER_HEIGTH}"       
echo -e "Uptime: ${UPTIME} | Status: ${SYNC_STATUS}"   

if [[ $(bc -l <<< "${EXPLORER_HEIGTH} - ${LOCAL_HEIGHT}") -gt ${SYNC_WINDOW} ]] && [[ ${UPTIME} -gt ${MIN_UPTIME} ]]
  then
    echo -e ${RED}"ALARM! ${CONTAINER_NAME} node on ${HOSTNAME} is out of sync"${NORMAL}
    MSG=$(echo -e "${CONTAINER_NAME} node on ${HOSTNAME} is out of sync\nLocal/Explorer: ${LOCAL_HEIGHT}\\${EXPLORER_HEIGTH}\nUptime: ${UPTIME} | Status: ${SYNC_STATUS}")
    
    if [[ $TG_TOKEN != "" ]]
      then
        curl -s -H 'Content-Type: application/json' --request 'POST' -d "{\"chat_id\":\"${TG_CHAT_ID}\",\"text\":\"${MSG}\"}" "https://api.telegram.org/bot${TG_TOKEN}/sendMessage"
    fi
    
    # restart container
    docker restart ${CONTAINER_NAME}
  else
    echo -e ${GREEN}"Node is synced: ${SYNC_STATUS}"${NORMAL}
fi
