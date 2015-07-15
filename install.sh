#!/bin/bash

REPO_URL="https://raw.githubusercontent.com/hongkongkiwi/Zonomi-DNS-Updator/master/"
REPO_UPDATE_SCRIPT="$REPO_URL/master/update.sh"
REPO_LOGGER_LIB="$REPO_URL/master/libs/task-logger/task-logger.sh"
UPDATE_SCRIPT="$HOME/Zonomi-DNS-Updator/update_zonomi.sh"
CRON_FREQUENCY="@hourly"
CONFIG_FILE="$HOME/.zonomi.conf"
ZONOMI_BASE="https://zonomi.com"
ZONOMI_TEST_API_URL="$ZONOMI_BASE/app/dns/dyndns.jsp?action=QUERYZONES&api_key"

echo "-> Checking Internet Connetion"
if ! curl -sSf "$ZONOMI_BASE" > /dev/null; then
  echo "ERROR: We cannot access $ZONOMI_BASE"
  echo "       Please check your internet connection"
  exit 255
fi


echo "-> Downloading extra libraries"
# Download some libraries
if [ -f "libs/task-logger/task-logger.sh" ]; then
  source "libs/task-logger/task-logger.sh"
else
  source <(curl -s "$REPO_LOGGER_LIB")
fi

# We dont need root and it may confuse some things
if [ "$EUID" -eq 0 ]; then 
    bad "Please do not run this script as root!"
    exit 2
fi

### SETUP SOME USEFUL FUNCTIONS ###
confirm () {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case $response in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

# It's important that we have Git on the local machine
if ! command -v wget >/dev/null 2>&1; then
    error "wget is not installed! Please install with apt-get install -y wget"
    exit 255
fi

MSG="Enter Zonomi API Key"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
  MSG="$MSG [$API_KEY]"
fi

read -p "$MSG: " KEY 
KEY=${KEY:-$API_KEY}
# Set the repo url or if empty use the default
if [ "$KEY" == "" ]; then
  echo "API key cannot be blank!"
  exit 1
else
  echo "-> Testing API Key"
  RESULT=`curl -s -o /dev/null -I -w "%{http_code}" "$ZONOMI_TEST_API_URL=$KEY"`
  if [ "$RESULT" == "500" ]; then
    error "Invalid API Key!"
    exit 1
  fi
fi

MSG="Enter Parent Domain"

if [ "$DOMAIN" != "" ]; then
  MSG="$MSG [$DOMAIN]"
fi

read -p "$MSG: " PARENT_DOMAIN
PARENT_DOMAIN=${PARENT_DOMAIN:-$DOMAIN} 
# Set the repo url or if empty use the default
if [ "$PARENT_DOMAIN" == "" ]; then
  echo "Domain cannot be blank!"
  exit 1
else
  echo "-> Checking Domain Name"
  RESULT=`curl -s "$ZONOMI_TEST_API_URL=$KEY" | grep "name=\"$PARENT_DOMAIN\""`
  if [ "$RESULT" == "" ]; then
    error "Invalid Parent Domain! (not listed in Zonomi Account)"
    exit 1
  fi
fi

echo "API_KEY=\"$KEY\"" > "$CONFIG_FILE"
echo "DOMAIN=\"$PARENT_DOMAIN\"" >> "$CONFIG_FILE"
echo "Values saved into config file $CONFIG_FILE"

# Set the repo url or if empty use the default
SCRIPT_DIR=${SCRIPT_DIR:-$DEFAULT_SCRIPT_DIR}

DEFAULT_SCRIPT_DIR=`dirname "$UPDATE_SCRIPT"`
read -p "Enter Install Path [ $DEFAULT_SCRIPT_DIR ]:" SCRIPT_DIR 
# Set the repo url or if empty use the default
SCRIPT_DIR=${SCRIPT_DIR:-$DEFAULT_SCRIPT_DIR}
SCRIPT_NAME=`basename "$UPDATE_SCRIPT"`

mkdir -p "$SCRIPT_DIR"

UPDATE_SCRIPT="$SCRIPT_DIR/$SCRIPT_NAME"

if [ ! -f "$UPDATE_SCRIPT" ]; then
  # Download update script
  echo "-> Downloading Update Script"
  #wget -O "$UPDATE_SCRIPT" "$REPO_UPDATE_SCRIPT"
  echo "wget $REPO_UPDATE_SCRIPT"
  if [ ! -f "$UPDATE_SCRIPT" ]; then
    echo "X> Cannot find update script"
    exit 255
  fi
  chmod +x "$UPDATE_SCRIPT"
fi

CRON_JOB="$CRON_FREQUENCY $UPDATE_SCRIPT -c $CONFIG_FILE"

cron_installed=`crontab -l 2>/dev/null| grep -q "^$CRON_JOB$"; echo $?`
crontab_exists=`crontab -l 2>/dev/null; echo $?`

if [ $cron_installed -ne 0 ]; then
    if [ $(confirm "Would you like to install the update script into crontab for automated updating? [Y/n]"; echo $?) -eq 0 ]; then
        # Add to crontab with no duplication
        ( crontab -l | grep -v "$CRON_JOB"; echo "$CRON_JOB" ) | crontab -
	good "Crontab entry is added for user $USER"
    else
        info "You have chosen not to setup crontab, that means you must run the script manually to update your SSHKeys, you can run it using the following command"
    fi
else
    good "Looks like the script is already installed in crontab!"
    if [ $(confirm "Would you like to remove it? [y/N]"; echo $?) -eq 0 ]; then
        # Remove it from crontab
        ( crontab -l | grep -v "$UPDATE_SCRIPT" ) | crontab -
	good "Crontab entry is removed for user $USER"
    fi
fi

if [ -w "/usr/local/bin/update-zonomi" ] && [ `stat -c %U "/usr/local/bin"` == "$USER" ] &&
	[ `stat -c %U "/usr/local/bin/update-zonomi"` == "$USER" ]; then
  ln -sfn "$UPDATE_SCRIPT" "/usr/local/bin/update-zonomi"
  echo "-> Updated symlink location"
fi
