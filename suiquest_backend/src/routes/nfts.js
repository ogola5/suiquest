const express = require("express");
const { authenticate } = require("../middleware/auth");
const router = express.Router();

// Fetch player NFTs
router.get("/", authenticate, async (req, res) => {
    const playerNFTs = await getNFTs(req.user.address);
    res.json(playerNFTs);
});

// Stake NFT
router.post("/stake", authenticate, async (req, res) => {
    const { nftId } = req.body;
    const result = await stakeNFT(req.user.address, nftId);
    res.json(result);
});

module.exports = router;
