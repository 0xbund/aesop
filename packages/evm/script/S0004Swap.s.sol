// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "../src/interfaces/IRouter.sol";
import {Script, console} from "forge-std/Script.sol";

contract S0004Swap is Script {
    function run() external {
        uint256 userPrivateKey = vm.envUint("S0004_USER_PRIVATE_KEY");
        string memory chain = vm.envString("CHAIN");
        address routerAddress = vm.envAddress("S0002_ROUTER_ADDRESS");
        address WETH = vm.envAddress("S0004_WETH");  // WETH 地址
        address tokenOut = vm.envAddress("S0004_TOKEN_OUT");
        uint256 amountIn = vm.envUint("S0004_AMOUNT_IN");
        uint256 v2Ratio = vm.envUint("S0004_V2_RATIO"); // 例如 5000 表示 50%
        uint256 v3Ratio = 10000 - v2Ratio; // 剩余比例分配给 V3
        uint24[] memory v3Fees = new uint24[](1);
        v3Fees[0] = uint24(vm.envUint("S0004_V3_FEE")); // 例如 3000 表示 0.3%

        // 构建 swap 路径
        address[] memory path = new address[](2);
        path[0] = WETH;  // 输入是 WETH
        path[1] = tokenOut;

        // 计算最小输出金额（基于滑点）
        uint256 v2AmountOutMin = 0;
        uint256 v3AmountOutMin = 0;

        // 构建 swap 参数
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            amountIn: amountIn,
            v2AmountOutMin: v2AmountOutMin,
            v3AmountOutMin: v3AmountOutMin,
            path: path,
            v2AmountRatio: v2Ratio,
            v3AmountRatio: v3Ratio,
            v3Fees: v3Fees,
            to: msg.sender,
            deadline: block.timestamp + 1200 // 20分钟超时
        });

        IRouter router = IRouter(routerAddress);
        
        vm.startBroadcast(userPrivateKey);
        (uint256 v2AmountOut, uint256 v3AmountOut) = router.swapExactIn{value: amountIn}(params, 0);
        vm.stopBroadcast();

        console.log("Swap completed on chain: %s", chain);
        console.log("Router address: %s", routerAddress);
        console.log("ETH input amount: %d", amountIn);
        console.log("Token out: %s", tokenOut);
        console.log("V2 output: %d", v2AmountOut);
        console.log("V3 output: %d", v3AmountOut);
        console.log("Total output: %d", v2AmountOut + v3AmountOut);
    }
} 