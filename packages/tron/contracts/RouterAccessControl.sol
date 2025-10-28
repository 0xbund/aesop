// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "./interfaces/IRouterAccessControl.sol";

contract RouterAccessControl is IRouterAccessControl, AccessControlEnumerable {
    bytes32 public constant ADMIN = DEFAULT_ADMIN_ROLE;

    address public pendingAdmin;

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
        pendingAdmin = newAdmin;
    }

    function acceptAdminTransfer() external {
        if (msg.sender != pendingAdmin) {
            revert NoAdminTransferInProgress();
        }

        address oldAdmin = getRoleMember(ADMIN, 0);
        _revokeRole(ADMIN, oldAdmin);
        _grantRole(ADMIN, msg.sender);
        pendingAdmin = address(0);
    }
}
