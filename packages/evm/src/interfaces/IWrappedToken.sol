// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IWrappedToken {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint256 amount) external;
    function withdrawTo(address account, uint256 amount) external;
}
