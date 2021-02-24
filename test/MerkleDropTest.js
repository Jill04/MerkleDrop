const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");

const truffleAssert = require("truffle-assertions");
const { assert, expect } = require("chai");
const MerkleDrop = artifacts.require("MerkleDrop");
const TokenBasic = artifacts.require("Tokenbasic");
const TokenBasic1 = artifacts.require("Tokenbasic");
const Lock = artifacts.require("Lock");

require("chai").use(require("chai-bignumber")(BN)).should();

const denominator = new BN(10).pow(new BN(16));
const getWith16Decimals = function (amount) {
  return new BN(amount).mul(denominator);
};

contract("MerkleDrop", () => {
  it("Should deploy smart contract properly", async () => {
    const token = await TokenBasic.deployed();
    const token1 = await TokenBasic1.deployed();
    const lock = await Lock.deployed();
    const merkle = await MerkleDrop.deployed(
      lock.address,
      getWith16Decimals(5),
      getWith16Decimals(5),
      "0x31de0c08f72fe94aadfa9adbfabb5b23238b9ce1"
    );

    assert(token.address !== "");
    assert(merkle.address !== "");
  });
  beforeEach(async function () {
    token = await TokenBasic.new();
    token1 = await TokenBasic1.new();
    lock = await Lock.new();
    accounts = await web3.eth.getAccounts();
    merkle = await MerkleDrop.new(
      lock.address,
      getWith16Decimals(5),
      getWith16Decimals(5),
      accounts[9]
    );
    await token.approve(merkle.address, getWith16Decimals(10));
    await token1.approve(merkle.address, getWith16Decimals(10));
    await lock.approve(merkle.address, getWith16Decimals(10));
  });

  describe("[Testcase 1: To create AirDrop and pay fees in token]", () => {
    it("Create AirDrop", async () => {
      await merkle.createAirDrop(
        token.address,
        160,
        "0xd44fec381892e6c49b756000d0ea0745eb3eceb4e380095d41ea5755e3bcf97a",
        1614150598,
        1616068615,
        "true"
      );
    });
  });

  describe("[Testcase 2: To create AirDrop and pay fees in eth]", () => {
    it("Create AirDrop", async () => {
      await merkle.createAirDrop(
        token1.address,
        160,
        "0x5f726e8b1ef32651e49545967f8b01a458b58e85e7d66b52e299c735c7d43b85",
        1614150598,
        1616068615,
        "false",
        {
          value: getWith16Decimals(5),
        }
      );
    });
  });

  describe("[Testcase 3: To claim air drop tokens]", () => {
    it("Claim AirDrop", async () => {
      await merkle.createAirDrop(
        token.address,
        160,
        "0xd44fec381892e6c49b756000d0ea0745eb3eceb4e380095d41ea5755e3bcf97a",
        1614150598,
        1631966215,
        "false",
        {
          value: getWith16Decimals(5),
        }
      );

      await merkle.createAirDrop(
        token1.address,
        160,
        "0x5f726e8b1ef32651e49545967f8b01a458b58e85e7d66b52e299c735c7d43b85",
        1614150598,
        1631966215,
        "true"
      );

      var hex = [
        "0xd44fec381892e6c49b756000d0ea0745eb3eceb4e380095d41ea5755e3bcf97a",
        "0x5f726e8b1ef32651e49545967f8b01a458b58e85e7d66b52e299c735c7d43b85",
      ];
      var proof = [
        ["0x2a7335270534e59e7706f81b43e93be7137d9609329d150b02332ba4f2bd7aea"],
        [
          "0x05be6624b7ab704d6c2721daf97766e6e0f06310b1c096d4b7151e6dff2e60e6",
          "0x2a7335270534e59e7706f81b43e93be7137d9609329d150b02332ba4f2bd7aea",
        ],
      ];
      var amount = ["50", "50"];
      var index = ["1", "1"];
      assert.isTrue(
        await merkle.claim.call(hex, proof, index, amount, {
          from: accounts[2],
        })
      );
    });
  });

  describe("[Testcase 4: To try to claim expired airDrop tokens]", () => {
    it("Claim AirDrop", async () => {
      await merkle.createAirDrop(
        token.address,
        160,
        "0xd44fec381892e6c49b756000d0ea0745eb3eceb4e380095d41ea5755e3bcf97a",
        1613113274,
        1613286074,
        "false",
        {
          value: getWith16Decimals(5),
        }
      );

      await merkle.createAirDrop(
        token1.address,
        160,
        "0x5f726e8b1ef32651e49545967f8b01a458b58e85e7d66b52e299c735c7d43b85",
        1613113274,
        1613286074,
        "true"
      );

      var hex = [
        "0xd44fec381892e6c49b756000d0ea0745eb3eceb4e380095d41ea5755e3bcf97a",
        "0x5f726e8b1ef32651e49545967f8b01a458b58e85e7d66b52e299c735c7d43b85",
      ];
      var proof = [
        ["0x2a7335270534e59e7706f81b43e93be7137d9609329d150b02332ba4f2bd7aea"],
        [
          "0x05be6624b7ab704d6c2721daf97766e6e0f06310b1c096d4b7151e6dff2e60e6",
          "0x2a7335270534e59e7706f81b43e93be7137d9609329d150b02332ba4f2bd7aea",
        ],
      ];
      var amount = ["50", "50"];
      var index = ["1", "1"];

      try {
        await merkle.claim(hex, proof, index, amount, {
          from: accounts[2],
        });
      } catch (error) {}
    });
  });

  describe("[Testcase 5: To send back expired airDrops to the AirDropper]", () => {
    it("Send token to AirDropper", async () => {
      await merkle.createAirDrop(
        token1.address,
        160,
        "0x1344f60b7c027761ab12f07f61c04297b298fb90743cc0b0f9a598bf5b4fdf68",
        1612162874,
        1612422074,
        "false",
        {
          value: getWith16Decimals(5),
        }
      );
      var vaultAddress = await merkle.vaultAddress.call(
        "0x1344f60b7c027761ab12f07f61c04297b298fb90743cc0b0f9a598bf5b4fdf68"
      );
      await merkle.sendTokenBackToAirDropperByVault(vaultAddress);
    });
  });

  describe("[Testcase 6: To send back non-expired airDrops to the AirDropperr]", () => {
    it("Send token to AirDropper", async () => {
      await merkle.createAirDrop(
        token1.address,
        160,
        "0x5f726e8b1ef32651e49545967f8b01a458b58e85e7d66b52e299c735c7d43b85",
        1614150598,
        1631966215,
        "false",
        {
          from: accounts[0],
          value: getWith16Decimals(5),
        }
      );
      var vaultAddress = await merkle.vaultAddress.call(
        "0x5f726e8b1ef32651e49545967f8b01a458b58e85e7d66b52e299c735c7d43b85"
      );
      try {
        await merkle.sendTokenBackToAirDropperByVault(vaultAddress, {
          from: accounts[0],
        });
      } catch (error) {}
      var actual = await token1.balanceOf(vaultAddress);
      var expected = "160";
      assert.equal(actual.toString(), expected);
    });
  });

  describe("[Testcase 7: To try to send back airDrops who is not the AirDropper]", () => {
    it("Send token to AirDropper", async () => {
      await merkle.createAirDrop(
        token1.address,
        160,
        "0x1344f60b7c027761ab12f07f61c04297b298fb90743cc0b0f9a598bf5b4fdf68",
        1612162874,
        1612422074,
        "false",
        {
          from: accounts[0],
          value: getWith16Decimals(5),
        }
      );
      var hex = "0x1344f60b7c027761ab12f07f61c04297b298fb90743cc0b0f9a598bf5b4fdf68";
      try {
        await merkle.sendTokenBackToAirDropperByHex(hex, {
          from: accounts[3],
        });
      } catch (error) {}
    });
  });
});
