// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// libraries
import {LSP2Utils} from "@lukso/lsp2-contracts/contracts/LSP2Utils.sol";

// constants
import {_TYPEID_LSP0_VALUE_RECEIVED} from "@lukso/lsp0-contracts/contracts/LSP0Constants.sol";
import {_LSP1_UNIVERSAL_RECEIVER_DELEGATE_PREFIX} from "@lukso/lsp1-contracts/contracts/LSP1Constants.sol";
import {
    _LSP6KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX,
    _LSP6KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX,
    _PERMISSION_TRANSFERVALUE,
    _PERMISSION_CALL,
    _ALLOWEDCALLS_TRANSFERVALUE,
    _ALLOWEDCALLS_CALL
} from "@lukso/lsp6-contracts/contracts/LSP6Constants.sol";

address constant UNIVERSAL_SWAP_UNIVERSAL_ROUTER = 0x6EDaC58326277F1Baf277C41740Db1ff8d7ab13c;

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs) external payable;
}

abstract contract DataKeysValuesConfig {
    // -------------------------------
    // |      Data Keys Configs      |
    // -------------------------------

    /// @dev `LSP1UniversalReceiverDelegate:<_TYPEID_LSP0_VALUE_RECEIVED>`
    /// Hex value = `0x0cfc51aec37c55a4d0b100009c4705229491d365fb5434052e12a386d6771d97`
    function configDataKeysValues() public view returns (bytes32[] memory, bytes[] memory) {
        bytes32[] memory dataKeysConfig = new bytes32[](3);
        bytes[] memory dataValuesConfig = new bytes[](3);

        // LSP1UniversalReceiverDelegate:<_TYPEID_LSP0_VALUE_RECEIVED>
        dataKeysConfig[0] = LSP2Utils.generateMappingKey(
            _LSP1_UNIVERSAL_RECEIVER_DELEGATE_PREFIX, bytes20(_TYPEID_LSP0_VALUE_RECEIVED)
        );
        dataValuesConfig[0] = abi.encodePacked(address(this));

        // AddressPermissions:Permissions:<swapper-contract-address>
        dataKeysConfig[1] = LSP2Utils.generateMappingWithGroupingKey(
            _LSP6KEY_ADDRESSPERMISSIONS_PERMISSIONS_PREFIX, bytes20(address(this))
        );
        dataValuesConfig[1] = abi.encodePacked(_PERMISSION_CALL | _PERMISSION_TRANSFERVALUE);

        // AddressPermissions:AllowedCalls:<swapper-contract-address>
        dataKeysConfig[2] =
            LSP2Utils.generateMappingKey(_LSP6KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX, bytes20(address(this)));

        dataValuesConfig[2] = _encodeAllowedCallsDataValueConfig();

        return (dataKeysConfig, dataValuesConfig);
    }

    /// @dev Value to set for the data key AddressPermissions:AllowedCalls:<address>.
    /// via `setData(bytes32,bytes)` to grant permissions on a Universal Profile
    /// to this Universal Receiver Delegate contract.
    ///
    /// Consists of:
    /// - CALL + TRANSFER_VALUE restrictions
    /// - UNIVERSAL_SWAP_UNIVERSAL_ROUTER
    /// - IUniversalRouter.execute.selector -> execute(bytes,bytes[])
    function _encodeAllowedCallsDataValueConfig() internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes2(0x0020),
            _ALLOWEDCALLS_TRANSFERVALUE | _ALLOWEDCALLS_CALL, // 00000003
            UNIVERSAL_SWAP_UNIVERSAL_ROUTER,
            bytes4(0xffffffff),
            IUniversalRouter.execute.selector
        );
    }
}
