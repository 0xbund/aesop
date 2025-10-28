// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);
}
