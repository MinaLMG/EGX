# EGX Platform: Automation Evolution & Trials

This document tracks the architectural decisions made to solve the "Real-time Market Data" challenge for the EGX platform.

## Trial 1: Local Node-Cron
- **Implementation:** Direct use of `node-cron` inside `app.js`.
- **Result:** **FAILED** (Deployment phase).
- **Lesson:** Vercel is a Serverless platform; it kills the process after the request ends. Background timers cannot survive in a serverless environment.

## Trial 2: Native Vercel Cron (`vercel.json`)
- **Implementation:** Using Vercel's built-in scheduler to hit `/api/cron` endpoints.
- **Result:** **INSUFFICIENT**.
- **Lesson:** Vercel Crons are limited in frequency (especially on the Pro/Hobby split) and have strict 60s–300s timeouts. Not suitable for a 5-hour continuous market loop.

## Trial 3: External Pinger (The "Trigger" Method)
- **Implementation:** Using `cron-job.org` or `Upstash` to hit Vercel API endpoints every minute.
- **Result:** **EFFICIENT BUT EXPENSIVE**.
- **Lesson:** This worked perfectly for data accuracy, but because the scraper is CPU-heavy (Puppeteer), it consumed the entire Vercel "Active CPU" monthly quota in a few days.

## Trial 4: GitHub Actions (Current State)
- **Implementation:** Running `runScraper.js` on a `.github/workflow` schedule.
- **Result:** **UNRELIABLE TIMING**.
- **Lesson:** GitHub Actions' shared runners are often delayed by 30–60 minutes. For a stock market that opens at 09:50, a script that starts at 10:30 is a failure.

## Trial 5: Render (REJECTED)
- **Status:** **ABANDONED**.
- **Reason:** Render's reliable services (Cron/Starter) require a Credit Card/Visa for verification, which was not suitable for this project.

## Trial 6: The "Hybrid Trigger" (Vercel + GitHub)
- **Status:** **ACTIVE / PROPOSED FINAL**.
- **Implementation:** 
    1. **Pinger:** `cron-job.org` hits a Vercel endpoint once/day at 09:40 Cairo.
    2. **Trigger:** Vercel (API) sends a `repository_dispatch` signal to GitHub.
    3. **Worker:** GitHub Actions runs the heavy 5-hour Puppeteer loop.
- **Optimization:** Implemented a persistent browser session across the 5-hour loop, reducing "Double Logins" and cutting cycle overhead by ~45 seconds.

## Trial 7: Full Hybrid Migration
- **Status:** **COMPLETED**.
- **Implementation:** 
    - Removed all heavy scraping logic from Vercel controllers.
    - Created a second dedicated workflow for daily fair-value scrapes (`daily-scrape.yml`).
    - Vercel is now purely an API and Trigger coordinator.
- **Key Strategy:** Complete decoupling of "Data Collection" (GitHub) from "Data Serving" (Vercel).
