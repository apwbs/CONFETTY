#!/bin/bash

# Default IP and Port
DEFAULT_IP="127.0.0.1"
DEFAULT_PORT="7545"
DEFAULT_NETWORK_ID="5777"

# Use provided IP and Port or default values
IP=${1:-$DEFAULT_IP}
PORT=${2:-$DEFAULT_PORT}
NETWORK_ID=${3:-$DEFAULT_NETWORK_ID}
NEW_URL="http://$IP:$PORT"

# Files to be updated
FILES="../src/client2.py ../src/server_authority.py ../src/block_int.py"
TRUFFLE_CONFIG="../blockchain/truffle-config.js"
CONTROLLER_JS="../../Process Manager/WebContent/lib/controller.js"

# Escape &
escaped_url=$(printf '%s\n' "$NEW_URL" | sed 's/&/\\&/g')

# Update ganache_url in Python files
for FILE in $FILES; do
    if [ -f "$FILE" ]; then
        sed -i "s|ganache_url = \".*\"|ganache_url = \"$escaped_url\"|g" "$FILE"
        echo "Updated ganache_url in $FILE"
    else
        echo "File $FILE not found!"
    fi
done

# Update truffle-config.js
if [ -f "$TRUFFLE_CONFIG" ]; then
    sed -i "s/host: \".*\".*Localhost/host: \"$IP\",     \/\/ (For Grep) Localhost/g" "$TRUFFLE_CONFIG"
    sed -i "s/port: [0-9]\{4,5\}.*Standard Ethereum/port: $PORT,            \/\/ (For Grep) Standard Ethereum/g" "$TRUFFLE_CONFIG"
    sed -i "s/network_id: [0-9]\{1,5\}.*Any network/network_id: $NETWORK_ID,       \/\/ (For Grep) Any network/g" "$TRUFFLE_CONFIG"
    echo "Updated host, port, and network_id in $TRUFFLE_CONFIG"
else
    echo "File $TRUFFLE_CONFIG not found!"
fi

cd ../blockchain

# Run truffle migrate and capture contract addresses
addresses=$(
  truffle migrate --network development \
  | tee /dev/tty \
  | grep "> contract address:" \
  | awk '{print $NF}'
)

# Extract first and second addresses
mart_address=$(printf '%s\n' "$addresses" | sed -n '1p' | tr -d '\r')
chor_address=$(printf '%s\n' "$addresses" | sed -n '2p' | tr -d '\r')

# Update .env file
sed -i.bak "s|^CONTRACT_ADDRESS_MARTSIA=\".*\"$|CONTRACT_ADDRESS_MARTSIA=\"$mart_address\"|" ../src/.env
sed -i.bak "s|^CONTRACT_ADDRESS_CHORCHAIN=\".*\"$|CONTRACT_ADDRESS_CHORCHAIN=\"$chor_address\"|" ../src/.env

# Update WebContent deploy.html
DEPLOY_FILE="/CONFETTY/Process Manager/WebContent/deploy.html"

if [ -f "$DEPLOY_FILE" ]; then

    echo "Updating $DEPLOY_FILE"

    sed -i.bak \
        "s|new web3.eth.Contract(\$scope.martsiaAbi, \"[^\"]*\")|new web3.eth.Contract(\$scope.martsiaAbi, \"$mart_address\")|g" \
        "$DEPLOY_FILE"

    sed -i.bak \
        "s|new web3.eth.Contract(\$scope.stateAbi, \"[^\"]*\")|new web3.eth.Contract(\$scope.stateAbi, \"$chor_address\")|g" \
        "$DEPLOY_FILE"

    echo "Updated contract addresses in $DEPLOY_FILE"
else
    echo "File not found: $DEPLOY_FILE"
fi

# Update controller.js addresses
if [ -f "$CONTROLLER_JS" ]; then
    sed -i.bak "s|new web3.eth.Contract(\\\$scope.martsiaAbi, \"[^\"]*\")|new web3.eth.Contract(\\\$scope.martsiaAbi, \"$mart_address\")|g" "$CONTROLLER_JS"
    sed -i.bak "s|new web3.eth.Contract(\\\$scope.stateAbi, \"[^\"]*\")|new web3.eth.Contract(\\\$scope.stateAbi, \"$chor_address\")|g" "$CONTROLLER_JS"
    echo "Updated contract addresses in controller.js"
else
    echo "controller.js not found at $CONTROLLER_JS"
fi

cd ../sh_files
sh db_and_IPFS.sh
