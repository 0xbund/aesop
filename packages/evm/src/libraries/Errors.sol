// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Errors {
    error FeeRateTooHigh();
    error InvalidPath();
    error InsufficientOutputAmount();
    error InsufficientInputAmount();
    error InvalidInputToken();
    error InvalidNativeTokenAmount();
    error InvalidRatio();
    error InsufficientToken();
    error NativeTransferFailed();
    error SwapFailed(bytes revertData);
    error InvalidOutputRecipient();
}

