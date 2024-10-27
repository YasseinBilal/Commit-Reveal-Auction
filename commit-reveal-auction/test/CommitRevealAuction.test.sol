// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CommitRevealAuction} from "../src/CommitRevealAuction.sol";

contract CommitRevealAuctionTest is Test {
    CommitRevealAuction auction;
    address owner = address(1);
    address bidder1 = address(2);
    address bidder2 = address(3);

    function setUp() public {
        vm.prank(owner);
        auction = new CommitRevealAuction();
    }

    function testCreateAuction() public {
        vm.prank(owner);
        auction.createAuction("Test Item", 1 ether, 1 days, 1 days);

        (
            uint256 id,
            string memory name,
            uint256 initialPrice,
            address itemOwner,
            uint256 biddingEnd,
            uint256 revealEnd,
            bool isSold,
            address winner,
            uint256 winningBid
        ) = auction.items(1);

        assertEq(id, 1);
        assertEq(name, "Test Item");
        assertEq(initialPrice, 1 ether);
        assertEq(itemOwner, owner);
        assertEq(biddingEnd, block.timestamp + 1 days);
        assertEq(revealEnd, block.timestamp + 2 days);
        assertEq(isSold, false);
        assertEq(winner, address(0));
        assertEq(winningBid, 0);
    }

    function testSubmitBid() public {
        vm.prank(owner);
        auction.createAuction("Test Item", 1 ether, 1 days, 1 days);

        bytes32 commitHash = keccak256(
            abi.encodePacked(uint256(2 ether), "secret")
        );

        vm.deal(bidder1, 2 ether);
        uint256 bidder1BalanceBefore = bidder1.balance;

        vm.prank(bidder1);
        auction.submitBid{value: 2 ether}(1, commitHash);

        assertEq(bidder1BalanceBefore - 2 ether, bidder1.balance);
    }

    function testRevealBid() public {
        vm.prank(owner);
        auction.createAuction("Test Item", 1 ether, 1 days, 1 days);

        vm.prank(bidder1);
        vm.deal(bidder1, 2 ether);

        bytes32 commitHash = keccak256(
            abi.encodePacked(uint256(2 ether), "secret")
        );

        auction.submitBid{value: 2 ether}(1, commitHash);

        vm.warp(block.timestamp + 1 days + 1); // Move to reveal period

        vm.prank(bidder1);

        auction.revealBid(1, 2 ether, "secret");

        (, , , , , , bool isSold, address winner, uint256 winningBid) = auction
            .items(1);

        assertEq(isSold, false);
        assertEq(winner, bidder1);
        assertEq(winningBid, 2 ether);
    }

    function testRevealWinner() public {
        vm.prank(owner);
        auction.createAuction("Test Item", 1 ether, 1 days, 1 days);

        bytes32 commitHash = keccak256(
            abi.encodePacked(uint256(2 ether), "secret")
        );

        vm.prank(bidder1);
        vm.deal(bidder1, 2 ether);
        auction.submitBid{value: 2 ether}(1, commitHash);

        vm.warp(block.timestamp + 1 days + 1); // Move to reveal period

        vm.prank(bidder1);
        auction.revealBid(1, 2 ether, "secret");

        vm.warp(block.timestamp + 1 days); // Move past reveal period

        uint256 initialOwnerBalance = owner.balance;

        vm.prank(owner);
        auction.revealWinnder(1);

        (, , , , , , bool isSold, address winner, uint256 winningBid) = auction
            .items(1);

        assertEq(isSold, true);
        assertEq(winner, bidder1);
        assertEq(winningBid, 2 ether);
        assertEq(owner.balance, initialOwnerBalance + 2 ether);
    }

    function testClaimDeposit() public {
        vm.prank(owner);
        auction.createAuction("Test Item", 1 ether, 1 days, 1 days);

        bytes32 bidder1CommitHash = keccak256(
            abi.encodePacked(uint256(3 ether), "secret")
        );

        bytes32 bidder2CommitHash = keccak256(
            abi.encodePacked(uint256(2 ether), "secret")
        );

        vm.prank(bidder1);
        vm.deal(bidder1, 3 ether);
        auction.submitBid{value: 3 ether}(1, bidder1CommitHash);

        vm.prank(bidder2);
        vm.deal(bidder2, 3 ether);
        auction.submitBid{value: 2 ether}(1, bidder2CommitHash);

        vm.warp(block.timestamp + 1 days + 1); // Move to reveal period

        vm.prank(bidder1);
        auction.revealBid(1, 3 ether, "secret");

        vm.prank(bidder2);
        auction.revealBid(1, 2 ether, "secret");

        vm.warp(block.timestamp + 1 days); // Move past reveal period

        vm.prank(owner);
        auction.revealWinnder(1);

        uint256 initialBidderBalance = bidder2.balance;

        vm.prank(bidder2);
        auction.claimDeposit(1);

        assertEq(bidder2.balance, initialBidderBalance + 2 ether);
    }
}
