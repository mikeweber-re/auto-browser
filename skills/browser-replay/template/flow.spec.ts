// Replay: __FLOW__
// __DESCRIPTION__
// Key: __KEY__
//
//   auto-browser run <this dir>
import { test, expect } from '@playwright/test';
import { execFileSync } from 'node:child_process';

const RUN_ID = process.env.RUN_ID ?? String(Date.now());

// Session cookies from the project's login script (auto-browser.json scripts.login).
// Delete this and the "log in" step if the app has no login.
const loginCookies = (email?: string): { name: string; value: string }[] =>
  JSON.parse(
    execFileSync(process.env.AUTO_BROWSER_CLI ?? 'auto-browser', ['login', ...(email ? [email] : [])], {
      encoding: 'utf8',
    }),
  );

test('__FLOW__', async ({ page, context, baseURL }) => {
  await test.step('log in', async () => {
    await context.addCookies(loginCookies().map((c) => ({ ...c, url: baseURL! })));
  });

  await test.step('open __START_PATH__', async () => {
    await page.goto('__START_PATH__');
  });

  // One test.step per user-visible action. getByRole / getByLabel / getByTestId only.
  // await test.step('fill the form', async () => {
  //   await page.getByLabel('Email').fill(`test+${RUN_ID}@example.com`);
  //   await page.getByRole('button', { name: 'Save' }).click();
  //   await expect(page.getByText('Saved')).toBeVisible();
  //   await page.screenshot({ path: `${process.env.REPLAY_DIR}/last-run/saved.png` });
  // });
});
