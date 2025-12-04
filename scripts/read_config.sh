#!/bin/bash
# Send data to Golioth LightDB State using coap-client

source ~/golioth-rpi4-demo/credentials.env


coap-client-gnutls -m get   -u "$GOLIOTH_PSK_ID"   -k "$GOLIOTH_PSK"   "coaps://coap.golioth.io/.d/config"

