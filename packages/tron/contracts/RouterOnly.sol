// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IRouter.sol";
import "./interfaces/IWrappedToken.sol";
import "./interfaces/ISmartRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract RouterOnly is IRouter {
    using SafeERC20 for IERC20;
    using Math for uint256;

    address public immutable smartRouter;
    address public immutable WRAPPED_TOKEN;

    constructor(address _smartRouter, address _WRAPPED_TOKEN) {
        smartRouter = _smartRouter;
        WRAPPED_TOKEN = _WRAPPED_TOKEN;
    }

    function swapExactIn(
        address[] calldata path,
        string[] calldata poolVersion,
        uint256[] calldata versionLen,
        uint24[] calldata fees,
        SwapData calldata data,
        uint16 routerFeeRate
    ) external payable override returns (uint256[] memory amountsOut) {
        amountsOut = _swapExactIn(
            path,
            poolVersion,
            versionLen,
            fees,
            data,
            routerFeeRate
        );
    }

    function _approve(address token, uint256 amount) internal {
        // Check current allowance first
        uint256 currentAllowance = IERC20(token).allowance(address(this), smartRouter);
        if (currentAllowance < amount) {
            // If current allowance is not enough, approve max uint256
            IERC20(token).approve(smartRouter, type(uint256).max);
        }
    }

    function approve(address token, uint256 amount) external {
        _approve(token, amount);
    }

    function _swapExactIn(
        address[] calldata path,
        string[] calldata poolVersion,
        uint256[] calldata versionLen,
        uint24[] calldata fees,
        SwapData calldata data,
        uint16 routerFeeRate
    ) internal returns (uint256[] memory amountsOut) {
        if (msg.value > 0) {
            require(path[0] == WRAPPED_TOKEN, "Unsupported path");
            require(data.amountIn == msg.value, "Amount mismatch");
            IWrappedToken(WRAPPED_TOKEN).deposit{value: data.amountIn}();
        } else {
            IERC20(path[0]).transferFrom(msg.sender, address(this), data.amountIn);
        }

        // Call approve function
        _approve(path[0], data.amountIn);

        address recipient = (path[0] == WRAPPED_TOKEN)
            ? data.to
            : address(this);
        uint256 swapAmount = data.amountIn;

        amountsOut = ISmartRouter(smartRouter).swapExactInput(
                path,
                poolVersion,
                versionLen,
                fees,
                ISmartRouter.SwapData({
                    amountIn: swapAmount,
                    amountOutMin: data.amountOutMin,
                    to: recipient,
                    deadline: data.deadline
                })
            );
    }
}
