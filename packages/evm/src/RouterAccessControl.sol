// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "./interfaces/IRouterAccessControl.sol";

contract RouterAccessControl is IRouterAccessControl, AccessControlEnumerable {
    bytes32 public constant ADMIN = DEFAULT_ADMIN_ROLE;
    uint256 public constant ADMIN_TRANSFER_DELAY = 2 days;

    address public pendingAdmin;
    mapping(address => uint256) public pendingAdminTimestamps;
    mapping(address => bool) public cancelledTransfers;

    constructor(address admin) {
        _grantRole(ADMIN, admin);
    }

    modifier validRole(bytes32 role) {
        if (role != ADMIN ) {
            revert InvalidRole(role);
        }
        _;
    }

    modifier onlyAdmin() {
        if (!hasRole(ADMIN, msg.sender)) {
            revert OnlyAdmin();
        }
        _;
    }

    function initiateAdminTransfer(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) {
            revert InvalidAddress();
        }
        pendingAdmin = newAdmin;
        pendingAdminTimestamps[newAdmin] = block.timestamp + ADMIN_TRANSFER_DELAY;
        cancelledTransfers[newAdmin] = false;
        emit AdminTransferInitiated(msg.sender, newAdmin, block.timestamp + ADMIN_TRANSFER_DELAY);
    }

    function cancelAdminTransfer() external onlyAdmin {
        if (pendingAdmin == address(0)) {
            revert NoAdminTransferInProgress();
        }
        cancelledTransfers[pendingAdmin] = true;
        emit AdminTransferCancelled(pendingAdmin);
    }

    function acceptAdminTransfer() external {
        if (pendingAdmin != msg.sender) {
            revert NotPendingAdmin();
        }
        if (cancelledTransfers[msg.sender]) {
            revert TransferCancelled();
        }
        if (block.timestamp < pendingAdminTimestamps[msg.sender]) {
            revert DelayNotPassed();
        }

        address oldAdmin = getRoleMember(ADMIN, 0);
        _revokeRole(ADMIN, oldAdmin);
        _grantRole(ADMIN, msg.sender);

        // 清理状态
        pendingAdmin = address(0);
        pendingAdminTimestamps[msg.sender] = 0;
        cancelledTransfers[msg.sender] = false;

        emit AdminTransferCompleted(oldAdmin, msg.sender);
    }
}
