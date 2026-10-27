// Smoke replay: drives a local file page, no app and no login needed.
import { test, expect } from '@playwright/test';
import { pathToFileURL } from 'node:url';

const PAGE = pathToFileURL(process.env.SMOKE_PAGE!).href;

test('smoke', async ({ page }) => {
  await test.step('open the page', async () => {
    await page.goto(PAGE);
    await expect(page.getByRole('heading', { name: 'Smoke page' })).toBeVisible();
  });

  await test.step('greet', async () => {
    await page.getByLabel('Name').fill('tester');
    await page.getByRole('button', { name: 'Greet' }).click();
    await expect(page.getByTestId('greeting')).toHaveText('Hello, tester');
    await page.screenshot({ path: `${process.env.REPLAY_DIR}/last-run/greeted.png` });
  });
});
