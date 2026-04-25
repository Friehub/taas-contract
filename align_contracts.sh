#!/bin/bash

# Institutional Alignment Script for TaaS Sepolia Contracts
# --------------------------------------------------------

# 1. Load institutional coordinates
if [ -f .env.sepolia ]; then
    source .env.sepolia
elif [ -f ../.env.sepolia ]; then
    source ../.env.sepolia
else
    echo "Error: .env.sepolia not found."
    exit 1
fi

echo "Initiating Contract Alignment (Upgrade) on Sepolia..."
echo "Target Proxy: $SERVICE_MANAGER_PROXY"
echo "RPC URL: $RPC_URL"

# 2. Run the forge script
# --broadcast: sends transactions to the network
# --verify: (optional) verify on etherscan if API key is present
# --slow: prevents gas spikes on testnets
~/.foundry/bin/forge script script/UpgradeTaaS.s.sol:UpgradeTaaS \
    --rpc-url $RPC_URL \
    --broadcast \
    --slow \
    -vvvv

echo "Alignment complete. Verifying state..."

# 3. Quick verification
~/.foundry/bin/cast call $SERVICE_MANAGER_PROXY "taskCount()(uint32)" --rpc-url $RPC_URL
