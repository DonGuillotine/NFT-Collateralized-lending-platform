// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ILoanTypes.sol";

library LibStorage {
    bytes32 constant STORAGE_POSITION = keccak256("nft.lending.diamond.storage");

    struct NFTDeposit {
        address owner;
        address collection;
        uint256 tokenId;
        uint256 depositTime;
        bool isLocked;
        uint256 activeLoanId;
    }

    struct Loan {
        address borrower;
        uint256 loanAmount;
        uint256 interestAmount;
        uint256 startTime;
        uint256 endTime;
        ILoanTypes.LoanStatus status;
        NFTCollateral collateral;
    }

    struct NFTCollateral {
        address collection;
        uint256 tokenId;
        uint256 valueAtLock;
    }

    struct NFTLendingStorage {
        mapping(address => mapping(uint256 => NFTDeposit)) nftDeposits;
        mapping(address => uint256[]) userDepositedNFTs;
        
        mapping(uint256 => Loan) loans;
        uint256 loanCounter;
        
        mapping(address => uint256) lenderBalances;
        uint256 totalETHDeposited;
        
        mapping(address => uint256) nftFloorPrices;
        uint256 collateralRatio;
        uint256 interestRate;
        uint256 loanDuration;
        bool paused;

        address admin;
    }

    function diamondStorage() internal pure returns (NFTLendingStorage storage ds) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}