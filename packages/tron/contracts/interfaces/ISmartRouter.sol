// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ISmartRouter {
    struct SwapData {
        uint256 amountIn;
        uint256 amountOutMin;
        address to;
        uint256 deadline;
    }

    function swapExactInput(
        address[] calldata path,
        string[] calldata poolVersion,
        uint256[] calldata versionLen,
        uint24[] calldata fees,
        SwapData calldata data
    ) external returns (uint256[] memory amounts);
}
