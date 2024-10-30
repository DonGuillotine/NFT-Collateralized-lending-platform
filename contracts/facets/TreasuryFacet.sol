// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ITreasury.sol";
import "../libraries/LibStorage.sol";
import "../libraries/LibNFTLending.sol";
import "../libraries/LibSecurity.sol";

contract TreasuryFacet is ITreasury {
    error InsufficientBalance();
    error InvalidAmount();
    error BelowMinimumDeposit();
    error InvalidFee();
    error InsufficientRevenue();
    error TransferFailed();

    event ETHReceived(uint256 amount, uint256 fee);

    modifier onlyAdmin() {
        LibNFTLending._authorizeAdmin();
        _;
    }

    function depositETH() external payable override {
        if (msg.value == 0) revert InvalidAmount();
        
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        if (msg.value < ds.minDeposit) revert BelowMinimumDeposit();

        ds.lenderBalances[msg.sender] += msg.value;
        ds.totalPoolBalance += msg.value;

        emit ETHDeposited(msg.sender, msg.value);
    }

    function withdrawETH(uint256 amount) external override {
        if (amount == 0) revert InvalidAmount();

        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        if (ds.lenderBalances[msg.sender] < amount) revert InsufficientBalance();

        ds.lenderBalances[msg.sender] -= amount;
        ds.totalPoolBalance -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit ETHWithdrawn(msg.sender, amount);
    }

    function setPlatformFee(uint256 newFee) external override onlyAdmin {
        if (newFee > 1000) revert InvalidFee();
        
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        ds.platformFee = newFee;
        
        emit PlatformFeeUpdated(newFee);
    }

    function setMinDeposit(uint256 newMinDeposit) external override onlyAdmin {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        ds.minDeposit = newMinDeposit;
        
        emit MinDepositUpdated(newMinDeposit);
    }

    function withdrawPlatformRevenue(uint256 amount) external override onlyAdmin {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        if (amount == 0) revert InvalidAmount();
        if (ds.platformRevenue < amount) revert InsufficientRevenue();

        ds.platformRevenue -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit RevenueWithdrawn(msg.sender, amount);
    }

    function getLenderBalance(address lender) external view override returns (uint256) {
        return LibStorage.diamondStorage().lenderBalances[lender];
    }

    function getTotalPoolBalance() external view override returns (uint256) {
        return LibStorage.diamondStorage().totalPoolBalance;
    }

    function getPlatformRevenue() external view override returns (uint256) {
        return LibStorage.diamondStorage().platformRevenue;
    }

    // Internal function to handle interest collection
    function _collectInterest(uint256 amount) internal {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        uint256 fee = (amount * ds.platformFee) / 10000;
        ds.platformRevenue += fee;
        ds.totalPoolBalance += (amount - fee);
    }

    receive() external payable {
        _handleIncomingETH();
    }

    fallback() external payable {
        _handleIncomingETH();
    }

    function _handleIncomingETH() internal {
        if (msg.value > 0) {
            LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
            uint256 fee = (msg.value * ds.platformFee) / 10000;
            
            // Debug event
            emit ETHReceived(msg.value, fee);
            
            ds.platformRevenue += fee;
            ds.totalPoolBalance += (msg.value - fee);
        }
    }
}