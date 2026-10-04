// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

library Base64 {
    string internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function encode(bytes memory data) internal pure returns (string memory result) {
        if (data.length == 0) return "";
        string memory table = TABLE;
        assembly ("memory-safe") {
            let encodedLen := mul(4, div(add(mload(data), 2), 3))
            result := mload(0x40)
            mstore(0x40, add(result, add(32, encodedLen)))
            mstore(result, encodedLen)
            let tablePtr := add(table, 1)
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))
            let resultPtr := add(result, 32)
            for {} lt(dataPtr, endPtr) {} {
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
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 { mstore8(sub(resultPtr, 1), 0x3d) }
        }
    }
}

contract Soulmint {
    using Base64 for bytes;

    string public constant name = "Soulmint AI Souls";
    string public constant symbol = "SOUL";
    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant MAX_NAME_BYTES = 72;
    uint256 public constant MAX_CATCHPHRASE_BYTES = 240;
    uint256 public constant MAX_BACKSTORY_BYTES = 1536;

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
    /// @dev ERC-4906: emitted whenever tokenURI(tokenId) may return different metadata.
    event MetadataUpdate(uint256 _tokenId);
    /// @dev ERC-4906: reserved for future batch metadata refreshes.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event OwnerChanged(
        uint256 indexed tokenId, address indexed previousOwner, address indexed newOwner, uint32 transferCount
    );

    error NotAuthorized();
    error InvalidSoul();
    error InvalidMBTI();
    error IncorrectValue();
    error UnsafeRecipient();
    error TransferFailed();

    constructor() {
        creator = msg.sender;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x80ac58cd || interfaceId == 0x5b5e139f
            || interfaceId == 0x49064906;
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

    function mint(
        string calldata mbti,
        string calldata soulName,
        string calldata catchphrase,
        string calldata backstory
    ) external payable returns (uint256 tokenId) {
        if (msg.value != MINT_PRICE) revert IncorrectValue();
        if (!_validMBTI(mbti)) revert InvalidMBTI();
        uint256 nameLength = bytes(soulName).length;
        uint256 catchphraseLength = bytes(catchphrase).length;
        uint256 backstoryLength = bytes(backstory).length;
        if (
            nameLength == 0 || nameLength > MAX_NAME_BYTES || catchphraseLength == 0
                || catchphraseLength > MAX_CATCHPHRASE_BYTES || backstoryLength == 0
                || backstoryLength > MAX_BACKSTORY_BYTES || _hasUnsafeControl(soulName)
                || _hasUnsafeControl(catchphrase) || _hasUnsafeControl(backstory)
        ) revert InvalidSoul();

        tokenId = ++totalSupply;
        uint256 seed = _newSeed(tokenId, mbti, soulName);
        _souls[tokenId] = Soul(mbti, soulName, catchphrase, backstory, 0, uint64(block.timestamp), 0, seed, address(0));
        _ownerOf[tokenId] = msg.sender;
        unchecked {
            _balanceOf[msg.sender]++;
        }
        emit Transfer(address(0), msg.sender, tokenId);
        emit SoulMinted(tokenId, msg.sender, mbti, soulName, seed);
    }

    function recordSummon(uint256 tokenId) external returns (uint64 count, uint8 stage) {
        ownerOf(tokenId);
        Soul storage soul = _souls[tokenId];
        count = ++soul.summons;
        stage = growthStage(count);
        emit SoulSummoned(tokenId, msg.sender, count, stage);
        emit MetadataUpdate(tokenId);
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
        if (msg.sender != from && msg.sender != getApproved[tokenId] && !isApprovedForAll[from][msg.sender]) {
            revert NotAuthorized();
        }
        delete getApproved[tokenId];
        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }
        _ownerOf[tokenId] = to;
        Soul storage soul = _souls[tokenId];
        soul.previousOwner = from;
        soul.transferCount++;
        emit Transfer(from, to, tokenId);
        emit OwnerChanged(tokenId, from, to, soul.transferCount);
        emit MetadataUpdate(tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);
        if (
            to.code.length != 0
                && IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data)
                    != IERC721Receiver.onERC721Received.selector
        ) revert UnsafeRecipient();
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        ownerOf(tokenId);
        Soul memory soul = _souls[tokenId];
        string memory stage = stageName(growthStage(soul.summons));
        string memory json = string.concat(
            '{"name":"',
            _escapeJSON(soul.soulName),
            " #",
            _toString(tokenId),
            '","description":"Soulmint on-chain MBTI AI Soul",',
            '"image":"data:image/svg+xml;base64,',
            bytes(_renderSVG(tokenId, soul, stage)).encode(),
            '",',
            '"attributes":[{"trait_type":"MBTI","value":"',
            soul.mbti,
            '"},{"trait_type":"Growth","value":"',
            stage,
            '"},{"trait_type":"Summons","value":',
            _toString(soul.summons),
            '},{"trait_type":"Transfers","value":',
            _toString(soul.transferCount),
            "}]}"
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
        string memory svg = string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 560 680"><defs><linearGradient id="g" x2="1" y2="1"><stop stop-color="',
            bg,
            '"/><stop offset="1" stop-color="#080A0D"/></linearGradient><radialGradient id="c"><stop stop-color="#fff"/><stop offset=".3" stop-color="',
            a,
            '"/><stop offset="1" stop-color="',
            b,
            '" stop-opacity="0"/></radialGradient></defs><rect width="560" height="680" rx="34" fill="url(#g)"/>',
            '<g fill="none" stroke="',
            a,
            '" opacity=".78" transform="rotate(',
            _toString(angle),
            ' 280 302)">'
        );
        svg = string.concat(
            svg,
            '<ellipse cx="280" cy="302" rx="',
            _toString(r1),
            '" ry="54" stroke-width="4"/><ellipse cx="280" cy="302" rx="',
            _toString(r2),
            '" ry="82" stroke="',
            b,
            '" stroke-width="3"/><ellipse cx="280" cy="302" rx="150" ry="106" stroke-width="2"/></g>',
            _avatar(soul.mbti, a, b)
        );
        svg = string.concat(
            svg,
            '<text x="48" y="54" fill="',
            a,
            '" font-family="monospace" font-size="18">SOULMINT / #',
            _toString(tokenId),
            "</text>",
            '<text x="280" y="550" fill="#fff" font-family="sans-serif" font-weight="800" font-size="64" text-anchor="middle" letter-spacing="8">',
            soul.mbti,
            "</text>"
        );
        svg = string.concat(
            svg,
            '<text x="280" y="592" fill="',
            a,
            '" font-family="sans-serif" font-size="20" text-anchor="middle">',
            _escapeXML(soul.soulName),
            "</text>"
        );
        return string.concat(
            svg,
            '<text x="48" y="638" fill="#fff" opacity=".55" font-family="monospace" font-size="14">',
            stage,
            " / SUMMONS ",
            _toString(soul.summons),
            "</text></svg>"
        );
    }

    function _avatar(string memory mbti, string memory a, string memory b) internal pure returns (string memory) {
        bytes memory t = bytes(mbti);
        bool extrovert = t[0] == bytes1("E");
        bool intuitive = t[1] == bytes1("N");
        bool thinker = t[2] == bytes1("T");

        string memory head = intuitive
            ? '<path d="M280 190 374 258 338 386 280 430 222 386 186 258Z"'
            : '<path d="M280 188c72 0 116 49 106 126-8 67-50 116-106 116s-98-49-106-116c-10-77 34-126 106-126Z"';
        string memory eyes = thinker
            ? string.concat(
                '<path d="m218 298 45 13-45 13M342 298l-45 13 45 13" stroke="', a, '" stroke-width="9" fill="none"/>'
            )
            : string.concat(
                '<circle cx="238" cy="312" r="15" fill="', a, '"/><circle cx="322" cy="312" r="15" fill="', a, '"/>'
            );
        string memory aura = extrovert
            ? string.concat(
                '<path d="M280 142V104M164 190l-29-28M396 190l29-28M142 302h-40M418 302h40" stroke="',
                a,
                '" stroke-width="6"/>'
            )
            : string.concat(
                '<circle cx="280" cy="302" r="174" fill="none" stroke="',
                a,
                '" stroke-width="3" stroke-dasharray="7 13"/>'
            );

        return string.concat(
            "<g>",
            aura,
            _sigil(mbti, a, b),
            head,
            ' fill="#090c0d" stroke="',
            a,
            '" stroke-width="6"/>',
            eyes,
            '<path d="M245 364q35 24 70 0" fill="none" stroke="',
            b,
            '" stroke-width="7"/>',
            '<circle cx="280" cy="302" r="9" fill="#fff" opacity=".88"/></g>'
        );
    }

    function _sigil(string memory mbti, string memory a, string memory b) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(mbti));
        string memory open = string.concat(
            '<g fill="none" stroke="', b, '" stroke-width="7" stroke-linecap="round" stroke-linejoin="round">'
        );
        if (kind == keccak256("INTJ")) {
            return string.concat(
                open,
                '<path d="m230 226 18-55 32 32 32-32 18 55M246 220h68"/><circle cx="280" cy="184" r="7" fill="',
                a,
                '" stroke="none"/></g>'
            );
        }
        if (kind == keccak256("INTP")) {
            return string.concat(
                open,
                '<path d="M240 184 280 162l40 22-40 22ZM240 184v42l40 23 40-23v-42M280 206v43"/><circle cx="280" cy="184" r="7" fill="',
                a,
                '" stroke="none"/></g>'
            );
        }
        if (kind == keccak256("ENTJ")) {
            return string.concat(open, '<path d="m226 228 54-70 54 70-54-24Zm24-4 30-20 30 20M280 158v46"/></g>');
        }
        if (kind == keccak256("ENTP")) {
            return string.concat(
                open,
                '<path d="m248 158-18 48 33-8-12 43 61-64-36 10 12-29"/><circle cx="224" cy="176" r="6" fill="',
                a,
                '" stroke="none"/><circle cx="326" cy="220" r="6" fill="',
                a,
                '" stroke="none"/></g>'
            );
        }
        if (kind == keccak256("INFJ")) {
            return string.concat(
                open,
                '<path d="M300 157a43 43 0 1 0 28 72 50 50 0 0 1-28-72ZM244 225q36-32 72 0-36 28-72 0Z"/><circle cx="280" cy="225" r="7" fill="',
                a,
                '" stroke="none"/></g>'
            );
        }
        if (kind == keccak256("INFP")) {
            return string.concat(
                open,
                '<path d="M280 213c-42-14-42-55 0-42 14-42 55-42 42 0 42 14 42 55 0 42-14 42-55 42-42 0-42-14-42-55 0-42Z"/><circle cx="280" cy="192" r="12" fill="',
                a,
                '" stroke="none"/></g>'
            );
        }
        if (kind == keccak256("ENFJ")) {
            return string.concat(
                open,
                '<circle cx="280" cy="195" r="27"/><path d="M280 151v-18M280 257v-18M236 195h-18M342 195h-18M249 164l-13-13M324 239l-13-13M311 164l13-13M236 239l13-13"/><circle cx="280" cy="195" r="9" fill="',
                a,
                '" stroke="none"/></g>'
            );
        }
        if (kind == keccak256("ENFP")) {
            return string.concat(
                open,
                '<path d="m280 151 9 29 30-8-21 22 21 21-30-7-9 29-9-29-30 7 21-21-21-22 30 8Z"/><circle cx="230" cy="155" r="6" fill="',
                a,
                '" stroke="none"/><circle cx="332" cy="232" r="6" fill="',
                a,
                '" stroke="none"/></g>'
            );
        }
        if (kind == keccak256("ISTJ")) {
            return string.concat(
                open,
                '<path d="M235 229h90M245 221v-52h70v52M260 169v52M280 169v52M300 169v52m-62-52 42-22 42 22"/></g>'
            );
        }
        if (kind == keccak256("ISFJ")) {
            return string.concat(
                open,
                '<path d="M280 151 326 169v34c0 28-19 46-46 57-27-11-46-29-46-57v-34Zm0 75s-31-17-31-36c0-17 21-22 31-8 10-14 31-9 31 8 0 19-31 36-31 36Z"/></g>'
            );
        }
        if (kind == keccak256("ESTJ")) {
            return string.concat(
                open,
                '<rect x="232" y="157" width="96" height="78" rx="8"/><path d="M264 157v78M296 157v78M232 183h96M232 209h96m-78-13 12 12 25-28"/></g>'
            );
        }
        if (kind == keccak256("ESFJ")) {
            return string.concat(
                open,
                '<circle cx="280" cy="193" r="18"/><circle cx="230" cy="177" r="12"/><circle cx="330" cy="177" r="12"/><circle cx="247" cy="229" r="12"/><circle cx="313" cy="229" r="12"/><path d="m242 181 20 7M298 188l20-7M258 218l12-12M302 218l-12-12"/></g>'
            );
        }
        if (kind == keccak256("ISTP")) {
            return string.concat(
                open,
                '<path d="m236 158 88 78M324 158l-88 78m-6-85 22 6-16 17Zm100 0-22 6 16 17Z"/><circle cx="280" cy="197" r="13" fill="',
                a,
                '"/></g>'
            );
        }
        if (kind == keccak256("ISFP")) {
            return string.concat(
                open,
                '<path d="M280 242c-10-48 4-80 45-94 7 45-8 76-45 94Zm0 0c-5-38-21-59-52-66-1 36 15 58 52 66Zm0 0 28-62"/></g>'
            );
        }
        if (kind == keccak256("ESTP")) {
            return string.concat(
                open,
                '<path d="M220 177h64l-24 24h78M220 218h86m8-54 26 37-26 37"/><circle cx="240" cy="201" r="8" fill="',
                a,
                '" stroke="none"/></g>'
            );
        }
        return string.concat(
            open,
            '<path d="m280 149 13 34 37 2-29 23 10 36-31-20-31 20 10-36-29-23 37-2ZM222 158v78M338 158v78M222 176l-18 25 18 25M338 176l18 25-18 25"/></g>'
        );
    }

    function _palette(string memory mbti) internal pure returns (string memory, string memory, string memory) {
        bytes memory t = bytes(mbti);
        bool intuitive = t[1] == bytes1("N");
        bool thinker = t[2] == bytes1("T");
        bool judging = t[3] == bytes1("J");
        if (intuitive && thinker) return ("#C4A7FF", "#8065E8", "#211A38");
        if (intuitive) return ("#7EE2A8", "#35B878", "#132A22");
        if (judging) return ("#79C7FF", "#4388D6", "#14283D");
        return ("#FFD66B", "#F29D49", "#342719");
    }

    function _newSeed(uint256 tokenId, string calldata mbti, string calldata soulName) internal view returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, msg.sender, tokenId, mbti, soulName)));
    }

    function _validMBTI(string memory value) internal pure returns (bool) {
        bytes32 hash = keccak256(bytes(value));
        return hash == keccak256("INTJ") || hash == keccak256("INTP") || hash == keccak256("ENTJ")
            || hash == keccak256("ENTP") || hash == keccak256("INFJ") || hash == keccak256("INFP")
            || hash == keccak256("ENFJ") || hash == keccak256("ENFP") || hash == keccak256("ISTJ")
            || hash == keccak256("ISFJ") || hash == keccak256("ESTJ") || hash == keccak256("ESFJ")
            || hash == keccak256("ISTP") || hash == keccak256("ISFP") || hash == keccak256("ESTP")
            || hash == keccak256("ESFP");
    }

    function _hasUnsafeControl(string memory value) internal pure returns (bool) {
        bytes memory source = bytes(value);
        for (uint256 i; i < source.length; i++) {
            uint8 char = uint8(source[i]);
            if (char < 0x20 && char != 0x09 && char != 0x0a && char != 0x0d) return true;
        }
        return false;
    }

    function _escapeXML(string memory value) internal pure returns (string memory) {
        bytes memory source = bytes(value);
        bytes memory out = new bytes(source.length * 6);
        uint256 j;
        for (uint256 i; i < source.length; i++) {
            bytes1 char = source[i];
            bytes memory replacement;
            if (char == '"') {
                replacement = bytes("&quot;");
            } else if (char == "<") {
                replacement = bytes("&lt;");
            } else if (char == ">") {
                replacement = bytes("&gt;");
            } else if (char == "&") {
                replacement = bytes("&amp;");
            } else {
                out[j++] = char;
                continue;
            }
            for (uint256 k; k < replacement.length; k++) {
                out[j++] = replacement[k];
            }
        }
        assembly ("memory-safe") { mstore(out, j) }
        return string(out);
    }

    function _escapeJSON(string memory value) internal pure returns (string memory) {
        bytes memory source = bytes(value);
        bytes memory out = new bytes(source.length * 2);
        uint256 j;
        for (uint256 i; i < source.length; i++) {
            bytes1 char = source[i];
            if (char == '"' || char == "\\") {
                out[j++] = "\\";
                out[j++] = char;
            } else if (char == 0x0a) {
                out[j++] = "\\";
                out[j++] = "n";
            } else if (char == 0x0d) {
                out[j++] = "\\";
                out[j++] = "r";
            } else if (char == 0x09) {
                out[j++] = "\\";
                out[j++] = "t";
            } else {
                out[j++] = char;
            }
        }
        assembly ("memory-safe") { mstore(out, j) }
        return string(out);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }
}
