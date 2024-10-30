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

    struct TreasuryStorage {
        uint256 platformFee;
        uint256 minDeposit;
        uint256 platformRevenue;
        mapping(address => uint256) lenderBalances;
        uint256 totalPoolBalance;
    }

    bytes32 constant TREASURY_STORAGE_POSITION = keccak256("nft.lending.treasury.storage");

    modifier onlyAdmin() {
        LibNFTLending._authorizeAdmin();
        _;
    }

    function treasuryStorage() internal pure returns (TreasuryStorage storage ts) {
        bytes32 position = TREASURY_STORAGE_POSITION;
        assembly {
            ts.slot := position
        }
    }

    function depositETH() external payable override {
        if (msg.value == 0) revert InvalidAmount();
        
        TreasuryStorage storage ts = treasuryStorage();
        if (msg.value < ts.minDeposit) revert BelowMinimumDeposit();

        ts.lenderBalances[msg.sender] += msg.value;
        ts.totalPoolBalance += msg.value;

        emit ETHDeposited(msg.sender, msg.value);
    }

    function withdrawETH(uint256 amount) external override {
        if (amount == 0) revert InvalidAmount();

        TreasuryStorage storage ts = treasuryStorage();
        if (ts.lenderBalances[msg.sender] < amount) revert InsufficientBalance();

        ts.lenderBalances[msg.sender] -= amount;
        ts.totalPoolBalance -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit ETHWithdrawn(msg.sender, amount);
    }

    function setPlatformFee(uint256 newFee) external override onlyAdmin {
        if (newFee > 1000) revert InvalidFee(); // Max 10%
        
        TreasuryStorage storage ts = treasuryStorage();
        ts.platformFee = newFee;
        
        emit PlatformFeeUpdated(newFee);
    }

    function setMinDeposit(uint256 newMinDeposit) external override onlyAdmin {
        TreasuryStorage storage ts = treasuryStorage();
        ts.minDeposit = newMinDeposit;
        
        emit MinDepositUpdated(newMinDeposit);
    }

    function withdrawPlatformRevenue(uint256 amount) external override onlyAdmin {
        TreasuryStorage storage ts = treasuryStorage();
        if (amount == 0) revert InvalidAmount();
        if (ts.platformRevenue < amount) revert InsufficientRevenue();

        ts.platformRevenue -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit RevenueWithdrawn(msg.sender, amount);
    }

    function getLenderBalance(address lender) external view override returns (uint256) {
        return treasuryStorage().lenderBalances[lender];
    }

    function getTotalPoolBalance() external view override returns (uint256) {
        return treasuryStorage().totalPoolBalance;
    }

    function getPlatformRevenue() external view override returns (uint256) {
        return treasuryStorage().platformRevenue;
    }

    // Internal function to handle interest collection
    function _collectInterest(uint256 amount) internal {
        TreasuryStorage storage ts = treasuryStorage();
        uint256 fee = (amount * ts.platformFee) / 10000;
        ts.platformRevenue += fee;
        ts.totalPoolBalance += (amount - fee);
    }

    receive() external payable {
        if (msg.value > 0) {
            treasuryStorage().totalPoolBalance += msg.value;
        }
    }

    fallback() external payable {
        if (msg.value > 0) {
            treasuryStorage().totalPoolBalance += msg.value;
        }
    }
}