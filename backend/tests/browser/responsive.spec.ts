import { test, expect } from '@playwright/test';

test('local font and admin layout fit small phones, tablets and desktop', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 740 });
  const response = await page.goto('/admin/login');
  expect(response?.headers()['x-shipx-qa']).toBe('isolated-checkout');
  await page.screenshot({ path: 'test-results/ui-login-320.png', fullPage: true });
  await page.getByLabel('Email', { exact: true }).fill('trips-admin-ui@example.test');
  await page.getByLabel('Kata sandi', { exact: true }).fill('ShipX-QA-Admin-2026!');
  await page.getByRole('button', { name: 'Masuk', exact: true }).click();
  await expect(page).toHaveURL(/\/admin$/);
  expect(await page.evaluate(async () => (await document.fonts.load('500 16px "Plus Jakarta Sans"')).length)).toBeGreaterThan(0);
  for (const width of [320, 390, 820, 1440]) {
    await page.setViewportSize({ width, height: width === 1440 ? 1000 : 844 });
    for (const route of ['/admin', '/admin/products', '/admin/orders', '/admin/trips']) {
      await page.goto(route);
      await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    }
    await page.goto('/admin');
    await page.screenshot({ path: `test-results/ui-dashboard-${width}.png`, fullPage: true });
  }
});
