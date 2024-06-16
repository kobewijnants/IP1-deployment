#!/bin/bash

URL="https://phygital.kobelabs.online"

while true; do
    RESPONSE=$(curl -o /dev/null -s -w "%{http_code}" $URL)
    if [ "$RESPONSE" -ne 200 ]; then
        echo -e "\e[31m$(date) - $URL is down. HTTP Status: $RESPONSE\e[0m" 
    else
        echo -e "\e[32m$(date) - $URL is up. HTTP Status: $RESPONSE\e[0m"
    fi
    sleep 1
done
