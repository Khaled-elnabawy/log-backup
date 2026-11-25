# Log Backup Automation

Automated, unattended backup of application logs using Bash and cron,
with secrets kept out of version control.

## Overview

Applications write logs every day, and left alone they fill the disk.
This project automates the cleanup: a Bash script archives the logs,
verifies the archive, removes old ones, and reports the result through a
webhook. Cron runs it on a fixed schedule, so no one has to be present.

## How it works

- **Backup script (`backup.sh`)**: compresses the log directory into a
  timestamped `tar.gz`, verifies it with `tar -tzf`, deletes archives older
  than 7 days, and logs every step to `backup.log`.
- **Reliability**: `set -euo pipefail` stops the script at the first failure,
  an `ERR` trap logs the failing line, and `flock` prevents overlapping runs.
- **Scheduling**: cron runs the script daily at 2 AM using absolute paths.
  Output and errors are captured in `cron.out`.
- **Notifications**: after each run, `curl` sends a success or failure
  message to a webhook.
- **Secrets**: all configuration, including the webhook URL, lives in `.env`,
  which is excluded by `.gitignore`. The script reads it as environment
  variables, and `.env.example` documents the required ones with
  placeholder values.

## Project structure

    log-backup/
    |-- backup.sh       the script
    |-- .env.example    configuration template (committed)
    |-- .env            real configuration (ignored by Git)
    |-- .gitignore
    `-- README.md

Source logs and backups live outside the repository, so it contains
code only.
