// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// interfaces
import {IERC725X} from "@erc725/smart-contracts/contracts/interfaces/IERC725X.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {
    ILSP1UniversalReceiverDelegate as ILSP1Delegate
} from "@lukso/lsp1-contracts/contracts/ILSP1UniversalReceiverDelegate.sol";

// modules
import {DataKeysValuesConfig} from "./DataKeysValuesConfig.sol";

// constants
import {OPERATION_0_CALL} from "@erc725/smart-contracts/contracts/constants.sol";
import {_INTERFACEID_LSP1_DELEGATE} from "@lukso/lsp1-contracts/contracts/LSP1Constants.sol";

// Universal Router command types
bytes1 constant WRAP_LYX = 0x0b;
bytes1 constant V3_SWAP_EXACT_IN = 0x00;
bytes1 constant PAY_PORTION = 0x06;
bytes1 constant SWEEP = 0x04;

interface ISLYXToken {
    function getSLYXTokenValue(uint256 stakedLyxAmount) external view returns (uint256);
}

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs) external payable;
}

contract AutomaticSLYXSwapAfterNFTSales is IERC165, ILSP1Delegate, DataKeysValuesConfig {
    /// @notice Address of the Universal.Page LSP7 + LSP8 Marketplace contract on LUKSO Mainnet.
    /// Responsible for sending LYX to UPs after sales and accepting offers.
    address public constant UNIVERSAL_PAGE_LSP7_MARKETPLACE_CONTRACT = 0xE04cF97440cD191096C4103f9C48ABd96184fB8D;
    address public constant UNIVERSAL_PAGE_LSP8_MARKETPLACE_CONTRACT = 0x6807c995602EAF523a95A6B97aCC4DA0d3894655;

    address public constant UNIVERSAL_SWAP_UNIVERSAL_ROUTER = 0x6EDaC58326277F1Baf277C41740Db1ff8d7ab13c;

    address public constant UNIVERSAL_SWAP_FEE_SPLITTER = 0xC514AC83d6EcC7Ddc9Cd23b353371934d285b36a;

    address public constant WLYX1 = 0x2dB41674F2b882889e5E1Bd09a3f3613952bC472;

    address public constant STAKINGVERSE_SLYX_TOKEN = 0x8A3982f0A7d154D11a5f43EEc7F50E52eBBc8F7D;

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
        // CHECK that we received money from the `LSP7/LSP8Marketplace` contract from UniversalPage
        // https://github.com/Universal-Page/contracts/blob/91893d701ef041a8a4f9d83b69d5b04da4dc9789/src/marketplace/lsp8/LSP8Marketplace.sol#L185
        if (sender != UNIVERSAL_PAGE_LSP7_MARKETPLACE_CONTRACT || sender != UNIVERSAL_PAGE_LSP8_MARKETPLACE_CONTRACT) {
            return "Error: Sender not Universal.Page Marketplace contracts.";
        }

        // callback the Universal Profile via `execute(...)` and call the UniversalRouter to perform the swap
        address userUniversalProfile = msg.sender;

        // Commands sent to Universal Router that are then sent to Universal Swap Dispatcher
        // 1. Wrap native LYX token into WLYX1
        // 2. Perform the swap
        // 3. Send fee
        // 4. Send remaining tokens held by the Universal Router to ensure none are left after the tx is complete
        bytes memory commands = abi.encodePacked(WRAP_LYX, V3_SWAP_EXACT_IN, PAY_PORTION, SWEEP);
        bytes[] memory inputs = new bytes[](4);

        // ---------------
        // | 1. WRAP_LYX |
        // ---------------

        // address(2) is used as a flag for identifying address(this), saves gas by sending more 0 bytes
        bytes memory wrapLyx = abi.encode(address(2), value);
        inputs[0] = wrapLyx;

        // --------------------
        // | 2. SWAP_EXACT_IN |
        // --------------------

        uint256 amountOutMin = ISLYXToken(STAKINGVERSE_SLYX_TOKEN).getSLYXTokenValue(value);

        bytes memory singleHopPathEncoding = abi.encodePacked(
            WLYX1,
            uint24(3000), // 0.3% in basis points
            STAKINGVERSE_SLYX_TOKEN
        );

        // address(2) is used as a flag for identifying address(this), saves gas by sending more 0 bytes
        // TODO: define if get `amountOutMin` should be obtained via SLYXToken conversion or via Universal Swap contract
        bytes memory swapExactIn = abi.encode(
            address(2), // recipient
            value, // uint256 amountIn
            amountOutMin, // uint256,
            singleHopPathEncoding,
            false
        );
        inputs[1] = swapExactIn;

        // ------------------
        // | 3. PAY_PORTION |
        // ------------------

        bytes memory payPortion = abi.encode(STAKINGVERSE_SLYX_TOKEN, UNIVERSAL_SWAP_FEE_SPLITTER, uint256(200));
        inputs[2] = payPortion;

        // ------------
        // | 4. SWEEP |
        // ------------
        bytes memory sweep = abi.encode(
            STAKINGVERSE_SLYX_TOKEN,
            address(1), // constant state used by the Universal Router (it will be the Universal Profile here)
            amountOutMin
        );
        inputs[3] = sweep;

        bytes memory universalRouterExecuteFunctionCall = abi.encodeCall(IUniversalRouter.execute, (commands, inputs));

        try IERC725X(userUniversalProfile)
            .execute(OPERATION_0_CALL, UNIVERSAL_SWAP_UNIVERSAL_ROUTER, 0, universalRouterExecuteFunctionCall) {
            return unicode"🪙🔄✅ Successfully swapped LYX for SLYX on Universal Swap 🛸";
        } catch {
            return unicode"🪙🔄❌ Failed to swap LYX for SLYX on Universal Swap 🛸";
        }
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == _INTERFACEID_LSP1_DELEGATE || interfaceId == type(IERC165).interfaceId;
    }
}
