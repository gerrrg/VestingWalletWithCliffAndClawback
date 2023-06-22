// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";

contract VestingWalletWithCliff is VestingWallet {

    error CurrentTimeIsBeforeCliff();

    uint256 private immutable _cliffDuration;

    modifier isAfterCliff() {
        if (_isBeforeCliff()) {
            revert CurrentTimeIsBeforeCliff();
        }
        _;
    }

    /**
     * @dev Set the cliff.
     * @dev Set the beneficiary, start timestamp, and vesting duration within VestingWallet base class.
     */
    constructor(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffDurationSeconds
    ) payable 
        VestingWallet(beneficiaryAddress, startTimestamp, durationSeconds)
    {
        _cliffDuration = cliffDurationSeconds;
    }

    /**
     * @dev Getter for the vesting cliff duration.
     */
    function cliffDuration() public view virtual returns (uint256) {
        return _cliffDuration;
    }

    /**
     * @dev Override of getter for the amount of releasable eth to return 0 prior to meeting the cliff.
     */
    function releasable() public view override returns (uint256) {
        if (_isBeforeCliff()) {
            return 0;
        }
        super.releasable();
    }

    /**
     * @dev Override of getter for the amount of releasable `token` tokens to return 0 prior to meeting the cliff.
     * `token` should be the address of an IERC20 contract.
     */
    function releasable(address token) public view override returns (uint256) {
        if (_isBeforeCliff()) {
            return 0;
        }
        super.releasable(token);
    }

    /**
     * @dev Release the native token (ether) that have already vested if the cliff has been passed.
     *
     * Emits a {EtherReleased} event.
     */
    function release() public override isAfterCliff {
        super.release();
    }

    /**
     * @dev Release the tokens that have already vested if the cliff has been passed.
     *
     * Emits a {ERC20Released} event.
     */
    function release(address token) public override isAfterCliff {
        super.release(token);
    }

    /**
     * @dev Returns `true` if the current time is before the cliff.
     */
    function _isBeforeCliff() internal view virtual returns (bool) {
        return block.timestamp < (start() + cliffDuration());
    }
}
