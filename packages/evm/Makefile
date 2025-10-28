ARBI_RPC := ""
ETH_RPC := ""
SEPOLIA_RPC := ""
BSC_RPC := ""
test_arbi:
	forge test -vv --gas-report --fork-url ${ARBI_RPC} --fork-block-number 264602864 --match-path test/ArbiRouterTest.t.sol

test_eth:
	forge test -vv --gas-report --fork-url ${ETH_RPC} --fork-block-number 21000000 --match-path test/ETHRouterTest.t.sol

test_eth_oneinch:
	forge test -vv --gas-report --match-path test/RouterOneInchSwap.t.sol

test_bsc:
	forge test -vv --gas-report --fork-url ${BSC_RPC} --fork-block-number 47550005 --match-path test/BSCRouterTest.t.sol

test_accesscontrol:
	forge test -vv --match-contract RouterAccessControlTest

test_all: test_arbi test_eth test_bsc

build:
	-rm -rf out
	-rm -rf abi
	forge build --force --names --sizes

read_chain:
	$(eval CHAIN := $(shell read -p "Please enter the chain: " CHAIN;echo "$$CHAIN"))
	$(eval RPC := $(shell if [ "${CHAIN}" == "Eth" ]; then \
        		echo ${ETH_RPC}; \
        	elif [ "${CHAIN}" == "Bsc" ]; then \
        		echo ${BSC_RPC}; \
        	elif [ "${CHAIN}" == "Arbi" ]; then \
        		echo ${ARBI_RPC}; \
        	elif [ "${CHAIN}" == "Mantle" ]; then \
        		echo ${MANTLE_RPC}; \
        	elif [ "${CHAIN}" == "Sepolia" ]; then \
        		echo ${SEPOLIA_RPC}; \
        	fi))

read_args: read_chain
	$(eval ARGS := $(shell \
                       read -p "Do you want to simulate on chain, Y/N? " SIMULATE; \
                       if [ "$$SIMULATE" == "Y" ]; then \
                         RPC_OPT="--rpc-url ${RPC}"; \
					   fi; \
                       read -p "Do you want to broadcast on chain, Y/N? " BROADCAST; \
                       if [ "$$BROADCAST" == "Y" ]; then \
                       	  read -p "Please reenter the chain to deploy for confirmation: " CONFIRM; \
                          if [ "$$CONFIRM" != "${CHAIN}" ]; then \
                            echo "${CHAIN} and $$CONFIRM are not matched"; \
                            exit 1; \
                          fi; \
                          BROADCAST_OPT="--broadcast"; \
                       fi; \
                       read -p "Please enter the gas multiplier: " GAS_MULTIPLIER; \
                       if [ -n "$$GAS_MULTIPLIER" ]; then \
                           GAS_MULTIPLIER_OPT="--gas-estimate-multiplier $$GAS_MULTIPLIER"; \
                       fi; \
                       read -p "Please enter the gas price: " GAS_PRICE; \
                       if [ -n "$$GAS_PRICE" ]; then \
                         GAS_PRICE_OPT="--with-gas-price $$GAS_PRICE"; \
                       fi; \
                       echo "$$RPC_OPT $$BROADCAST_OPT $$GAS_MULTIPLIER_OPT $$GAS_PRICE_OPT" \
                       ) \
    )

deploy_router: read_args
	@read -ra ARR <<< "${ARGS}"; \
	set -x; \
	CHAIN=${CHAIN} forge script script/S0001DeployRouter.s.sol $${ARR[@]}

initiate_admin_transfer: read_args
	@read -ra ARR <<< "${ARGS}"; \
	set -x; \
	CHAIN=${CHAIN} forge script script/S0002InitiateAdminTransfer.s.sol $${ARR[@]}

swap: read_args
	@read -ra ARR <<< "${ARGS}"; \
	set -x; \
	CHAIN=${CHAIN} forge script script/S0004Swap.s.sol $${ARR[@]}

oneinch_swap: read_args
	@read -ra ARR <<< "${ARGS}"; \
	set -x; \
	CHAIN=${CHAIN} forge script script/S0005OneInchSwap.s.sol $${ARR[@]}

oneinch_approve: read_args
	@read -ra ARR <<< "${ARGS}"; \
	set -x; \
	CHAIN=${CHAIN} forge script script/S0006ApproveOneInch.s.sol $${ARR[@]}