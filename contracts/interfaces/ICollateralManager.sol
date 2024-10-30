// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ILoanTypes.sol";

interface ICollateralManager {
    event NFTPriceSet(address indexed collection, uint256 price);
    event CollateralRatioSet(uint256 newRatio);
    event CollateralLiquidated(uint256 indexed loanId, address indexed collection, uint256 tokenId);
    
    /**
     * @dev Sets the floor price for an NFT collection
     * @param collection The NFT collection address
     * @param price The floor price in ETH (in wei)
     */
    function setNFTPrice(address collection, uint256 price) external;

    /**
     * @dev Sets the collateralization ratio
     * @param newRatio The new ratio (15000 = 150%)
     */
    function setCollateralRatio(uint256 newRatio) external;

    /**
     * @dev Liquidates a defaulted loan
     * @param loanId The ID of the defaulted loan
     */
    function liquidateLoan(uint256 loanId) external;

    /**
     * @dev Gets the current floor price for an NFT collection
     * @param collection The NFT collection address
     */
    function getNFTPrice(address collection) external view returns (uint256);

    /**
     * @dev Gets the current collateralization ratio
     */
    function getCollateralRatio() external view returns (uint256);

    /**
     * @dev Checks if a loan can be liquidated
     * @param loanId The loan ID to check
     */
    function canBeLiquidated(uint256 loanId) external view returns (bool);

    /**
     * @dev Validates if an NFT has sufficient collateral value for a loan amount
     * @param collection The NFT collection address
     * @param loanAmount The requested loan amount
     */
    function validateCollateralValue(address collection, uint256 loanAmount) external view returns (bool);

    /**
     * @dev Creates a new Test Loan
     * @param borrower The address of the borrower
     * @param loanAmount The requested loan amount
     * @param interestAmount The intereast amount
     * @param startTime The time started
     * @param endTime The time ended
     * @param collection The NFT collection address
     * @param tokenId The ID of the Token
     */
    function createTestLoan(
        address borrower,
        uint256 loanAmount,
        uint256 interestAmount,
        uint256 startTime,
        uint256 endTime,
        address collection,
        uint256 tokenId
    ) external returns (uint256);

    /**
     * @dev Gets the loan details
     * @param loanId The loan ID to query
     */
    function getLoanStatus(uint256 loanId) external view returns (ILoanTypes.LoanStatus);
}