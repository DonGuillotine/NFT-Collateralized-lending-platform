// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LibStorage.sol";

library LibSecurity {
    using LibStorage for LibStorage.NFTLendingStorage;

    error SystemPaused();
    error NotAuthorized();

    modifier whenNotPaused() {
        if (LibStorage.diamondStorage().paused) {
            revert SystemPaused();
        }
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != LibStorage.diamondStorage().admin) {
            revert NotAuthorized();
        }
        _;
    }

    function _initializeSecurity(address _admin) internal {
        LibStorage.NFTLendingStorage storage ds = LibStorage.diamondStorage();
        ds.admin = _admin;
        ds.paused = false;
    }
}