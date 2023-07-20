// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";

/**
 * @title VestingWalletWithReleaseGuard
 * @dev This contract builds on OpenZeppelin's VestingWallet. See comments in VestingWallet for base details.
 *
 * This contract adds the following functionality:
 *   - Add a release guard: only `beneficiary` can release vested funds; no one can force funds upon `beneficiary`
 */
abstract contract VestingWalletWithReleaseGuard is VestingWallet {

    error CallerIsNotBeneficiary();

    /**
     * @dev Throws if called by any account other than the beneficiary.
     */
    modifier onlyBeneficiary() {
        if (beneficiary() != msg.sender) {
            revert CallerIsNotBeneficiary();
        }
        _;
    }

    /**
     * @dev Override of VestingWallet's `release` to enforce that the caller must be the beneficiary.
     */
    function release() public virtual override onlyBeneficiary {
        super.release();
    }

    /**
     * @dev Override of VestingWallet's `release` to enforce that the caller must be the beneficiary.
     */
    function release(address token) public virtual override onlyBeneficiary {
        super.release(token);
    }
}
