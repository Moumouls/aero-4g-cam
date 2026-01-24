const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");

const s3Client = new S3Client({
    region: "auto",
    endpoint: process.env.R2_ENDPOINT,
    credentials: {
        accessKeyId: process.env.R2_ACCESS_KEY_ID,
        secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
    },
});

async function uploadToR2(base64Data, objectKey, logger = null) {
    try {
        const isVerbose = process.env.VERBOSE === "true" || process.env.VERBOSE === "1";

        const logMessage = (msg, level = "info") => {
            // Only log info/warn messages if verbose is enabled
            // Always log errors
            if (level === "error" || isVerbose) {
                if (logger) {
                    logger[level](msg);
                } else {
                    console[level === "error" ? "error" : level === "warn" ? "warn" : "log"](
                        msg
                    );
                }
            }
        };

        logMessage(`Uploading to R2: ${objectKey}...`);

        // Convert base64 string to Buffer
        const fileContent = Buffer.from(base64Data, 'base64');

        const fileSizeKB = Math.round(fileContent.length / 1024);
        logMessage(`File size: ${fileSizeKB} KB`);

        const command = new PutObjectCommand({
            Bucket: process.env.R2_BUCKET_NAME,
            Key: objectKey,
            Body: fileContent,
            ContentType: "video/mp4",
            CacheControl: "no-cache, no-store, must-revalidate",
        });

        logMessage("Sending request to R2...");
        await s3Client.send(command);
        logMessage(`✅ Upload successful: ${objectKey}`);

        const uploadUrl = `${process.env.R2_ENDPOINT}/${process.env.R2_BUCKET_NAME}/${objectKey}`;
        logMessage(`📍 Video URL: ${uploadUrl}`);

        return {
            success: true,
            key: objectKey,
            url: uploadUrl,
            sizeKB: fileSizeKB,
        };
    } catch (error) {
        const errorMsg = `❌ R2 Upload Error: ${error.message}`;
        if (logger) {
            logger.error(errorMsg);
        } else {
            console.error(errorMsg);
        }
        throw error;
    }
}

async function uploadJsonToR2(jsonData, objectKey, logger = null) {
    try {
        const isVerbose = process.env.VERBOSE === "true" || process.env.VERBOSE === "1";

        const logMessage = (msg, level = "info") => {
            if (level === "error" || isVerbose) {
                if (logger) {
                    logger[level](msg);
                } else {
                    console[level === "error" ? "error" : level === "warn" ? "warn" : "log"](msg);
                }
            }
        };

        logMessage(`Uploading JSON to R2: ${objectKey}...`);

        const command = new PutObjectCommand({
            Bucket: process.env.R2_BUCKET_NAME,
            Key: objectKey,
            Body: JSON.stringify(jsonData),
            ContentType: "application/json",
            CacheControl: "no-cache, no-store, must-revalidate",
        });

        await s3Client.send(command);
        logMessage(`✅ JSON Upload successful: ${objectKey}`);

        const uploadUrl = `${process.env.R2_ENDPOINT}/${process.env.R2_BUCKET_NAME}/${objectKey}`;

        return {
            success: true,
            key: objectKey,
            url: uploadUrl,
        };
    } catch (error) {
        const errorMsg = `❌ R2 JSON Upload Error: ${error.message}`;
        if (logger) {
            logger.error(errorMsg);
        } else {
            console.error(errorMsg);
        }
        throw error;
    }
}

module.exports = { uploadToR2, uploadJsonToR2 };

