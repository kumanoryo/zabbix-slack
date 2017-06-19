#!/bin/bash -x
# shellcheck disable=SC1091

# config
channel="$1"
title="$2"
params="$3"

SCRIPTS_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1

# shellcheck source=${SCRIPTS_DIR}/slack.conf.example
. "${SCRIPTS_DIR}/slack.conf" || exit 1

# create CHART_BASEDIR
if [ ! -d "${CHART_BASEDIR}" ]
then
    mkdir "${CHART_BASEDIR}"
fi

# set params
host=$(echo "${params}" | grep 'HOST: ' | awk -F'HOST: ' '{print $2}' | sed -e 's///g')
trigger_name=$(echo "${params}" | grep 'TRIGGER_NAME: ' | awk -F'TRIGGER_NAME: ' '{print $2}' | sed -e 's///g')
trigger_status=$(echo "${params}" | grep 'TRIGGER_STATUS: ' | awk -F'TRIGGER_STATUS: ' '{print $2}' | sed -e 's///g')
trigger_severity=$(echo "${params}" | grep 'TRIGGER_SEVERITY: ' | awk -F'TRIGGER_SEVERITY: ' '{print $2}' | sed -e 's///g')
trigger_url=$(echo "${params}" | grep 'TRIGGER_URL: ' | awk -F'TRIGGER_URL: ' '{print $2}' | sed -e 's///g')
datetime=$(echo "${params}" | grep 'DATETIME: ' | awk -F'DATETIME: ' '{print $2}' | sed -e 's///g')
item_value=$(echo "${params}" | grep 'ITEM_VALUE: ' | awk -F'ITEM_VALUE: ' '{print $2}' | sed -e 's///g')
item_id=$(echo "${params}" | grep 'ITEM_ID: ' | awk -F'ITEM_ID: ' '{print $2}' | sed -e 's///g')

# get charts
if [ "${item_id}" != "" ]; then
    timestamp=$(date +%s)

    ${CMD_WGET} --save-cookies="${CHART_COOKIE}_${timestamp}" --keep-session-cookies --post-data "name=${ZABBIX_USERNAME}&password=${ZABBIX_PASSWORD}&enter=Sign+in" -O /dev/null -q "${ZABBIX_BASEURL}/index.php?login=1"
    ${CMD_WGET} --load-cookies="${CHART_COOKIE}_${timestamp}"  -O "${CHART_BASEDIR}/graph-${item_id}-${timestamp}.png" -q "${ZABBIX_BASEURL}/chart.php?&itemid=${item_id}&width=${CHART_WIDTH}&period=${CHART_PERIOD}"
    
    rm -f "${CHART_COOKIE}_${timestamp}"

    # if trigger url is empty then we link to the graph with the item_id
    if [ "${trigger_url}" == "" ]; then
        trigger_url="${ZABBIX_BASEURL}/history.php?action=showgraph&itemid=${item_id}"
    fi
fi

# set color
if [ "${trigger_status}" == 'OK' ]; then
  case "${trigger_severity}" in
    'Information')
      color="#439FE0"
      ;;
    *)
      color="good"
      ;;
  esac
elif [ "${trigger_status}" == 'PROBLEM' ]; then
  case "${trigger_severity}" in
    'Information')
      color="#439FE0"
      ;;
    'Warning')
      color="warning"
      ;;
    *)
      color="danger"
      ;;
  esac
else
  color="#808080"
fi

# set payload
payload="payload={
  \"channel\": \"${channel}\",
  \"attachments\": [
    {
      \"fallback\": \"Date / Time: ${datetime} - ${title}\",
      \"title\": \"${title}\",
      \"title_link\": \"${trigger_url}\",
      \"color\": \"${color}\",
      \"fields\": [
        {
            \"title\": \"Date / Time\",
            \"value\": \"${datetime}\",
            \"short\": true
        },
        {
            \"title\": \"Status\",
            \"value\": \"${trigger_status}\",
            \"short\": true
        },
        {
            \"title\": \"Host\",
            \"value\": \"${host}\",
            \"short\": true
        },
        {
            \"title\": \"Trigger\",
            \"value\": \"${trigger_name}: ${item_value}\",
            \"short\": true
        }
      ]
    }
  ]
}"

# send to slack
${CMD_CURL} -m "${TIMEOUT}" --data-urlencode "${payload}" "${SLACK_URL}"
${CMD_CURL} -F file="@${CHART_BASEDIR}/graph-${item_id}-${timestamp}.png" -F token="${SLACK_TOKEN}" -F channels="${channel}" -F title="${title}" https://slack.com/api/files.upload
rm -f "${CHART_BASEDIR}/graph-${item_id}-${timestamp}.png"
