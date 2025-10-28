// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockOneInchRouter
/// @notice Simulate 1inch behavior: parse calldata (inputToken, outputToken, amountIn) and swap with 1:2 ratio
/// Supported scenarios:
/// 1) Native -> ERC20
/// 2) Wrapped native (ERC20) -> ERC20
/// 3) ERC20 -> Native
/// 4) ERC20 -> Wrapped native (ERC20)
contract MockOneInchRouter is Ownable {
    // Custom selectors (re-using common 1inch swap selectors for identification only)
    bytes4 private constant SWAP_SELECTOR = 0x7c025200;
    bytes4 private constant UNOSWAP_SELECTOR = 0x0502b1c5;

    // Native token placeholder (common convention)
    address public constant NATIVE_PLACEHOLDER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event SwapExecuted(bytes4 selector, address inputToken, address outputToken, uint256 amountIn, uint256 amountOut);

    // Extra ETH to return back to caller after swap, used to simulate aggregator refunding dust/native surplus
    uint256 public extraEthToReturn;

    constructor() Ownable(msg.sender) {}

    /// @notice Fallback parses calldata: (inputToken, outputToken, amountIn)
    /// - If input is native placeholder, requires msg.value == amountIn
    /// - If input is ERC20, pull amountIn from msg.sender (must be pre-approved)
    /// - Output = amountIn * 2; if output is native placeholder, send ETH; otherwise transfer ERC20
    fallback() external payable {
        bytes4 selector = bytes4(msg.data[:4]);
        require(selector == SWAP_SELECTOR || selector == UNOSWAP_SELECTOR, "Mock1inch: bad selector");

        // Decode calldata after the 4-byte selector as (inputToken, outputToken, amountIn)
        bytes memory args = new bytes(msg.data.length - 4);
        assembly {
            calldatacopy(add(args, 32), 4, sub(calldatasize(), 4))
        }
        (address inputToken, address outputToken, uint256 amountIn) = abi.decode(args, (address, address, uint256));
        require(amountIn > 0, "Mock1inch: amountIn = 0");

        // 1) Handle input side
        if (inputToken == NATIVE_PLACEHOLDER) {
            // Native input: receive ETH
            require(msg.value == amountIn, "Mock1inch: bad msg.value");
        } else {
            // ERC20 input: pull from caller (typically the Router)
            require(IERC20(inputToken).transferFrom(msg.sender, address(this), amountIn), "Mock1inch: transferFrom failed");
        }

        // 2) Compute output (fixed 1:2)
        uint256 amountOut = amountIn * 2;

        // 3) Send output to caller
        if (outputToken == NATIVE_PLACEHOLDER) {
            require(address(this).balance >= amountOut, "Mock1inch: insufficient ETH");
            (bool ok, ) = payable(msg.sender).call{value: amountOut}("");
            require(ok, "Mock1inch: ETH transfer failed");
        } else {
            require(IERC20(outputToken).transfer(msg.sender, amountOut), "Mock1inch: ERC20 transfer failed");
        }

        // Optionally send extra ETH back to caller to simulate surplus refunds from aggregator
        if (extraEthToReturn > 0) {
            require(address(this).balance >= extraEthToReturn, "Mock1inch: insufficient ETH for extra return");
            (bool ok2, ) = payable(msg.sender).call{value: extraEthToReturn}("");
            require(ok2, "Mock1inch: extra ETH return failed");
        }

        emit SwapExecuted(selector, inputToken, outputToken, amountIn, amountOut);

        // Simulate 1inch return (returnAmount, spentAmount)
        bytes memory returnData = abi.encode(amountOut, amountIn);
        assembly {
            return(add(returnData, 0x20), mload(returnData))
        }
    }

    /// @notice Receive ETH (funding for tests)
    receive() external payable {}

    /// @notice Withdraw ETH (test maintenance)
    function withdrawETH(uint256 amount) external onlyOwner {
        (bool ok, ) = payable(owner()).call{value: amount}("");
        require(ok, "withdraw ETH failed");
    }

    /// @notice Withdraw arbitrary ERC20 (test maintenance)
    function withdrawToken(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(owner(), amount), "withdraw token failed");
    }

    /// @notice Configure extra ETH amount that will be returned to caller after each swap
    function setExtraEthToReturn(uint256 amount) external onlyOwner {
        extraEthToReturn = amount;
    }
}