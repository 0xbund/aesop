// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Errors {
    error FeeRateTooHigh();
    error InvalidFeeCollector();
    error InvalidPath();
    error Expired();
    error InsufficientOutputAmount();
    error V2InputExceedsMaximum();
    error V3InputExceedsMaximum();
    error SubtractionOverflow();
    error InsufficientInputAmount();
    error InvalidAmountOut();
    error AdditionOverflow();
    error InvalidInputToken();
    error InvalidNativeTokenAmount();
    error InvalidRatio();
    error InsufficientFeeAmount();
    error DeductFeeFailed();
    error RouterFeeRateTooLow();
    error InsufficientToken();
    error NativeTransferFailed();
    error SwapFailed(bytes revertData);
    error InvalidOutputRecipient();
}

