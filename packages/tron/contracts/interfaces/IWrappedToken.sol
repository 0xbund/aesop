// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IWrappedToken {
    function deposit() external payable;
    function transfer(address dst, uint sad) external returns (bool);
    function withdraw(uint) external;
}
