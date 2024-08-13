import { CronJob } from "cron";
import { backup } from "./backup";
import { env } from "./env";

const startBackup = async () => {
  if (env.RUN_ON_STARTUP) {
    console.log("Running on start backup...");

    await backup();

    console.log("Database backup completed.");
  }

  const job = new CronJob(env.BACKUP_CRON_SCHEDULE, async () => {
    try {
      await backup();
    } catch (error) {
      console.error("Error while creating backup: ", error);
    }
  });

  job.start();

  console.log("Backup cron scheduler started.");
};

startBackup().catch((error) => {
  console.error("Failed to start backup process: ", error);
});