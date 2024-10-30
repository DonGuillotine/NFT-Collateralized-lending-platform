// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./helpers/DiamondUtils.sol";
import "../contracts/facets/CollateralManagerFacet.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/interfaces/ICollateralManager.sol";
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

contract CollateralManagerFacetTest is Test, DiamondUtils {
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
        
        collateralFacet = new CollateralManagerFacet();
        
        mockNFT = new MockNFT();
        
        admin = address(this);
        user1 = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        user2 = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        bytes4[] memory selectors = generateSelectors("CollateralManagerFacet");
        
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(collateralFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        bytes memory initData = abi.encodeWithSelector(DiamondInit.init.selector, admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(diamondInit), initData);

        ICollateralManager(address(diamond)).setNFTPrice(address(mockNFT), 1 ether);
        ICollateralManager(address(diamond)).setCollateralRatio(15000);
    }

    function testSetNFTPrice() public {
        uint256 newPrice = 2 ether;
        ICollateralManager(address(diamond)).setNFTPrice(address(mockNFT), newPrice);
        assertEq(ICollateralManager(address(diamond)).getNFTPrice(address(mockNFT)), newPrice);
    }

    function testSetCollateralRatio() public {
        uint256 newRatio = 20000;
        ICollateralManager(address(diamond)).setCollateralRatio(newRatio);
        assertEq(ICollateralManager(address(diamond)).getCollateralRatio(), newRatio);
    }

    function testValidateCollateralValue() public {
        ICollateralManager(address(diamond)).setNFTPrice(address(mockNFT), 1 ether);
        
        bool isValid = ICollateralManager(address(diamond)).validateCollateralValue(
            address(mockNFT),
            0.6 ether
        );
        assertTrue(isValid);

        isValid = ICollateralManager(address(diamond)).validateCollateralValue(
            address(mockNFT),
            0.8 ether
        );
        assertFalse(isValid);
    }

    function testLoanLiquidation() public {
        uint256 tokenId = 0;
        mockNFT.mint(user1);

        vm.startPrank(user1);
        mockNFT.transferFrom(user1, address(diamond), tokenId);
        vm.stopPrank();

        uint256 loanId = ICollateralManager(address(diamond)).createTestLoan(
            user1,
            0.5 ether,
            0.05 ether,
            block.timestamp - 8 days,
            block.timestamp - 1 days,
            address(mockNFT),
            tokenId
        );

        assertTrue(ICollateralManager(address(diamond)).canBeLiquidated(loanId));
        
        vm.startPrank(user2);
        ICollateralManager(address(diamond)).liquidateLoan(loanId);
        vm.stopPrank();

        assertEq(
            uint256(ICollateralManager(address(diamond)).getLoanStatus(loanId)),
            uint256(ILoanTypes.LoanStatus.Defaulted)
        );
    }
}