import { test, expect } from '@playwright/test';

test('operations monitor, report filters, CSV and depot contact work responsively', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  const response = await page.goto('/admin/login');
  expect(response?.headers()['x-shipx-qa']).toBe('isolated-checkout');
  await page.getByLabel('Email', { exact: true }).fill('admin-ui@example.test');
  await page.getByLabel('Kata sandi', { exact: true }).fill('ShipX-QA-Admin-2026!');
  await page.getByRole('button', { name: 'Masuk', exact: true }).click();
  await expect(page).toHaveURL(/\/admin$/);
  await expect(page.getByText('Trip aktif', { exact: true })).toBeVisible();
  await page.goto('/admin/monitor');
  await expect(page.getByText('Belum ada trip aktif', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Perbarui monitor' })).toBeEnabled();
  for (const width of [1440, 390, 320]) {
    await page.setViewportSize({ width, height: 1000 });
    await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    await page.screenshot({ path: `test-results/monitor-${width}.png` });
  }
  await page.goto('/admin/trips/create');
  const props = JSON.parse((await page.locator('#app').getAttribute('data-page'))!).props;
  const orders = props.orders.filter((order: { address_text: string }) => order.address_text === 'Alamat QA khusus trip');
  const group = props.deliveryGroups.find((candidate: { delivery_slot_id: number }) => candidate.delivery_slot_id === orders[0].delivery_slot_id);
  await page.getByLabel('Jadwal pengantaran', { exact: true }).selectOption(group.key);
  await page.getByLabel('Kurir', { exact: true }).selectOption({ label: 'QA Kurir' });
  await page.getByLabel('Kendaraan', { exact: true }).selectOption({ label: 'QA-TRIP · B2026QA' });
  await page.locator('#departure_local').fill('09:00');
  for (const order of orders) await page.getByRole('checkbox', { name: new RegExp(order.order_number) }).check();
  await page.getByRole('button', { name: 'Simpan draft', exact: true }).click();
  await expect(page).toHaveURL(/\/admin\/trips\/\d+$/);
  await page.getByRole('button', { name: 'Tetapkan trip', exact: true }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Tetapkan trip', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Buka ulang trip', exact: true })).toBeVisible();
  await page.goto('/admin/monitor');
  await expect(page.getByText('QA Kurir', { exact: true })).toBeVisible();
  await expect(page.getByText('0 dari 2 tujuan ditangani', { exact: true })).toBeVisible();
  await page.screenshot({ path: 'test-results/monitor-assigned-320.png' });
  await page.goto('/admin/reports');
  await expect(page.getByRole('heading', { name: 'Laporan pengiriman' })).toBeVisible();
  const deliveryDate = orders[0].window_start_at.slice(0, 10);
  await page.getByLabel('Dari tanggal', { exact: true }).fill(deliveryDate);
  await page.getByLabel('Sampai tanggal', { exact: true }).fill(deliveryDate);
  await page.getByRole('button', { name: 'Tampilkan laporan', exact: true }).click();
  await expect(page.getByText(orders[0].order_number, { exact: true })).toBeVisible();
  const csvUrl = await page.getByRole('link', { name: 'Unduh CSV' }).getAttribute('href');
  const csv = await page.request.get(csvUrl!);
  expect(csv.status()).toBe(200);
  expect(await csv.text()).toContain('Total COD');
  for (const width of [1440, 390, 320]) {
    await page.setViewportSize({ width, height: 1000 });
    await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    await page.screenshot({ path: `test-results/reports-${width}.png` });
  }
  await page.goto('/admin/depot');
  await page.getByLabel('Telepon depot', { exact: true }).fill('+62 812 1234 5678');
  await page.getByRole('button', { name: 'Simpan depot', exact: true }).click();
  await page.reload();
  await expect(page.getByLabel('Telepon depot', { exact: true })).toHaveValue('+62 812 1234 5678');
  expect(errors).toEqual([]);
});
