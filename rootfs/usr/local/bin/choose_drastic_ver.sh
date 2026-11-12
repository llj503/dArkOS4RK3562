#!/bin/bash

if [[ "$1" == "dsperate" ]]; then
    /opt/DSperate/dsperate.sh "$2"
else
    /usr/local/bin/drastic.sh "$2"
fi