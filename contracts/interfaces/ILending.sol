// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibStorage.sol";

interface ILending {
    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed collection,
        uint256 tokenId,
        uint256 amount
    );
    event LoanRepaid(uint256 indexed loanId, uint256 amount, uint256 interest);
    event LoanDefaulted(uint256 indexed loanId);
    event InterestRateUpdated(uint256 newRate);
    event LoanDurationUpdated(uint256 newDuration);

    /**
     * @dev Creates a loan using an NFT as collateral
     * @param collection The NFT collection address
     * @param tokenId The token ID to use as collateral
     * @param amount The amount to borrow
     */
    function createLoan(
        address collection,
        uint256 tokenId,
        uint256 amount
    ) external returns (uint256 loanId);

    /**
     * @dev Repays a loan
     * @param loanId The ID of the loan to repay
     */
    function repayLoan(uint256 loanId) external payable;

    /**
     * @dev Sets the platform interest rate
     * @param newRate The new interest rate (1000 = 10%)
     */
    function setInterestRate(uint256 newRate) external;

    /**
     * @dev Sets the loan duration
     * @param newDuration The new duration in seconds
     */
    function setLoanDuration(uint256 newDuration) external;

    /**
     * @dev Gets loan details
     * @param loanId The loan ID to query
     */
    function getLoanDetails(uint256 loanId) external view returns (LibStorage.Loan memory);

    /**
     * @dev Gets current interest rate
     */
    function getInterestRate() external view returns (uint256);

    /**
     * @dev Gets current loan duration
     */
    function getLoanDuration() external view returns (uint256);
}