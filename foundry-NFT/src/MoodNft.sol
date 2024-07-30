// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract MoodNft is ERC721 {
    // errors
    error MoodNft__CantFlipMoodIfNotOwner();

    uint256 private s_tokenCounter;
    string private s_happySvgImageUri;
    string private s_sadSvgImageUri;

    enum Mood {
        HAPPY,
        SAD
    }

    mapping(uint256 => Mood) private s_tokenIdtoMood;

    constructor(
        string memory happySvgImageUri,
        string memory sadSvgImageUri
    ) ERC721("Emoji NFT", "EN") {
        s_tokenCounter = 0;
        s_happySvgImageUri = happySvgImageUri;
        s_sadSvgImageUri = sadSvgImageUri;
    }

    function mintNft() public {
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenIdtoMood[s_tokenCounter] = Mood.HAPPY;
        s_tokenCounter++;
    }

    function flipMood(uint256 tokenId) public {
        // fetch the owner of the token
        address owner = ownerOf(tokenId);
        // Only owner can flip mood
        _checkAuthorized(owner, msg.sender, tokenId);
        // if (_isAuthorized(owner, msg.sender, tokenId)) {
        //     revert MoodNft__CantFlipMoodIfNotOwner();
        // }

        if (s_tokenIdtoMood[tokenId] == Mood.HAPPY) {
            s_tokenIdtoMood[tokenId] = Mood.SAD;
        } else if (s_tokenIdtoMood[tokenId] == Mood.SAD) {
            s_tokenIdtoMood[tokenId] = Mood.HAPPY;
        }
    }

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        string memory imageURI;
        if (s_tokenIdtoMood[tokenId] == Mood.HAPPY) {
            imageURI = s_happySvgImageUri;
        } else if (s_tokenIdtoMood[tokenId] == Mood.SAD) {
            imageURI = s_sadSvgImageUri;
        }

        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name(),
                                '", "description": "An Nft that reflects moods", "attributes": [{"traits_type": "moodiness", "value": 100}]}, "image": "',
                                imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }
}
