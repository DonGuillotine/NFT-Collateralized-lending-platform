// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdmin.sol";
import "../libraries/LibStorage.sol";
import "../libraries/LibNFTLending.sol";
import "../libraries/LibSecurity.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract AdminFacet is IAdmin {
    error ZeroAddress();
    error InvalidParameter();
    error NotAuthorized();
    error InvalidCollectionAddress();

    modifier onlyAdmin() {
        if (msg.sender != LibStorage.diamondStorage().admin) revert NotAuthorized();
        _;
    }

    function setAdmin(address newAdmin) external override onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        address oldAdmin = ds.admin;
        ds.admin = newAdmin;
        
        emit AdminChanged(oldAdmin, newAdmin);
    }

    function setEmergencyPause(bool pauseState) external override onlyAdmin {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        ds.paused = pauseState;
        
        emit EmergencyPaused(pauseState);
    }

    function updateWhitelistedCollection(address collection, bool status) 
        external 
        override 
        onlyAdmin 
    {
        if (collection == address(0)) revert InvalidCollectionAddress();
        
        // Verify it's actually an NFT contract
        try IERC721(collection).supportsInterface(0x80ac58cd) returns (bool supported) {
            if (!supported) revert InvalidCollectionAddress();
        } catch {
            revert InvalidCollectionAddress();
        }

        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        ds.whitelistedCollections[collection] = status;
        
        emit WhitelistedCollectionUpdated(collection, status);
    }

    function updateParameters(
        uint256 interestRate,
        uint256 collateralRatio,
        uint256 loanDuration,
        uint256 platformFee
    ) external override onlyAdmin {
        if (interestRate > 10000 || 
            collateralRatio < 10000 ||
            loanDuration < 1 days || 
            loanDuration > 365 days ||
            platformFee > 1000)
        {
            revert InvalidParameter();
        }

        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        ds.interestRate = interestRate;
        ds.collateralRatio = collateralRatio;
        ds.loanDuration = loanDuration;
        ds.platformFee = platformFee;

        emit ParametersUpdated("interestRate", interestRate);
        emit ParametersUpdated("collateralRatio", collateralRatio);
        emit ParametersUpdated("loanDuration", loanDuration);
        emit ParametersUpdated("platformFee", platformFee);
    }

    function setFeeRecipient(address newFeeRecipient) external override onlyAdmin {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        ds.feeRecipient = newFeeRecipient;
        
        emit FeeRecipientUpdated(newFeeRecipient);
    }

    function getAdmin() external view override returns (address) {
        return LibStorage.diamondStorage().admin;
    }

    function isPaused() external view override returns (bool) {
        return LibStorage.diamondStorage().paused;
    }

    function isCollectionWhitelisted(address collection) 
        external 
        view 
        override 
        returns (bool) 
    {
        return LibStorage.diamondStorage().whitelistedCollections[collection];
    }

    function getFeeRecipient() external view override returns (address) {
        return LibStorage.diamondStorage().feeRecipient;
    }

    function getInterestRate() external view returns (uint256) {
        return LibStorage.diamondStorage().interestRate;
    }

    function getCollateralRatio() external view returns (uint256) {
        return LibStorage.diamondStorage().collateralRatio;
    }

    function getLoanDuration() external view returns (uint256) {
        return LibStorage.diamondStorage().loanDuration;
    }

    function getPlatformFee() external view returns (uint256) {
        return LibStorage.diamondStorage().platformFee;
    }
}