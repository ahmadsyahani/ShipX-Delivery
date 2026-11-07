import { test, expect } from '@playwright/test';

test('depot map uses device permission on request and allows map fallback', async ({ page, context }) => {
  await page.route('https://tile.openstreetmap.org/**', route => route.abort());
  const first = await page.goto('/admin/login');
  expect(first?.headers()['x-shipx-qa']).toBe('isolated-checkout');
  await page.getByLabel('Email', { exact: true }).fill('trips-admin-ui@example.test');
  await page.getByLabel('Kata sandi', { exact: true }).fill('ShipX-QA-Admin-2026!');
  await page.getByRole('button', { name: 'Masuk', exact: true }).click();
  await expect(page).toHaveURL(/\/admin$/);
  await page.addInitScript(() => {
    Object.defineProperty(navigator.geolocation, 'getCurrentPosition', {
      configurable: true,
      value: (_success: unknown, error: (reason: { code: number }) => void) => error({ code: 1 }),
    });
  });
  await page.goto('/admin/depot');
  await expect(page.getByLabel('Latitude (lintang)')).toHaveCount(0);
  await expect(page.getByLabel('Longitude (bujur)')).toHaveCount(0);
  await expect(page.getByRole('alert')).toHaveCount(0);
  await page.getByRole('button', { name: 'Gunakan lokasi perangkat', exact: true }).click();
  await expect(page.getByRole('alert')).toContainText('Periksa izin lokasi');
  await page.getByRole('button', { name: 'Gunakan titik tengah peta', exact: true }).click();
  await expect(page.getByRole('alert')).toHaveCount(0);
  for (const width of [1440, 390, 320]) {
    await page.setViewportSize({ width, height: 844 });
    await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    await page.screenshot({ path: `test-results/depot-map-${width}.png`, fullPage: true });
  }
  // This scenario intentionally does not save the depot or request real location.
  await context.clearPermissions();
});
