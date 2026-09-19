// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external returns (bytes4);
}

library Base64 {
    string internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function encode(bytes memory data) internal pure returns (string memory result) {
        if (data.length == 0) return "";
        string memory table = TABLE;
        assembly {
            let encodedLen := mul(4, div(add(mload(data), 2), 3))
            result := mload(0x40)
            mstore(0x40, add(result, add(32, encodedLen)))
            mstore(result, encodedLen)
            let tablePtr := add(table, 1)
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))
            let resultPtr := add(result, 32)
            for {} lt(dataPtr, endPtr) {}
            {
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1)
            }
            switch mod(mload(data), 3)
            case 1 { mstore8(sub(resultPtr, 1), 0x3d) mstore8(sub(resultPtr, 2), 0x3d) }
            case 2 { mstore8(sub(resultPtr, 1), 0x3d) }
        }
    }
}

contract Soulmint {
    using Base64 for bytes;

    string public constant name = "Soulmint AI Souls";
    string public constant symbol = "SOUL";
    uint256 public constant MINT_PRICE = 0.01 ether;

    struct Soul {
        string mbti;
        string soulName;
        string catchphrase;
        string backstory;
        uint64 summons;
        uint64 bornAt;
        uint32 transferCount;
        uint256 seed;
        address previousOwner;
    }

    address public immutable creator;
    uint256 public totalSupply;
    mapping(uint256 => Soul) private _souls;
    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256) private _balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event SoulMinted(uint256 indexed tokenId, address indexed owner, string mbti, string soulName, uint256 seed);
    event SoulSummoned(uint256 indexed tokenId, address indexed summoner, uint64 totalSummons, uint8 stage);
    event OwnerChanged(uint256 indexed tokenId, address indexed previousOwner, address indexed newOwner, uint32 transferCount);

    error NotAuthorized();
    error InvalidSoul();
    error InvalidMBTI();
    error IncorrectValue();
    error UnsafeRecipient();
    error TransferFailed();

    constructor() { creator = msg.sender; }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x80ac58cd || interfaceId == 0x5b5e139f;
    }

    function ownerOf(uint256 tokenId) public view returns (address owner) {
        owner = _ownerOf[tokenId];
        if (owner == address(0)) revert InvalidSoul();
    }

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert InvalidSoul();
        return _balanceOf[owner];
    }

    function soulOf(uint256 tokenId) external view returns (Soul memory) {
        ownerOf(tokenId);
        return _souls[tokenId];
    }

    function mint(string calldata mbti, string calldata soulName, string calldata catchphrase, string calldata backstory)
        external payable returns (uint256 tokenId)
    {
        if (msg.value != MINT_PRICE) revert IncorrectValue();
        if (!_validMBTI(mbti)) revert InvalidMBTI();
        if (bytes(soulName).length == 0 || bytes(soulName).length > 72 || bytes(catchphrase).length > 240 || bytes(backstory).length > 1536) revert InvalidSoul();

        tokenId = ++totalSupply;
        uint256 seed = uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, msg.sender, tokenId, mbti, soulName)));
        _souls[tokenId] = Soul(mbti, soulName, catchphrase, backstory, 0, uint64(block.timestamp), 0, seed, address(0));
        _ownerOf[tokenId] = msg.sender;
        unchecked { _balanceOf[msg.sender]++; }
        emit Transfer(address(0), msg.sender, tokenId);
        emit SoulMinted(tokenId, msg.sender, mbti, soulName, seed);
    }

    function recordSummon(uint256 tokenId) external returns (uint64 count, uint8 stage) {
        ownerOf(tokenId);
        Soul storage soul = _souls[tokenId];
        count = ++soul.summons;
        stage = growthStage(count);
        emit SoulSummoned(tokenId, msg.sender, count, stage);
    }

    function growthStage(uint64 summons) public pure returns (uint8) {
        if (summons >= 100) return 4;
        if (summons >= 30) return 3;
        if (summons >= 10) return 2;
        if (summons >= 3) return 1;
        return 0;
    }

    function stageName(uint8 stage) public pure returns (string memory) {
        if (stage == 4) return unicode"传奇";
        if (stage == 3) return unicode"成熟";
        if (stage == 2) return unicode"觉醒";
        if (stage == 1) return unicode"萌芽";
        return unicode"初生";
    }

    function approve(address spender, uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert NotAuthorized();
        getApproved[tokenId] = spender;
        emit Approval(owner, spender, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (to == address(0) || ownerOf(tokenId) != from) revert InvalidSoul();
        if (msg.sender != from && msg.sender != getApproved[tokenId] && !isApprovedForAll[from][msg.sender]) revert NotAuthorized();
        delete getApproved[tokenId];
        unchecked { _balanceOf[from]--; _balanceOf[to]++; }
        _ownerOf[tokenId] = to;
        Soul storage soul = _souls[tokenId];
        soul.previousOwner = from;
        soul.transferCount++;
        emit Transfer(from, to, tokenId);
        emit OwnerChanged(tokenId, from, to, soul.transferCount);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external { safeTransferFrom(from, to, tokenId, ""); }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0 && IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) != IERC721Receiver.onERC721Received.selector) revert UnsafeRecipient();
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        ownerOf(tokenId);
        Soul memory soul = _souls[tokenId];
        string memory stage = stageName(growthStage(soul.summons));
        string memory json = string.concat(
            '{"name":"', _escape(soul.soulName), ' #', _toString(tokenId),
            '","description":"Soulmint on-chain MBTI AI Soul",',
            '"image":"data:image/svg+xml;base64,', bytes(_renderSVG(tokenId, soul, stage)).encode(), '",',
            '"attributes":[{"trait_type":"MBTI","value":"', soul.mbti,
            '"},{"trait_type":"Growth","value":"', stage,
            '"},{"trait_type":"Summons","value":', _toString(soul.summons),
            '},{"trait_type":"Transfers","value":', _toString(soul.transferCount), '}]}'
        );
        return string.concat("data:application/json;base64,", bytes(json).encode());
    }

    function renderSVG(uint256 tokenId) external view returns (string memory) {
        ownerOf(tokenId);
        Soul memory soul = _souls[tokenId];
        return _renderSVG(tokenId, soul, stageName(growthStage(soul.summons)));
    }

    function withdraw() external {
        if (msg.sender != creator) revert NotAuthorized();
        (bool ok,) = creator.call{value: address(this).balance}("");
        if (!ok) revert TransferFailed();
    }

    function _renderSVG(uint256 tokenId, Soul memory soul, string memory stage) internal pure returns (string memory) {
        (string memory a, string memory b, string memory bg) = _palette(soul.mbti);
        uint256 r1 = 74 + soul.seed % 52;
        uint256 r2 = 96 + (soul.seed >> 32) % 64;
        uint256 angle = soul.seed % 180;
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 560 680"><defs><linearGradient id="g" x2="1" y2="1"><stop stop-color="', bg,
            '"/><stop offset="1" stop-color="#080A0D"/></linearGradient><radialGradient id="c"><stop stop-color="#fff"/><stop offset=".3" stop-color="', a,
            '"/><stop offset="1" stop-color="', b, '" stop-opacity="0"/></radialGradient></defs><rect width="560" height="680" rx="34" fill="url(#g)"/>',
            '<g fill="none" stroke="', a, '" opacity=".78" transform="rotate(', _toString(angle), ' 280 302)"><ellipse cx="280" cy="302" rx="', _toString(r1), '" ry="54" stroke-width="4"/><ellipse cx="280" cy="302" rx="', _toString(r2), '" ry="82" stroke="', b, '" stroke-width="3"/><ellipse cx="280" cy="302" rx="150" ry="106" stroke-width="2"/></g>',
            '<circle cx="280" cy="302" r="94" fill="url(#c)"/><circle cx="280" cy="302" r="15" fill="#fff"/>',
            '<text x="48" y="54" fill="', a, '" font-family="monospace" font-size="18">SOULMINT / #', _toString(tokenId), '</text>',
            '<text x="280" y="550" fill="#fff" font-family="sans-serif" font-weight="800" font-size="64" text-anchor="middle" letter-spacing="8">', soul.mbti, '</text>',
            '<text x="280" y="592" fill="', a, '" font-family="sans-serif" font-size="20" text-anchor="middle">', _escape(soul.soulName), '</text>',
            '<text x="48" y="638" fill="#fff" opacity=".55" font-family="monospace" font-size="14">', stage, ' / SUMMONS ', _toString(soul.summons), '</text></svg>'
        );
    }

    function _palette(string memory mbti) internal pure returns (string memory, string memory, string memory) {
        bytes memory t = bytes(mbti);
        bool intuitive = t[1] == bytes1("N");
        bool thinker = t[2] == bytes1("T");
        bool judging = t[3] == bytes1("J");
        if (intuitive && thinker) return ("#B9FF66", "#56E0C5", "#17252B");
        if (intuitive) return ("#FF7AC8", "#9C7CFF", "#241B38");
        if (judging) return ("#FFD166", "#FF8A5B", "#342318");
        return ("#66C7FF", "#3D7CFF", "#14243A");
    }

    function _validMBTI(string memory value) internal pure returns (bool) {
        bytes32 hash = keccak256(bytes(value));
        return hash == keccak256("INTJ") || hash == keccak256("INTP") || hash == keccak256("ENTJ") || hash == keccak256("ENTP") ||
            hash == keccak256("INFJ") || hash == keccak256("INFP") || hash == keccak256("ENFJ") || hash == keccak256("ENFP") ||
            hash == keccak256("ISTJ") || hash == keccak256("ISFJ") || hash == keccak256("ESTJ") || hash == keccak256("ESFJ") ||
            hash == keccak256("ISTP") || hash == keccak256("ISFP") || hash == keccak256("ESTP") || hash == keccak256("ESFP");
    }

    function _escape(string memory value) internal pure returns (string memory) {
        bytes memory source = bytes(value);
        bytes memory out = new bytes(source.length * 6);
        uint256 j;
        for (uint256 i; i < source.length; i++) {
            bytes1 char = source[i];
            bytes memory replacement;
            if (char == '"') replacement = bytes("&quot;");
            else if (char == '<') replacement = bytes("&lt;");
            else if (char == '>') replacement = bytes("&gt;");
            else if (char == '&') replacement = bytes("&amp;");
            else { out[j++] = char; continue; }
            for (uint256 k; k < replacement.length; k++) out[j++] = replacement[k];
        }
        assembly { mstore(out, j) }
        return string(out);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) { digits--; buffer[digits] = bytes1(uint8(48 + value % 10)); value /= 10; }
        return string(buffer);
    }
}
