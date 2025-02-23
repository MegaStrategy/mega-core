#!/bin/bash

# Deploys contracts
# Usage:
# ./deploy.sh
#   --sequence <sequence-file>
#   --account <account>
#   --broadcast <false>
#   --verify <false>
#   --resume <false>
#   --env <.env>
#
# Environment variables:
# CHAIN:              Chain name to deploy to. Corresponds to names in "./script/env.json".
# ETHERSCAN_API_KEY:  API key for Etherscan verification.
# RPC_URL:            URL for the RPC node.
# VERIFIER_URL:       URL for the Etherscan API verifier.

# Exit if there is an error
set -e

# Load named arguments
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source $SCRIPT_DIR/lib/arguments.sh
load_named_args "$@"

# Load environment variables
load_env

# Apply defaults to command-line arguments
SEQUENCE_FILE=$sequence
BROADCAST=${broadcast:-false}
VERIFY=${verify:-false}
RESUME=${resume:-false}

# Validate named arguments
echo ""
echo "Validating arguments"
validate_text "$SEQUENCE_FILE" "No sequence file specified. Provide the path to the sequence file after the --sequence flag."
validate_file "$SEQUENCE_FILE" "The sequence file ($SEQUENCE_FILE) does not exist."
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
echo "  Deploy from account: $account"
echo "  Sender: $CAST_ADDRESS"
echo "  Chain: $CHAIN"
echo "  RPC URL: $RPC_URL"
echo "  Sequence file: $SEQUENCE_FILE"

# Validate and set forge script flags
source $SCRIPT_DIR/lib/forge.sh
set_broadcast_flag $BROADCAST
set_verify_flag $VERIFY
set_resume_flag $RESUME

# Deploy using script
forge script ./script/deploy/Deploy.s.sol:Deploy \
    --sig "deploy(string,string)()" $CHAIN $SEQUENCE_FILE \
    --rpc-url $RPC_URL --account $account --slow -vvv \
    --sender $CAST_ADDRESS \
    $BROADCAST_FLAG \
    $VERIFY_FLAG \
    $RESUME_FLAG

# Lint
pnpm run lint
