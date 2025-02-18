#!/bin/bash

# Updates the salts for the Banker policy
#
# Usage:
# ./banker_salts.sh
#   --env <.env file>
#   --account <cast account>
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

forge script script/salts/banker/BankerSalts.s.sol:BankerSalts \
    --sender $CAST_ADDRESS \
    --sig "generate(string)()" $CHAIN

# Lint
pnpm run lint
