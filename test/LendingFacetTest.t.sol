// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./helpers/DiamondUtils.sol";
import "../contracts/facets/LendingFacet.sol";
import "../contracts/facets/NFTManagementFacet.sol";
import "../contracts/facets/CollateralManagerFacet.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/interfaces/ILending.sol";
import "../contracts/interfaces/INFTManagement.sol";
import {DiamondInit} from "../contracts/upgradeInitializers/DiamondInit.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract MockNFT is ERC721 {
    uint256 private _tokenIdCounter;

    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _mint(to, tokenId);
        return tokenId;
    }
}

contract LendingFacetTest is Test, DiamondUtils {
    LendingFacet lendingFacet;
    NFTManagementFacet nftFacet;
    CollateralManagerFacet collateralFacet;
    DiamondCutFacet diamondCutFacet;
    Diamond diamond;
    DiamondInit diamondInit;
    MockNFT mockNFT;
    address admin;
    address user1;
    address user2;

    function setUp() public {
        diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(diamondCutFacet));
        diamondInit = new DiamondInit();
        lendingFacet = new LendingFacet();
        nftFacet = new NFTManagementFacet();
        collateralFacet = new CollateralManagerFacet();
        mockNFT = new MockNFT();

        admin = address(this);
        user1 = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        user2 = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(address(diamond), 1000 ether);
        
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(lendingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("LendingFacet")
        });
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(nftFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("NFTManagementFacet")
        });
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(collateralFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("CollateralManagerFacet")
        });

        bytes memory initData = abi.encodeWithSelector(DiamondInit.init.selector, admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(diamondInit), initData);

        ILending(address(diamond)).setInterestRate(1000);
        ILending(address(diamond)).setLoanDuration(7 days);

        ICollateralManager(address(diamond)).setNFTPrice(address(mockNFT), 1 ether);
        
        mockNFT.mint(user1);
    }

    function testCreateLoan() public {
        uint256 tokenId = 0;
        uint256 loanAmount = 0.5 ether;

        vm.startPrank(user1);
        
        mockNFT.approve(address(diamond), tokenId);
        INFTManagement(address(diamond)).depositNFT(address(mockNFT), tokenId);

        uint256 loanId = ILending(address(diamond)).createLoan(
            address(mockNFT),
            tokenId,
            loanAmount
        );

        LibStorage.Loan memory loan = ILending(address(diamond)).getLoanDetails(loanId);
        assertEq(loan.borrower, user1);
        assertEq(loan.loanAmount, loanAmount);
        assertEq(uint256(loan.status), uint256(ILoanTypes.LoanStatus.Active));
        
        vm.stopPrank();
    }

    function testRepayLoan() public {
        uint256 tokenId = 0;
        uint256 loanAmount = 0.5 ether;

        vm.startPrank(user1);
        
        mockNFT.approve(address(diamond), tokenId);
        INFTManagement(address(diamond)).depositNFT(address(mockNFT), tokenId);
        uint256 loanId = ILending(address(diamond)).createLoan(
            address(mockNFT),
            tokenId,
            loanAmount
        );

        LibStorage.Loan memory loan = ILending(address(diamond)).getLoanDetails(loanId);
        uint256 totalDue = loan.loanAmount + loan.interestAmount;

        ILending(address(diamond)).repayLoan{value: totalDue}(loanId);

        loan = ILending(address(diamond)).getLoanDetails(loanId);
        assertEq(uint256(loan.status), uint256(ILoanTypes.LoanStatus.Repaid));
        
        vm.stopPrank();
    }

    function testLoanDefaultHandling() public {
        uint256 tokenId = 0;
        uint256 loanAmount = 0.5 ether;

        vm.startPrank(user1);
        
        mockNFT.approve(address(diamond), tokenId);
        INFTManagement(address(diamond)).depositNFT(address(mockNFT), tokenId);
        uint256 loanId = ILending(address(diamond)).createLoan(
            address(mockNFT),
            tokenId,
            loanAmount
        );

        vm.warp(block.timestamp + 8 days);

        uint256 totalDue = loanAmount + (loanAmount * 10 / 100);
        vm.expectRevert(LendingFacet.LoanAlreadyDefaulted.selector);
        ILending(address(diamond)).repayLoan{value: totalDue}(loanId);
        
        vm.stopPrank();
    }
}