require("dotenv").config();
const { createDriver } = require("./appium-config");
const { uploadToR2, uploadJsonToR2 } = require("../upload/r2-uploader");
const { Logger } = require("../utils/logger");
const { EnvironmentValidator } = require("../utils/env-validator");


const IDS = {
    AGREEMENT_BUTTON: 'id=cn.ubia.ubox:id/ok_btn',
    PRE_LOGIN_BUTTON: 'id=cn.ubia.ubox:id/login_tv',
    EMAIL_INPUT: 'id=cn.ubia.ubox:id/login_name_edit',
    PASSWORD_INPUT: 'id=cn.ubia.ubox:id/login_pwd_edit',
    LOGIN_BUTTON: 'id=cn.ubia.ubox:id/login_btn',
    CANCEL_NOTIFICATION_BUTTON: 'id=cn.ubia.ubox:id/comfirm_del_device_cancel',
}

const USE_FS = false

async function recordCamera() {
    const logger = new Logger();
    const validator = new EnvironmentValidator();

    // Validate environment first
    if (!validator.validate()) {
        throw new Error("Environment validation failed");
    }
    validator.printConfig();

    const driver = await createDriver();

    const element = await driver.$(IDS.AGREEMENT_BUTTON);
    await element.waitForDisplayed({ timeout: 30000 });
    await element.click();

    const firstLoginButton = await driver.$(IDS.PRE_LOGIN_BUTTON);
    await firstLoginButton.waitForDisplayed({ timeout: 30000 });
    await firstLoginButton.click();

    const emailInput = await driver.$(IDS.EMAIL_INPUT);
    await emailInput.waitForDisplayed({ timeout: 30000 });
    await emailInput.setValue(process.env.UBOX_EMAIL);

    const passwordInput = await driver.$(IDS.PASSWORD_INPUT);
    await passwordInput.waitForDisplayed({ timeout: 30000 });
    await passwordInput.setValue(process.env.UBOX_PASSWORD);

    await driver.startRecordingScreen({
        videoSize: '1280x720',
        timeLimit: '1800', // 30 minutes max
        bitRate: '1000000' // 1 Mbps
    });

    const loginButton = await driver.$(IDS.LOGIN_BUTTON);
    await loginButton.waitForDisplayed({ timeout: 30000 });
    await loginButton.click();

    const cancelNotificationButton = await driver.$(IDS.CANCEL_NOTIFICATION_BUTTON);
    await cancelNotificationButton.waitForDisplayed({ timeout: 30000 });
    await cancelNotificationButton.click();


    logger.info("Stopping screen recording...");
    const videoBase64 = await driver.stopRecordingScreen();

    const timestamp = new Date().toISOString();

    if (USE_FS) {
        // Save the video to a file
        const fs = require('fs');
        const path = require('path');
        const videoPath = path.join(__dirname, '..', '..', 'recordings', `recording.mp4`);

        // Create recordings directory if it doesn't exist
        const recordingsDir = path.join(__dirname, '..', '..', 'recordings');
        if (!fs.existsSync(recordingsDir)) {
            fs.mkdirSync(recordingsDir, { recursive: true });
        }

        // Write video file
        fs.writeFileSync(videoPath, videoBase64, 'base64');
    } else {

        // Upload video
        await uploadToR2(videoBase64, `terrain.mp4`, logger);

        // Upload metadata JSON
        const metadata = {
            timestamp: timestamp,
            videoKey: "terrain.mp4"
        };
        await uploadJsonToR2(metadata, `terrain.json`, logger);

        logger.info(`✅ Video recorded at: ${timestamp}`);
    }

    // await driver.debug();

}

// Exécution
if (require.main === module) {
    recordCamera().catch(console.error);
}

module.exports = { recordCamera };

