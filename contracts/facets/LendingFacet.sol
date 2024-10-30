// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/ILending.sol";
import "../interfaces/ICollateralManager.sol";
import "../libraries/LibStorage.sol";
import "../libraries/LibNFTLending.sol";
import "../libraries/LibSecurity.sol";

contract LendingFacet is ILending {
    error InvalidAmount();
    error InvalidLoan();
    error LoanNotActive();
    error InsufficientRepayment();
    error InsufficientCollateral();
    error NFTNotAvailable();
    error NotLoanOwner();
    error InvalidInterestRate();
    error InvalidDuration();
    error LoanAlreadyDefaulted();
    error InsufficientLiquidity();

    modifier onlyAdmin() {
        LibNFTLending._authorizeAdmin();
        _;
    }

    function createLoan(
        address collection,
        uint256 tokenId,
        uint256 amount
    ) external override returns (uint256) {
        if (amount == 0) revert InvalidAmount();

        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();

        LibStorage.NFTDeposit storage deposit = ds.nftDeposits[collection][tokenId];
        if (deposit.owner != msg.sender || deposit.isLocked) {
            revert NFTNotAvailable();
        }

        if (!ICollateralManager(address(this)).validateCollateralValue(collection, amount)) {
            revert InsufficientCollateral();
        }

        if (address(this).balance < amount) {
            revert InsufficientLiquidity();
        }

        uint256 loanId = _createLoan(msg.sender, amount, collection, tokenId);

        deposit.isLocked = true;
        deposit.activeLoanId = loanId;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit LoanCreated(loanId, msg.sender, collection, tokenId, amount);
        return loanId;
    }

    function repayLoan(uint256 loanId) external payable override {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        LibStorage.Loan storage loan = ds.loans[loanId];

        if (loan.borrower != msg.sender) revert NotLoanOwner();
        if (loan.status != ILoanTypes.LoanStatus.Active) revert LoanNotActive();
        if (block.timestamp > loan.endTime) revert LoanAlreadyDefaulted();

        uint256 totalDue = loan.loanAmount + loan.interestAmount;
        if (msg.value < totalDue) revert InsufficientRepayment();

        loan.status = ILoanTypes.LoanStatus.Repaid;

        LibStorage.NFTDeposit storage deposit = ds.nftDeposits[loan.collateral.collection][loan.collateral.tokenId];
        deposit.isLocked = false;
        deposit.activeLoanId = 0;

        uint256 excess = msg.value - totalDue;
        if (excess > 0) {
            (bool success, ) = msg.sender.call{value: excess}("");
            require(success, "Excess refund failed");
        }

        emit LoanRepaid(loanId, loan.loanAmount, loan.interestAmount);
    }

    function setInterestRate(uint256 newRate) external override onlyAdmin {
        if (newRate == 0 || newRate > 10000) revert InvalidInterestRate();
        
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        ds.interestRate = newRate;
        
        emit InterestRateUpdated(newRate);
    }

    function setLoanDuration(uint256 newDuration) external override onlyAdmin {
        if (newDuration < 1 days || newDuration > 30 days) revert InvalidDuration();
        
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        ds.loanDuration = newDuration;
        
        emit LoanDurationUpdated(newDuration);
    }

    function getLoanDetails(uint256 loanId) 
        external 
        view 
        override 
        returns (LibStorage.Loan memory) 
    {
        return LibStorage.diamondStorage().loans[loanId];
    }

    function getInterestRate() external view override returns (uint256) {
        return LibStorage.diamondStorage().interestRate;
    }

    function getLoanDuration() external view override returns (uint256) {
        return LibStorage.diamondStorage().loanDuration;
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

        uint256 interestAmount = LibNFTLending._calculateInterest(loanAmount, ds.interestRate);
        
        ds.loans[loanId] = LibStorage.Loan({
            borrower: borrower,
            loanAmount: loanAmount,
            interestAmount: interestAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + ds.loanDuration,
            status: ILoanTypes.LoanStatus.Active,
            collateral: LibStorage.NFTCollateral({
                collection: collection,
                tokenId: tokenId,
                valueAtLock: ds.nftFloorPrices[collection]
            })
        });

        return loanId;
    }

    receive() external payable {}
    fallback() external payable {}
}