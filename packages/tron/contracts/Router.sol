// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./interfaces/IRouter.sol";
import "./RouterAccessControl.sol";
import "./interfaces/IWrappedToken.sol";
import "./interfaces/ISmartRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Router is IRouter {
    using SafeERC20 for IERC20;
    using Math for uint256;

    address public immutable smartRouter;
    address public immutable WRAPPED_TOKEN;
    address public admin;
    address public pendingAdmin;
    uint16 constant FEE_DENOMINATOR = 1e4;
    uint16 public feeRate;

    event FeeRateUpdated(uint16 newFeeRate);

    constructor(
        address _admin,
        address _smartRouter,
        address _WRAPPED_TOKEN,
        uint16 _initialFeeRate
    ) {
        smartRouter = _smartRouter;
        WRAPPED_TOKEN = _WRAPPED_TOKEN;
        feeRate = _initialFeeRate;
        admin = _admin;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "admin only");
        _;
    }

    function initiateAdminTransfer(address newAdmin) external onlyAdmin {
        pendingAdmin = newAdmin;
    }

    function acceptAdminTransfer() external {
        require(msg.sender == pendingAdmin, "not pending admin");
        admin = msg.sender;
        pendingAdmin = address(0);
    }
    
    function updateFeeRate(uint16 _newFeeRate) external onlyAdmin {
        feeRate = _newFeeRate;
        emit FeeRateUpdated(_newFeeRate);
    }

    function withdrawToken(
        address token,
        uint256 amount,
        address recipient
    ) public onlyAdmin {
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token");
        IERC20(token).transfer(recipient, amount);
    }

    function _approve(address token, uint256 amount) internal {
        // Check current allowance first
        uint256 currentAllowance = IERC20(token).allowance(
            address(this),
            smartRouter
        );
        if (currentAllowance < amount) {
            // If current allowance is not enough, approve max uint256
            IERC20(token).approve(smartRouter, type(uint256).max);
        }
    }

    function approve(address token, uint256 amount) external onlyAdmin {
        _approve(token, amount);
    }

    function swapExactIn(
        address[] calldata path,
        string[] calldata poolVersion,
        uint256[] calldata versionLen,
        uint24[] calldata fees,
        SwapData calldata data,
        uint16 routerFeeRate
    ) external payable override returns (uint256[] memory amountsOut) {
        uint16 _feeRate = routerFeeRate == 0 ? feeRate : routerFeeRate;
        amountsOut = _swapExactIn(
            path,
            poolVersion,
            versionLen,
            fees,
            data,
            _feeRate
        );
    }

    function _swapExactIn(
        address[] calldata path,
        string[] calldata poolVersion,
        uint256[] calldata versionLen,
        uint24[] calldata fees,
        SwapData calldata data,
        uint16 routerFeeRate
    ) internal returns (uint256[] memory amountsOut) {
        require(
            path[0] == WRAPPED_TOKEN || path[path.length - 1] == WRAPPED_TOKEN,
            "Unsupported path"
        );
        if (msg.value > 0) {
            require(path[0] == WRAPPED_TOKEN, "Unsupported path");
            require(data.amountIn == msg.value, "Amount mismatch");
            IWrappedToken(WRAPPED_TOKEN).deposit{value: data.amountIn}();
        } else {
            IERC20(path[0]).transferFrom(msg.sender, address(this), data.amountIn);
        }

        _approve(path[0], data.amountIn);

        address recipient = (path[0] == WRAPPED_TOKEN)
            ? data.to
            : address(this);
        uint256 swapAmount = data.amountIn;

        if (path[0] == WRAPPED_TOKEN) {
            (swapAmount, ) = _deductFee(data.amountIn, routerFeeRate);
        }

        amountsOut = _executeSwap(
            path,
            poolVersion,
            versionLen,
            fees,
            recipient,
            swapAmount,
            data
        );

        if (path[path.length - 1] == WRAPPED_TOKEN) {
            (uint256 remainingAmount, ) = _deductFee(
                amountsOut[amountsOut.length - 1],
                routerFeeRate
            );
            IWrappedToken(WRAPPED_TOKEN).transfer(recipient, remainingAmount);
        }
    }

    function _executeSwap(
        address[] calldata path,
        string[] calldata poolVersion,
        uint256[] calldata versionLen,
        uint24[] calldata fees,
        address recipient,
        uint256 swapAmount,
        SwapData calldata data
    ) internal returns (uint256[] memory amountsOut) {
        return
            ISmartRouter(smartRouter).swapExactInput(
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

    function _deductFee(
        uint256 amount,
        uint256 routerFeeRate
    ) internal pure returns (uint256, uint256) {
        uint256 feeAmount = amount.mulDiv(routerFeeRate, FEE_DENOMINATOR);
        return (amount - feeAmount, feeAmount);
    }
}
