// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";

// modules
import {ILSP7DigitalAsset as ILSP7} from "@lukso/lsp7-contracts/contracts/ILSP7DigitalAsset.sol";
import {UniversalProfile} from "@lukso/universalprofile-contracts/contracts/UniversalProfile.sol";

// libraries
import {LSP2Utils} from "@lukso/lsp2-contracts/contracts/LSP2Utils.sol";

// constants
import {_TYPEID_LSP0_VALUE_RECEIVED} from "@lukso/lsp0-contracts/contracts/LSP0Constants.sol";
import {_LSP1_UNIVERSAL_RECEIVER_DELEGATE_PREFIX} from "@lukso/lsp1-contracts/contracts/LSP1Constants.sol";
import {
    _LSP6KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX,
    _LSP6KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX,
    _PERMISSION_CALL,
    _PERMISSION_TRANSFERVALUE,
    _ALLOWEDCALLS_TRANSFERVALUE,
    _ALLOWEDCALLS_CALL
} from "@lukso/lsp6-contracts/contracts/LSP6Constants.sol";

// To test
import {AutomaticSLYXSwapAfterNFTSales, ISLYXToken} from "../src/SLYXSwap/AutomaticSLYXSwapAfterNFTSales.sol";
import {UNIVERSAL_SWAP_UNIVERSAL_ROUTER, IUniversalRouter} from "../src/SLYXSwap/DataKeysValuesConfig.sol";

contract AutomaticSLYXSwapAfterNFTSalesTest is Test {
    UniversalProfile universalProfile = UniversalProfile(payable(0x927aAD446E3bF6eeB776387B3d7A89D8016fA54d));
    address mainController = 0xAe5DD8B8cc58DfC30B38c9b5B763E7b5BC4a5D09;

    AutomaticSLYXSwapAfterNFTSales automaticSLYXSwapAfterNFTSales;

    function setUp() public {
        automaticSLYXSwapAfterNFTSales = new AutomaticSLYXSwapAfterNFTSales();

        (bytes32[] memory dataKeys, bytes[] memory dataValues) = automaticSLYXSwapAfterNFTSales.configDataKeysValues();

        vm.prank(mainController);
        universalProfile.setDataBatch(dataKeys, dataValues);
    }

    function test_lsp1DelegateIsSet() public view {
        bytes32 lsp1DelegateDataKeyForValueReceived = LSP2Utils.generateMappingKey(
            _LSP1_UNIVERSAL_RECEIVER_DELEGATE_PREFIX, bytes20(_TYPEID_LSP0_VALUE_RECEIVED)
        );
        bytes memory value = universalProfile.getData(lsp1DelegateDataKeyForValueReceived);
        assertEq(value.length, 20);
        assertEq(address(bytes20(value)), address(automaticSLYXSwapAfterNFTSales));
    }

    function test_lsp1DelegatePermissionsAreSet() public view {
        bytes32 lsp1DelegatePermissionsDataKey = LSP2Utils.generateMappingWithGroupingKey(
            _LSP6KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, bytes20(address(automaticSLYXSwapAfterNFTSales))
        );
        bytes memory value = universalProfile.getData(lsp1DelegatePermissionsDataKey);
        assertEq(value.length, 32);
        assertEq(bytes32(value), _PERMISSION_CALL | _PERMISSION_TRANSFERVALUE);
    }

    function test_lsp1DelegateAllowedCallsAreSet() public view {
        bytes32 lsp1DelegateAllowedCallsDataKey = LSP2Utils.generateMappingKey(
            _LSP6KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX, bytes20(address(automaticSLYXSwapAfterNFTSales))
        );
        bytes memory value = universalProfile.getData(lsp1DelegateAllowedCallsDataKey);
        assertEq(value.length, 34);
        assertEq(bytes2(value), bytes2(0x0020));

        console.logBytes(value);

        bytes4 callTypes;
        assembly {
            callTypes := mload(add(value, add(32, 2)))
        }
        assertEq(callTypes, _ALLOWEDCALLS_TRANSFERVALUE | _ALLOWEDCALLS_CALL);

        bytes20 allowedAddress;
        assembly {
            allowedAddress := mload(add(value, add(32, 6)))
        }
        assertEq(address(allowedAddress), UNIVERSAL_SWAP_UNIVERSAL_ROUTER);

        bytes4 allowedStandard;
        assembly {
            allowedStandard := mload(add(value, add(32, 26)))
        }
        assertEq(allowedStandard, bytes4(0xffffffff));

        bytes4 allowedFunctionSelector;
        assembly {
            allowedFunctionSelector := mload(add(value, add(32, 30)))
        }
        assertEq(allowedFunctionSelector, IUniversalRouter.execute.selector);
    }

    function test_swapWhenReceiveLyxFromLsp8MarketplaceContract() public {
        address lsp8Marketplace = automaticSLYXSwapAfterNFTSales.UNIVERSAL_PAGE_LSP8_MARKETPLACE_CONTRACT();
        address stakingverseSlyxToken = automaticSLYXSwapAfterNFTSales.STAKINGVERSE_SLYX_TOKEN();

        uint256 amount = 100 ether;
        vm.deal(lsp8Marketplace, amount);

        uint256 balanceBefore = address(universalProfile).balance;
        uint256 slyxBalanceBefore = ILSP7(stakingverseSlyxToken).balanceOf(address(universalProfile));

        vm.prank(lsp8Marketplace);
        (bool success,) = address(universalProfile).call{value: amount}("");
        assertTrue(success);

        uint256 balanceAfter = address(universalProfile).balance;
        uint256 slyxBalanceAfter = ILSP7(stakingverseSlyxToken).balanceOf(address(universalProfile));

        // CHECK that the balance of the Universal Profile is the same before and after the transfer
        // because LYX got swapped to SLYX automatically
        assertEq(balanceAfter, balanceBefore);

        // Check the user has more SLYX tokens after the swap
        assertGt(slyxBalanceAfter, slyxBalanceBefore);

        // CHECK the `UniversalRouter` contract does not have any LYX or SLYX left after the swap
        assertEq(address(UNIVERSAL_SWAP_UNIVERSAL_ROUTER).balance, 0);
        assertEq(ILSP7(stakingverseSlyxToken).balanceOf(address(UNIVERSAL_SWAP_UNIVERSAL_ROUTER))s, 0);
    }
}
