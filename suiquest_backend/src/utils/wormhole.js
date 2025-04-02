const { transferNFT } = require("@wormhole-foundation/sdk");

async function bridgeNFT(nftId, destinationChain) {
    return await transferNFT({
        tokenId: nftId,
        fromChain: "sui",
        toChain: destinationChain
    });
}

module.exports = { bridgeNFT };
