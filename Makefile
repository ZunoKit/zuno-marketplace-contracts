# Foundry Marketplace Deployment Commands

# Start local anvil node
start-anvil:; @anvil  --port 8545

# Deploy all contracts to local network (anvil) - RECOMMENDED
deploy-all-local:; @forge script script/DeployAll.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast;

update-abi:; @node extract-abis.js;

