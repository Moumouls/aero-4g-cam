require("dotenv").config();
const { createDriver } = require("./appium-config");
const { uploadToR2, uploadJsonToR2 } = require("../upload/r2-uploader");
const { Logger } = require("../utils/logger");
const { EnvironmentValidator } = require("../utils/env-validator");


const IDS = {
    AGREEMENT_BUTTON: 'id=cn.ubia.ubox:id/ok_btn',
    COUNTRY_SELECT_BUTTON: 'id=cn.ubia.ubox:id/login_country_tv',
    COUNTRY_SEARCH_INPUT: 'id=cn.ubia.ubox:id/et_search',
    COUNTRY_SELECTOR: "id=cn.ubia.ubox:id/tv_name",
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

    try {

        const element = await driver.$(IDS.AGREEMENT_BUTTON);
        await element.waitForExist({ timeout: 30000 });
        await element.click();

        const countrySelectButton = await driver.$(IDS.COUNTRY_SELECT_BUTTON);
        await countrySelectButton.waitForExist({ timeout: 10000 });
        await countrySelectButton.click();

        const countrySearchInput = await driver.$(IDS.COUNTRY_SEARCH_INPUT);
        await countrySearchInput.waitForExist({ timeout: 10000 });
        await countrySearchInput.setValue('France');

        await sleep(1000);

        const countrySelector = await driver.$(IDS.COUNTRY_SELECTOR);
        await countrySelector.waitForExist({ timeout: 10000 });
        await countrySelector.click();

        await sleep(1000);

        const firstLoginButton = await driver.$(IDS.PRE_LOGIN_BUTTON);
        await firstLoginButton.waitForExist({ timeout: 10000 });
        await firstLoginButton.click();

        const emailInput = await driver.$(IDS.EMAIL_INPUT);
        await emailInput.waitForExist({ timeout: 10000 });
        await emailInput.setValue(process.env.UBOX_EMAIL, { mask: true });

        await sleep(3000);

        const passwordInput = await driver.$(IDS.PASSWORD_INPUT);
        await passwordInput.waitForExist({ timeout: 10000 });
        await passwordInput.setValue(process.env.UBOX_PASSWORD, { mask: true });
        await sleep(3000);

        const loginButton = await driver.$(IDS.LOGIN_BUTTON);
        await loginButton.waitForExist({ timeout: 10000 });
        await loginButton.click();

        const cancelNotificationButton = await driver.$(IDS.CANCEL_NOTIFICATION_BUTTON);
        await cancelNotificationButton.waitForExist({ timeout: 30000 });
        await cancelNotificationButton.click();

        const tutoHomeButton = await driver.$(IDS.TUTO_CONTAINER);
        await tutoHomeButton.waitForExist({ timeout: 10000 });
        await tutoHomeButton.click();
        await tutoHomeButton.click();
        await tutoHomeButton.click();
        await tutoHomeButton.click();

        await sleep(5000);

        const cameraThumbnail = await driver.$(IDS.CAMERA_THUMBNAIL);
        await cameraThumbnail.waitForExist({ timeout: 10000 });
        await cameraThumbnail.click();

        const tutoCameraButton = await driver.$(IDS.TUTO_CONTAINER);
        // Important to wait here for the stream to be ready
        await tutoCameraButton.waitForExist({ timeout: 60000 });
        await tutoCameraButton.click();
        await tutoCameraButton.click();
        await tutoCameraButton.click();
        await tutoCameraButton.click();
        await tutoCameraButton.click();
        await tutoCameraButton.click();
        await tutoCameraButton.click();
        await tutoCameraButton.click();
        await tutoCameraButton.click();

        await sleep(1000);

        const fullscreenButton = await driver.$(IDS.FULLSCREEN_BUTTON);
        await fullscreenButton.waitForExist({ timeout: 10000 });
        await fullscreenButton.click();
        await sleep(1000);

        const removeControlLayout = await driver.$(IDS.REMOVE_CONTROL_LAYOUT);
        await removeControlLayout.waitForExist({ timeout: 10000 });
        await removeControlLayout.click();
        await sleep(1000);

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

    } catch (error) {
        console.error(error);
        await driver.saveScreenshot('./screenshots/error.png');
        process.exit(1);
    }

    // await driver.debug();

}

// Exécution
if (require.main === module) {
    recordCamera().catch(console.error);
}

module.exports = { recordCamera };

