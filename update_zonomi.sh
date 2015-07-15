#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
DEFAULT_CONFIG_FILE="$DIR/config"
HOSTNAME=`hostname | tr '[:upper:]' '[:lower:]'`

# Read the config file (if it exists)
if [ -f "$DEFAULT_CONFIG_FILE" ]; then
  source "$DEFAULT_CONFIG_FILE" 2> /dev/null
fi

# Read command line Options
while getopts ":s:d:c:a:i:" opt
do
    case ${opt} in
        s) SUBDOMAIN=${OPTARG};;
        d) DOMAIN=${OPTARG};;
        c) CONFIG_FILE=${OPTARG};;
        a) API_KEY=${OPTARG};;
        i) IP_ADDRESS=${OPTARG};;
    esac
done
shift $((${OPTIND} - 1))

# Read the config file (if it exists)
if [ "$CONFIG_FILE" == ""  ] && [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE" 2> /dev/null
fi

SUBDOMAIN=${SUBDOMAIN:-$(echo "$HOSTNAME")}
HOST="$SUBDOMAIN.$DOMAIN"

if [ "$IP_ADDRESS" == "" ]; then
  API_URL="https://zonomi.com/app/dns/dyndns.jsp?host=${HOST}&api_key=$API_KEY"
else
  API_URL="https://zonomi.com/app/dns/dyndns.jsp?action=SET&${HOST}&value=$IP_ADDRESS&type=A&api_key=$API_KEY"
fi

OUTPUT=`wget -O - -q -t 1 "$API_URL"`
RESULT=$?

if [ -z "$PS1" ]; then
  if [ $RESULT -eq 0 ]; then
    if [[ "$IP_ADDRESS" == "" ]]; then
      echo "Successfully updated $HOST"
    else
      echo "Successfully updated $HOST with $IP_ADDRESS"
    fi
  else
    echo "Failed to update $HOST!"
  fi
fi

exit $RESULT
