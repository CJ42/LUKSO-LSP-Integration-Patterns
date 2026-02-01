// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// interfaces
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC725X} from "@erc725/smart-contracts/contracts/interfaces/IERC725X.sol";
import {IERC725Y} from "@erc725/smart-contracts/contracts/interfaces/IERC725Y.sol";
import {
    ILSP1UniversalReceiverDelegate as ILSP1Delegate
} from "@lukso/lsp1-contracts/contracts/ILSP1UniversalReceiverDelegate.sol";

// libraries
import {LSP2Utils} from "@lukso/lsp2-contracts/contracts/LSP2Utils.sol";
import {LSP6Utils} from "@lukso/lsp6-contracts/contracts/LSP6Utils.sol";

// constants
import {OPERATION_0_CALL} from "@erc725/smart-contracts/contracts/constants.sol";
import {_TYPEID_LSP0_VALUE_RECEIVED} from "@lukso/lsp0-contracts/contracts/LSP0Constants.sol";
import {
    _INTERFACEID_LSP1_DELEGATE,
    _LSP1_UNIVERSAL_RECEIVER_DELEGATE_PREFIX
} from "@lukso/lsp1-contracts/contracts/LSP1Constants.sol";
import {
    _LSP6KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX,
    _PERMISSION_TRANSFERVALUE,
    _PERMISSION_CALL,
    _ALLOWEDCALLS_TRANSFERVALUE,
    _ALLOWEDCALLS_CALL
} from "@lukso/lsp6-contracts/contracts/LSP6Constants.sol";

/// @dev Minimal interface of Stakingverse Vault. Used to encode the `deposit(address)` function call.
/// https://github.com/Stakingverse/pool-contracts/blob/43e481e4b42e8f24af0432b3a83da7d7b6c6d79c/src/IVault.sol#L61-L64
interface IStakingverseVault {
    function deposit(address beneficiary) external payable;
}

