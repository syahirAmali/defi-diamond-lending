// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import {LibDiamond} from "./libraries/LibDiamond.sol";
import {PTokenStorage} from "./facets/PTokenFacet/storage/PTokenStorage.sol";
import {DebtTokenStorage} from "./facets/DebtTokenFacet/storage/DebtTokenStorage.sol";
import {TokenManagerStorage} from "./facets/TokenManagerFacet/storage/TokenManagerStorage.sol";
import {IDiamondCut} from "./facets/diamondCut/interfaces/IDiamondCut.sol";
import {IERC20Diamond} from "./facets/tokenFacetBase/IERC20Diamond.sol";
import {Errors} from "./libraries/helpers/Errors.sol";

contract DiamondToken {
    struct TokenInit {
        address _contractOwner;
        address _diamond;
        address _diamondCutFacetImpl;
        address _poolImpl;
        address _tokenImplementation;
        address _underlyingAsset;
        address _tokenManagerImplementation;
        address _accessControlImplementation;
        address _treasury;
        string _name;
        string _symbol;
        uint8 _decimals;
        bool _isPToken;
    }

    constructor(TokenInit memory _params) payable {
        // address token;
        require(
            _params._diamondCutFacetImpl != address(0),
            Errors.ADDRESS_NOT_ZERO
        );
        require(
            _params._tokenManagerImplementation != address(0),
            Errors.ADDRESS_NOT_ZERO
        );

        LibDiamond.setContractOwner(_params._contractOwner);
        TokenManagerStorage.tokenManagerStorage().coreDiamond = _params._diamond;

        // Add the diamondCut external function from the diamondCutFacet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _params._diamondCutFacetImpl,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        LibDiamond.diamondCut(cut, address(0), "");

        // Token facet

        IDiamondCut.FacetCut[] memory cutToken = new IDiamondCut.FacetCut[](1);
        // If pTokenFacet function selector has a different number of function selector
        bytes4[] memory tokenFunctionSelectors = new bytes4[](19);
        tokenFunctionSelectors[0] = IERC20Diamond.totalSupply.selector;
        tokenFunctionSelectors[1] = IERC20Diamond.balanceOf.selector;
        tokenFunctionSelectors[2] = IERC20Diamond.allowance.selector;
        tokenFunctionSelectors[3] = IERC20Diamond.approve.selector;
        tokenFunctionSelectors[4] = IERC20Diamond.transfer.selector;
        tokenFunctionSelectors[5] = IERC20Diamond.transferFrom.selector;
        tokenFunctionSelectors[6] = IERC20Diamond.increaseAllowance.selector;
        tokenFunctionSelectors[7] = IERC20Diamond.decreaseAllowance.selector;
        tokenFunctionSelectors[8] = IERC20Diamond.name.selector;
        tokenFunctionSelectors[9] = IERC20Diamond.symbol.selector;
        tokenFunctionSelectors[10] = IERC20Diamond.decimals.selector;
        tokenFunctionSelectors[11] = IERC20Diamond.mint.selector;
        tokenFunctionSelectors[12] = 0xe655dbd8; // setIncentivesController
        tokenFunctionSelectors[13] = 0x75d26413; // getIncentivesController

        if (_params._isPToken == true) {
            tokenFunctionSelectors[14] = 0xd7020d0a; // burn function
            tokenFunctionSelectors[15] = 0x4efecaa5; // transferUnderlyingto function
            tokenFunctionSelectors[16] = 0x7df5bd3b; // mintToTreasury
            tokenFunctionSelectors[17] = 0x6605bfda; // setTreasuryAddress
            tokenFunctionSelectors[18] = 0xe0024604; // getTreasuryAddress
        } else {
            tokenFunctionSelectors[14] = 0xf5298aca; // burn function
            tokenFunctionSelectors[15] = 0x6bd76d24; // borrowAllowance
            tokenFunctionSelectors[16] = 0xacf3dd30; // increaseBorrowDelegation
            tokenFunctionSelectors[17] = 0x8d33a725; // decreaseBorrowDelegation
            tokenFunctionSelectors[18] = 0xcb0f53dc; // decreaseBorrowDelegationDiamond
        }

        cutToken[0] = IDiamondCut.FacetCut({
            facetAddress: address(_params._tokenImplementation),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: tokenFunctionSelectors
        });

        LibDiamond.diamondCut(cutToken, address(0), "");

        // Token manager facet

        if (_params._isPToken == true) {
            IDiamondCut.FacetCut[]
                memory cutTokenManager = new IDiamondCut.FacetCut[](1);
            bytes4[] memory tokenManagerFunctionSelectors = new bytes4[](6);

            tokenManagerFunctionSelectors[0] = 0x6817031b; // setVault
            tokenManagerFunctionSelectors[1] = 0xf82b1ddb; // workFunds
            tokenManagerFunctionSelectors[2] = 0x8d928af8; // getVault
            tokenManagerFunctionSelectors[3] = 0x155dd5ee; // withdrawFunds
            tokenManagerFunctionSelectors[4] = 0x12065fe0; // getBalance

            cutTokenManager[0] = IDiamondCut.FacetCut({
                facetAddress: address(_params._tokenManagerImplementation),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: tokenManagerFunctionSelectors
            });

            LibDiamond.diamondCut(cutTokenManager, address(0), "");
        }

        {
            // Access Control facet

            IDiamondCut.FacetCut[]
                memory accessCut = new IDiamondCut.FacetCut[](1);
            bytes4[] memory accessfunctionSelectors = new bytes4[](3);
            accessfunctionSelectors[0] = 0xf2fde38b; // transfer ownership
            accessfunctionSelectors[1] = 0x8da5cb5b; // owner
            accessfunctionSelectors[2] = 0x8f32d59b; // is owner

            accessCut[0] = IDiamondCut.FacetCut({
                facetAddress: address(_params._accessControlImplementation),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: accessfunctionSelectors
            });

            LibDiamond.diamondCut(accessCut, address(0), "");
        }

        if (_params._isPToken == true) {
            PTokenStorage._init(
                _params._underlyingAsset,
                _params._poolImpl,
                _params._name,
                _params._symbol,
                _params._decimals,
                _params._treasury
            );
        } else {
            DebtTokenStorage._init(
                _params._underlyingAsset,
                _params._poolImpl,
                _params._name,
                _params._symbol,
                _params._decimals
            );
        }
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }
        // get facet from function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), Errors.FUNCTION_DOESNT_EXIST);
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}
