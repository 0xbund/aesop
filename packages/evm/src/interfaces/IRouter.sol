// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRouter {
    struct SwapExactInParams {
        address[] path;
        uint256 amountIn;
        uint256 v2AmountRatio;
        uint256 v3AmountRatio;
        uint256 v2AmountOutMin;
        uint256 v3AmountOutMin;
        uint24[] v3Fees;
        address to;
        uint256 deadline;
    }

    struct SwapExactOutParams {
        address[] path;
        uint256 v2AmountInMax;
        uint256 v3AmountInMax;
        uint256 v2AmountRatio;
        uint256 v3AmountRatio;
        uint256 amountOut;
        uint24[] v3Fees;
        address to;
        uint256 deadline;
    }

    struct OneInchSwapParams {
        bytes oneInchCallData;
        address inputToken;
        address outputToken;
        uint256 amountIn;
        uint256 minOutputAmount;
    }

    function swapExactIn(SwapExactInParams calldata params, uint256 routerFeeRate) external payable returns (uint256 v2AmountOut, uint256 v3AmountOut);
    function swapExactOut(SwapExactOutParams calldata params, uint256 routerFeeRate) external payable returns (uint256 v2AmountIn, uint256 v3AmountIn);
    function swapOn1inch(
        OneInchSwapParams calldata params,
        uint256 routerFeeRate
    ) external payable returns (uint256 returnAmount);
}
