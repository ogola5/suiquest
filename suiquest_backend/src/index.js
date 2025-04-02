require("dotenv").config(); // Load environment variables

const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");

const app = express();

// ✅ Middleware Setup
app.use(cors()); // Allow cross-origin requests
app.use(bodyParser.json()); // Parse JSON bodies
app.use(bodyParser.urlencoded({ extended: true })); // Parse URL-encoded bodies

// ✅ Basic Route
app.get("/", (req, res) => {
  res.json({ message: "SuiQuest Backend Running!" });
});
app.get("/api/nfts", (req, res) => {
    res.json({ message: "NFTs endpoint working!" });
});


// ✅ Error Handling Middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: "Something went wrong!" });
});

// ✅ Set Port from ENV or Default to 3000
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));

module.exports = app;
