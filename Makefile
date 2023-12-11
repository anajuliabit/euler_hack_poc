include .env

exploit:
	forge t --mt "test_Attack"

invariant:
	forge t --mt "invariant_NeverInsolvent"

echidna:
	export ETHERSCAN_API_KEY=$(ETHERSCAN_API_KEY) && export ECHIDNA_RPC_URL=$(MAINNET_RPC_URL) && echidna test/echidna/EchidnaInvariant.t.sol --config test/echidna/config.yaml --contract InvariantTestEchidna
