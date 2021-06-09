#!/bin/bash

LOG_PERIOD_MIN=40
LOG_NAME="mina_log.txt"
SYNC_WINDOW=3
# 2700 sec = 45 min
MIN_UPTIME=3000
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
MAX_UNVALIDATED_BLOCK=$(jq .highest_unvalidated_block_length_received <<< $STATUS_DATA)
LOCAL_HEIGHT=$(jq .blockchain_length <<< $STATUS_DATA)
UPTIME=$(jq .uptime_secs <<< $STATUS_DATA)
SYNC_STATUS=$(jq .sync_status <<< $STATUS_DATA)


send_message() {
  if [[ ${TG_TOKEN} != "" ]]; then
    local tg_msg="$@"
    curl -s -H 'Content-Type: application/json' --request 'POST' -d "{\"chat_id\":\"${TG_CHAT_ID}\",\"text\":\"${tg_msg}\"}" "https://api.telegram.org/bot${TG_TOKEN}/sendMessage"
  fi
}


send_file() {
  if [[ ${TG_TOKEN} != "" ]]; then
    local file_to_send="$@"
    curl -F document=@"${file_to_send}" https://api.telegram.org/bot${TG_TOKEN}/sendDocument?chat_id=${TG_CHAT_ID}
  fi
}


echo -e "\n-------------------------"
echo -e $(date)
echo -e "LOCAL_HEIGHT/MAX_UNVALIDATED_HEIGHT: ${LOCAL_HEIGHT}\\${MAX_UNVALIDATED_BLOCK}"       
echo -e "Uptime: ${UPTIME} | Status: ${SYNC_STATUS}"   

if [[ $(bc -l <<< "${MAX_UNVALIDATED_BLOCK} - ${LOCAL_HEIGHT}") -gt ${SYNC_WINDOW} ]] && [[ ${UPTIME} -gt ${MIN_UPTIME} ]]; then
  echo -e ${RED}"$(date -u) ALARM! ${CONTAINER_NAME} node on ${HOSTNAME} is out of sync"${NORMAL}
  MSG=$(echo -e "$(date -u) ${CONTAINER_NAME} node on ${HOSTNAME} LOCAL_HEIGHT: ${LOCAL_HEIGHT}\nMAX_UNVALIDATED_BLOCK: ${MAX_UNVALIDATED_BLOCK}")
  # export logs
  docker logs ${CONTAINER_NAME} --since "${LOG_PERIOD_MIN}m" > ${LOG_NAME}
  send_message ${MSG}
  # send log file
  send_file ${LOG_NAME}
  # restart container
  docker restart ${CONTAINER_NAME}
    
elif [[ ${SYNC_STATUS} != "Synced" ]] && [[ ${UPTIME} -gt ${MIN_UPTIME} ]]; then
  echo -e ${RED}"$(date -u) ALARM! ${CONTAINER_NAME} node status on ${HOSTNAME} is not synced: ${SYNC_STATUS}"${NORMAL}
  MSG=$(echo -e "$(date -u) ${CONTAINER_NAME} node status on ${HOSTNAME} is not synced: ${SYNC_STATUS}")
  docker exec ${CONTAINER_NAME} mina client status > status.txt
  send_message ${MSG}
  send_file "status.txt"

elif [[ $(bc -l <<< "${MAX_UNVALIDATED_BLOCK} - ${EXPLORER_HEIGTH}") -gt ${SYNC_WINDOW} ]] && [[ ${UPTIME} -gt ${MIN_UPTIME} ]]; then
  echo -e ${RED}"$(date -u) ALARM! ${CONTAINER_NAME} ${HOSTNAME} EXPLORER_HEIGHT: ${EXPLORER_HEIGTH}\nLOCAL_HEIGHT: ${LOCAL_HEIGHT}"${NORMAL}
  MSG=$(echo -e "$(date -u) ${CONTAINER_NAME} ${HOSTNAME} EXPLORER_HEIGHT: ${EXPLORER_HEIGTH}\nLOCAL_HEIGHT: ${LOCAL_HEIGHT}")
  send_message $MSG
fi
