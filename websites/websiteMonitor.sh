#!/bin/bash

# ===========================================
#                  SETTINGS
# ===========================================
source parse_yml.sh
eval $(parse_yaml config.yml "config_")

NOTIFY_EMAIL=rui.carvalho@businessoffashion.com
ALERT_TO_EMAIL=alert@localhost
WEBSITE=www.businessoffashion.com
PAUSE=60
FAILED=0
DEBUG=1

# ===========================================
#                  FUNCTIONS
# ===========================================
function main {
    while true 
    do
        CURL_OUTPUT="Response code: %{http_code}" 
        RESPONSE=$(/usr/bin/curl --write-out "$CURL_OUTPUT" --silent --output /dev/null $WEBSITE)
        RESPONSE_CODE=${RESPONSE#Response code: }
        
        echo $RESPONSE_CODE

        RESP_STATUS=$? # libcurl error codes: https://curl.haxx.se/libcurl/c/libcurl-errors.html

        logStatus

        # If the server is down and no alert is sent - alert
        if [ $RESP_STATUS -ne 0 ] && [ $FAILED -eq 0 ]; then
            whenServerGoesDown

        # If the server is back up and no alert is sent - alert
        elif [ $RESP_STATUS -eq 0 ] && [ $FAILED -eq 1 ]; then
            whenServerGoesUp
        fi
        sleep $PAUSE
    done

}

function logStatus {
    if [ $DEBUG -eq 1 ]
    then
        echo -e "\n_____________________"
        echo "STATUS = $RESP_STATUS"
        echo "FAILED = $FAILED"
        if [ $RESP_STATUS -ne 0 ]
        then
            echo "$WEBSITE ==> is down"

        elif [ $RESP_STATUS -eq 0 ]
        then
            echo "$WEBSITE ==> is up"
        fi
        echo -e "_____________________\n"
    fi
}

function whenServerGoesUp {
    sendEmailThroughGmail "BACK UP"
    FAILED=1
}

function whenServerGoesDown {
    sendEmailThroughGmail "DOWN"
    FAILED=0
}

function sendEmailThroughGmail {
    CONTENT_FILE="$HOME/mail.txt"
    URL="smtps://smtp.gmail.com:465"

    GMAIL_EMAIL="$config_git_account_user"
    GMAIL_APP_PASSWORD="$config_git_account_pass"

    MAIL_FROM="alerts@businessoffashion.com"
    NAME_FROM="Rui Carvalho"
    
    MAIL_TO="rui.carvalho@businessoffashion.com"
    NAME_TO="Alerts at BoF"

    SUBJECT="Website $WEBSITE id $1"

    # ---EMAIL CONTENT---
    read -r -d '' EMAIL_CONTENT <<- EOF
From: "$NAME_FROM" <$MAIL_FROM>
To: "$NAME_TO" <$MAIL_TO>
Subject: $SUBJECT

ALERT Report,
The website $WEBSITE is $1. 
Check done at: `date`
EOF

    # ---SENDING THE EMAIL---
    echo "$EMAIL_CONTENT" > $CONTENT_FILE

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
sendEmailThroughGmail
#main
