#!/bin/bash

# ===========================================
#                  SETTINGS
# ===========================================
source parse_yml.sh
if [ "$ENV" = "local" ]; then
    CONFIG_FILE="config_local.yml"
else
    CONFIG_FILE="config.yml"
fi
CONFIG=$(parse_yaml $CONFIG_FILE "config_")
eval $CONFIG
IS_DOWN=0

# ===========================================
#                  FUNCTIONS
# ===========================================
function main {
    while true; do
        CURL_OUTPUT="Response code: %{http_code}" 
        RESPONSE=$(/usr/bin/curl --write-out "$CURL_OUTPUT" --silent --output /dev/null $config_WEBSITE)
        RESP_STATUS=$?
        # libcurl error codes: https://curl.haxx.se/libcurl/c/libcurl-errors.html
        RESPONSE_CODE=${RESPONSE#Response code: }
         
        logStatus

        # If the server has gone down and no alert has been sent
        if ([ $RESP_STATUS -ne 0 ] && [ $RESPONSE_CODE -ne 200 ] && [ $IS_DOWN -eq 0 ]); then
            whenServerGoesDown

        # If the server as gone back up and no alert has been sent
        elif ([ $RESP_STATUS -eq 0 ] && [ $RESPONSE_CODE -eq 200 ] && [ $IS_DOWN -eq 1 ]) ; then
            whenServerGoesUp
        fi

        sleep $config_INTERVAL
    done

}

function logStatus {
    if [ $config_DEBUG -eq 1 ]; then
        echo -e "\n_____________________"
        echo "Response Code = $RESPONSE_CODE"
        if [ $RESPONSE_CODE -eq 200 ]; then
            echo "$config_WEBSITE ==> is up"
        elif [ $RESPONSE_CODE -eq 000 ]; then
            echo -e "Could not Resolve DNS for $config_WEBSITE \n$config_WEBSITE ==> is down"
        else
            echo "$config_WEBSITE ==> is down"
        fi
        echo -e "_____________________\n"
    fi
}

function whenServerGoesUp {
    sendEmailThroughGmail "BACK UP"
    IS_DOWN=0
}

function whenServerGoesDown {
    # Execute all commands defined to run when server goes down
    for (( i = 0; i < ${#config_COMMANDS_WHEN_SERVER_GOES_DOWN[@]} ; i++ )); do
        eval ${config_COMMANDS_WHEN_SERVER_GOES_DOWN[$i]}
    done
    sendEmailThroughGmail "DOWN"
    #sendSMS 00447775696076 "$config_WEBSITE has gone DOWN at `date`"
    IS_DOWN=1
}

function sendSMS {
    curl -X POST http://textbelt.com/intl -d number=$1 -d "$2"
}

function sendEmailThroughGmail {
    CONTENT_FILE="$HOME/mail.txt"
    URL="smtps://smtp.gmail.com:465"

    GMAIL_EMAIL="$config_GIT_ACCOUNT_USER"
    GMAIL_APP_PASSWORD="$config_GIT_ACCOUNT_PASS"

    MAIL_FROM="$config_NOTIFY_FROM_EMAIL"
    NAME_FROM="$config_NOTIFY_FROM_NAME"
    
    MAIL_TO="$config_NOTIFY_TO_EMAIL"
    NAME_TO="$config_NOTIFY_TO_NAME"

    SUBJECT="Website $config_WEBSITE is $1"

    # ---EMAIL CONTENT---
read -r -d '' EMAIL_CONTENT <<- EOF
From: "$NAME_FROM" <$MAIL_FROM>
To: "$NAME_TO" <$MAIL_TO>
Subject: $SUBJECT

ALERT Report,
$SUBJECT
Check done at: `date`
EOF

    # ---SENDING THE EMAIL--- 
    echo "$EMAIL_CONTENT" > $CONTENT_FILE

    # Note: use --verbose on curl to debug if necessary
    curl --ssl --digest --silent \
        --mail-from "$MAIL_FROM" \
        --mail-rcpt "$MAIL_TO" \
        --url "$URL" \
        --user "$GMAIL_EMAIL:$GMAIL_APP_PASSWORD" \
        --upload-file "$CONTENT_FILE"

    rm -f $CONTENT_FILE
}

# ===========================================
#                  RUN MAIN
# ===========================================
main
