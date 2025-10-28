// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

interface IRouterAccessControl is IAccessControlEnumerable {

    error InvalidRole(bytes32 role);
    error OnlyAdmin();
    error NoAdminTransferInProgress();

    function pendingAdmin() external view returns (address);

    function initiateAdminTransfer(address newAdmin) external;

    function acceptAdminTransfer() external;
}
