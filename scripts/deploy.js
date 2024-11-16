const { ethers } = require("hardhat");

async function main() {
    const TokenSaleDistributor = await ethers.getContractFactory("TokenSaleDistributor");
    const tokenSaleDistributor = await TokenSaleDistributor.deploy();

    console.log("TokenSaleDistributor deployed to:", tokenSaleDistributor.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });