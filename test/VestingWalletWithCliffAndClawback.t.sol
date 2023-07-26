// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
pragma solidity ^0.8.13;

import "forge-std/StdCheats.sol";
import "forge-std/Test.sol";

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import "../src/VestingWalletWithCliffAndClawback.sol";
import "../src/VestingWalletWithCliffAndClawbackFactory.sol";

contract VestingWalletWithCliffAndClawbackTest is Test {
    VestingWalletWithCliffAndClawbackFactory public factory;
    VestingWalletWithCliffAndClawback public wallet;

    address provider = vm.addr(0x1);
    address beneficiary = vm.addr(0x2);
    address owner = vm.addr(0x3);
    ERC20 fakeToken;

    uint256 amountDeposit = 1e18;

    uint64 startDelay = 10;
    uint64 vestDuration = 40;
    uint64 cliffDuration = 10;

    function _assertReleasableIsAmount(uint256 amount) internal view {
        assert(wallet.releasable() == amount);
        assert(wallet.releasable(address(fakeToken)) == amount);
    }

    function _assertClawbackHasOccurred(bool expectedSuccess) internal view {
        assert(wallet.clawbackHasOccurred() == expectedSuccess);
        assert(wallet.clawbackHasOccurred(address(fakeToken)) == expectedSuccess);
    }

    function _getErc20AndEthBalances(address user) internal view returns (uint256, uint256) {
        return (address(user).balance, fakeToken.balanceOf(user));
    }

    function _getReleasableAmount() internal view returns (uint256) {
        uint256 amount = wallet.releasable();

        // ETH and ERC20 amounts should be the same
        assert(wallet.releasable(address(fakeToken)) == amount);

        return amount;
    }

    function _assertAbilityTo(string memory funcName, address user, bool expectedSuccess) internal {
        vm.startPrank(user);
        bool success;

        (success, ) = address(wallet).call(abi.encodeWithSignature(string.concat(funcName, "()")));
        assert(success == expectedSuccess);

        (success, ) = address(wallet).call(abi.encodeWithSignature(string.concat(funcName, "(address)"), address(fakeToken)));
        assert(success == expectedSuccess);

        vm.stopPrank();
    }

    function _assertAbilityToRelease(address user, bool expectedSuccess) internal {
        _assertAbilityTo("release", user, expectedSuccess);
    }

    function _assertAbilityToClawback(address user, bool expectedSuccess) internal {
        _assertAbilityTo("clawback", user, expectedSuccess);
    }

    function _assertAbilityToSweep(address user, bool expectedSuccess) internal {
        _assertAbilityTo("sweep", user, expectedSuccess);
    }

    function _clawback(address user) internal {
        _assertAbilityToClawback(user, true);
    }

    function _release(address user) internal {
        _assertAbilityToRelease(user, true);
    }

    function _sweep(address user) internal {
        _assertAbilityToSweep(user, true);
    }

    function _assertProceedsEqual(uint256 amount, address user, function (address) func) internal {
        (uint256 prevBalanceEth, uint256 prevBalanceToken) = _getErc20AndEthBalances(user);
        func(user);
        (uint256 postBalanceEth, uint256 postBalanceToken) = _getErc20AndEthBalances(user);

        assert(postBalanceEth - prevBalanceEth == amount);
        assert(postBalanceToken - prevBalanceToken == amount);
    }

    function _assertProceedsFromClawbackEqual(uint256 amount) internal {
        _assertProceedsEqual(amount, owner, _clawback);
    }

    function _assertProceedsFromReleaseEqual(uint256 amount) internal {
        _assertProceedsEqual(amount, beneficiary, _release);
    }

    function _assertProceedsFromSweepEqual(uint256 amount) internal {
        _assertProceedsEqual(amount, owner, _sweep);
    }

    function _assertReleasableAndProceedsFromReleaseEqual(uint256 amount) internal {
        _assertReleasableIsAmount(amount);
        _assertProceedsEqual(amount, beneficiary, _release);
        _assertReleasableIsAmount(0);
    }

    function _assertProceedsFromReleaseEqualReleasable() internal {
        uint256 amount = _getReleasableAmount();
        _assertProceedsEqual(amount, beneficiary, _release);
        _assertReleasableIsAmount(0);
    }

    function _depositTokensAndEth(address user, uint256 amount) internal {
        vm.prank(user);
        (bool success, ) = address(wallet).call{value: amount}("");
        assert(success);
        assert(amount == address(wallet).balance);

        vm.prank(user);
        success = fakeToken.transfer(address(wallet), amount);
        assert(success);
        assert(amount == fakeToken.balanceOf(address(wallet)));
    }

    function setUp() public {
        uint64 startTime = uint64(block.timestamp) + startDelay;        

        factory = new VestingWalletWithCliffAndClawbackFactory();
        address walletAddress = factory.create(owner, beneficiary, startTime, vestDuration, cliffDuration);
        wallet = VestingWalletWithCliffAndClawback(payable(walletAddress));

        vm.deal(provider, 1000 ether);
        vm.deal(beneficiary, 1 ether);

        fakeToken = new ERC20("Fake Token", "FAKE");
        deal(address(fakeToken), provider, amountDeposit * 2);

        _depositTokensAndEth(provider, amountDeposit);
    }

    function testWalletIsFromFactory() view public {
        assert(factory.isWalletFromFactory(address(wallet)));
    }

    function testCliffDuration() view public {
        assert(wallet.cliffDuration() == cliffDuration);
    }

    function testNothingReleasedBeforeCliff() public {
        _assertReleasableAndProceedsFromReleaseEqual(0);

        skip(startDelay);
        _assertReleasableAndProceedsFromReleaseEqual(0);

        skip(cliffDuration - 1);
        _assertReleasableAndProceedsFromReleaseEqual(0);
    }

    function testReleasableAfterCliffNonZero() public {
        skip(startDelay + cliffDuration);
        uint256 amount;
        for (uint256 i = startDelay + cliffDuration; i < startDelay + vestDuration; i++) {
            amount = amountDeposit * (i - startDelay) / vestDuration;
            _assertReleasableIsAmount(amount);
            skip(1);
        }
    }

    function testReleaseAfterCliff() public {
        skip(startDelay + cliffDuration);
        for (uint256 i = startDelay + cliffDuration; i < startDelay + vestDuration; i++) {
            _assertProceedsFromReleaseEqualReleasable();
            skip(1);
        }
    }

    function testReleasableAfterVestFullAmount() public {
        skip(startDelay + vestDuration);
        _assertReleasableAndProceedsFromReleaseEqual(amountDeposit);
    }

    // Only owner can clawback
    function testClawbackUsers() public {
        _assertAbilityToClawback(provider, false);
        _assertAbilityToClawback(beneficiary, false);
        _assertAbilityToClawback(owner, true);
    }

    // Only beneficiary can release
    function testReleaseUsers() public {
        _assertAbilityToRelease(provider, false);
        _assertAbilityToRelease(beneficiary, true);
        _assertAbilityToRelease(owner, false);
    }

    // Clawback before cliff should return everything
    function testImmediateClawback() public {
        _assertClawbackHasOccurred(false);
        _assertProceedsFromClawbackEqual(amountDeposit);
        _assertClawbackHasOccurred(true);
    }

    // Clawback after cliff should return (everything - claimable)
    function testClawbackAfterCliff() public {
        _assertClawbackHasOccurred(false);

        skip(startDelay + cliffDuration + vestDuration/2);

        uint256 claimable = _getReleasableAmount();
        assert(claimable != 0);

        // Run and verify clawback
        _assertProceedsFromClawbackEqual(amountDeposit - claimable);

        // Run and verify release
        _assertReleasableAndProceedsFromReleaseEqual(claimable);

        _assertClawbackHasOccurred(true);
    }

    // Clawback after duration has elapsed should return nothing
    function testClawbackAfterVest() public {
        _assertClawbackHasOccurred(false);

        skip(startDelay + cliffDuration + vestDuration);

        // Run and verify clawback
        _assertProceedsFromClawbackEqual(0);

        // Run and verify release
        _assertReleasableAndProceedsFromReleaseEqual(amountDeposit);

        _assertClawbackHasOccurred(true);
    }

    // Sweep should fail before clawback
    function testUsersSweepBeforeAfterClawback() public {
        _assertAbilityToSweep(provider, false);
        _assertAbilityToSweep(beneficiary, false);
        _assertAbilityToSweep(owner, false);

        _clawback(owner);

        // Only owner can sweep after clawback
        _assertAbilityToSweep(provider, false);
        _assertAbilityToSweep(beneficiary, false);
        _assertAbilityToSweep(owner, true);
    }

    // Sweep should return nothing after clawback
    function testNothingToSweepAfterClawback() public {
        _clawback(owner);

        // Sweep immediately after clawback
        _assertProceedsFromSweepEqual(0);
    }

    // Sweep should return amount after amount is sent to contract after clawback
    function testAssetsToSweepAfterDepositAfterClawback() public {
        _clawback(owner);

        _depositTokensAndEth(provider, amountDeposit);
        _assertReleasableAndProceedsFromReleaseEqual(0); // ensure beneficiary can't get it

        // Sweep after deposit after clawback
        _assertProceedsFromSweepEqual(amountDeposit);
    }
}
