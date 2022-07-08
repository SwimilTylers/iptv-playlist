#!/usr/bin/env bash

set -o errexit
set -o pipefail

FROM=
TO='auto.m3u'
CHANNELS_FILE='auto.cfg'

CHANNELS_ID=()
CHANNELS=()

DB=''

QUERY_RES=''

function read_channels() {
    if [ ! -f "$CHANNELS_FILE" ]; then
        echo "file not found: $CHANNELS_FILE"
        exit 1
    fi

    while read -r line
    do
      line=$(tr -d '\r' <<< "$line")
      CH=$(awk -F',' '{ print $1 }' <<< "$line")
      ID=$(awk -F',' '{ print $2 }' <<< "$line")

      CHANNELS+=("$CH")
      CHANNELS_ID+=("$ID")
    done < "$CHANNELS_FILE"
}

function read_input() {
    if [ ! -f "$FROM" ]; then
        echo "file not found: $FROM"
        exit 1
    fi

    DB=$(grep -A1 '#EXTINF:' "$FROM")
}

function query() {
    local CHANNEL_ID=$1
    local CHANNEL=$2

    if [ -z "$CHANNEL_ID" ]; then
        CHANNEL_ID=$CHANNEL
    fi
    
    if grep -q "$CHANNEL_ID" <<< "$DB"; then
      QUERY_RES=$(grep -A1 "$CHANNEL_ID" <<< "$DB" | sed -n -e '/^http.*m3u/{p;q}')
    else
      QUERY_RES=''
    fi
}

function write_output() {
    local CHANNEL_ID=$1
    local CHANNEL=$2
    local URL=$3

    echo "#EXTINF:-1 tvg-id=\"$CHANNEL_ID\" tvg-country=\"CN\" tvg-language=\"Chinese;Mandarin Chinese\" tvg-logo=\"\" group-title=\"\",$CHANNEL" >> $TO
    echo "$URL" >> $TO
}

function usage() {
    echo "Usage:"
    echo "extract.sh [-I INPUT_FILE] [-O OUTPUT_FILE] [-C CONFIG_FILE]"
    echo " -I: input file"
    echo " -O: output file, default to $TO"
    echo " -C: channel config file, default to $CHANNELS_FILE"
    exit 1
}

while getopts 'I:O:C:' OPT; do
    case $OPT in
        I) FROM="$OPTARG";;
        O) TO="$OPTARG";;
        C) CHANNELS_FILE="$OPTARG";;
        ?) usage;;
    esac
done

read_input

read_channels

if [ -f "$TO" ]; then
    TS=$(date '+%s')
    mv "$TO" "$TO.$TS.bak"
fi

for (( i = 0; i < ${#CHANNELS[@]}; i++ )); do
    channel_id=${CHANNELS_ID[i]}
    channel=${CHANNELS[i]}

    query "$channel_id" "$channel"
    if [ -n "$QUERY_RES" ]; then
        write_output "$channel_id" "$channel" "$QUERY_RES"
    fi
done
