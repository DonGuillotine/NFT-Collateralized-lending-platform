// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAdmin {
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event EmergencyPaused(bool paused);
    event WhitelistedCollectionUpdated(address indexed collection, bool status);
    event ParametersUpdated(string parameterName, uint256 newValue);
    event FeeRecipientUpdated(address indexed newFeeRecipient);

    /**
     * @dev Sets a new admin address
     * @param newAdmin The address of the new admin
     */
    function setAdmin(address newAdmin) external;

    /**
     * @dev Toggles emergency pause state
     * @param pauseState The new pause state
     */
    function setEmergencyPause(bool pauseState) external;

    /**
     * @dev Updates whitelist status for NFT collections
     * @param collection The collection address
     * @param status The whitelist status
     */
    function updateWhitelistedCollection(address collection, bool status) external;

    /**
     * @dev Updates platform parameters
     * @param interestRate The new interest rate (1000 = 10%)
     * @param collateralRatio The new collateral ratio (15000 = 150%)
     * @param loanDuration The new loan duration in seconds
     * @param platformFee The new platform fee (100 = 1%)
     */
    function updateParameters(
        uint256 interestRate,
        uint256 collateralRatio,
        uint256 loanDuration,
        uint256 platformFee
    ) external;

    /**
     * @dev Sets the fee recipient address
     * @param newFeeRecipient The new fee recipient address
     */
    function setFeeRecipient(address newFeeRecipient) external;

    /**
     * @dev Gets the current admin address
     */
    function getAdmin() external view returns (address);

    /**
     * @dev Gets the emergency pause state
     */
    function isPaused() external view returns (bool);

    /**
     * @dev Checks if a collection is whitelisted
     * @param collection The collection address to check
     */
    function isCollectionWhitelisted(address collection) external view returns (bool);

    /**
     * @dev Gets the current fee recipient address
     */
    function getFeeRecipient() external view returns (address);
}