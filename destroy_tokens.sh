#!/bin/bash
set -e

###############################################################################
###############################################################################
NAME="minter"
SENDER_ADDR=$(cat ${NAME}/${NAME}_base.addr)
POLICY_ID=$(cat policy/policy.id)
ASSET_NAME="ADAMakerSpaceContributorCoin"
MINT="-2021 ${POLICY_ID}.${ASSET_NAME}"
###############################################################################
###############################################################################


# Check if a directory does not exist
if [ -d transaction ] 
then
  echo "Folder Exists."
else
  mkdir -p transaction
fi
cd transaction

# Passive relay or Daedalus is required.
#
# Must have a live Network.Socket.connect

# protocol
echo "Getting protocol parameters"
cardano-cli query protocol-parameters \
--mainnet \
--out-file protocol.json

# get utxo
echo "Getting utxo"
cardano-cli query utxo \
--cardano-mode \
--mainnet \
--address ${SENDER_ADDR} \
--out-file utxo.json

# transaction variables
TXNS=$(jq length utxo.json)
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' utxo.json)
HEXTXIN=${TXIN::-8}
BALANCE=$(jq .[].value.lovelace utxo.json | awk '{sum=sum+$0} END{print sum}' )
echo $BALANCE
echo $HEXTXIN

# Next tip before no transaction
echo "Getting chain tip"
cardano-cli query tip --mainnet --out-file tip.json
TIP=$(jq .slot tip.json)
echo $TIP
DELTA=200000
FINALTIP=$(( ${DELTA} + ${TIP} ))

echo "Building Draft Transaction"
cardano-cli transaction build-raw \
--mary-era \
--fee 0 \
--tx-in $HEXTXIN \
--tx-out ${SENDER_ADDR}+${BALANCE} \
--mint "${MINT}" \
--minting-script-file "../policy/policy.script" \
--invalid-hereafter $FINALTIP \
--out-file tx.draft

echo "Calculating Transaction Fee"
FEE=$(cardano-cli transaction calculate-min-fee \
--tx-body-file tx.draft \
--tx-in-count ${TXNS} \
--tx-out-count 1 \
--witness-count 3 \
--mainnet \
--protocol-params-file protocol.json \
| tr -dc '0-9')

echo $SENDER "has" $BALANCE "ADA"
echo "The fee is" ${FEE} "to move" ${BALANCE} "Lovelace"
CHANGE=$(( ${BALANCE} - ${FEE} ))
echo "The change is" ${CHANGE}

echo "Building Raw Transaction"
cardano-cli transaction build-raw \
--mary-era \
--fee $FEE \
--tx-in $HEXTXIN \
--tx-out ${SENDER_ADDR}+${CHANGE} \
--mint "${MINT}" \
--minting-script-file "../policy/policy.script" \
--invalid-hereafter $FINALTIP \
--out-file tx.raw

echo "Signing Transaction"
cardano-cli transaction sign \
--tx-body-file tx.raw \
--signing-key-file "../minter/minter_payment.skey" \
--signing-key-file "../policy/policy.skey" \
--mainnet \
--out-file tx.signed

# # ###### THIS MAKES IT LIVE #####################################################
# cardano-cli transaction submit \
# --tx-file tx.signed \
# --mainnet
# # ###############################################################################