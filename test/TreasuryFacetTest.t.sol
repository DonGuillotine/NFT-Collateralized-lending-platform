// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./helpers/DiamondUtils.sol";
import "../contracts/facets/TreasuryFacet.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/interfaces/ITreasury.sol";
import {DiamondInit} from "../contracts/upgradeInitializers/DiamondInit.sol";

contract TreasuryFacetTest is Test, DiamondUtils {
    TreasuryFacet treasuryFacet;
    DiamondCutFacet diamondCutFacet;
    Diamond diamond;
    DiamondInit diamondInit;
    address admin;
    address user1;
    address user2;

    function setUp() public {
        diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(diamondCutFacet));
        diamondInit = new DiamondInit();
        treasuryFacet = new TreasuryFacet();

        admin = address(this);
        user1 = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        user2 = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(address(diamond), 100 ether); 

        // Get regular function selectors
        bytes4[] memory functionsSelectors = generateSelectors("TreasuryFacet");
        
        // Create new array with space for receive() and fallback()
        bytes4[] memory selectors = new bytes4[](functionsSelectors.length + 2);
        
        // Copy existing selectors
        for(uint i = 0; i < functionsSelectors.length; i++) {
            selectors[i] = functionsSelectors[i];
        }
        
        // Add receive() and fallback() selectors
        selectors[functionsSelectors.length] = bytes4(0); // receive()
        selectors[functionsSelectors.length + 1] = 0xffffffff; // fallback()
        
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(treasuryFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        bytes memory initData = abi.encodeWithSelector(DiamondInit.init.selector, admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(diamondInit), initData);

        ITreasury(address(diamond)).setPlatformFee(100);
        ITreasury(address(diamond)).setMinDeposit(0.1 ether);
    }

    receive() external payable {}
    fallback() external payable {}

    function testDepositETH() public {
        uint256 depositAmount = 1 ether;
        
        vm.startPrank(user1);
        ITreasury(address(diamond)).depositETH{value: depositAmount}();

        assertEq(ITreasury(address(diamond)).getLenderBalance(user1), depositAmount);
        assertEq(ITreasury(address(diamond)).getTotalPoolBalance(), depositAmount);
        vm.stopPrank();
    }

    function testWithdrawETH() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;
        
        vm.startPrank(user1);
        
        ITreasury(address(diamond)).depositETH{value: depositAmount}();
        
        uint256 balanceBefore = address(user1).balance;
        ITreasury(address(diamond)).withdrawETH(withdrawAmount);
        uint256 balanceAfter = address(user1).balance;

        assertEq(balanceAfter - balanceBefore, withdrawAmount);
        assertEq(ITreasury(address(diamond)).getLenderBalance(user1), depositAmount - withdrawAmount);
        vm.stopPrank();
    }

    function testPlatformFee() public {
        console.log("Testing platform fee...");
        
        uint256 newFee = 200; // 2%
        ITreasury(address(diamond)).setPlatformFee(newFee);
        console.log("Platform fee set to:", newFee);
        
        uint256 interestAmount = 1 ether;
        console.log("Sending interest amount:", interestAmount);
        
        uint256 initialRevenue = ITreasury(address(diamond)).getPlatformRevenue();
        console.log("Initial platform revenue:", initialRevenue);
        
        vm.deal(address(this), interestAmount);
        (bool success,) = address(diamond).call{value: interestAmount}("");
        require(success, "ETH transfer failed");
        console.log("ETH sent to contract");
        
        uint256 expectedFee = (interestAmount * newFee) / 10000;
        uint256 actualRevenue = ITreasury(address(diamond)).getPlatformRevenue();
        console.log("Expected fee:", expectedFee);
        console.log("Actual revenue:", actualRevenue);
        
        assertEq(actualRevenue, expectedFee, "Platform revenue incorrect");
    }

    function testMinimumDeposit() public {
        uint256 minDeposit = 0.1 ether;
        ITreasury(address(diamond)).setMinDeposit(minDeposit);

        vm.startPrank(user1);
        
        vm.expectRevert(TreasuryFacet.BelowMinimumDeposit.selector);
        ITreasury(address(diamond)).depositETH{value: 0.05 ether}();
        
        ITreasury(address(diamond)).depositETH{value: minDeposit}();
        vm.stopPrank();
    }

    function testWithdrawPlatformRevenue() public {
        console.log("Testing withdraw platform revenue...");
        
        uint256 fee = 200;
        ITreasury(address(diamond)).setPlatformFee(fee);
        console.log("Platform fee set to:", fee);
        
        uint256 amount = 1 ether;
        vm.deal(address(this), amount);
        
        vm.deal(address(diamond), amount);
        
        (bool success,) = address(diamond).call{value: amount}("");
        require(success, "ETH transfer failed");
        console.log("ETH sent to contract:", amount);
        
        uint256 expectedFee = (amount * fee) / 10000;
        uint256 actualRevenue = ITreasury(address(diamond)).getPlatformRevenue();
        console.log("Expected fee:", expectedFee);
        console.log("Actual revenue:", actualRevenue);
        
        uint256 balanceBefore = address(this).balance;
        console.log("Balance before withdrawal:", balanceBefore);
        
        ITreasury(address(diamond)).withdrawPlatformRevenue(expectedFee);
        
        uint256 balanceAfter = address(this).balance;
        assertEq(balanceAfter - balanceBefore, expectedFee, "Withdrawal amount incorrect");
        assertEq(ITreasury(address(diamond)).getPlatformRevenue(), 0, "Platform revenue not cleared");
    }

    function testDirectETHTransfer() public {
        console.log("Testing direct ETH transfer...");
        
        ITreasury(address(diamond)).setPlatformFee(200);
        
        uint256 initialRevenue = ITreasury(address(diamond)).getPlatformRevenue();
        console.log("Initial revenue:", initialRevenue);
        
        vm.deal(address(this), 1 ether);
        (bool success,) = address(diamond).call{value: 1 ether}("");
        require(success, "ETH transfer failed");
        console.log("Sent 1 ETH to diamond");
        
        uint256 expectedFee = (1 ether * 200) / 10000;
        uint256 finalRevenue = ITreasury(address(diamond)).getPlatformRevenue();
        console.log("Expected fee:", expectedFee);
        console.log("Final revenue:", finalRevenue);
        
        assertEq(finalRevenue, expectedFee, "Revenue not updated correctly");
    }
}