// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../interfaces/ISmartRouter.sol";

contract MockSmartRouter is ISmartRouter {
    function swapExactInput(
        address[] calldata path,
        string[] calldata poolVersion,
        uint256[] calldata versionLen,
        uint24[] calldata fees,
        SwapData calldata data
    ) external override returns (uint256[] memory amounts) {
        // 模拟交换，返回一个固定的输出金额数组
        amounts = new uint256[](path.length);
        for(uint i = 0; i < path.length; i++) {
            amounts[i] = data.amountIn; // 简单起见，返回相同的金额
        }
        return amounts;
    }
} 