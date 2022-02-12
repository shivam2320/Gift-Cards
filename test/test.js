const { expect } = require("chai");
const { ethers } = require("hardhat");
const { isCallTrace } = require("hardhat/internal/hardhat-network/stack-traces/message-trace");

describe("GiftCards Contract", function() {
    it("Mint", async function() {

        const [owner,addr1, addr2] = await ethers.getSigners();
        const  GiftCards = await ethers.getContractFactory("GiftCards");
        const gift = await GiftCards.deploy("Test","tst");
        await gift.deployed();
        console.log("Contract Address", gift.address);

        await gift.mint(addr1.address, 100, "Message", "imageLink",{value: ethers.utils.parseEther("2")});
        expect(await gift.totalSupply()).to.equal(1);
        expect(await gift.balanceOf(addr1.address)).to.equal(1);
        
        console.log("tokenURI", await gift.tokenURI(1));

        await gift.connect(addr1).redeem(1);
        
        await gift.changeMaxTotalSupply(35);
        
    });
});