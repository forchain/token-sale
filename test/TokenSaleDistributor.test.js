const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenSaleDistributor", function () {
    let TokenSaleDistributor;
    let tokenSaleDistributor;
    let admin;
    let user;
    let tokenAddress;
    let mockToken;

    beforeEach(async function () {
        // Get the signers
        [admin, user] = await ethers.getSigners();

        // Deploy a mock ERC20 token
        const MockToken = await ethers.getContractFactory("MockToken");
        mockToken = await MockToken.deploy("Mock Token", "MTK", ethers.parseEther("10000"));
        await mockToken.waitForDeployment();
        tokenAddress = mockToken.address;

        // Deploy the TokenSaleDistributor contract
        TokenSaleDistributor = await ethers.getContractFactory("TokenSaleDistributor");
        tokenSaleDistributor = await TokenSaleDistributor.deploy();
        await tokenSaleDistributor.waitForDeployment();

        // Set the token address in the distributor contract
        await tokenSaleDistributor.setTokenAddress(tokenAddress);
    });

    it("should allow admin to withdraw tokens", async function () {
        // Admin deposits tokens into the contract
        const amountToDeposit = ethers.parseEther("1000");
        await mockToken.approve(tokenSaleDistributor.address, amountToDeposit);
        await tokenSaleDistributor.withdraw(tokenAddress, amountToDeposit);

        // Check the balance of the admin before withdrawal
        const initialAdminBalance = await mockToken.balanceOf(admin.address);

        // Admin withdraws tokens
        await tokenSaleDistributor.withdraw(tokenAddress, amountToDeposit);

        // Check the balance of the admin after withdrawal
        const finalAdminBalance = await mockToken.balanceOf(admin.address);
        expect(finalAdminBalance).to.equal(initialAdminBalance.add(amountToDeposit));
    });

    it("should revert if non-admin tries to withdraw tokens", async function () {
        // User tries to withdraw tokens
        await expect(tokenSaleDistributor.connect(user).withdraw(tokenAddress, ethers.parseEther("100")))
            .to.be.revertedWith("admin only");
    });
}); 