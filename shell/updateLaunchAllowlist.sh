#!/bin/bash

# Updates the merkle root and IPFS hash for the launch auction
# Usage: ./updateLaunchAllowlist.sh
#       --lotId <lotId>
#       --merkleRoot <merkleRoot>
#       --ipfsHash <ipfsHash>
#       --account <cast account>
#       [--broadcast <true|false>]
#
# Environment variables:
# RPC_URL
# CHAIN

# Exit if any error occurs
set -e

# Load named arguments
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source $SCRIPT_DIR/lib/arguments.sh
load_named_args "$@"

# Load environment variables
load_env

# Set sane defaults
BROADCAST=${broadcast:-false}

# Validate named arguments
echo ""
echo "Validating arguments"
validate_number "$lotId" "No lotId specified or it was not a valid number. Provide the lotId after the --lotId flag."
validate_bytes32 "$merkleRoot" "No merkleRoot specified or it was not a valid bytes32 value. Provide the merkleRoot after the --merkleRoot flag."
validate_text "$ipfsHash" "No ipfsHash specified or it was not a valid text value. Provide the ipfsHash after the --ipfsHash flag."
validate_text "$account" "No account specified. Provide the cast wallet after the --account flag."

# Validate environment variables
echo ""
echo "Validating environment variables"
validate_text "$CHAIN" "No chain specified. Specify the CHAIN in the $ENV_FILE file."
validate_text "$RPC_URL" "No RPC URL specified. Specify the RPC_URL in the $ENV_FILE file."

# Get the address of the cast wallet
echo ""
echo "Getting address for cast account $account"
CAST_ADDRESS=$(cast wallet address --account $account)

echo ""
echo "Summary:"
echo "  Account: $account"
echo "  Sender: $CAST_ADDRESS"
echo "  Chain: $CHAIN"
echo "  RPC URL: $RPC_URL"
echo "  LotId: $lotId"
echo "  Merkle Root: $merkleRoot"
echo "  IPFS Hash: $ipfsHash"

# Validate and set forge script flags
source $SCRIPT_DIR/lib/forge.sh
set_broadcast_flag $BROADCAST

# Run
echo ""
echo "Running the script"
forge script ./script/LaunchAuction.s.sol \
    --sig "updateAllowlist(string,uint96,bytes32,string)" $CHAIN $lotId $merkleRoot $ipfsHash \
    --rpc-url $RPC_URL \
    --account $account \
    --sender $CAST_ADDRESS \
    $BROADCAST_FLAG \
    --slow \
    -vvv

echo ""
echo "Allowlist updated"
