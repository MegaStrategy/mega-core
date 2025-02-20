#!/bin/bash

# Updates the salts for the given test key
# Usage:
# ./test_salts.sh
#   --saltKey <salt key>
#   --account <cast account>
#   --env <.env file>
#
# Environment variables:
# CHAIN

# Exit if any error occurs
set -e

# Load named arguments
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source $SCRIPT_DIR/lib/arguments.sh
load_named_args "$@"

# Load environment variables
load_env

# Validate named arguments
echo ""
echo "Validating arguments"
validate_text "$account" "No account specified. Provide the cast wallet after the --account flag."
validate_text "$saltKey" "No salt key specified. Provide the salt key after the --saltKey flag."

# Validate environment variables
echo ""
echo "Validating environment variables"
validate_text "$CHAIN" "No chain specified. Specify the CHAIN in the $ENV_FILE file."

# Get the address of the cast wallet
echo ""
echo "Getting address for cast account $account"
CAST_ADDRESS=$(cast wallet address --account $account)

echo ""
echo "Summary:"
echo "  Deploy from account: $account"
echo "  Sender: $CAST_ADDRESS"
echo "  Chain: $CHAIN"
echo "  Salt key: $saltKey"

salt_file="./script/salts/salts.json"
salt_tmp_file="./script/salts/salts.json.tmp"

# Clear the salts for the specified salt key
if [ -f $salt_file ]; then
    echo "Clearing old values for salt key: $saltKey"
    jq "del(.\"Test_$saltKey\")" $salt_file > $salt_tmp_file && mv $salt_tmp_file $salt_file
fi

# Generate bytecode
forge script ./script/salts/test/TestSalts.s.sol:TestSalts \
    --sender $CAST_ADDRESS \
    --sig "generate(string,string)()" $CHAIN $saltKey

# Lint
pnpm run lint
