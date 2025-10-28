// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

library Errors {
    error FeeRateTooHigh();
    error InvalidFeeCollector();
    error InvalidPath();
    error Expired();
    error InsufficientOutputAmount();
    error V2InputExceedsMaximum();
    error V3InputExceedsMaximum();
    error SubtractionOverflow();
    error AdditionOverflow();
    error InvalidInputToken();
    error InvalidEthAmount();
    error InvalidRatio();
    error InsufficientFeeAmount();
    error DeductFeeFailed();
    error RouterFeeRateTooLow();
}

