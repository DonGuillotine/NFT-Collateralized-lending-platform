// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./helpers/DiamondUtils.sol";
import "../contracts/facets/AdminFacet.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/interfaces/IAdmin.sol";
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

contract AdminFacetTest is Test, DiamondUtils {
    DiamondCutFacet diamondCutFacet;
    AdminFacet adminFacet;
    Diamond diamond;
    DiamondInit diamondInit;
    MockNFT mockNFT;
    address admin;
    address user1;
    address newAdmin;

    function setUp() public {
        diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(diamondCutFacet));
        diamondInit = new DiamondInit();
        adminFacet = new AdminFacet();
        mockNFT = new MockNFT();

        admin = address(this);
        user1 = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        newAdmin = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);

        bytes4[] memory selectors = generateSelectors("AdminFacet");
        
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(adminFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        bytes memory initData = abi.encodeWithSelector(DiamondInit.init.selector, admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(diamondInit), initData);

        IAdmin(address(diamond)).setAdmin(admin);
    }

    function testSetAdmin() public {
        IAdmin(address(diamond)).setAdmin(newAdmin);
        assertEq(IAdmin(address(diamond)).getAdmin(), newAdmin);
    }

    function testEmergencyPause() public {
        IAdmin(address(diamond)).setEmergencyPause(true);
        assertTrue(IAdmin(address(diamond)).isPaused());

        IAdmin(address(diamond)).setEmergencyPause(false);
        assertFalse(IAdmin(address(diamond)).isPaused());
    }

    function testWhitelistCollection() public {
        IAdmin(address(diamond)).updateWhitelistedCollection(address(mockNFT), true);
        assertTrue(IAdmin(address(diamond)).isCollectionWhitelisted(address(mockNFT)));

        IAdmin(address(diamond)).updateWhitelistedCollection(address(mockNFT), false);
        assertFalse(IAdmin(address(diamond)).isCollectionWhitelisted(address(mockNFT)));
    }

    function testParameterBoundaries() public {
        AdminFacet af = AdminFacet(address(diamond));

        af.updateParameters(
            10000,
            20000,
            365 days,
            1000
        );

        af.updateParameters(
            1,
            10000,
            1 days,
            1
        );

        vm.expectRevert(AdminFacet.InvalidParameter.selector);
        af.updateParameters(
            10001,
            15000,
            7 days,
            100
        );

        vm.expectRevert(AdminFacet.InvalidParameter.selector);
        af.updateParameters(
            1000,
            9999,
            7 days,
            100
        );

        vm.expectRevert(AdminFacet.InvalidParameter.selector);
        af.updateParameters(
            1000,
            15000,
            366 days,
            100
        );

        vm.expectRevert(AdminFacet.InvalidParameter.selector);
        af.updateParameters(
            1000,
            15000,
            7 days,
            1001
        );
    }

    function testSetFeeRecipient() public {
        address newFeeRecipient = address(0x3);
        IAdmin(address(diamond)).setFeeRecipient(newFeeRecipient);
        assertEq(IAdmin(address(diamond)).getFeeRecipient(), newFeeRecipient);
    }

    function testOnlyAdminModifier() public {
        vm.startPrank(user1);
        vm.expectRevert(AdminFacet.NotAuthorized.selector);
        IAdmin(address(diamond)).setAdmin(user1);
        vm.stopPrank();
    }

    function testInvalidParameters() public {
        vm.expectRevert(AdminFacet.InvalidParameter.selector);
        IAdmin(address(diamond)).updateParameters(
            20000,
            15000,
            7 days,
            100
        );
    }
}