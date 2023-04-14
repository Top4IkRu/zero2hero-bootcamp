const { ethers } = require("hardhat");
const { assert, expect } = require("chai");

describe("SocialFi", function () {
  let factoryToken,
    token,
    factory,
    contract,
    owner,
    manager,
    user1,
    user2,
    user3;
  beforeEach(async function () {
    [owner, manager, user1, user2, user3] = await ethers.getSigners();
    factoryToken = await ethers.getContractFactory("TestToken");
    token = await factoryToken.deploy([
      owner.address,
      manager.address,
      user1.address,
      user2.address,
      user3.address,
    ]);
    factory = await ethers.getContractFactory("SocialFi");
    const param0 = "0xd99d1c33f9fc3444f8101754abc46c52416550d1";
    const param1 = 5;
    const param2 = "ipfs://QmSPdJyCiJCbJ2sWnomh6gHqkT2w1FSnp7ZnXxk3itvc14/";
    contract = await factory.deploy(param0, param1, param2);
    const priceToMint = await contract.priceToMint(owner.address);
    await contract.connect(owner).safeMint({ value: priceToMint });
  });

  it("returns true when address is present in collection", async function () {
    const addressToCheck = user1.address;
    console.log(addressToCheck);
    const collection = [user1.address, user2.address, user3.address];
    expect(await contract.isAddressExist(addressToCheck, collection)).to.be
      .true;
  });

  it("returns false when address is not present in collection", async function () {
    const addressToCheck = user1.address;
    const collection = [user2.address, user3.address];
    expect(await contract.isAddressExist(addressToCheck, collection)).to.be
      .false;
  });

  it("creates a new session with ETH payment", async function () {
    await expect(
      contract
        .connect(owner)
        .createNewSessionByEth(0, 10 ** 6, 1000, 10, 0, "Test session")
    )
      .to.emit(contract, "NewSessionCreated")
      .withArgs(
        0,
        "Test session",
        "0x0000000000000000000000000000000000000000",
        10 ** 6,
        1000,
        10,
        0
      );

    const sessions = await contract.sessionByAuthor(0, 0);
    expect(sessions.length).to.equal(1);
    expect(sessions[0].name).to.equal("Test session");
    expect(sessions[0].price).to.equal(10 ** 6);
    expect(sessions[0].expirationTime).to.equal(1000);
    expect(sessions[0].maxParticipants).to.equal(10);
    expect(sessions[0].typeOf).to.equal(0);
    expect(sessions[0].participants.notConfirmed.length).to.equal(0);
    expect(sessions[0].participants.confirmed.length).to.equal(0);
    expect(sessions[0].participants.rejected.length).to.equal(0);
    expect(sessions[0].rating.up).to.equal(0);
    expect(sessions[0].rating.down).to.equal(0);
  });

  it("creates a new session with Token payment", async function () {
    await expect(
      contract
        .connect(owner)
        .createNewSessionByToken(
          0,
          token.address,
          100,
          1000,
          10,
          0,
          "Test session"
        )
    )
      .to.emit(contract, "NewSessionCreated")
      .withArgs(0, "Test session", token.address, 100, 1000, 10, 0);

    const sessions = await contract.sessionByAuthor(0, 0);
    expect(sessions.length).to.equal(1);
    expect(sessions[0].name).to.equal("Test session");
    expect(sessions[0].price).to.equal(100);
    expect(sessions[0].expirationTime).to.equal(1000);
    expect(sessions[0].maxParticipants).to.equal(10);
    expect(sessions[0].typeOf).to.equal(0);
    expect(sessions[0].participants.notConfirmed.length).to.equal(0);
    expect(sessions[0].participants.confirmed.length).to.equal(0);
    expect(sessions[0].participants.rejected.length).to.equal(0);
    expect(sessions[0].rating.up).to.equal(0);
    expect(sessions[0].rating.down).to.equal(0);
  });
});
