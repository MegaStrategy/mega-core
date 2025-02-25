#!/bin/bash

# Revokes a role from an account
# Usage: ./revoke_role.sh
#   --env <.env>
#   --account <account>
#   --role <admin|manager|emergency>
#   --recipient <address>
#   --broadcast <false>
#
# Environment variables:
# CHAIN:              Chain name to deploy to. Corresponds to names in "./script/env.json".
# RPC_URL:            URL for the RPC node.

# Exit if there is an error
set -e

# Load named arguments
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source $SCRIPT_DIR/lib/arguments.sh
load_named_args "$@"

# Load environment variables
load_env

# Apply defaults to command-line arguments
BROADCAST=${broadcast:-false}

# Validate named arguments
echo ""
echo "Validating arguments"
validate_text "$account" "No account specified. Provide the cast wallet after the --account flag."
validate_text "$role" "No role specified. Provide the role after the --role flag."
validate_address "$recipient" "No recipient specified. Provide the recipient after the --recipient flag."

# Check that the role is valid
if [ "$role" != "admin" ] && [ "$role" != "manager" ] && [ "$role" != "emergency" ]; then
    echo "Invalid role: $role"
    exit 1
fi

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
echo "  Role: $role"
echo "  Recipient: $recipient"

# Validate and set forge script flags
source $SCRIPT_DIR/lib/forge.sh
set_broadcast_flag $BROADCAST

forge script ./script/Tasks.s.sol:TasksScript \
    --sig "revokeRole(string,string,address)()" $CHAIN $role $recipient \
    --rpc-url $RPC_URL --account $account \
    --sender $CAST_ADDRESS \
    --slow -vvv \
    $BROADCAST_FLAG
