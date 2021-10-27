// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "base64-sol/base64.sol";

contract RandomSVG is ERC721URIStorage, VRFConsumerBase {
    bytes32 public keyHash;
    uint256 public fee;
    uint256 public tokenCounter;

    // SVG parameters
    uint256 public maxPaths;
    uint256 public maxCommands;
    uint256 public size;
    string[] public pathCommands;
    string[] public colors;
    
    mapping(bytes32 => address) public requestIdToSender;
    mapping(bytes32 => uint256) public requestIdtoTokenId; 
    mapping(uint256 => uint256) public tokenIdToRandomNumber;
 
    event requestedRandomSVG(bytes32 indexed requestId, uint256 indexed tokenId);
    event CreateUnfinishedRandomSVG(uint256 indexed tokenId, uint256 randomNumber);
    event CreateRandomSVG(uint256 indexed tokenId, string tokenURI);

    constructor(address vrfCoordinator, address linkToken, bytes32 keyHashIn, uint256 feeIn) 
    VRFConsumerBase(vrfCoordinator, linkToken)
    ERC721 ("RandomSVG", "rsNFT") 
    {
        fee = feeIn;
        keyHash = keyHashIn;
        tokenCounter = 0;

        maxPaths = 10;
        maxCommands = 5;
        size = 500;
        pathCommands = ["M", "L"];
        colors = ["red", "blue", "green", "yellow", "black", "white"];
    }

    function create() public returns (bytes32 requestId) {
        requestId = requestRandomness(keyHash, fee);
        requestIdToSender[requestId] = msg.sender;
        uint256 tokenId = tokenCounter;
        requestIdtoTokenId[requestId] = tokenId;
        tokenCounter = tokenCounter + 1;
        emit requestedRandomSVG(requestId, tokenId);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomNumber) internal override {
        address nftOwner = requestIdToSender[requestId];
        uint256 tokenId = requestIdtoTokenId[requestId];
        _safeMint(nftOwner, tokenId);
        tokenIdToRandomNumber[tokenId] = randomNumber;
        emit CreateUnfinishedRandomSVG(tokenId, randomNumber);
    }

    function finishMint(uint256 tokenId) public {
        require(bytes(tokenURI(tokenId)).length <= 0, "tokenURL is already set");
        require(tokenCounter > tokenId, "tokenId has not been minted yet");
        
        uint256 randomNumber = tokenIdToRandomNumber[tokenId];
        require(randomNumber > 0, "No random number for tokenId");

        string memory svg = generateSVG(randomNumber);
        string memory imageURI = svgToImageURI(svg);
        string memory tokenURI = formatTokenURI(imageURI);
        _setTokenURI(tokenId, tokenURI);
        emit CreateRandomSVG(tokenId, svg);
    }

    function generateSVG(uint256 randomNumber) public view returns (string memory finalSvg) {
        uint256 numberOfPaths = (randomNumber % maxPaths) + 1;
        finalSvg = string(abi.encodePacked(
            "<svg xmlns='http://www.w3.org/2000/svg' height='", 
            uint2String(size), 
            "' width='",
            uint2String(size),
            "'>"));
        for(uint i=0; i<numberOfPaths; i++) {
            uint256 newRng = uint256(keccak256(abi.encode(randomNumber, i)));
            string memory pathSvg = generatePath(newRng);
            finalSvg = string(abi.encodePacked(finalSvg, pathSvg));
        }
        finalSvg = string(abi.encodePacked(finalSvg, "</svg>"));
    }

    function generatePath(uint256 randomNumber) public view returns(string memory pathSvg) {
        uint256 numberOfCommands = (randomNumber % maxCommands) + 1;
        pathSvg = "<path d='"; 
        for (uint i=0; i<numberOfCommands; i++) {
            uint newRng = uint(keccak256(abi.encode(randomNumber, size + i)));
            string memory pathCommand = generatePathCommand(newRng);
            pathSvg = string(abi.encodePacked(pathSvg, pathCommand));
        }
        string memory color = colors[randomNumber % colors.length];
        pathSvg = string(abi.encodePacked(pathSvg, "' fill='", color, "'>"));
    }

    function generatePathCommand(uint256 randomNumber) public view returns(string memory pathCommand) {
        pathCommand = pathCommands[randomNumber % pathCommands.length];
        uint256 param1 = uint256(keccak256(abi.encode(randomNumber, size * 2))) % size;
        uint256 param2 = uint256(keccak256(abi.encode(randomNumber, size * 3))) % size;
        pathCommand = string(abi.encodePacked(
            pathCommand, 
            " ", 
            uint2String(param1),
            " ",
            uint2String(param2
        )));
    }

    function svgToImageURI(string memory _svg) public pure returns (string memory) {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(_svg))));
        string memory imageURI = string(abi.encodePacked(baseURL, svgBase64Encoded));
        return imageURI;
    }
 
    function formatTokenURI(string memory _imageURI) public pure returns (string memory) {
        string memory baseURL = "data:application/json;base64,";
        return string(abi.encodePacked(
            baseURL,
            Base64.encode(
                bytes(abi.encodePacked(
                    "{'name': 'SVG NFT', ",
                    "'description': 'An NFT based on an SVG', '", 
                    "'attributes' : '', '", 
                    "'image': '", _imageURI, "'}"
                )
            )) 
        ));
    }

    // https://stackoverflow.com/questions/47129173/how-to-convert-uint-to-string-in-solidity
    function uint2String(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}