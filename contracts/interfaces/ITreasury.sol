// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITreasury {
    event ETHDeposited(address indexed lender, uint256 amount);
    event ETHWithdrawn(address indexed lender, uint256 amount);
    event PlatformFeeUpdated(uint256 newFee);
    event RevenueWithdrawn(address indexed admin, uint256 amount);
    event MinDepositUpdated(uint256 newMinDeposit);

    /**
     * @dev Deposits ETH into the lending pool
     */
    function depositETH() external payable;

    /**
     * @dev Withdraws ETH from the lending pool
     * @param amount The amount to withdraw
     */
    function withdrawETH(uint256 amount) external;

    /**
     * @dev Sets the platform fee percentage
     * @param newFee The new fee percentage (100 = 1%)
     */
    function setPlatformFee(uint256 newFee) external;

    /**
     * @dev Sets the minimum deposit amount
     * @param newMinDeposit The new minimum deposit amount
     */
    function setMinDeposit(uint256 newMinDeposit) external;

    /**
     * @dev Withdraws platform revenue (admin only)
     * @param amount The amount to withdraw
     */
    function withdrawPlatformRevenue(uint256 amount) external;

    /**
     * @dev Gets the current balance of a lender
     * @param lender The address of the lender
     */
    function getLenderBalance(address lender) external view returns (uint256);

    /**
     * @dev Gets the total ETH in the lending pool
     */
    function getTotalPoolBalance() external view returns (uint256);

    /**
     * @dev Gets the current platform revenue
     */
    function getPlatformRevenue() external view returns (uint256);
}