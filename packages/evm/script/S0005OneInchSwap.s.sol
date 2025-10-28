// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "../src/interfaces/IRouter.sol";
import {Script, console} from "forge-std/Script.sol";

/// @notice Example script showing how to execute a `swapOn1inch` trade through the Router.
/// @dev All parameters are intentionally left blank so they can be filled in later.
contract S0005OneInchSwap is Script {
    function run() external {
        // --- Basic runtime configuration ---
        // User private key that will broadcast the transaction
        uint256 userPrivateKey = vm.envUint("S0005_USER_PRIVATE_KEY");
        // Chain identifier (purely for console output)
        string memory chain = vm.envString("CHAIN");
        // Router address that exposes `swapOn1inch`
        address routerAddress = vm.envAddress("S0002_ROUTER_ADDRESS");

        // --- 1inch swap parameters (TO-DO: fill in before running) ---
        bytes memory oneInchCallData = vm.parseBytes("0x07ed2379000000000000000000000000de9e4fe32b049f821c7f3e9802381aa470ffca730000000000000000000000000e09fabb73bd3ade0a17ecc321fd13a19e81ce82000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000de9e4fe32b049f821c7f3e9802381aa470ffca730000000000000000000000003ef630871dd8623e3d3a3d854ec0626518d8dc6400000000000000000000000000000000000000000000000000071afd498d000000000000000000000000000000000000000000000000000000000649097dc67b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000013900000000000000000000000000000000000000011b0001050000c900004e00a0744c8c090e09fabb73bd3ade0a17ecc321fd13a19e81ce8290cbe4bdd538d6e9b379bff5fe72c3d67a521de500000000000000000000000000000000000000000000000000000574fbde60000c200e09fabb73bd3ade0a17ecc321fd13a19e81ce82a527a61703d82139f8a06bc30097cc9caa2df5a66ae4071198001e8480a527a61703d82139f8a06bc30097cc9caa2df5a600000000000000000000000000000000000000000000000000000649097dc67b0e09fabb73bd3ade0a17ecc321fd13a19e81ce824101bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c00042e1a7d4d0000000000000000000000000000000000000000000000000000000000000000c061111111125421ca6dc452d289314280a0f8842a65000000000000003a070644");
        address inputToken = address(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);      // token you are swapping from
        address outputToken = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);     // token you are receiving
        uint256 amountIn = 2000000000000000;                 // amount of inputToken to swap (also msg.value if ETH)
        uint256 routerFeeRate = 0;
        uint256 minOutputAmount = 0; // set a reasonable minOut before running
        IRouter router = IRouter(routerAddress);

        // Broadcast the transaction
        vm.startBroadcast(userPrivateKey);
        uint256 returnAmount = router.swapOn1inch(
            IRouter.OneInchSwapParams({
                oneInchCallData: oneInchCallData,
                inputToken: inputToken,
                outputToken: outputToken,
                amountIn: amountIn,
                minOutputAmount: minOutputAmount
            }),
            routerFeeRate
        );
        vm.stopBroadcast();

        // --- Console output ---
        console.log("Swap via 1inch completed on chain: %s", chain);
        console.log("Router address: %s", routerAddress);
        console.log("ETH input amount: %d", amountIn);
        console.log("Input token: %s", inputToken);
        console.log("Output token: %s", outputToken);
        console.log("Return amount: %d", returnAmount);
    }
}