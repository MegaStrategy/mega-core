#!/bin/bash

# Functions for interacting with auction metadata

# @description Uploads the auction metadata to IPFS
# @param {string} $1 The auction metadata file
# @param {string} $2 The allowlist file
# @sideEffects Sets the IPFS hash in the IPFS_HASH environment variable
function upload_auction_metadata() {
    local launch_file=$1
    local allowlist_file=$2

    # Validate that the auction info has the required fields
    echo ""
    echo "Validating auction info"
    if ! jq -e '.auctionInfo.name' $launch_file > /dev/null 2>&1; then
        echo "Error: auctionInfo.name is required"
        exit 1
    fi

    if ! jq -e '.auctionInfo.description' $launch_file > /dev/null 2>&1; then
        echo "Error: auctionInfo.description is required"
        exit 1
    fi

    if ! jq -e '.auctionInfo.tagline' $launch_file > /dev/null 2>&1; then
        echo "Error: auctionInfo.tagline is required"
        exit 1
    fi

    if ! jq -e '.auctionInfo.links.projectBanner' $launch_file > /dev/null 2>&1; then
        echo "Error: auctionInfo.links.projectBanner is required"
        exit 1
    fi

    if ! jq -e '.auctionInfo.links.projectLogo' $launch_file > /dev/null 2>&1; then
        echo "Error: auctionInfo.links.projectLogo is required"
        exit 1
    fi

    if ! jq -e '.auctionInfo.links.payoutTokenLogo' $launch_file > /dev/null 2>&1; then
        echo "Error: auctionInfo.links.payoutTokenLogo is required"
        exit 1
    fi

    if ! jq -e '.auctionInfo.links.website' $launch_file > /dev/null 2>&1; then
        echo "Error: auctionInfo.links.website is required"
        exit 1
    fi

    # Extract the "auctionInfo" key from the input file and store it in the tmp directory
    echo ""
    echo "Extracting auction info from $launch_file for upload to IPFS"
    mkdir -p tmp
    local auction_info=$(jq -r '.auctionInfo' $launch_file)

    # Generate the allowlist from CSV
    echo ""
    echo "Formatting and validating allowlist from file $allowlist_file"
    local allowlist_json=$(awk -F, 'BEGIN {print "["} NR>1 && NF>1 {printf("%s[\"%s\",\"%s\"]", (NR==2)?"":",\n", $1, $2)} END {print "]"}' $allowlist_file)

    # Set the "allowlist" key in the auction info
    auction_info=$(echo "$auction_info" | jq --argjson allowlist "$allowlist_json" '.allowlist = $allowlist')

    # Write the auction info to a file
    echo ""
    echo "Writing auction info to tmp/auctionInfo.json"
    echo "$auction_info" > tmp/auctionInfo.json

    # Validate and format the auction info JSON file
    echo ""
    echo "Validating and formatting auction info JSON file"
    auction_info=$(jq -s . tmp/auctionInfo.json)

    # Upload the data to IPFS
    echo ""
    echo "Uploading data to IPFS"
    echo "If nothing happens, you may need to run 'npx fleek login' to authenticate, and then select a project using 'npx fleek projects switch'"
    local ipfs_output=$(npx fleek storage add tmp/auctionInfo.json)
    # Extract the IPFS CID (59 characters long) from the fleek output
    local ipfs_hash=$(echo "$ipfs_output" | grep -o "[a-zA-Z0-9]\{59\}")

    # Verify we got a valid hash
    if [ -z "$ipfs_hash" ]; then
        echo "Error: Failed to extract IPFS hash from fleek output"
        exit 1
    else
        echo "IPFS hash: $ipfs_hash"
    fi

    # Set the IPFS hash in the environment variable
    export IPFS_HASH=$ipfs_hash
}
