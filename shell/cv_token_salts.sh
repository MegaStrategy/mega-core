#!/bin/bash

# Creates a salt for a ConvertibleDebtToken
#
# Usage:
# ./cv_token_salts.sh
#   --env <.env file>
#   --account <cast account>
#   --prefix <prefix>
#   --auctionFilePath <auction file path>
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
validate_text "$prefix" "No prefix specified. Provide the prefix after the --prefix flag."
validate_file "$auctionFilePath" "No auction file path specified. Provide the path after the --auctionFilePath flag."

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
echo "  Prefix: $prefix"
echo "  Auction file path: $auctionFilePath"

forge script script/salts/banker/BankerSalts.s.sol:BankerSalts \
    --sender $CAST_ADDRESS \
    --account $account \
    --rpc-url $RPC_URL \
    --sig "generateDebtTokenSalt(string,string,string)()" $CHAIN $auctionFilePath $prefix \
    --slow -vvv

# Lint
pnpm run lint
