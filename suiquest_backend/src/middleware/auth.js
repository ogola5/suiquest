const { zkLogin } = require("zklogin");

const authenticate = async (req, res, next) => {
    try {
        const token = req.headers.authorization;
        const user = await zkLogin.verifyToken(token);
        req.user = user;
        next();
    } catch (err) {
        res.status(401).json({ error: "Unauthorized" });
    }
};

module.exports = { authenticate };
