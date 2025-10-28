// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/RouterAccessControl.sol";
import "../src/interfaces/IRouterAccessControl.sol";

contract RouterAccessControlTest is Test {
    RouterAccessControl public accessControl;
    address public admin;
    address public newAdmin;
    address public randomUser;

    function setUp() public {
        admin = makeAddr("admin");
        newAdmin = makeAddr("newAdmin");
        randomUser = makeAddr("randomUser");
        
        // 部署合约并设置初始管理员
        accessControl = new RouterAccessControl(admin);
    }

    function testInitiateAdminTransfer() public {
        vm.prank(admin);
        accessControl.initiateAdminTransfer(newAdmin);
        
        assertEq(accessControl.pendingAdmin(), newAdmin, "PendingAdmin should be set correctly");
        assertEq(
            accessControl.pendingAdminTimestamps(newAdmin), 
            block.timestamp + accessControl.ADMIN_TRANSFER_DELAY(), 
            "Timestamp should be set correctly"
        );
        assertFalse(accessControl.cancelledTransfers(newAdmin), "Transfer should not be cancelled");
    }

    function testCancelAdminTransfer() public {
        // 先初始化一个管理员转移
        vm.prank(admin);
        accessControl.initiateAdminTransfer(newAdmin);
        
        // 然后取消它
        vm.prank(admin);
        accessControl.cancelAdminTransfer();
        
        assertTrue(accessControl.cancelledTransfers(newAdmin), "Transfer should be marked as cancelled");
    }

    function testAcceptAdminTransferBeforeDelay() public {
        // 初始化管理员转移
        vm.prank(admin);
        accessControl.initiateAdminTransfer(newAdmin);
        
        // 尝试在延迟期之前接受转移（应该失败）
        vm.prank(newAdmin);
        vm.expectRevert(IRouterAccessControl.DelayNotPassed.selector);
        accessControl.acceptAdminTransfer();
    }

    function testAcceptAdminTransferAfterDelay() public {
        // 初始化管理员转移
        vm.prank(admin);
        accessControl.initiateAdminTransfer(newAdmin);
        
        // 增加时间超过延迟期
        vm.warp(block.timestamp + accessControl.ADMIN_TRANSFER_DELAY() + 1);
        
        // 现在接受转移（应该成功）
        vm.prank(newAdmin);
        accessControl.acceptAdminTransfer();
        
        // 验证管理员角色已转移
        assertTrue(accessControl.hasRole(accessControl.ADMIN(), newAdmin), "newAdmin should have ADMIN role");
        assertFalse(accessControl.hasRole(accessControl.ADMIN(), admin), "old admin should not have ADMIN role");
        
        // 验证状态已清理
        assertEq(accessControl.pendingAdmin(), address(0), "pendingAdmin should be reset");
        assertEq(accessControl.pendingAdminTimestamps(newAdmin), 0, "timestamp should be reset");
        assertFalse(accessControl.cancelledTransfers(newAdmin), "cancelled status should be reset");
    }

    function testAcceptCancelledTransfer() public {
        // 初始化管理员转移
        vm.prank(admin);
        accessControl.initiateAdminTransfer(newAdmin);
        
        // 取消转移
        vm.prank(admin);
        accessControl.cancelAdminTransfer();
        
        // 增加时间超过延迟期
        vm.warp(block.timestamp + accessControl.ADMIN_TRANSFER_DELAY() + 1);
        
        // 尝试接受已取消的转移（应该失败）
        vm.prank(newAdmin);
        vm.expectRevert(IRouterAccessControl.TransferCancelled.selector);
        accessControl.acceptAdminTransfer();
    }

    function testCancelledTransferStorage() public {
        // 初始化管理员转移给newAdmin
        vm.prank(admin);
        accessControl.initiateAdminTransfer(newAdmin);
        
        // 取消转移
        vm.prank(admin);
        accessControl.cancelAdminTransfer();
        
        // 然后再次初始化转移给同一个用户
        vm.prank(admin);
        accessControl.initiateAdminTransfer(newAdmin);
        
        // 验证cancelledTransfers已重置
        assertFalse(accessControl.cancelledTransfers(newAdmin), "Cancelled status should be reset for new transfer");
        
        // 增加时间超过延迟期
        vm.warp(block.timestamp + accessControl.ADMIN_TRANSFER_DELAY() + 1);
        
        // 现在应该可以接受转移了
        vm.prank(newAdmin);
        accessControl.acceptAdminTransfer();
        
        // 验证管理员角色已正确转移
        assertTrue(accessControl.hasRole(accessControl.ADMIN(), newAdmin), "newAdmin should have ADMIN role after accepting re-initiated transfer");
    }

    function testInvalidAddressTransfer() public {
        // 尝试传入零地址（应该失败）
        vm.prank(admin);
        vm.expectRevert(IRouterAccessControl.InvalidAddress.selector);
        accessControl.initiateAdminTransfer(address(0));
    }

    function testNonAdminInitiateTransfer() public {
        // 非管理员尝试初始化转移（应该失败）
        vm.prank(randomUser);
        vm.expectRevert(IRouterAccessControl.OnlyAdmin.selector);
        accessControl.initiateAdminTransfer(newAdmin);
    }

    function testNonAdminCancelTransfer() public {
        // 初始化管理员转移
        vm.prank(admin);
        accessControl.initiateAdminTransfer(newAdmin);
        
        // 非管理员尝试取消转移（应该失败）
        vm.prank(randomUser);
        vm.expectRevert(IRouterAccessControl.OnlyAdmin.selector);
        accessControl.cancelAdminTransfer();
    }

    function testWrongUserAcceptTransfer() public {
        // 初始化管理员转移
        vm.prank(admin);
        accessControl.initiateAdminTransfer(newAdmin);
        
        // 错误的用户尝试接受转移（应该失败）
        vm.prank(randomUser);
        vm.expectRevert(IRouterAccessControl.NotPendingAdmin.selector);
        accessControl.acceptAdminTransfer();
    }

    function testCancelNonExistentTransfer() public {
        // 尝试取消不存在的转移（应该失败）
        vm.prank(admin);
        vm.expectRevert(IRouterAccessControl.NoAdminTransferInProgress.selector);
        accessControl.cancelAdminTransfer();
    }

    function testConsecutiveTransfers() public {
        // 第一次转移
        vm.prank(admin);
        accessControl.initiateAdminTransfer(newAdmin);
        
        // 增加时间超过延迟期
        vm.warp(block.timestamp + accessControl.ADMIN_TRANSFER_DELAY() + 1);
        
        // 接受第一次转移
        vm.prank(newAdmin);
        accessControl.acceptAdminTransfer();
        
        // 创建另一个地址用于第二次转移
        address thirdAdmin = makeAddr("thirdAdmin");
        
        // 第二次转移（现在由newAdmin发起）
        vm.prank(newAdmin);
        accessControl.initiateAdminTransfer(thirdAdmin);
        
        // 增加时间超过延迟期
        vm.warp(block.timestamp + accessControl.ADMIN_TRANSFER_DELAY() + 1);
        
        // 接受第二次转移
        vm.prank(thirdAdmin);
        accessControl.acceptAdminTransfer();
        
        // 验证管理员角色已转移
        assertTrue(accessControl.hasRole(accessControl.ADMIN(), thirdAdmin), "thirdAdmin should have ADMIN role");
        assertFalse(accessControl.hasRole(accessControl.ADMIN(), newAdmin), "newAdmin should not have ADMIN role");
    }
} 