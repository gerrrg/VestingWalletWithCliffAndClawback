// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./VestingWalletWithCliffAndClawback.sol";

/**
 * @title VestingWalletWithCliffAndClawbackFactory
 * @dev Factory for VestingWalletWithCliffAndClawback. See VestingWalletWithCliffAndClawback.sol for details.
 */
contract VestingWalletWithCliffAndClawbackFactory {

    event VestingWalletCreated(
        address indexed walletAddress,
        address ownerAddress,
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffDurationSeconds
    );

    mapping(address => bool) private _isFromFactory;

    /**
     * @dev Creates a new VestingWalletWithCliffAndClawback.
     */
    function create(
        address ownerAddress,
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffDurationSeconds
    ) public virtual returns (address) {
        VestingWalletWithCliffAndClawback wallet = new VestingWalletWithCliffAndClawback(
            ownerAddress,
            beneficiaryAddress,
            startTimestamp,
            durationSeconds,
            cliffDurationSeconds
        );
        
        // Log publicly
        emit VestingWalletCreated(
            address(wallet),
            ownerAddress,
            beneficiaryAddress,
            startTimestamp,
            durationSeconds,
            cliffDurationSeconds
        );
        
        // Log locally
        _isFromFactory[address(wallet)] = true;
        
        return address(wallet);
    }

    /**
     * @dev Returns `true` if given `wallet` was created by this factory.
     */
    function isWalletFromFactory(address wallet) external view returns (bool) {
        return _isFromFactory[wallet];
    }
}
