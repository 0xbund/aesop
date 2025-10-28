// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

interface IRouterAccessControl is IAccessControlEnumerable {
    error OnlyAdmin();
    error NoAdminTransferInProgress();
    error InvalidAddress();
    error NotPendingAdmin();
    error DelayNotPassed();
    error TransferCancelled();

    event AdminTransferInitiated(address indexed currentAdmin, address indexed newAdmin, uint256 effectiveTime);
    event AdminTransferCancelled(address indexed pendingAdmin);
    event AdminTransferCompleted(address indexed oldAdmin, address indexed newAdmin);

    function pendingAdmin() external view returns (address);
    
    function pendingAdminTimestamps(address admin) external view returns (uint256);
    
    function cancelledTransfers(address admin) external view returns (bool);

    function initiateAdminTransfer(address newAdmin) external;

    function cancelAdminTransfer() external;

    function acceptAdminTransfer() external;
}
