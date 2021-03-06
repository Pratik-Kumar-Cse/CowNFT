const { expect } = require("chai");
const { hexStripZeros } = require("ethers/lib/utils");
const { ethers } = require("hardhat");

const token = require("./token.json");

let nft,sales,x22;
let owner,user1,user2,user3,user4,user5;

let accountToImpersonate = "0x8313665D1eaBDa663CB0c9C976c41679A8C22344";

async function getAddresses() {
  [owner,user1,user2,user3,user4,user5] = await ethers.getSigners();
}

function toWei(n) {
  return ethers.utils.parseEther(n);
}

async function deploy() {

  const NFT = await ethers.getContractFactory("WorldCow");
  nft = await NFT.deploy("Hello", "World", 250);
  await nft.deployed();

  const Sales = await ethers.getContractFactory("Purchase");
  sales = await Sales.deploy(nft.address,"0x87e41175921d283c10Ce42C9200AA3c8d51835A2", "0xc08e5f3D4fD146aB1AB0ae3AeeF1cDa4Fb30ED10");
  await sales.deployed();

  x22 = await ethers.getContractAt(token.abi,"0x87e41175921d283c10Ce42C9200AA3c8d51835A2");

  console.log("Cow NFT address:",nft.address);
  console.log("CowSale address:",sales.address);
  console.log("X22 address:",x22.address);

  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [accountToImpersonate],
  });
  const admin = await ethers.getSigner(accountToImpersonate);
  console.log(admin.address)
  console.log(await x22.balanceOf(admin.address));
  await x22.connect(admin).transfer(owner.address,toWei("100000"));
  await hre.network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: [accountToImpersonate],
  });

}

describe("Deploying Contracts", async() => {
  it("Contracts Deployed", async() => {
      await getAddresses();
      await deploy();
  }).timeout("150s")
})

describe("Minting", function () {

  it("check minting ", async function () {

    await nft.mint(user1.address);
    expect(await nft.balanceOf(user1.address)).to.equal(1);
  });

  it("transfer tokens", async function () {

    await nft.connect(user1).approve(user3.address, 1);
    await nft.connect(user3).transferFrom(user1.address, user2.address, 1);
    expect(await nft.balanceOf(user2.address)).to.equal(1);
  });

  it("check burning", async function () {

    await nft.connect(user2).burn(1);
    expect(await nft.balanceOf(user2.address)).to.equal(0);
  });

  it("return tokens", async function () {

    await nft.mint(user1.address);
    const x = await nft.getTokens(user1.address);
    expect(x[0]).to.equal(2);
  });

});

describe("ERC 2981", function () {

  it("supports interface", async function () {

    expect(await nft.supportsInterface("0x2a55205a")).to.equal(true);
  });

  it("checks royalty", async function () {

    const y = await nft.royaltyInfo(1, 10000);
    expect(y[0]).to.equal('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
    expect(y[1]).to.equal(250);

    await nft.setRoyaltyInfo(user2.address, 300);
    const z = await nft.royaltyInfo(1, 100000);
    expect(z[0]).to.equal('0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC');
    expect(z[1]).to.equal(3000);

    await nft.deleteDefaultRoyalty();
    const j = await nft.royaltyInfo(1, 10000);
    expect(j[0]).to.equal('0x0000000000000000000000000000000000000000');
    expect(j[1]).to.equal(0);

    await nft.setTokenRoyalty(1, user3.address, 350);
    const i = await nft.royaltyInfo(1, 10000);
    expect(i[0]).to.equal('0x90F79bf6EB2c4f870365E785982E1f101E93b906');
    expect(i[1]).to.equal(350);
  });
});

describe("Sales", function () {

  it("sets values", async function () {
   
    await sales.setTokensLimit(30);
    expect(await sales.maxTokenForOneSaleTransaction()).to.equal(30);

    await sales.updateIsDiscount(true);
    expect(await sales.isDiscount()).to.equal(true);

    await sales.setPrices(toWei("2"));
    expect(await sales.priceInBNB()).to.equal(toWei("2"));

    await sales.setPricesX22(10000);
    expect(await sales.priceInX22()).to.equal(10000);

    await sales.setDiscount(4000);
    expect(await sales.discount()).to.equal(4000);

    await sales.setTreasurerAddress(user1.address);
    expect(await sales.treasurerAddress()).to.equal("0x70997970C51812dc3A010C7d01b50e0d17dc79C8");

    await nft.addAuthorized(sales.address);
    await sales.batchNFTCreate(["0x70997970C51812dc3A010C7d01b50e0d17dc79C8", "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"]);
    expect(await nft.balanceOf("0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC")).to.equal(1);
    expect(await nft.balanceOf("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")).to.equal(2);

    await sales.unpause();
    await sales.connect(user4).buyWithBNB(3, { value: ethers.utils.parseEther("6") });
    expect(await nft.balanceOf(user4.address)).to.equal(3);

    // TODO:-
    // Allowance of X22 tokens is not with this address so below case fails.. but initial important 
    // conditions are passing.. 
    await sales.updateIsDiscount(false);

    await x22.transfer(user5.address,toWei("10000"));
    await x22.connect(user5).approve(sales.address,toWei("10000"));

    await sales.connect(user5).buyWithX22(20000, 2);

    expect(await nft.balanceOf(user5.address)).to.equal(2);

    //const priceInX22 = await sales.getPriceInx22(4);
    // await sales.connect(user5).buyWithX22(priceInX22, 2);
    // expect(await nft.balanceOf(user5.address)).to.equal(2);
  });


  it("check current price",async function(){

    const currentPrice = await sales.getPriceInx22(toWei("1"));

    console.log(currentPrice);

  })

});