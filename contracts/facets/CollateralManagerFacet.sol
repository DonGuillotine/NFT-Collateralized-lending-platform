// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/ICollateralManager.sol";
import "../libraries/LibStorage.sol";
import "../libraries/LibNFTLending.sol";
import "../libraries/LibSecurity.sol";

contract CollateralManagerFacet is ICollateralManager {
    using LibStorage for LibStorage.NFTLendingStorage;

    error InvalidPrice();
    error InvalidRatio();
    error LoanNotDefaulted();
    error UnauthorizedLiquidation();
    error InsufficientCollateralValue();
    error LoanNotFound();
    error InvalidLoanStatus();

    modifier onlyAdmin() {
        LibNFTLending._authorizeAdmin();
        _;
    }

    function setNFTPrice(address collection, uint256 price) 
        external 
        override 
        onlyAdmin 
    {
        if (price == 0) revert InvalidPrice();
        
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        ds.nftFloorPrices[collection] = price;
        
        emit NFTPriceSet(collection, price);
    }

    function setCollateralRatio(uint256 newRatio) 
        external 
        override 
        onlyAdmin 
    {
        if (newRatio < 10000) revert InvalidRatio();
        
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        ds.collateralRatio = newRatio;
        
        emit CollateralRatioSet(newRatio);
    }

    function liquidateLoan(uint256 loanId) external override {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        LibStorage.Loan storage loan = ds.loans[loanId];

        if (loan.borrower == address(0)) revert LoanNotFound();
        if (!_isLoanDefaulted(loan)) revert LoanNotDefaulted();
        if (loan.status != ILoanTypes.LoanStatus.Active) revert InvalidLoanStatus();

        loan.status = ILoanTypes.LoanStatus.Defaulted;

        address collection = loan.collateral.collection;
        uint256 tokenId = loan.collateral.tokenId;

        ds.nftDeposits[collection][tokenId].isLocked = false;
        ds.nftDeposits[collection][tokenId].activeLoanId = 0;

        IERC721(collection).transferFrom(address(this), msg.sender, tokenId);

        emit CollateralLiquidated(loanId, collection, tokenId);
    }

    function getNFTPrice(address collection) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return LibStorage.diamondStorage().nftFloorPrices[collection];
    }

    function getCollateralRatio() 
        external 
        view 
        override 
        returns (uint256) 
    {
        return LibStorage.diamondStorage().collateralRatio;
    }

    function canBeLiquidated(uint256 loanId) 
        external 
        view 
        override 
        returns (bool) 
    {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        LibStorage.Loan storage loan = ds.loans[loanId];
        
        return loan.borrower != address(0) && 
               loan.status == ILoanTypes.LoanStatus.Active && 
               _isLoanDefaulted(loan);
    }

    function validateCollateralValue(address collection, uint256 loanAmount) 
        external 
        view 
        override 
        returns (bool) 
    {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        
        uint256 nftValue = ds.nftFloorPrices[collection];
        uint256 requiredCollateral = LibNFTLending._calculateCollateralRequired(
            loanAmount,
            ds.collateralRatio
        );
        
        return nftValue >= requiredCollateral;
    }

    function _isLoanDefaulted(LibStorage.Loan storage loan) 
        internal 
        view 
        returns (bool) 
    {
        return block.timestamp > loan.endTime;
    }

    function createTestLoan(
        address borrower,
        uint256 loanAmount,
        uint256 interestAmount,
        uint256 startTime,
        uint256 endTime,
        address collection,
        uint256 tokenId
    ) external onlyAdmin returns (uint256) {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        
        uint256 loanId = ds.loanCounter + 1;
        ds.loanCounter = loanId;

        ds.loans[loanId] = LibStorage.Loan({
            borrower: borrower,
            loanAmount: loanAmount,
            interestAmount: interestAmount,
            startTime: startTime,
            endTime: endTime,
            status: ILoanTypes.LoanStatus.Active,
            collateral: LibStorage.NFTCollateral({
                collection: collection,
                tokenId: tokenId,
                valueAtLock: ds.nftFloorPrices[collection]
            })
        });

        ds.nftDeposits[collection][tokenId] = LibStorage.NFTDeposit({
            owner: borrower,
            collection: collection,
            tokenId: tokenId,
            depositTime: startTime,
            isLocked: true,
            activeLoanId: loanId
        });

        return loanId;
    }

    function getLoanStatus(uint256 loanId) 
        external 
        view 
        override 
        returns (ILoanTypes.LoanStatus) 
    {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        return ds.loans[loanId].status;
    }
}