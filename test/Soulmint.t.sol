// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contracts/Soulmint.sol";

contract SoulmintTest {
    Soulmint private soulmint;
    Receiver private receiver;

    function setUp() public {
        soulmint = new Soulmint();
        receiver = new Receiver();
    }

    function testMintMetadataAndGrowth() public {
        uint256 id = soulmint.mint{value: 0.01 ether}("INTJ", unicode"墨菲", unicode"先看本质。", unicode"来自雪线之上的观察者。");
        require(id == 1 && soulmint.ownerOf(1) == address(this), "mint failed");
        for (uint256 i; i < 10; i++) soulmint.recordSummon(1);
        Soulmint.Soul memory soul = soulmint.soulOf(1);
        require(soul.summons == 10 && soulmint.growthStage(soul.summons) == 2, "growth failed");
        require(bytes(soulmint.tokenURI(1)).length > 100, "metadata missing");
    }

    function testTransferRemembersPreviousOwner() public {
        soulmint.mint{value: 0.01 ether}("ENFP", "Nova", "Hello", "Story");
        soulmint.safeTransferFrom(address(this), address(receiver), 1);
        Soulmint.Soul memory soul = soulmint.soulOf(1);
        require(soul.previousOwner == address(this) && soul.transferCount == 1, "history failed");
    }

    receive() external payable {}
}

contract Receiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
