#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script is designed to be run in the org3cli container as the
# first step of the EYFN tutorial.  It creates and submits a
# configuration transaction to add org3 to the network previously
# setup in the BYFN tutorial.
#

CHANNEL_NAME="$1"
DELAY="$2"
LANGUAGE="$3"
TIMEOUT="$4"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${LANGUAGE:="golang"}
: ${TIMEOUT:="10"}
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/ord1.example.com/orderers/orderer0.ord1.example.com/msp/tlscacerts/tlsca.ord1.example.com-cert.pem

CC_SRC_PATH="github.com/chaincode/chaincode_example02/go/"
if [ "$LANGUAGE" = "node" ]; then
	CC_SRC_PATH="/opt/gopath/src/github.com/chaincode/chaincode_example02/node/"
fi

# import utils
. scripts/utils.sh

echo
echo "========= Creating config transaction to add org3 to network =========== "
echo

echo "Installing jq"
# apt-get -y update && apt-get -y install jq

# Fetch the config for the channel, writing it to config.json
fetchChannelConfig ${CHANNEL_NAME} config.json

# Modify the configuration to append the new org
set -x
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"Org3MSP":.[1]}}}}}' config.json ./channel-artifacts/org3.json > config1.json
set +x

# Modify the configuration to append the new orderer org
set -x
jq -s '.[0] * {"channel_group":{"groups":{"Orderer":{"groups": {"Orderer3MSP":.[1]}}}}}' config1.json ./channel-artifacts/ord3.json > config2.json
set +x

# Add the new orderer address
set -x
jq '.channel_group.values.OrdererAddresses.value.addresses=[.channel_group.values.OrdererAddresses.value.addresses[],"orderer0.ord3.example.com:7050"]' config2.json > modified_config.json
set +x

# Compute a config update, based on the differences between config.json and modified_config.json, write it as a transaction to org3_update_in_envelope.pb
createConfigUpdate ${CHANNEL_NAME} config.json modified_config.json org3_update_in_envelope.pb

echo
echo "========= Config transaction to add org3 to network created ===== "
echo

echo "Signing config transaction"
echo
# By default, 
# ADMIN Policy needs N/2+1 signatures by orgs
# ANY Policy needs 1 signature by any org
# CUSTOM Policy needs 1 signature by only one of genesis org

# signConfigtxAsPeerOrg 1 org3_update_in_envelope.pb
signConfigtxAsOrdererOrg 1 org3_update_in_envelope.pb
# signConfigtxAsOrdererOrg 2 org3_update_in_envelope.pb
echo
echo "========= Submitting transaction from a different peer (peer0.org2) which also signs it ========= "
echo
setGlobals 0 1
set -x
peer channel update -f org3_update_in_envelope.pb -c ${CHANNEL_NAME} -o orderer0.ord1.example.com:7050 --tls --cafile ${ORDERER_CA}
set +x

echo
echo "========= Config transaction to add org3 to network submitted! =========== "
echo
fetchChannelConfig ${CHANNEL_NAME} config_after.json
cp config_after.json channel-artifacts
exit 0
