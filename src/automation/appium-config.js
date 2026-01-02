const { remote } = require("webdriverio");

const isLocal = process.argv.includes("--local");

const capabilities = {
    platformName: "Android",
    "appium:deviceName": isLocal ? "emulator-5554" : "Android Emulator",
    "appium:automationName": "UiAutomator2",
    "appium:appPackage": "cn.ubia.ubox",
    "appium:appWaitActivity": "*", // Wait for any activity to avoid timeout
    "appium:autoGrantPermissions": true,
    "appium:noReset": false,
    "appium:ensureWebviewsHavePages": true,
    "appium:nativeWebScreenshot": true,
    "appium:newCommandTimeout": 300,
    // "appium:orientation": "LANDSCAPE", // TODO: Re-enable later - currently causing rotation lock error
    "appium:uiautomator2ServerInstallTimeout": 60000, // Increased timeout for driver installation
};

async function createDriver() {
    const isVerbose = process.env.VERBOSE === "true" || process.env.VERBOSE === "1";

    const driver = await remote({
        hostname: "localhost",
        port: 4723,
        // path defaults to "/" for Appium 2.x+ - explicitly set for clarity
        path: "/",
        logLevel: isVerbose ? "info" : "error", // Silent unless verbose mode
        capabilities,
        // Connection retry settings for better reliability with WebdriverIO v9
        connectionRetryTimeout: 120000,
        connectionRetryCount: 3,
    });
    return driver;
}

module.exports = { createDriver, capabilities };

