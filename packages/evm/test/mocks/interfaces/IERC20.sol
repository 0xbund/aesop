// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

abstract contract IERC20 {
    function totalSupply() external view virtual returns (uint256);

    function decimals() external view virtual returns (uint8);

    function symbol() external view virtual returns (string memory);

    function name() external view virtual returns (string memory);

    function getOwner() external view virtual returns (address);

    function gatewayAddress() external view virtual returns (address);

    function balanceOf(address account) external view virtual returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external virtual returns (bool);

    function allowance(
        address _owner,
        address spender
    ) external view virtual returns (uint256);

    function approve(
        address spender,
        uint256 amount
    ) external virtual returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external virtual returns (bool);

    function mint(address to, uint256 amount) public virtual returns (bool);

    function issue(uint256 amount) external virtual;

    function bridgeMint(address account, uint256 amount) external virtual;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}
