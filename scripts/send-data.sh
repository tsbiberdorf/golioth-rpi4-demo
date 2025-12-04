#!/bin/bash
# Send data to Golioth LightDB State using coap-client

source ~/golioth-rpi4-demo/credentials.env

counter=0
while true; do
    echo "Sending counter=$counter to LightDB State..."
    
    echo -n "{\"counter\":$counter,\"source\":\"RPi4\"}" | \
    coap-client-gnutls -m put \
        -u "$GOLIOTH_PSK_ID" \
        -k "$GOLIOTH_PSK" \
        -f - \
        "coaps://coap.golioth.io/.d/state"
    
    echo "Sent!"
    counter=$((counter + 1))
    sleep 10
done
