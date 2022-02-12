pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Base64.sol";


contract GiftCards is Ownable, ERC721, ERC721Enumerable, ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIDs;

    struct Gift {
        uint256 tokenID;
        uint256 amount;
        bool redeemed;
        address from;
        uint256 redeem_at;
    }
    
    event GiftMintedToOwner(address indexed previousOwner,address indexed newOwner);
    event GiftRedeemed(address indexed owner,uint256 indexed tokenID);

    mapping(uint256 => Gift) private gifts;
    mapping(address => uint256[]) private ownerGifts;

    bool public _scheduledRedeemSwitch = true;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {}

    function mint(address ownerAddress, uint256 redeem_at, string memory message, string memory imageLink) public payable returns (uint256) {

        // check if message length is greater than 140 chars
        require(bytes(message).length <= 140, "Message cannot be greater than 140 characters");

        _tokenIDs.increment();
        uint256 newID = _tokenIDs.current();

        uint256 amount = msg.value;

        Gift memory newGift = Gift({
            tokenID: newID,
            amount: amount,
            redeemed: false,
            redeem_at: redeem_at,
            from: msg.sender
        });

        gifts[newID] = newGift;
        ownerGifts[ownerAddress].push(newID);

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Gift Card #',
                        toString(newID),
                        '", "description": "',
                        message, '. Redeem at link',
                        '", "image": "',imageLink ,'"}'
                    )
                )
            )
        );

        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        _safeMint(ownerAddress, newID);
        _setTokenURI(newID, finalTokenUri);

        emit GiftMintedToOwner(msg.sender, ownerAddress);

        return newID;
    }

    function getAllGifts(address owner) public view returns (Gift[] memory) {

        Gift[] memory result = new Gift[](ownerGifts[owner].length);

        for (uint256 i = 0; i < ownerGifts[owner].length; i++) {
            result[i] = gifts[ownerGifts[owner][i]];
        }

        return result;
    }

    function redeem(uint256 tokenID) public returns (uint256) {
        Gift memory gift = gifts[tokenID];
        require(gift.redeemed == false, "Gift has already been redeemed");

        address tokenOwner = ownerOf(tokenID);
        require(tokenOwner == msg.sender, "You do not own this gift");

        if(gift.redeem_at > 0 && _scheduledRedeemSwitch){
            require(gift.redeem_at < block.timestamp, "Gift can't be redeemed yet");
        }

        payable(msg.sender).transfer(gift.amount);
        gifts[tokenID].redeemed = true;

        emit GiftRedeemed(msg.sender, tokenID);

        return gift.amount;
    }

    function redeemAll() public {
        for (uint256 i = 0; i < ownerGifts[msg.sender].length; i++) {
            if(!gifts[ownerGifts[msg.sender][i]].redeemed) {
                if(gifts[ownerGifts[msg.sender][i]].redeem_at > 0){
                    require(gifts[ownerGifts[msg.sender][i]].redeem_at < block.timestamp, "Gift can't be redeemed yet");
                }

                payable(msg.sender).transfer(gifts[ownerGifts[msg.sender][i]].amount);
                gifts[ownerGifts[msg.sender][i]].redeemed = true;

                emit GiftRedeemed(msg.sender, gifts[ownerGifts[msg.sender][i]].tokenID);
            }
        }
    }

    function transferToken(
        address from,
        address to,
        uint256 tokenID
    ) public returns (bool) {
        super.safeTransferFrom(from, to, tokenID);
        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        return super.ownerOf(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function overrideRedeemTime(uint256 tokenID, uint256 timestamp) public onlyOwner returns(Gift memory)  {
        gifts[tokenID].redeem_at = timestamp;
        return gifts[tokenID];
    }

    function updateScheduleRedeemSwitch(bool switchStatus) public onlyOwner {
        _scheduledRedeemSwitch = switchStatus;
    }

    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT license
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}