/// @dev This contract automatically converts LYX reci in Stakingverse's Vault
/// when receiving LYX from new NFT sales from Universal.Page
///
/// It can be setup by setting the address of this contract as value under the data key
/// `LSP1UniversalReceiverDelegate:<_TYPEID_LSP0_VALUE_RECEIVED>`
/// (data key in hex = `0x0cfc51aec37c55a4d0b100009c4705229491d365fb5434052e12a386d6771d97`
///
/// @dev WARNING! This contract is a PoC and has not been tested
contract AutomaticStakingAfterNFTSales is IERC165, ILSP1Delegate {
    using LSP6Utils for *;

    /// @notice Address of the Universal.Page LSP8 Marketplace contract on LUKSO Mainnet.
    /// Responsible for sending LYX to UPs after sales and accepting offers.
    address public constant UNIVERSAL_PAGE_LSP8_MARKETPLACE_CONTRACT = 0x6807c995602EAF523a95A6B97aCC4DA0d3894655;

    /// @notice Address of the Stakingverse Vault contract on LUKSO Mainnet.
    /// Where we want to forward automatically LYX received from sales to stake.
    address public constant STAKINGVERSE_VAULT_CONTRACT = 0x9F49a95b0c3c9e2A6c77a16C177928294c0F6F04;

    /// @notice AddressPermissions:AllowedCalls:<this-contract-address>
    /// Data key to set via `setData(bytes32,bytes)` to grant permissions on a Universal Profile
    /// to this Universal Receiver Delegate contract.
    ///
    /// @dev The value of this variable is initialized when the contract is deployed,
    /// as <this-contract-address> cannot be a compile time constant
    /// (The address of this contract is only know on deployment)
    bytes32 public immutable ALLOWED_CALLS_DATA_KEY_CONFIG;

    /// @notice Value to set for the data key AddressPermissions:AllowedCalls:<address>.
    /// Data key to set via `setData(bytes32,bytes)` to grant permissions on a Universal Profile
    /// to this Universal Receiver Delegate contract.
    ///
    /// Consists of:
    /// - CALL + TRANSFER_VALUE restrictions
    /// - STAKINGVERSE_VAULT_CONTRACT
    /// - IStakingverseVault.deposit.selector
    bytes public constant ALLOWED_CALLS_DATA_VALUE_CONFIG = abi.encodePacked(
        hex"0020",
        _ALLOWEDCALLS_TRANSFERVALUE | _ALLOWEDCALLS_CALL, // 00000003
        STAKINGVERSE_VAULT_CONTRACT,
        IStakingverseVault.deposit.selector
    );

    /// @dev `LSP1UniversalReceiverDelegate:<_TYPEID_LSP0_VALUE_RECEIVED>`
    /// @return Hex value `0x0cfc51aec37c55a4d0b100009c4705229491d365fb5434052e12a386d6771d97`
    bytes32 public immutable _LSP1DELEGATE_TYPEID_VALUE_RECEIVED_DATA_KEY_CONFIG;

    constructor() {
        ALLOWED_CALLS_DATA_KEY_CONFIG =
            LSP2Utils.generateMappingKey(_LSP6KEY_ADDRESSPERMISSIONS_ALLOWEDCALLS_PREFIX, bytes20(address(this)));

        _LSP1DELEGATE_TYPEID_VALUE_RECEIVED_DATA_KEY_CONFIG =
            LSP2Utils.generateMappingKey(_LSP1_UNIVERSAL_RECEIVER_DELEGATE_PREFIX, bytes20(address(this)));
    }

    function universalReceiverDelegate(
        address sender,
        uint256 value,
        bytes32,
        /* typeId */
        bytes memory /* data */
    )
        external
        returns (bytes memory)
    {
        // CHECK that we received money from the `LSP8Marketplace` contract from UniversalPage
        // see:
        // https://github.com/Universal-Page/contracts/blob/91893d701ef041a8a4f9d83b69d5b04da4dc9789/src/marketplace/lsp8/LSP8Marketplace.sol#L185
        if (sender != UNIVERSAL_PAGE_LSP8_MARKETPLACE_CONTRACT) {
            return "Error: Sender not Universal.Page LSP8Marketplace contract.";
        }

        // callback the Universal Profile via `execute(...)` and call the Stakingverse Vault to
        // stake the received LYX
        address userUniversalProfile = msg.sender;

        bytes memory vaultDepositCalldata = abi.encodeCall(IStakingverseVault.deposit, (userUniversalProfile));

        try IERC725X(userUniversalProfile)
            .execute(OPERATION_0_CALL, STAKINGVERSE_VAULT_CONTRACT, value, vaultDepositCalldata) {
            // Successfully staked LYX
            return unicode"✅ LYX received from NFT sale staked successfully";
        } catch (bytes memory error) {
            return bytes(string.concat(unicode"❌ Failed to stake LYX received from NFT sale. Error: ", string(error)));
        }
    }

    // Helper functionalities (not needed to have the contract working)

    /// @dev View functions to check if this Universal Receiver Delegate contract has the right
    /// permissions to operate on `userUniversalProfile`
    /// - ✅ permission CALL
    /// - ✅ permission TRANSFER_VALUE
    /// - ✅ AllowedCall: (Any Standard + STAKINGVERSE_VAULT_CONTRACT + `deposit(address)`) function
    /// @param userUniversalProfile The Universal Profile contract to check on for the permissions
    /// TODO: add checks if this contract would ever be set with permission `SUPER_CALL` +
    /// `SUPER_TRANSFERVALUE` (it should return true)
    function checkRequiredPermissions(address userUniversalProfile)
        public
        view
        returns (bool permissionsSet, string memory debuggingMessage)
    {
        bytes32 thisContractPermissions = IERC725Y(userUniversalProfile).getPermissionsFor(address(this));

        bool hasCallPermission = thisContractPermissions.hasPermission(_PERMISSION_CALL);
        bool hasTransferValuePermission = thisContractPermissions.hasPermission(_PERMISSION_TRANSFERVALUE);

        if (!hasCallPermission) return (false, unicode"❌ Missing CALL Permission");

        if (!hasTransferValuePermission) return (false, unicode"❌ Missing TRANSFER_VALUE Permission");

        bytes memory thisContractAllowedCalls = IERC725Y(userUniversalProfile).getAllowedCallsFor(address(this));

        // Note that this is a minimal implementation here. This check would fail if a list of
        // AllowedCalls is set for this contract. For simplicity, we assume only this single value is set.

        if (keccak256(thisContractAllowedCalls) != keccak256(ALLOWED_CALLS_DATA_VALUE_CONFIG)) {
            return (false, unicode"❌ Invalid AllowedCalls");
        }

        return (true, unicode"✅ All required permissions are set");
    }

    /// @notice Check if this Universal Receiver Delegate contract is to connect to a specific Universal Profile
    /// to react when the `_TYPEID_LSP0_VALUE_RECEIVED` is triggered on the `universalReceiver(...)` function.
    function isConnectedToProfile(address userUniversalProfile) public view returns (bool) {
        bytes memory value = IERC725Y(userUniversalProfile).getData(_LSP1DELEGATE_TYPEID_VALUE_RECEIVED_DATA_KEY_CONFIG);

        // MUST be a 20 bytes long address set as value
        if (value.length != 20) return false;

        return address(bytes20(value)) == address(this);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == _INTERFACEID_LSP1_DELEGATE || interfaceId == type(IERC165).interfaceId;
    }
}
