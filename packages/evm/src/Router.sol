// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IRouter.sol";  
import "./RouterAccessControl.sol";
import "./libraries/Errors.sol";
import "./interfaces/IWrappedToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/// @title Router Contract for Cross-DEX Trading
/// @notice Handles token swaps across Uniswap V2 and V3 with customizable ratios
/// @dev Implements fee collection and admin controls
contract Router is Context, IRouter, RouterAccessControl {
    using SafeERC20 for IERC20;
    using Math for uint256;

    address public immutable v2Router;
    address public immutable v3Router;
    address public immutable oneInchRouter;
    address public immutable WRAPPED_TOKEN;
    address public immutable USDT_TOKEN;
    address public immutable NATIVE_PLACEHOLDER;
    uint256 constant RATIO_DENOMINATOR = 1e4;
    uint256 constant FEE_DENOMINATOR = 1e4;
    uint256 public feeRate;

    mapping(address => bool) public supportedTokens;

    event FeeRateUpdated(uint256 newFeeRate);
    event TokenSupported(address token);
    event TokenUnsupported(address token);
    event Swap(address indexed sender, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    /// @notice Initializes the router contract
    /// @param admin Address of the admin
    /// @param _v2Router Address of Uniswap V2 router
    /// @param _v3Router Address of Uniswap V3 router
    /// @param _WRAPPED_TOKEN Address of the wrapped native token (e.g. WETH)
    /// @param _USDT_TOKEN Address of USDT token used in the platform
    /// @param _initialFeeRate Initial fee rate in basis points
    /// @param _oneInchRouter Address of 1inch GenericRouter (v6)
    constructor(
        address admin,
        address _v2Router,
        address _v3Router,
        address _oneInchRouter,
        address _WRAPPED_TOKEN,
        address _USDT_TOKEN,
        address _NATIVE_PLACEHOLDER,
        uint256 _initialFeeRate
    ) RouterAccessControl(admin) {
        v2Router = _v2Router;
        v3Router = _v3Router;
        oneInchRouter = _oneInchRouter;
        WRAPPED_TOKEN = _WRAPPED_TOKEN;
        USDT_TOKEN = _USDT_TOKEN;
        NATIVE_PLACEHOLDER = _NATIVE_PLACEHOLDER;
        feeRate = _initialFeeRate;
        supportedTokens[_WRAPPED_TOKEN] = true;
        supportedTokens[_USDT_TOKEN] = true;
        supportedTokens[NATIVE_PLACEHOLDER] = true;
    }

    /// @notice Swaps exact input amount with custom fee rate
    /// @param params Parameters for the swap
    /// @param routerFeeRate Custom fee rate to use for this swap
    /// @return v2AmountOut Amount of tokens received from V2 swap
    /// @return v3AmountOut Amount of tokens received from V3 swap
    function swapExactIn(
        SwapExactInParams calldata params,
        uint256 routerFeeRate
    )
        external
        payable
        override
        returns (uint256 v2AmountOut, uint256 v3AmountOut)
    {
        uint256 actualFeeRate = routerFeeRate == 0 ? feeRate : routerFeeRate;
        return _swapExactIn(params, actualFeeRate);
    }

    /// @notice Internal function to handle exact input swaps
    /// @param params Parameters for the swap
    /// @param routerFeeRate Fee rate to use for this swap
    /// @return v2AmountOut Amount of tokens received from V2 swap
    /// @return v3AmountOut Amount of tokens received from V3 swap
    function _swapExactIn(
        SwapExactInParams calldata params,
        uint256 routerFeeRate
    ) internal returns (uint256 v2AmountOut, uint256 v3AmountOut) {
        if (params.path.length < 2) revert Errors.InvalidPath();
        if (params.v2AmountRatio + params.v3AmountRatio != RATIO_DENOMINATOR)
            revert Errors.InvalidRatio();
        if (!supportedTokens[params.path[0]] && !supportedTokens[params.path[params.path.length - 1]]) 
            revert Errors.InvalidInputToken();

        address inputToken = params.path[0];
        address outputToken = params.path[params.path.length - 1];
        bool isInputSupported = supportedTokens[inputToken];
        bool isOutputSupported = supportedTokens[outputToken];

        if (msg.value > 0) {
            if (inputToken != WRAPPED_TOKEN) revert Errors.InvalidInputToken();
            if (params.amountIn != msg.value) revert Errors.InvalidNativeTokenAmount();
            IWrappedToken(WRAPPED_TOKEN).deposit{value: params.amountIn}();
        } else {
            IERC20(inputToken).safeTransferFrom(_msgSender(), address(this), params.amountIn);
        }

        // If input token is supported, collect fee from input amount
        // Otherwise collect fee from output amount
        // If output is WETH, always use contract address to enable ETH conversion
        address recipient = (isInputSupported && outputToken != WRAPPED_TOKEN) ? params.to : address(this);

        uint256 swapAmount = params.amountIn;
        if (isInputSupported) {
            (swapAmount, ) = _calculateFee(params.amountIn, routerFeeRate);
        }

        uint256 v2AmountIn = swapAmount.mulDiv(
            params.v2AmountRatio,
            RATIO_DENOMINATOR
        );
        uint256 v3AmountIn = swapAmount - v2AmountIn;

        if (v2AmountIn > 0) {
            v2AmountOut = _swapExactInV2(
                v2AmountIn,
                params.v2AmountOutMin,
                params.path,
                recipient,
                params.deadline
            );
        }

        if (v3AmountIn > 0) {
            v3AmountOut = _swapExactInV3(
                v3AmountIn,
                params.v3AmountOutMin,
                params.path,
                params.v3Fees,
                recipient,
                params.deadline
            );
        }

        uint256 totalOutput = v2AmountOut + v3AmountOut;

        // If input token is not supported but output token is supported,
        // collect fee from output amount
        if (!isInputSupported && isOutputSupported) {
            (uint256 remainingAmount, ) = _calculateFee(
                totalOutput,
                routerFeeRate
            );
            // Check if output token is WETH and automatically convert to ETH
            if (outputToken == WRAPPED_TOKEN) {
                IWrappedToken(WRAPPED_TOKEN).withdraw(remainingAmount);
                _transferNativeToken(params.to, remainingAmount);
            } else {
                IERC20(outputToken).safeTransfer(params.to, remainingAmount);
            }
        } else if (isInputSupported && outputToken == WRAPPED_TOKEN) {
            // If output is WETH and no fee collection needed, convert to ETH
            IWrappedToken(WRAPPED_TOKEN).withdraw(totalOutput);
            _transferNativeToken(params.to, totalOutput);
        }

        return (v2AmountOut, v3AmountOut);
    }

    /// @notice Swaps tokens to receive exact output amount with custom fee rate
    /// @param params Parameters for the swap
    /// @param routerFeeRate Custom fee rate to use for this swap
    /// @return v2AmountIn Amount of tokens spent in V2 swap
    /// @return v3AmountIn Amount of tokens spent in V3 swap
    function swapExactOut(
        SwapExactOutParams calldata params,
        uint256 routerFeeRate
    )
        external
        payable
        override
        returns (uint256 v2AmountIn, uint256 v3AmountIn)
    {
        uint256 actualFeeRate = routerFeeRate == 0 ? feeRate : routerFeeRate;
        return _swapExactOut(params, actualFeeRate);
    }

    /// @notice Internal function to handle exact output swaps
    /// @param params Parameters for the swap
    /// @param routerFeeRate Fee rate to use for this swap
    /// @return v2AmountIn Amount of tokens spent in V2 swap
    /// @return v3AmountIn Amount of tokens spent in V3 swap
    function _swapExactOut(
        SwapExactOutParams calldata params,
        uint256 routerFeeRate
    ) internal returns (uint256 v2AmountIn, uint256 v3AmountIn) {
        if (params.path.length < 2) revert Errors.InvalidPath();
        if (params.v2AmountRatio + params.v3AmountRatio != RATIO_DENOMINATOR)
            revert Errors.InvalidRatio();
        if (!supportedTokens[params.path[0]] && !supportedTokens[params.path[params.path.length - 1]])
            revert Errors.InvalidInputToken();
        if (routerFeeRate >= FEE_DENOMINATOR) revert Errors.FeeRateTooHigh();

        address inputToken = params.path[0];
        address outputToken = params.path[params.path.length - 1];
        bool isInputSupported = supportedTokens[inputToken];
        bool isOutputSupported = supportedTokens[outputToken];
        uint256 actualMaxAmountIn = params.v2AmountInMax + params.v3AmountInMax;

        // Handle ETH/WETH input
        if (msg.value > 0) {
            if (inputToken != WRAPPED_TOKEN) revert Errors.InvalidInputToken();
            if (actualMaxAmountIn != msg.value) revert Errors.InvalidNativeTokenAmount();
            IWrappedToken(WRAPPED_TOKEN).deposit{value: msg.value}();
        } else {
            IERC20(inputToken).safeTransferFrom(_msgSender(), address(this), actualMaxAmountIn);
        }

        // Calculate target output amount based on whether output token is supported
        uint256 targetAmountOut = params.amountOut;
        uint256 feeAmount;
        if (isOutputSupported) {
            // If output token is supported, calculate how much we need to swap to give user params.amountOut after fee
            // Formula: targetAmountOut = params.amountOut / (1 - feeRate), using ceil rounding
            targetAmountOut = Math.mulDiv(params.amountOut, FEE_DENOMINATOR, FEE_DENOMINATOR - routerFeeRate, Math.Rounding.Ceil);
            feeAmount = targetAmountOut - params.amountOut;
        }

        // Determine recipient based on whether output token is supported
        // If output is WETH, always use contract address to enable ETH conversion
        address recipient = (isOutputSupported || outputToken == WRAPPED_TOKEN) ? address(this) : params.to;

        // Calculate amounts for V2 and V3
        uint256 v2AmountOut = params.v2AmountRatio == 0 ? 0 : targetAmountOut.mulDiv(
            params.v2AmountRatio,
            RATIO_DENOMINATOR
        );
        uint256 v3AmountOut = targetAmountOut - v2AmountOut;

        // Execute V2 swap if needed
        if (v2AmountOut > 0) {
            v2AmountIn = _swapExactOutV2(
                params.v2AmountInMax,
                v2AmountOut,
                params.path,
                recipient,
                params.deadline
            );
        }

        // Execute V3 swap if needed
        if (v3AmountOut > 0) {
            v3AmountIn = _swapExactOutV3(
                params.v3AmountInMax,
                v3AmountOut,
                params.path,
                params.v3Fees,
                recipient,
                params.deadline
            );
        }

        uint256 totalAmountIn = v2AmountIn + v3AmountIn;
        // if (actualMaxAmountIn < totalAmountIn + feeAmount) revert Errors.InsufficientInputAmount();

        // Handle fee collection and token transfer
        if (isInputSupported && !isOutputSupported) {
            // Collect fee from input amount
            feeAmount = totalAmountIn * routerFeeRate / (FEE_DENOMINATOR - routerFeeRate);
            if (actualMaxAmountIn < totalAmountIn + feeAmount) revert Errors.InsufficientInputAmount();

            uint256 remainingInput = actualMaxAmountIn - totalAmountIn - feeAmount;
            
            // Return unused tokens to user
            _refundInputToken(inputToken, params.to, remainingInput);
        }

        if (isOutputSupported) {
            // Refund unused input, favoring native ETH when msg.value supplied
            uint256 refundAmount = actualMaxAmountIn - totalAmountIn;
            _refundInputToken(inputToken, params.to, refundAmount);
            // Transfer output amount minus fee to user
            uint256 remainingAmount = targetAmountOut - feeAmount;
            // Check if output token is WETH and automatically convert to ETH
            if (outputToken == WRAPPED_TOKEN) {
                IWrappedToken(WRAPPED_TOKEN).withdraw(remainingAmount);
                _transferNativeToken(params.to, remainingAmount);
            } else {
                IERC20(outputToken).safeTransfer(params.to, remainingAmount);
            }
        }

        return (v2AmountIn, v3AmountIn);
    }

    function _refundInputToken(address inputToken, address recipient, uint256 amount) internal {
        if (amount == 0) return;
        if (msg.value > 0) {
            IWrappedToken(WRAPPED_TOKEN).withdraw(amount);
            _transferNativeToken(recipient, amount);
        } else {
            IERC20(inputToken).safeTransfer(recipient, amount);
        }
    }

    /// @notice Clear token allowance for a specific spender
    /// @dev Used to eliminate residual allowance after external DEX interactions
    /// @param token Token address to clear allowance for
    /// @param spender Spender address (router) to clear allowance from
    function _clearApproval(address token, address spender) internal {
        IERC20(token).forceApprove(spender, 0);
    }

    /// @notice Executes swap on Uniswap V2 with exact input
    /// @param amountIn Amount of input tokens
    /// @param amountOutMin Minimum amount of output tokens to receive
    /// @param path Array of token addresses for the swap path
    /// @param to Recipient address
    /// @param deadline Timestamp after which the transaction will revert
    /// @return Amount of output tokens received
    function _swapExactInV2(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) internal returns (uint256) {
        IUniswapV2Router02 v2RouterContract = IUniswapV2Router02(v2Router);
        IERC20(path[0]).safeIncreaseAllowance(v2Router, amountIn);
        uint256[] memory amounts = v2RouterContract.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
        _clearApproval(path[0], v2Router);
        return amounts[amounts.length - 1];
    }

    /// @notice Executes swap on Uniswap V3 with exact input
    /// @param amountIn Amount of input tokens
    /// @param amountOutMinimum Minimum amount of output tokens to receive
    /// @param path Array of token addresses for the swap path
    /// @param fees Array of fee tiers for each hop
    /// @param to Recipient address
    /// @param deadline Timestamp after which the transaction will revert
    /// @return Amount of output tokens received
    function _swapExactInV3(
        uint256 amountIn,
        uint256 amountOutMinimum,
        address[] calldata path,
        uint24[] calldata fees,
        address to,
        uint256 deadline
    ) internal returns (uint256) {
        ISwapRouter swapRouter = ISwapRouter(v3Router);
        IERC20(path[0]).safeIncreaseAllowance(address(swapRouter), amountIn);
        bytes memory encodedPath = _encodeV3Path(path, fees);
        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: encodedPath,
                recipient: to,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum
            });

        uint256 amountOut = swapRouter.exactInput(params);
        _clearApproval(path[0], address(swapRouter));
        return amountOut;
    }

    /// @notice Executes swap on Uniswap V2 with exact output
    /// @param amountInMax Maximum amount of input tokens to spend
    /// @param amountOut Exact amount of output tokens to receive
    /// @param path Array of token addresses for the swap path
    /// @param to Recipient address
    /// @param deadline Timestamp after which the transaction will revert
    /// @return Amount of input tokens spent
    function _swapExactOutV2(
        uint256 amountInMax,
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) internal returns (uint256) {
        IUniswapV2Router02 v2RouterContract = IUniswapV2Router02(v2Router);
        IERC20(path[0]).safeIncreaseAllowance(v2Router, amountInMax);
        uint256[] memory amounts = v2RouterContract.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            to,
            deadline
        );
        _clearApproval(path[0], v2Router);
        return amounts[0];
    }

    /// @notice Executes swap on Uniswap V3 with exact output
    /// @param amountInMaximum Maximum amount of input tokens to spend
    /// @param amountOut Exact amount of output tokens to receive
    /// @param path Array of token addresses for the swap path
    /// @param fees Array of fee tiers for each hop
    /// @param to Recipient address
    /// @param deadline Timestamp after which the transaction will revert
    /// @return Amount of input tokens spent
    function _swapExactOutV3(
        uint256 amountInMaximum,
        uint256 amountOut,
        address[] calldata path,
        uint24[] calldata fees,
        address to,
        uint256 deadline
    ) internal returns (uint256) {
        ISwapRouter swapRouter = ISwapRouter(v3Router);
        IERC20(path[0]).safeIncreaseAllowance(
            address(swapRouter),
            amountInMaximum
        );
        bytes memory encodedPath = _encodeV3PathReverse(path, fees);
        ISwapRouter.ExactOutputParams memory params = ISwapRouter
            .ExactOutputParams({
                path: encodedPath,
                recipient: to,
                deadline: deadline,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum
            });
        uint256 amountIn = swapRouter.exactOutput(params);
        _clearApproval(path[0], address(swapRouter));
        return amountIn;
    }

    /// @notice Calculates fee amount based on input amount and fee rate
    /// @param amount Input amount to calculate fee for
    /// @param routerFeeRate Fee rate to use for calculation
    /// @return Remaining amount after fee and fee amount
    function _calculateFee(
        uint256 amount,
        uint256 routerFeeRate
    ) internal pure returns (uint256, uint256) {
        uint256 feeAmount = amount.mulDiv(routerFeeRate, FEE_DENOMINATOR);
        return (amount - feeAmount, feeAmount);
    }

    /// @notice Encodes path for Uniswap V3 exact input swaps
    /// @param path Array of token addresses
    /// @param fees Array of fee tiers
    /// @return Encoded path bytes
    function _encodeV3Path(
        address[] calldata path,
        uint24[] calldata fees
    ) internal pure returns (bytes memory) {
        bytes memory encoded = abi.encodePacked(path[0]);
        for (uint256 i = 0; i < fees.length; i++) {
            encoded = abi.encodePacked(encoded, fees[i], path[i + 1]);
        }
        return encoded;
    }

    /// @notice Encodes path for Uniswap V3 exact output swaps
    /// @param path Array of token addresses
    /// @param fees Array of fee tiers
    /// @return Encoded path bytes
    function _encodeV3PathReverse(
        address[] calldata path,
        uint24[] calldata fees
    ) internal pure returns (bytes memory) {
        bytes memory encoded = abi.encodePacked(path[path.length - 1]);
        for (uint256 i = fees.length; i > 0; i--) {
            encoded = abi.encodePacked(encoded, fees[i - 1], path[i - 1]);
        }
        return encoded;
    }

    /// @notice Pass-through 1inch calldata while safely collecting the fee.
    /// @dev
    ///      ‣ If `params.inputToken` is in `supportedTokens`, the fee is charged on the input side.
    ///      ‣ Otherwise, if `params.outputToken` is in `supportedTokens`, the fee is charged on the output side.
    ///      ‣ At least one of input or output must be supported; otherwise the call reverts.
    ///      ‣ Any 1inch selector is supported; this contract only validates balance deltas.
    ///      ‣ For native ETH as input, set `srcToken` to `NATIVE_PLACEHOLDER` and pass equal `msg.value`.
    ///      ‣ If `params.outputToken` is `NATIVE_PLACEHOLDER`, the function returns ETH to the caller.
    /// @param params Struct containing 1inch calldata, tokens, amountIn and minOutputAmount.
    /// @param routerFeeRate Fee rate to override the default (0 to use default `feeRate`).
    /// @return returnAmount The actual `outputToken` amount sent to the user after fees.
    function swapOn1inch(
        OneInchSwapParams calldata params,
        uint256 routerFeeRate
    ) external payable override returns (uint256 returnAmount) {
        (bool isInputSupported, bool isOutputSupported, bool isInputNative, bool isOutputNative) = _checkOneInch(
            params.inputToken,
            params.outputToken,
            params.amountIn
        );

        uint256 actualFeeRate = routerFeeRate == 0 ? feeRate : routerFeeRate;
        uint256 amountToSwap = params.amountIn;
        uint256 fee;
        if (isInputSupported) {
            (amountToSwap, fee) = _calculateFee(params.amountIn, actualFeeRate);
        }

        if (!isInputNative) {
            _approve(oneInchRouter, params.inputToken, amountToSwap);
        }

        // Snapshot ETH before calling out, used for surplus refund check and as output snapshot when output is native
        uint256 ethBefore = (isInputNative || isOutputNative) ? address(this).balance : 0;
        // Snapshot input ERC20 balance before calling out to detect unspent input and refund it later
        uint256 inputTokenBalanceBefore = isInputNative ? 0 : IERC20(params.inputToken).balanceOf(address(this));
        // Snapshot caller's balance to ensure aggregator cannot bypass fee by sending output directly to user
        uint256 userOutputBalanceBefore = isOutputNative
            ? _msgSender().balance
            : IERC20(params.outputToken).balanceOf(_msgSender());
        uint256 outputTokenAmountBefore = isOutputNative
            ? ethBefore
            : IERC20(params.outputToken).balanceOf(address(this));

        _callOneInch(
            params.oneInchCallData,
            amountToSwap,
            isInputNative
        );

        if (!isInputNative) {
            _clearApproval(params.inputToken, oneInchRouter);
        }

        // Enforce that no output was sent directly to the user during the external call
        uint256 userOutputBalanceAfter = isOutputNative
            ? _msgSender().balance
            : IERC20(params.outputToken).balanceOf(_msgSender());
        if (userOutputBalanceAfter > userOutputBalanceBefore) revert Errors.InvalidOutputRecipient();

        uint256 outputTokenAmountAfter = isOutputNative ? 
            address(this).balance - outputTokenAmountBefore : 
            IERC20(params.outputToken).balanceOf(address(this)) - outputTokenAmountBefore;
        if (!isInputSupported && isOutputSupported) {
            (outputTokenAmountAfter, fee) = _calculateFee(outputTokenAmountAfter, actualFeeRate);
        }

        if (isOutputNative) {
            _transferNativeToken(_msgSender(), outputTokenAmountAfter);
        } else {
            IERC20(params.outputToken).safeTransfer(_msgSender(), outputTokenAmountAfter);
        }
        // Set named return value
        returnAmount = outputTokenAmountAfter;

        // Enforce slippage/out-amount check (after fee if fee is taken on output side)
        if (returnAmount < params.minOutputAmount) revert Errors.InsufficientOutputAmount();

        // Refund any surplus native ETH that shouldn't stay in the contract
        if (isInputNative || isOutputNative) {
            uint256 sentOut = isInputNative ? amountToSwap : 0;
            bool isEthFee = (isInputNative && isInputSupported) || (isOutputNative && isOutputSupported);
            uint256 expectedEth = isEthFee ? fee : 0;
            _refundSurplusNativeToken(ethBefore, sentOut, expectedEth);
        }

        // Refund any surplus ERC20 input tokens that were not spent by 1inch
        if (!isInputNative) {
            uint256 expectedRetention = isInputSupported ? fee : 0; // keep fee in-contract if fee is charged on input side
            _refundSurplusErc20Token(params.inputToken, params.amountIn, inputTokenBalanceBefore, expectedRetention);
        }

        emit Swap(
            _msgSender(), 
            _normalizeTokenForEvent(params.inputToken), 
            _normalizeTokenForEvent(params.outputToken), 
            amountToSwap, 
            returnAmount
        );

        return returnAmount;
    }

    /// @dev Normalizes token address for event emission. Converts NATIVE_PLACEHOLDER to WRAPPED_TOKEN.
    function _normalizeTokenForEvent(address token) internal view returns (address) {
        return token == NATIVE_PLACEHOLDER ? WRAPPED_TOKEN : token;
    }

    /// @dev Internal function to check tokens and handle input for a 1inch swap.
    function _checkOneInch(
        address inputToken,
        address outputToken,
        uint256 amountIn
    )
        internal
        returns (
            bool isInputSupported,
            bool isOutputSupported,
            bool isInputNative,
            bool isOutputNative
        )
    {
        isInputSupported = supportedTokens[inputToken];
        isOutputSupported = supportedTokens[outputToken];
        if (!isInputSupported && !isOutputSupported) revert Errors.InvalidInputToken();

        isInputNative = (inputToken == NATIVE_PLACEHOLDER);
        isOutputNative = (outputToken == NATIVE_PLACEHOLDER);

        if (isInputNative && isOutputNative) revert Errors.InvalidInputToken();
        if (isInputNative) {
            if (msg.value != amountIn) revert Errors.InvalidNativeTokenAmount();
        } else {
            if (msg.value != 0) revert Errors.InvalidNativeTokenAmount();
            uint256 balanceBefore = IERC20(inputToken).balanceOf(address(this));
            IERC20(inputToken).safeTransferFrom(_msgSender(), address(this), amountIn);
            if (IERC20(inputToken).balanceOf(address(this)) - balanceBefore != amountIn) {
                revert Errors.InsufficientInputAmount();
            }
        }
    }

    /// @dev Internal function to execute a swap on 1inch.
    function _callOneInch(
        bytes calldata oneInchCallData,
        uint256 amountToSwap,
        bool isInputNative
    ) internal {
        (bool success, bytes memory result) = isInputNative
            ? oneInchRouter.call{value: amountToSwap}(oneInchCallData)
            : oneInchRouter.call(oneInchCallData);
        if (!success) {
            revert Errors.SwapFailed(result);
        }
    }

    /// @notice Updates the fee rate for the router
    /// @param _newFeeRate New fee rate in basis points
    /// @dev Only callable by admin
    function updateFeeRate(uint256 _newFeeRate) external onlyAdmin {
        if (_newFeeRate > FEE_DENOMINATOR / 10) revert Errors.FeeRateTooHigh();
        feeRate = _newFeeRate;
        emit FeeRateUpdated(_newFeeRate);
    }

    /// @notice Withdraws tokens from the contract
    /// @param token Address of token to withdraw
    /// @param amount Amount of tokens to withdraw
    /// @param recipient Address to receive the tokens
    /// @dev Only callable by admin
    function withdrawToken(
        address token,
        uint256 amount,
        address recipient
    ) public onlyAdmin {
        if (IERC20(token).balanceOf(address(this)) < amount) revert Errors.InsufficientToken();
        IERC20(token).safeTransfer(recipient, amount);
    }

    /// @notice Approves router contract to spend tokens
    /// @param router Router address to approve
    /// @param token Token address to approve
    /// @param amount Amount to approve
    function _approve(address router, address token, uint256 amount) internal {
        IERC20 tokenContract = IERC20(token);
        uint256 currentAllowance = tokenContract.allowance(
            address(this),
            router
        );
        if (currentAllowance < amount) {
            tokenContract.safeIncreaseAllowance(router, amount - currentAllowance);
        }
    }

    /// @notice External function to approve router spending
    /// @param router Router address to approve
    /// @param token Token address to approve
    /// @param amount Amount to approve
    /// @dev Only callable by admin
    function approve(address router, address token, uint256 amount) external onlyAdmin {
        _approve(router, token, amount);
    }

    /// @notice Internal function to transfer native tokens
    /// @param to Recipient address
    /// @param amount Amount of native tokens to transfer
    function _transferNativeToken(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert Errors.NativeTransferFailed();
    }

    /// @notice Refund surplus native ETH that belongs to the caller
    /// @param ethBefore Contract ETH balance snapshot *before* the external swap call
    /// @param sentOut   The amount of native ETH that was sent to the external router (0 if none)
    /// @param expectedFee The fee amount (in native ETH) that should remain in the contract after this swap
    function _refundSurplusNativeToken(
        uint256 ethBefore,
        uint256 sentOut,
        uint256 expectedFee
    ) internal {
        uint256 expectedBalance = ethBefore - sentOut;
        if (sentOut == 0 && expectedFee > 0) {
            // output‑side fee in native ETH
            expectedBalance += expectedFee;
        }

        uint256 currentBalance = address(this).balance;
        if (currentBalance > expectedBalance) {
            uint256 refund = currentBalance - expectedBalance;
            _transferNativeToken(_msgSender(), refund);
        }
    }

    /// @notice Refund surplus ERC20 input tokens that belong to the caller
    /// @param token The ERC20 token address of the input token
    /// @param amountIn The amount of tokens user provided for this swap
    /// @param balanceBefore Contract token balance snapshot before the external swap call
    /// @param expectedRetention The fee amount to be retained in-contract (when fee is taken on input side)
    function _refundSurplusErc20Token(
        address token,
        uint256 amountIn,
        uint256 balanceBefore,
        uint256 expectedRetention
    ) internal {
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        uint256 actuallySpent = balanceBefore > balanceAfter ? (balanceBefore - balanceAfter) : 0;
        uint256 refundable = amountIn > (actuallySpent + expectedRetention)
            ? (amountIn - actuallySpent - expectedRetention)
            : 0;
        if (refundable > 0) {
            IERC20(token).safeTransfer(_msgSender(), refundable);
        }
    }

    /// @notice Withdraws native tokens from the contract
    /// @param amount Amount of native tokens to withdraw
    /// @param recipient Address to receive the native tokens
    /// @dev Only callable by admin
    function withdrawNativeToken(uint256 amount, address recipient) external onlyAdmin {
        if (address(this).balance < amount) revert Errors.InsufficientToken();
        _transferNativeToken(recipient, amount);
    }

    /// @notice Required for receiving native tokens
    /// @dev This function is needed to receive ETH when unwrapping WETH
    receive() external payable {}

    /// @notice Add a token to the list of supported trading tokens
    /// @param token Address of the token to add
    /// @dev Only callable by admin
    function addSupportedToken(address token) external onlyAdmin {
        supportedTokens[token] = true;
        emit TokenSupported(token);
    }

    /// @notice Remove a token from the list of supported trading tokens
    /// @param token Address of the token to remove
    /// @dev Only callable by admin
    function removeSupportedToken(address token) external onlyAdmin {
        if (token == WRAPPED_TOKEN) revert Errors.InvalidInputToken();
        supportedTokens[token] = false;
        emit TokenUnsupported(token);
    }

    /// @notice Check if a token is supported for trading
    /// @param token Address of the token to check
    /// @return Whether the token is supported for trading
    function isTokenSupported(address token) external view returns (bool) {
        return supportedTokens[token];
    }
}
