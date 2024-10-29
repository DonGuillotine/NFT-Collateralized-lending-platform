// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibStorage.sol";

interface INFTManagement {
    event NFTDeposited(address indexed user, address indexed collection, uint256 tokenId);
    event NFTWithdrawn(address indexed user, address indexed collection, uint256 tokenId);

    /**
     * @dev Deposits an NFT into the lending platform
     * @param collection The NFT collection address
     * @param tokenId The token ID to deposit
     */
    function depositNFT(address collection, uint256 tokenId) external;

    /**
     * @dev Withdraws an NFT from the lending platform
     * @param collection The NFT collection address
     * @param tokenId The token ID to withdraw
     */
    function withdrawNFT(address collection, uint256 tokenId) external;

    /**
     * @dev Returns all NFTs deposited by a user
     * @param user The address of the user
     */
    function getUserNFTs(address user) external view returns (LibStorage.NFTDeposit[] memory);

    /**
     * @dev Checks if an NFT is deposited and available for borrowing
     * @param collection The NFT collection address
     * @param tokenId The token ID to check
     */
    function isNFTAvailable(address collection, uint256 tokenId) external view returns (bool);

    /**
     * @dev Returns detailed information about a deposited NFT
     * @param collection The NFT collection address
     * @param tokenId The token ID to query
     */
    function getNFTDeposit(address collection, uint256 tokenId) external view returns (LibStorage.NFTDeposit memory);
}