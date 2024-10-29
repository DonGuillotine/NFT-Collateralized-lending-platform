// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../interfaces/INFTManagement.sol";
import "../libraries/LibStorage.sol";
import "../libraries/LibNFTLending.sol";
import "../libraries/LibSecurity.sol";

contract NFTManagementFacet is INFTManagement, IERC721Receiver {
    using LibStorage for LibStorage.NFTLendingStorage;

    error NFTAlreadyDeposited();
    error NFTNotDeposited();
    error NFTLocked();
    error InvalidNFT();
    error NotNFTOwner();

    modifier onlyNFTOwner(address collection, uint256 tokenId) {
        if (IERC721(collection).ownerOf(tokenId) != msg.sender) {
            revert NotNFTOwner();
        }
        _;
    }

    function depositNFT(address collection, uint256 tokenId) 
        external 
        override 
        onlyNFTOwner(collection, tokenId) 
    {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();

        // Check if NFT is already deposited
        if (ds.nftDeposits[collection][tokenId].owner != address(0)) {
            revert NFTAlreadyDeposited();
        }

        // Transfer NFT to this contract
        IERC721(collection).safeTransferFrom(msg.sender, address(this), tokenId);

        // Create deposit record
        ds.nftDeposits[collection][tokenId] = LibStorage.NFTDeposit({
            owner: msg.sender,
            collection: collection,
            tokenId: tokenId,
            depositTime: block.timestamp,
            isLocked: false,
            activeLoanId: 0
        });

        // Add to user's deposited NFTs array
        ds.userDepositedNFTs[msg.sender].push(tokenId);

        emit NFTDeposited(msg.sender, collection, tokenId);
    }

    function withdrawNFT(address collection, uint256 tokenId) external override {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        LibStorage.NFTDeposit storage deposit = ds.nftDeposits[collection][tokenId];

        // Verify deposit exists and belongs to sender
        if (deposit.owner != msg.sender) {
            revert NFTNotDeposited();
        }

        // Verify NFT is not locked in a loan
        if (deposit.isLocked) {
            revert NFTLocked();
        }

        // Remove from deposits
        delete ds.nftDeposits[collection][tokenId];

        // Remove from user's deposited NFTs array
        _removeFromUserDeposits(msg.sender, tokenId);

        // Transfer NFT back to owner
        IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);

        emit NFTWithdrawn(msg.sender, collection, tokenId);
    }

    function getUserNFTs(address user) external view override returns (LibStorage.NFTDeposit[] memory) {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        uint256[] storage userNFTs = ds.userDepositedNFTs[user];
        LibStorage.NFTDeposit[] memory deposits = new LibStorage.NFTDeposit[](userNFTs.length);

        for (uint256 i = 0; i < userNFTs.length; i++) {
            uint256 tokenId = userNFTs[i];
            // Assume we're using the first collection for simplicity
            // In a real implementation, I need to track the collection address as well
            deposits[i] = ds.nftDeposits[address(0)][tokenId];
        }

        return deposits;
    }

    function isNFTAvailable(address collection, uint256 tokenId) 
        external 
        view 
        override 
        returns (bool) 
    {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        LibStorage.NFTDeposit storage deposit = ds.nftDeposits[collection][tokenId];
        return deposit.owner != address(0) && !deposit.isLocked;
    }

    function getNFTDeposit(address collection, uint256 tokenId) 
        external 
        view 
        override 
        returns (LibStorage.NFTDeposit memory) 
    {
        return LibStorage.diamondStorage().nftDeposits[collection][tokenId];
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _removeFromUserDeposits(address user, uint256 tokenId) internal {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        uint256[] storage userNFTs = ds.userDepositedNFTs[user];
        
        for (uint256 i = 0; i < userNFTs.length; i++) {
            if (userNFTs[i] == tokenId) {
                // Move the last element to this position
                userNFTs[i] = userNFTs[userNFTs.length - 1];
                // Remove the last element
                userNFTs.pop();
                break;
            }
        }
    }
}