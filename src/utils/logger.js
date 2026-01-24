const fs = require("fs");
const path = require("path");

class Logger {
    constructor(logDir = ".logs") {
        this.logDir = logDir;
        this.logFile = path.join(logDir, `run-${Date.now()}.log`);
        this.startTime = Date.now();

        // Create logs directory if it doesn't exist
        if (!fs.existsSync(logDir)) {
            fs.mkdirSync(logDir, { recursive: true });
        }

        this.log("═".repeat(60));
        this.log(`Automation started: ${new Date().toISOString()}`);
        this.log("═".repeat(60));
    }

    log(message, level = "INFO") {
        const timestamp = new Date().toISOString();
        const levelStr = level.padEnd(5);
        const formattedMessage = `[${timestamp}] [${levelStr}] ${message}`;

        // Console output - only show errors unless VERBOSE is enabled
        const isVerbose = process.env.VERBOSE === "true" || process.env.VERBOSE === "1";

        switch (level) {
            case "ERROR":
                console.error(formattedMessage);
                break;
            case "WARN":
                if (isVerbose) {
                    console.warn(formattedMessage);
                }
                break;
            case "DEBUG":
                if (process.env.DEBUG === "true" || process.env.DEBUG === "1") {
                    console.debug(formattedMessage);
                }
                break;
            default:
                if (isVerbose) {
                    console.log(formattedMessage);
                }
        }

        // File output - always write everything to file
        try {
            fs.appendFileSync(this.logFile, formattedMessage + "\n");
        } catch (e) {
            console.error("Failed to write to log file:", e.message);
        }
    }

    info(message) {
        this.log(message, "INFO");
    }

    warn(message) {
        this.log(message, "WARN");
    }

    error(message) {
        this.log(message, "ERROR");
    }

    debug(message) {
        this.log(message, "DEBUG");
    }

    section(title) {
        this.log("─".repeat(60), "INFO");
        this.log(`📌 ${title}`, "INFO");
        this.log("─".repeat(60), "INFO");
    }

    success(message) {
        this.log(`✅ ${message}`, "INFO");
    }

    fail(message) {
        this.log(`❌ ${message}`, "ERROR");
    }

    progress(current, total, label = "Progress") {
        const percent = Math.round((current / total) * 100);
        const filled = Math.round(percent / 5);
        const empty = 20 - filled;
        const bar = "█".repeat(filled) + "░".repeat(empty);
        this.log(`${label}: [${bar}] ${percent}% (${current}/${total})`);
    }

    duration() {
        const elapsed = Date.now() - this.startTime;
        const seconds = Math.floor(elapsed / 1000);
        const minutes = Math.floor(seconds / 60);
        return `${minutes}m ${seconds % 60}s`;
    }

    finish() {
        this.log("─".repeat(60));
        this.log(`Automation finished: ${new Date().toISOString()}`);
        this.log(`Total duration: ${this.duration()}`);
        this.log("═".repeat(60));
        // Always show log file location, even in non-verbose mode
        console.log(`📋 Full log available at: ${this.logFile}`);
    }

    getLogPath() {
        return this.logFile;
    }
}

module.exports = { Logger };

