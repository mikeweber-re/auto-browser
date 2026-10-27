// Shared config for Playwright replays. `auto-browser run` sets REPLAY_DIR and BASE_URL.
//
// Browser: Playwright's bundled Chromium by default (`npm run setup:playwright`
// downloads it). Set AUTO_BROWSER_PW_CHANNEL=chrome to use the installed Google
// Chrome instead and skip the download. Either way each run gets a throwaway profile.
const dir = process.env.REPLAY_DIR;
const width = Number(process.env.WIDTH) || 1280;
const height = Number(process.env.HEIGHT) || (process.env.WIDTH ? 900 : 720);

module.exports = {
  testDir: dir,
  testMatch: 'flow.spec.ts',
  outputDir: `${dir}/last-run`,
  reporter: [['list'], ['json', { outputFile: `${dir}/last-run/report.json` }]],
  retries: 0,
  use: {
    baseURL: process.env.BASE_URL,
    channel: process.env.AUTO_BROWSER_PW_CHANNEL || undefined,
    headless: !process.env.AB_HEADED,
    viewport: { width, height },
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
};
