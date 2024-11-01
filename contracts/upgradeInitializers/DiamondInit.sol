// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibStorage} from "../libraries/LibStorage.sol";
import {LibSecurity} from "../libraries/LibSecurity.sol";
import { IDiamondLoupe } from "../interfaces/IDiamondLoupe.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";
import { IERC173 } from "../interfaces/IERC173.sol";
import { IERC165 } from "../interfaces/IERC165.sol";

// It is exapected that this contract is customized if you want to deploy your diamond
// with data from a deployment script. Use the init function to initialize state variables
// of your diamond. Add parameters to the init funciton if you need to.

contract DiamondInit {    
    error ZeroAddress();

    // You can add parameters to this function in order to pass in 
    // data to set your own state variables
    function init(address _admin) external {
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // NFT Lending Platform parameters
        LibStorage.NFTLendingStorage storage nftLendingDS = LibStorage.diamondStorage();

        nftLendingDS.admin = _admin;
        
        nftLendingDS.collateralRatio = 15000;
        nftLendingDS.interestRate = 1000;
        nftLendingDS.loanDuration = 7 days;
        
        if(msg.sender == address(0)) revert ZeroAddress();
        nftLendingDS.admin = msg.sender;
        nftLendingDS.paused = false;

        nftLendingDS.loanCounter = 0;

         // Initialize Treasury parameters
        nftLendingDS.platformFee = 100; // 1%
        nftLendingDS.minDeposit = 0.1 ether;
        nftLendingDS.platformRevenue = 0;
        nftLendingDS.totalPoolBalance = 0;

        // add your own state variables 
        // EIP-2535 specifies that the `diamondCut` function takes two optional 
        // arguments: address _init and bytes calldata _calldata
        // These arguments are used to execute an arbitrary function using delegatecall
        // in order to set state variables in the diamond during deployment or an upgrade
        // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface 
    }


}