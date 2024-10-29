// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Attestation } from "@signprotocol/signprotocol-evm/src/models/Attestation.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Interface for the PoolManager
contract ISPMock {
    function attest(
        Attestation calldata attestation,
        string calldata indexingKey,
        bytes calldata delegateSignature,
        bytes calldata extraData
    )
        external
        returns (uint64 attestationId)
    {
        return 0;
    }
}
