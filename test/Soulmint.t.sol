// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contracts/Soulmint.sol";

interface Vm {
    function deal(address who, uint256 newBalance) external;
    function prank(address sender) external;
    function expectRevert(bytes4 revertData) external;
}

contract SoulmintTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Soulmint private soulmint;
    Receiver private receiver;
    BadReceiver private badReceiver;

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);

    function setUp() public {
        soulmint = new Soulmint();
        receiver = new Receiver();
        badReceiver = new BadReceiver();
        vm.deal(ALICE, 10 ether);
        vm.deal(BOB, 10 ether);
    }

    function testMintStoresCompleteSoul() public {
        uint256 id = _mintAs(
            ALICE, "INTJ", unicode"墨菲", unicode"先看本质。", unicode"来自雪线之上的观察者。"
        );
        Soulmint.Soul memory soul = soulmint.soulOf(id);

        require(id == 1 && soulmint.ownerOf(id) == ALICE, "owner");
        require(keccak256(bytes(soul.mbti)) == keccak256("INTJ"), "mbti");
        require(keccak256(bytes(soul.soulName)) == keccak256(unicode"墨菲"), "name");
        require(soul.bornAt > 0 && soul.seed != 0, "identity");
        require(soulmint.totalSupply() == 1, "supply");
    }

    function testAllSixteenTypesMintAndRenderDistinctIdentity() public {
        string[16] memory types = [
            "INTJ",
            "INTP",
            "ENTJ",
            "ENTP",
            "INFJ",
            "INFP",
            "ENFJ",
            "ENFP",
            "ISTJ",
            "ISFJ",
            "ESTJ",
            "ESFJ",
            "ISTP",
            "ISFP",
            "ESTP",
            "ESFP"
        ];
        bytes32 previous;
        for (uint256 i; i < types.length; i++) {
            uint256 id = _mintAs(ALICE, types[i], "Soul", "Hello", "Backstory");
            bytes32 current = keccak256(bytes(soulmint.renderSVG(id)));
            require(current != previous, "duplicate render");
            require(_contains(soulmint.renderSVG(id), types[i]), "missing type");
            previous = current;
        }
        require(soulmint.totalSupply() == 16, "all types");
    }

    function testMintRejectsBadInputs() public {
        vm.prank(ALICE);
        vm.expectRevert(Soulmint.IncorrectValue.selector);
        soulmint.mint("INTJ", "Soul", "Hello", "Story");

        vm.prank(ALICE);
        vm.expectRevert(Soulmint.InvalidMBTI.selector);
        soulmint.mint{value: 0.01 ether}("ABCD", "Soul", "Hello", "Story");

        vm.prank(ALICE);
        vm.expectRevert(Soulmint.InvalidSoul.selector);
        soulmint.mint{value: 0.01 ether}("INTJ", "Soul", "", "Story");

        vm.prank(ALICE);
        vm.expectRevert(Soulmint.InvalidSoul.selector);
        soulmint.mint{value: 0.01 ether}("INTJ", "Soul", "Hello", "");

        vm.prank(ALICE);
        vm.expectRevert(Soulmint.InvalidSoul.selector);
        soulmint.mint{value: 0.01 ether}("INTJ", string.concat("Soul", string(hex"01")), "Hello", "Story");
    }

    function testGrowthBoundariesAndSummonEventState() public {
        uint256 id = _mintAs(ALICE, "INFJ", "Sage", "Listen", "Story");
        require(soulmint.growthStage(0) == 0, "birth");
        require(soulmint.growthStage(2) == 0, "birth max");
        require(soulmint.growthStage(3) == 1, "sprout");
        require(soulmint.growthStage(10) == 2, "awake");
        require(soulmint.growthStage(30) == 3, "mature");
        require(soulmint.growthStage(100) == 4, "legend");

        for (uint256 i; i < 10; i++) {
            vm.prank(i % 2 == 0 ? ALICE : BOB);
            soulmint.recordSummon(id);
        }
        Soulmint.Soul memory soul = soulmint.soulOf(id);
        require(soul.summons == 10 && soulmint.growthStage(soul.summons) == 2, "summon state");
    }

    function testFuzzGrowthStage(uint64 summons) public view {
        uint8 stage = soulmint.growthStage(summons);
        if (summons >= 100) require(stage == 4, "legend");
        else if (summons >= 30) require(stage == 3, "mature");
        else if (summons >= 10) require(stage == 2, "awake");
        else if (summons >= 3) require(stage == 1, "sprout");
        else require(stage == 0, "birth");
    }

    function testTransferAuthorizationApprovalAndMemory() public {
        uint256 id = _mintAs(ALICE, "ENFP", "Nova", "Hello", "Story");
        vm.prank(BOB);
        vm.expectRevert(Soulmint.NotAuthorized.selector);
        soulmint.transferFrom(ALICE, BOB, id);

        vm.prank(ALICE);
        soulmint.approve(BOB, id);
        vm.prank(BOB);
        soulmint.safeTransferFrom(ALICE, address(receiver), id);

        Soulmint.Soul memory soul = soulmint.soulOf(id);
        require(soulmint.ownerOf(id) == address(receiver), "new owner");
        require(soul.previousOwner == ALICE && soul.transferCount == 1, "history");
        require(soulmint.getApproved(id) == address(0), "approval not cleared");
    }

    function testUnsafeReceiverRevertsWholeTransfer() public {
        uint256 id = _mintAs(ALICE, "ISTP", "Tool", "Try it", "Story");
        vm.prank(ALICE);
        vm.expectRevert(Soulmint.UnsafeRecipient.selector);
        soulmint.safeTransferFrom(ALICE, address(badReceiver), id);
        require(soulmint.ownerOf(id) == ALICE, "owner changed");
        require(soulmint.soulOf(id).transferCount == 0, "history changed");
    }

    function testMetadataAndXMLAreSafe() public {
        uint256 id = _mintAs(ALICE, "ENTP", 'A <B> & "C"', "Back\\slash", "Line one\nLine two");
        string memory svg = soulmint.renderSVG(id);
        string memory uri = soulmint.tokenURI(id);
        require(_contains(svg, "A &lt;B&gt; &amp; &quot;C&quot;"), "xml escape");
        require(_startsWith(uri, "data:application/json;base64,"), "metadata uri");
        require(bytes(uri).length > 500, "metadata empty");
    }

    function testInterfaceAndWithdrawPermissions() public {
        require(soulmint.supportsInterface(0x80ac58cd), "erc721");
        require(soulmint.supportsInterface(0x5b5e139f), "metadata");
        _mintAs(ALICE, "ISFJ", "Guard", "Here", "Story");

        vm.prank(BOB);
        vm.expectRevert(Soulmint.NotAuthorized.selector);
        soulmint.withdraw();
        soulmint.withdraw();
        require(address(soulmint).balance == 0, "not withdrawn");
    }

    function _mintAs(
        address minter,
        string memory mbti,
        string memory soulName,
        string memory catchphrase,
        string memory backstory
    ) internal returns (uint256 id) {
        vm.prank(minter);
        id = soulmint.mint{value: 0.01 ether}(mbti, soulName, catchphrase, backstory);
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i; i <= h.length - n.length; i++) {
            bool matchFound = true;
            for (uint256 j; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) return true;
        }
        return false;
    }

    function _startsWith(string memory value, string memory prefix) internal pure returns (bool) {
        bytes memory v = bytes(value);
        bytes memory p = bytes(prefix);
        if (p.length > v.length) return false;
        for (uint256 i; i < p.length; i++) {
            if (v[i] != p[i]) return false;
        }
        return true;
    }

    receive() external payable {}
}

contract Receiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract BadReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0x00000000;
    }
}
