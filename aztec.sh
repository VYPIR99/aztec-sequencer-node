#!/bin/bash

CYAN='\033[0;36m'
LIGHTBLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
PURPLE='\033[1;35m'
BOLD='\033[1m'
RESET='\033[0m'

curl -s https://raw.githubusercontent.com/zunxbt/logo/main/logo.sh | bash
sleep 3

echo -e "\n${CYAN}${BOLD}---- CHECKING DOCKER AVAILABILITY ----${RESET}\n"
if ! command -v docker &> /dev/null; then
  echo -e "${RED}${BOLD}Docker is not available in this Codespace. Make sure 'features' includes Docker in devcontainer.json.${RESET}"
  exit 1
fi

if [ ! -S /var/run/docker.sock ]; then
  echo -e "${RED}${BOLD}Docker socket not found. Docker may not be properly configured in Codespaces.${RESET}"
  exit 1
fi

echo -e "${GREEN}${BOLD}Docker is available and ready to use.${RESET}"

echo -e "\n${CYAN}${BOLD}---- INSTALLING DEPENDENCIES ----${RESET}\n"
sudo apt-get update
sudo apt-get install -y curl screen net-tools psmisc jq

[ -d /home/codespace/.aztec/alpha-testnet ] && rm -r /home/codespace/.aztec/alpha-testnet

AZTEC_PATH=/home/codespace/.aztec
BIN_PATH=$AZTEC_PATH/bin
mkdir -p $BIN_PATH

echo -e "\n${CYAN}${BOLD}---- INSTALLING AZTEC TOOLKIT ----${RESET}\n"

curl -fsSL https://install.aztec.network | bash

if ! command -v aztec >/dev/null 2>&1; then
    echo -e "${LIGHTBLUE}${BOLD}Aztec CLI not found in PATH. Adding it for current session...${RESET}"
    export PATH="$PATH:/home/codespace/.aztec/bin"

    if ! grep -Fxq 'export PATH=$PATH:/home/codespace/.aztec/bin' "/home/codespace/.bashrc"; then
        echo 'export PATH=$PATH:/home/codespace/.aztec/bin' >> "/home/codespace/.bashrc"
        echo -e "${GREEN}${BOLD}Added Aztec to PATH in .bashrc${RESET}"
    fi
fi

if [ -f "/home/codespace/.bashrc" ]; then
    source "/home/codespace/.bashrc"
fi

export PATH="$PATH:/home/codespace/.aztec/bin"

if ! command -v aztec &> /dev/null; then
  echo -e "${RED}${BOLD}ERROR: Aztec installation failed. Please check the logs above.${RESET}"
  exit 1
fi

echo -e "\n${CYAN}${BOLD}---- UPDATING AZTEC TO ALPHA-TESTNET ----${RESET}\n"
aztec-up alpha-testnet

echo -e "\n${CYAN}${BOLD}---- CONFIGURING NODE ----${RESET}\n"

# IP not used in Codespace; using loopback
IP="127.0.0.1"

echo -e "${LIGHTBLUE}${BOLD}Visit ${PURPLE}https://dashboard.alchemy.com/apps${RESET}${LIGHTBLUE}${BOLD} or ${PURPLE}https://developer.metamask.io/register${RESET}${LIGHTBLUE}${BOLD} to get a Sepolia RPC URL.${RESET}"
read -p "Enter Your Sepolia Ethereum RPC URL: " L1_RPC_URL

echo -e "\n${LIGHTBLUE}${BOLD}Visit ${PURPLE}https://chainstack.com/global-nodes${RESET}${LIGHTBLUE}${BOLD} to get a beacon RPC URL.${RESET}"
read -p "Enter Your Sepolia Ethereum BEACON URL: " L1_CONSENSUS_URL

echo -e "\n${LIGHTBLUE}${BOLD}Please create a new EVM wallet, fund it with Sepolia Faucet and then provide the private key.${RESET}"
read -p "Enter your new evm wallet private key (with 0x prefix): " VALIDATOR_PRIVATE_KEY
read -p "Enter the wallet address associated with the private key you just provided: " COINBASE_ADDRESS

echo -e "\n${CYAN}${BOLD}---- CHECKING PORT AVAILABILITY ----${RESET}\n"
if netstat -tuln | grep -q ":8080 "; then
    echo -e "${LIGHTBLUE}${BOLD}Port 8080 is in use. Attempting to free it...${RESET}"
    fuser -k 8080/tcp
    sleep 2
    echo -e "${GREEN}${BOLD}Port 8080 has been freed successfully.${RESET}"
else
    echo -e "${GREEN}${BOLD}Port 8080 is already free and available.${RESET}"
fi

echo -e "\n${CYAN}${BOLD}---- STARTING AZTEC NODE ----${RESET}\n"
cat > /home/codespace/start_aztec_node.sh << EOL
#!/bin/bash
export PATH=\$PATH:/home/codespace/.aztec/bin
aztec start --node --archiver --sequencer \\
  --network alpha-testnet \\
  --port 8080 \\
  --l1-rpc-urls $L1_RPC_URL \\
  --l1-consensus-host-urls $L1_CONSENSUS_URL \\
  --sequencer.validatorPrivateKey $VALIDATOR_PRIVATE_KEY \\
  --sequencer.coinbase $COINBASE_ADDRESS \\
  --p2p.p2pIp $IP
EOL

chmod +x /home/codespace/start_aztec_node.sh

# Use screen if available; fallback to background
if command -v screen &> /dev/null; then
    screen -dmS aztec /home/codespace/start_aztec_node.sh
else
    nohup /home/codespace/start_aztec_node.sh > /home/codespace/aztec.log 2>&1 &
fi

echo -e "${GREEN}${BOLD}Aztec node started successfully in background.${RESET}\n"
