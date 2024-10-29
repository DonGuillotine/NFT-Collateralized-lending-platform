// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LibStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

library LibNFTLending {
    using LibStorage for LibStorage.NFTLendingStorage;

    event NFTDeposited(address indexed user, address indexed collection, uint256 tokenId);
    event NFTWithdrawn(address indexed user, address indexed collection, uint256 tokenId);
    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanDefaulted(uint256 indexed loanId, address indexed borrower);
    event PriceSet(address indexed collection, uint256 price);
    event CollateralLiquidated(uint256 indexed loanId, address indexed collection, uint256 tokenId);

    error NotAuthorized();
    error InvalidNFT();
    error NFTAlreadyDeposited();
    error NFTNotDeposited();
    error NFTLocked();
    error InsufficientCollateral();
    error LoanNotActive();
    error LoanAlreadyRepaid();
    error InsufficientRepayment();
    error LoanNotDefaulted();
    error InvalidAmount();
    error SystemPaused();

    function _authorizeAdmin() internal view {
        if (msg.sender != LibStorage.diamondStorage().admin) {
            revert NotAuthorized();
        }
    }

    function _calculateInterest(uint256 amount, uint256 rate) internal pure returns (uint256) {
        return (amount * rate) / 10000;
    }

    function _calculateCollateralRequired(uint256 loanAmount, uint256 ratio) internal pure returns (uint256) {
        return (loanAmount * ratio) / 10000;
    }

    function _isLoanDefaulted(LibStorage.Loan memory loan) internal view returns (bool) {
        return block.timestamp > loan.endTime && loan.status == LibStorage.LoanStatus.Active;
    }

    function _validateNFTOwnership(address collection, uint256 tokenId, address owner) internal view {
        if (IERC721(collection).ownerOf(tokenId) != owner) {
            revert InvalidNFT();
        }
    }

    function _createLoan(
        address borrower,
        uint256 loanAmount,
        address collection,
        uint256 tokenId
    ) internal returns (uint256) {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        
        uint256 loanId = ds.loanCounter + 1;
        ds.loanCounter = loanId;

        uint256 interestAmount = _calculateInterest(loanAmount, ds.interestRate);
        
        ds.loans[loanId] = LibStorage.Loan({
            borrower: borrower,
            loanAmount: loanAmount,
            interestAmount: interestAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + ds.loanDuration,
            status: LibStorage.LoanStatus.Active,
            collateral: LibStorage.NFTCollateral({
                collection: collection,
                tokenId: tokenId,
                valueAtLock: ds.nftFloorPrices[collection]
            })
        });

        return loanId;
    }
}