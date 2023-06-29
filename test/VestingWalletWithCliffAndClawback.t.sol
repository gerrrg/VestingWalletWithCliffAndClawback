// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "../src/VestingWalletWithCliffAndClawback.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract VestingWalletWithCliffAndClawbackTest is Test {
    VestingWalletWithCliffAndClawback public wallet;

    // Foundry does not handle overloaded functions well at all.
    // Manually entering the function selectors here is the easiest workaround.
    bytes4 constant releaseSelector = "\x86\xd1\xa6\x9f";
    bytes4 constant releaseAddressSelector = "\x19\x16\x55\x87";
    bytes4 constant clawbackSelector = "\x25\x26\xd9\x60";
    bytes4 constant clawbackAddressSelector = "\xed\xf6\x85\x58";
    bytes4 constant sweepSelector = "\x35\xfa\xa4\x16";
    bytes4 constant sweepAddressSelector = "\x01\x68\x1a\x62";
    bytes4 constant clawbackHasOccurredSelector = "\x37\x29\xc2\x21";
    bytes4 constant clawbackHasOccurredAddressSelector = "\x0e\x9f\x2b\xea";

    address provider = vm.addr(0x1);
    address recipient = vm.addr(0x2);
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

    function _clawback(address user) internal {
        vm.startPrank(user);
        wallet.clawback();
        wallet.clawback(address(fakeToken));
        vm.stopPrank();
    }

    function _release(address user) internal {
        vm.startPrank(user);
        wallet.release();
        wallet.release(address(fakeToken));
        vm.stopPrank();
    }

    function _sweep(address user) internal {
        vm.startPrank(user);
        wallet.sweep();
        wallet.sweep(address(fakeToken));
        vm.stopPrank();
    }

    function _assertProceedsFromClawbackEqual(uint256 amount) internal {
        (uint256 prevBalanceEth, uint256 prevBalanceToken) = _getErc20AndEthBalances(owner);
        _clawback(owner);
        (uint256 postBalanceEth, uint256 postBalanceToken) = _getErc20AndEthBalances(owner);

        // Owner gets their tokens back
        assert(postBalanceEth - prevBalanceEth == amount);
        assert(postBalanceToken - prevBalanceToken == amount);
    }

    function _assertProceedsFromReleaseEqual(uint256 amount) internal {
        (uint256 prevBalanceEth, uint256 prevBalanceToken) = _getErc20AndEthBalances(recipient);
        _release(recipient);
        (uint256 postBalanceEth, uint256 postBalanceToken) = _getErc20AndEthBalances(recipient);

        // Owner gets their tokens back
        assert(postBalanceEth - prevBalanceEth == amount);
        assert(postBalanceToken - prevBalanceToken == amount);
    }


    function _assertProceedsFromSweepEqual(uint256 amount) internal {
        (uint256 prevBalanceEth, uint256 prevBalanceToken) = _getErc20AndEthBalances(owner);
        _sweep(owner);
        (uint256 postBalanceEth, uint256 postBalanceToken) = _getErc20AndEthBalances(owner);

        assert(postBalanceEth - prevBalanceEth == amount);
        assert(postBalanceToken - prevBalanceToken == amount);
    }

    function _assertAbilityToRelease(bool expectedSuccess) internal {
        bool success;
        (success, ) = address(wallet).call(abi.encodeWithSelector(releaseSelector));
        assert(success == expectedSuccess);

        (success, ) = address(wallet).call(abi.encodeWithSelector(releaseAddressSelector, address(fakeToken)));
        assert(success == expectedSuccess);
    }

    function _assertAbilityToClawback(address user, bool expectedSuccess) internal {
        bool success;

        vm.prank(user);
        (success, ) = address(wallet).call(abi.encodeWithSelector(clawbackSelector));
        assert(success == expectedSuccess);

        vm.prank(user);
        (success, ) = address(wallet).call(abi.encodeWithSelector(clawbackAddressSelector, address(fakeToken)));
        assert(success == expectedSuccess);
    }

    function _assertAbilityToSweep(address user, bool expectedSuccess) internal {
        bool success;

        vm.prank(user);
        (success, ) = address(wallet).call(abi.encodeWithSelector(sweepSelector));
        assert(success == expectedSuccess);

        vm.prank(user);
        (success, ) = address(wallet).call(abi.encodeWithSelector(sweepAddressSelector, address(fakeToken)));
        assert(success == expectedSuccess);
    }

    function _depositTokensAndEth(address user, uint256 amt) internal {
        vm.prank(user);
        (bool success, ) = address(wallet).call{value: amt}("");
        assert(success);
        assert(amt == address(wallet).balance);
        vm.prank(user);
        fakeToken.transfer(address(wallet), amt);
        assert(amt == fakeToken.balanceOf(address(wallet)));
    }

    function setUp() public {
        uint64 startTime = uint64(block.timestamp) + startDelay;
        wallet = new VestingWalletWithCliffAndClawback(owner, recipient, startTime, vestDuration, cliffDuration);
        vm.deal(provider, 1000 ether);
        vm.deal(recipient, 1 ether);

        fakeToken = new ERC20("Fake Token","FAKE");
        deal(address(fakeToken), provider, amountDeposit * 2);

        _depositTokensAndEth(provider, amountDeposit);
    }

    function testCliffDuration() view public {
        assert(wallet.cliffDuration() == cliffDuration);
    }

    function testPreCliffReleasableZero() view public {
        _assertReleasableIsAmount(0);
    }

    function testReleasableDuringCliffZero() public {
        skip(startDelay);
        _assertReleasableIsAmount(0);

        skip(cliffDuration - 1);
        _assertReleasableIsAmount(0);
    }

    function testCannotReleaseDuringCliff() public {
        skip(startDelay);
        _assertAbilityToRelease(false);

        skip(cliffDuration - 1);
        _assertAbilityToRelease(false);
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
            _assertAbilityToRelease(true);
            skip(1);
        }
    }

    function testReleasableAfterVestFullAmount() public {
        skip(startDelay + vestDuration);
        assert(wallet.releasable() == amountDeposit);
        assert(wallet.releasable(address(fakeToken)) == amountDeposit);
    }

    // Only owner can clawback
    function testClawbackUsers() public {
        _assertAbilityToClawback(provider, false);
        _assertAbilityToClawback(recipient, false);
        _assertAbilityToClawback(owner, true);
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

        uint256 claimableNative = wallet.releasable();
        uint256 claimableERC20 = wallet.releasable(address(fakeToken));
        assert(claimableNative == claimableERC20);
        assert(claimableNative != 0);

        // Run and verify clawback
        _assertProceedsFromClawbackEqual(amountDeposit - claimableNative);

        // Run and verify release
        _assertProceedsFromReleaseEqual(claimableNative);

        _assertClawbackHasOccurred(true);
    }

    // Clawback after duration has elapsed should return nothing
    function testClawbackAfterVest() public {
        _assertClawbackHasOccurred(false);

        skip(startDelay + cliffDuration + vestDuration);

        // Run and verify clawback
        _assertProceedsFromClawbackEqual(0);

        // Run and verify release
        _assertProceedsFromReleaseEqual(amountDeposit);

        _assertClawbackHasOccurred(true);
    }

    // Sweep should fail before clawback
    function testUsersSweepBeforeAfterClawback() public {
        _assertAbilityToSweep(provider, false);
        _assertAbilityToSweep(recipient, false);
        _assertAbilityToSweep(owner, false);

        _clawback(owner);

        _assertAbilityToSweep(provider, false);
        _assertAbilityToSweep(recipient, false);
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
        _assertReleasableIsAmount(0); // ensure recipient can't get it

        // Sweep after deposit after clawback
        _assertProceedsFromSweepEqual(amountDeposit);
    }
}
