// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/VestingWalletWithCliff.sol";

contract VestingWalletWithCliffTest is Test {
    VestingWalletWithCliff public counter;

    function setUp() public {
        counter = new VestingWalletWithCliff();
        counter.setNumber(0);
    }

    function testIncrement() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function testSetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
