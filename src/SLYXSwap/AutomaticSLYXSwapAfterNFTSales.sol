// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// interfaces
import {IERC725X} from "@erc725/smart-contracts/contracts/interfaces/IERC725X.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {
    ILSP1UniversalReceiverDelegate as ILSP1Delegate
} from "@lukso/lsp1-contracts/contracts/ILSP1UniversalReceiverDelegate.sol";

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

contract AutomaticSLYXSwapAfterNFTSales is IERC165, ILSP1Delegate {
    /// @notice Address of the Universal.Page LSP8 Marketplace contract on LUKSO Mainnet.
    /// Responsible for sending LYX to UPs after sales and accepting offers.
    address public constant UNIVERSAL_PAGE_LSP8_MARKETPLACE_CONTRACT = 0x6807c995602EAF523a95A6B97aCC4DA0d3894655;

    address public constant UNIVERSAL_SWAP_UNIVERSAL_ROUTER = 0x6EDaC58326277F1Baf277C41740Db1ff8d7ab13c;

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
        // CHECK that we received money from the `LSP8Marketplace` contract from UniversalPage
        // https://github.com/Universal-Page/contracts/blob/91893d701ef041a8a4f9d83b69d5b04da4dc9789/src/marketplace/lsp8/LSP8Marketplace.sol#L185
        if (sender != UNIVERSAL_PAGE_LSP8_MARKETPLACE_CONTRACT) {
            return "Error: Sender not Universal.Page LSP8Marketplace contract.";
        }

        // callback the Universal Profile via `execute(...)` and call the UniversalRouter to perform the swap
        address userUniversalProfile = msg.sender;

        // commands: 2 commands. Each bytes1 corresponds to a `commandType` according to the Uniswap V3 Dispatcher
        // TODO: define if we also need to do commands for PAY_PORTION and SWEEP
        bytes memory commands = abi.encodePacked(WRAP_LYX, V3_SWAP_EXACT_IN);
        bytes[] memory inputs = new bytes[](2);

        // inputs[0] = wrap LYX to WLYX1
        // address(2) is used as a flag for identifying address(this), saves gas by sending more 0 bytes
        bytes memory inputsWrapLyx = abi.encode(address(2), value);
        inputs[0] = inputsWrapLyx;

        uint256 amountOutMin = ISLYXToken(STAKINGVERSE_SLYX_TOKEN).getSLYXTokenValue(value);

        bytes memory singleHopPathEncoding = abi.encodePacked(
            WLYX1,
            uint24(3000), // 0.3% in basis points
            STAKINGVERSE_SLYX_TOKEN
        );

        // TODO: define if recipient should be user or Universal Router address
        // abi.encode(
        //     recipient, ✅
        //     amountIn,
        //     amountOutMin,
        //     path, -> The encoded route for the swap (e.g: for single hop, address tokenIn, uint24 fee, address
        // tokenOut). payerIsUser
        // );
        bytes memory inputsSwapExactIn = abi.encode(
            userUniversalProfile, // address recipient
            value, // uint256 amountIn
            amountOutMin, // uint256, TODO: get `amountOutMin` via SLYXToken conversion or via Universal Swap contract
            singleHopPathEncoding,
            false
        );
        inputs[1] = inputsSwapExactIn;

        // TODO: figure out if needing to pass those
        // ------------------------------------------
        // 3 x bytes32
        // 0x0000000000000000000000008a3982f0a7d154d11a5f43eec7f50e52ebbc8f7d000000000000000000000000c514ac83d6ecc7ddc9cd23b353371934d285b36a00000000000000000000000000000000000000000000000000000000000000c8
        // 
        // 3 x bytes32
        // 0x0000000000000000000000008a3982f0a7d154d11a5f43eec7f50e52ebbc8f7d00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000bfecae1685bf20d
        // ------------------------------------------

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
