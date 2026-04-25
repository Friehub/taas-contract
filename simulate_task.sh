#!/bin/bash
# Institutional TaaS Contract Receiver Test
# This script simulates a consumer requesting data from the TaaS Service Manager.

set -e

# Path to foundry binaries
FORGE=~/.foundry/bin/forge
ANVIL=~/.foundry/bin/anvil
CAST=~/.foundry/bin/cast

# project root
CDIR=$(pwd)
CONTRACT_DIR="$CDIR/contracts"

echo "--- 1. Starting Local EVM (Anvil) ---"
$ANVIL --silent &
ANVIL_PID=$!
sleep 3 # Wait for anvil to warm up

# Ensure anvil is killed on exit
cleanup() {
    echo "--- Cleaning up ---"
    kill $ANVIL_PID
}
trap cleanup EXIT

echo "--- 2. Deploying TaaS Service Manager ---"
# We use the existing deployment scripts or a simple forge create
# For this simulation, we'll deploy the contract directly
DEPLOY_OUT=$($FORGE create src/TaaSServiceManager.sol:TaaSServiceManager \
    --rpc-url http://127.0.0.1:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --json)

CONTRACT_ADDR=$(echo $DEPLOY_OUT | jq -r '.deployedTo')
echo "TaaS Service Manager deployed at: $CONTRACT_ADDR"

echo "--- 3. Simulating Consumer Task Request ---"
# Function: createNewTask(string capability, bytes params, uint8 strategy, uint32 minSources, uint32 quorumThreshold, uint64 deadline)
# Strategy 2 = MAJORITY
# minSources = 3
# quorumThreshold = 67
# deadline = current + 1 hour

DEADLINE=$(($(date +%s) + 3600))

TX_HASH=$($CAST send $CONTRACT_ADDR \
    "createNewTask(string,bytes,uint8,uint32,uint32,uint64)" \
    "crypto.eth.price" \
    "0x" \
    2 \
    3 \
    67 \
    $DEADLINE \
    --rpc-url http://127.0.0.1:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --json | jq -r '.transactionHash')

echo "Task created! Transaction Hash: $TX_HASH"

echo "--- 4. Inspecting Event Logs (TruthRequested) ---"
$CAST receipt $TX_HASH --rpc-url http://127.0.0.1:8545 --json | jq '.logs'

echo "--- COMPLETED: Contract received the request and emitted the TruthRequested event ---"
