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
    TUTO_CONTAINER: 'id=cn.ubia.ubox:id/fl_container',
    CAMERA_THUMBNAIL: 'id=cn.ubia.ubox:id/cameraListItemThumbnail',
    FULLSCREEN_BUTTON: 'id=cn.ubia.ubox:id/full_btn',
    REMOVE_CONTROL_LAYOUT: 'id=cn.ubia.ubox:id/monitorLayout',
    LIGHT_BUTTON: 'id=cn.ubia.ubox:id/light_button',
}

const VERBOSE = !!process.env.VERBOSE
const USE_FS = false

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));


async function recordCamera() {
    const logger = new Logger();
    const validator = new EnvironmentValidator();

    // Validate environment first
    if (!validator.validate()) {
        throw new Error("Environment validation failed");
    }
    validator.printConfig();

    const driver = await createDriver();

    await sleep(1000);


    const element = await driver.$(IDS.AGREEMENT_BUTTON);
    await element.waitForDisplayed({ timeout: 10000 });
    await element.click();

    await sleep(3000);

    const firstLoginButton = await driver.$(IDS.PRE_LOGIN_BUTTON);
    await firstLoginButton.waitForDisplayed({ timeout: 10000 });
    await firstLoginButton.click();

    await sleep(1000);


    const emailInput = await driver.$(IDS.EMAIL_INPUT);
    await emailInput.waitForDisplayed({ timeout: 10000 });
    await emailInput.setValue(process.env.UBOX_EMAIL, { mask: true });

    const passwordInput = await driver.$(IDS.PASSWORD_INPUT);
    await passwordInput.waitForDisplayed({ timeout: 10000 });
    await passwordInput.setValue(process.env.UBOX_PASSWORD, { mask: true });

    const loginButton = await driver.$(IDS.LOGIN_BUTTON);
    await loginButton.waitForDisplayed({ timeout: 10000 });
    await loginButton.click();


    const cancelNotificationButton = await driver.$(IDS.CANCEL_NOTIFICATION_BUTTON);
    await cancelNotificationButton.waitForDisplayed({ timeout: 10000 });
    await cancelNotificationButton.click();

    if (VERBOSE) await driver.saveScreenshot('./screenshots/home.png');

    const tutoHomeButton = await driver.$(IDS.TUTO_CONTAINER);
    await tutoHomeButton.waitForDisplayed({ timeout: 10000 });
    await tutoHomeButton.click();
    await tutoHomeButton.click();
    await tutoHomeButton.click();
    await tutoHomeButton.click();

    const cameraThumbnail = await driver.$(IDS.CAMERA_THUMBNAIL);
    await cameraThumbnail.waitForDisplayed({ timeout: 10000 });
    await cameraThumbnail.click();

    const waitStream = await driver.$(IDS.LIGHT_BUTTON);
    await waitStream.waitForDisplayed({ timeout: 10000 });

    await sleep(1000);

    if (VERBOSE) await driver.saveScreenshot('./screenshots/camera_home.png');


    const tutoCameraButton = await driver.$(IDS.TUTO_CONTAINER);
    await tutoCameraButton.waitForDisplayed({ timeout: 10000 });
    await tutoCameraButton.click();
    await tutoCameraButton.click();
    await tutoCameraButton.click();
    await tutoCameraButton.click();
    await tutoCameraButton.click();
    await tutoCameraButton.click();
    await tutoCameraButton.click();
    await tutoCameraButton.click();
    await tutoCameraButton.click();

    if (VERBOSE) await driver.saveScreenshot('./screenshots/camera_fullscreen.png');

    const fullscreenButton = await driver.$(IDS.FULLSCREEN_BUTTON);
    await fullscreenButton.waitForDisplayed({ timeout: 10000 });
    await fullscreenButton.click();

    if (VERBOSE) await driver.saveScreenshot('./screenshots/camera_remove_control_layout.png');

    const removeControlLayout = await driver.$(IDS.REMOVE_CONTROL_LAYOUT);
    await removeControlLayout.waitForDisplayed({ timeout: 10000 });
    await removeControlLayout.click();

    await driver.startRecordingScreen({
        videoSize: '1280x720',
        timeLimit: '1800', // 30 minutes max
        bitRate: '1000000' // 1 Mbps
    });

    // wait 10 seconds before stopping the recording
    await sleep(10000);

    const videoBase64 = await driver.stopRecordingScreen();

    // quit the app
    await driver.execute('mobile: terminateApp', { appId: 'cn.ubia.ubox' })

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

