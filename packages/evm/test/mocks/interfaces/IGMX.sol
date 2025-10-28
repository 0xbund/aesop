// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract IGMX is IERC20 {
    function gov() external view virtual returns (address);

    function addAdmin(address _account) external virtual;

    function setMinter(address _minter, bool _isActive) external virtual;

    function mint(address _account, uint256 _amount) external virtual;

    function decimals() external view virtual returns (uint256);
}
