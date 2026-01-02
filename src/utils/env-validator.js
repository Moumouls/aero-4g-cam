require("dotenv").config();

const REQUIRED_VARS = {
    R2_ACCOUNT_ID: "Cloudflare R2 Account ID",
    R2_ACCESS_KEY_ID: "R2 Access Key ID",
    R2_SECRET_ACCESS_KEY: "R2 Secret Access Key",
    R2_BUCKET_NAME: "R2 Bucket Name",
    R2_ENDPOINT: "R2 Endpoint URL",
    UBOX_EMAIL: "UBox Email",
    UBOX_PASSWORD: "UBox Password",
};

const OPTIONAL_VARS = {
    RECORDING_DURATION: "30000",
    SCREEN_ORIENTATION: "LANDSCAPE",
};

class EnvironmentValidator {
    constructor() {
        this.errors = [];
        this.warnings = [];
    }

    validate() {
        const isVerbose = process.env.VERBOSE === "true" || process.env.VERBOSE === "1";

        if (isVerbose) {
            console.log("🔍 Validating environment variables...\n");
        }

        this.checkRequiredVars();
        this.checkOptionalVars();
        this.checkPathsExist();

        if (this.errors.length > 0) {
            console.error("❌ Validation failed with errors:");
            this.errors.forEach((err) => console.error(`  - ${err}`));
            return false;
        }

        if (this.warnings.length > 0 && isVerbose) {
            console.warn("⚠️  Warnings:");
            this.warnings.forEach((warn) => console.warn(`  - ${warn}`));
        }

        if (isVerbose) {
            console.log("✅ Environment validation passed!\n");
        }
        return true;
    }

    checkRequiredVars() {
        Object.entries(REQUIRED_VARS).forEach(([key, description]) => {
            if (!process.env[key]) {
                this.errors.push(`Missing required variable: ${key} (${description})`);
            } else if (process.env[key].includes("your_")) {
                this.errors.push(`${key} appears to be unconfigured (contains "your_")`);
            }
        });
    }

    checkOptionalVars() {
        const isVerbose = process.env.VERBOSE === "true" || process.env.VERBOSE === "1";

        Object.entries(OPTIONAL_VARS).forEach(([key, defaultValue]) => {
            if (!process.env[key]) {
                if (isVerbose) {
                    console.log(`  ℹ️  ${key} not set, using default: ${defaultValue}`);
                }
                process.env[key] = defaultValue;
            }
        });

        // Validate recording duration is a number
        const duration = parseInt(process.env.RECORDING_DURATION);
        if (isNaN(duration) || duration <= 0) {
            this.errors.push(
                `RECORDING_DURATION must be a positive number, got: ${process.env.RECORDING_DURATION}`
            );
        }
    }

    checkPathsExist() {
        const fs = require("fs");
        const splitApksDir = "./split-apks";

        if (!fs.existsSync(splitApksDir)) {
            this.errors.push(
                `Split APKs directory not found at ${splitApksDir}. Please run setup.sh to extract the XAPK`
            );
        } else {
            const apkFiles = fs.readdirSync(splitApksDir).filter(f => f.endsWith('.apk'));
            if (apkFiles.length === 0) {
                this.errors.push(
                    `No APK files found in ${splitApksDir}. Please run setup.sh to extract the XAPK`
                );
            }
        }
    }

    printConfig() {
        const isVerbose = process.env.VERBOSE === "true" || process.env.VERBOSE === "1";

        if (isVerbose) {
            console.log("📋 Current Configuration:");
            console.log("  R2 Endpoint:", process.env.R2_ENDPOINT?.substring(0, 50) + "...");
            console.log("  R2 Bucket:", process.env.R2_BUCKET_NAME);
            console.log("  App Package: cn.ubia.ubox (pre-installed from split APKs)");
            console.log("  Recording Duration:", `${process.env.RECORDING_DURATION}ms`);
            console.log("  Screen Orientation:", process.env.SCREEN_ORIENTATION);
            console.log("");
        }
    }
}

// Export for use in other modules
module.exports = { EnvironmentValidator, REQUIRED_VARS, OPTIONAL_VARS };

// Run validation if called directly
if (require.main === module) {
    const validator = new EnvironmentValidator();
    const isValid = validator.validate();
    if (isValid) {
        validator.printConfig();
    }
    process.exit(isValid ? 0 : 1);
}

