// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./helpers/DiamondUtils.sol";
import "../contracts/facets/NFTManagementFacet.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/interfaces/INFTManagement.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Mock NFT contract for testing
contract MockNFT is ERC721 {
    uint256 private _tokenIdCounter;

    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _mint(to, tokenId);
        return tokenId;
    }
}

contract NFTManagementFacetTest is Test, DiamondUtils {
    NFTManagementFacet nftFacet;
    DiamondCutFacet diamondCutFacet;
    MockNFT mockNFT;
    Diamond diamond;
    address user1;
    address user2;

    function setUp() public {
        diamondCutFacet = new DiamondCutFacet();
        
        diamond = new Diamond(address(this), address(diamondCutFacet));
        
        nftFacet = new NFTManagementFacet();
        
        mockNFT = new MockNFT();
        
        user1 = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        user2 = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        mockNFT.mint(user1);

        bytes4[] memory selectors = generateSelectors("NFTManagementFacet");
        
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(nftFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function testDepositNFT() public {
        uint256 tokenId = 0;
        vm.startPrank(user1);
        mockNFT.approve(address(diamond), tokenId);
        
        INFTManagement(address(diamond)).depositNFT(address(mockNFT), tokenId);
        
        LibStorage.NFTDeposit memory deposit = INFTManagement(address(diamond)).getNFTDeposit(address(mockNFT), tokenId);
        assertEq(deposit.owner, user1);
        assertEq(deposit.collection, address(mockNFT));
        assertEq(deposit.tokenId, tokenId);
        assertEq(deposit.isLocked, false);
        vm.stopPrank();
    }

    function testWithdrawNFT() public {
        uint256 tokenId = 0;
        
        vm.startPrank(user1);
        mockNFT.approve(address(diamond), tokenId);
        INFTManagement(address(diamond)).depositNFT(address(mockNFT), tokenId);
        
        INFTManagement(address(diamond)).withdrawNFT(address(mockNFT), tokenId);
        
        LibStorage.NFTDeposit memory deposit = INFTManagement(address(diamond)).getNFTDeposit(address(mockNFT), tokenId);
        assertEq(deposit.owner, address(0));
        assertEq(mockNFT.ownerOf(tokenId), user1);
        vm.stopPrank();
    }

    // function testCannotWithdrawLockedNFT() public {
    //     uint256 tokenId = 0;
        
    //     vm.startPrank(user1);
    //     mockNFT.approve(address(diamond), tokenId);
    //     INFTManagement(address(diamond)).depositNFT(address(mockNFT), tokenId);
        
    //     // Simulate locking NFT
    //     LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
    //     ds.nftDeposits[address(mockNFT)][tokenId].isLocked = true;
        
    //     // Attempt to withdraw should fail
    //     vm.expectRevert(NFTManagementFacet.NFTLocked.selector);
    //     INFTManagement(address(diamond)).withdrawNFT(address(mockNFT), tokenId);
    //     vm.stopPrank();
    // }
}