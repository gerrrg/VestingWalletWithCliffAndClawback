// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./VestingWalletWithCliff.sol";
import "./VestingWalletWithClawback.sol";

/**
 * @title VestingWalletWithCliffAndClawback
 * @dev This contract builds on OpenZeppelin's VestingWallet. See comments in VestingWallet for base details.
 *
 * This contract adds the following functionality:
 *   - Add a vesting cliff: `recipient` cannot claim any vested tokens until a cliff duration has elapsed
 *   - Add `owner`: contract is `Ownable2Step`
 *   - Add clawbacks: contract `owner` can clawback any unvested tokens
 *   - Add post-clawback sweeps: contract `owner` can sweep any excess tokens sent to the contract after clawback
 */
contract VestingWalletWithCliffAndClawback is VestingWalletWithCliff, VestingWalletWithClawback {

    /**
     * @dev Set the cliff and owner.
     * @dev Set the beneficiary, start timestamp, and vesting duration within VestingWallet base class.
     */
    constructor(
        address ownerAddress,
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffDurationSeconds
    ) payable 
        VestingWallet(beneficiaryAddress, startTimestamp, durationSeconds)
        VestingWalletWithCliff(cliffDurationSeconds)
        VestingWalletWithClawback(ownerAddress)
    {
    }

    /**
     * @dev Override for `releasable()` to stack logic respectively from VestingWalletWith{Cliff,Clawback}.
     */
    function releasable() public view override(VestingWalletWithCliff, VestingWalletWithClawback) returns (uint256) {
        return super.releasable();
    }

    /**
     * @dev Override for `releasable(token)` to stack logic respectively from VestingWalletWith{Cliff,Clawback}.
     */
    function releasable(address token)
        public
        view
        override(VestingWalletWithCliff, VestingWalletWithClawback)
        returns (uint256)
    {
        return super.releasable(token);
    }

    /**
     * @dev Override for `release()` to use VestingWalletWithCliff w/ cliff modifier.
     */
    function release() public override(VestingWallet, VestingWalletWithCliff) {
        super.release();
    }

    /**
     * @dev Override for `release(token)` to use VestingWalletWithCliff w/ cliff modifier.
     */
    function release(address token) public override(VestingWallet, VestingWalletWithCliff) {
        super.release(token);
    }


}
