import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';

test('trip schedule groups filter orders, preserve customer services and clear previous selection', async ({ page }) => {
  const response = await page.goto('/admin/login');
  expect(response?.headers()['x-shipx-qa']).toBe('isolated-checkout');
  await page.getByLabel('Email', { exact: true }).fill('trips-admin-ui@example.test');
  await page.getByLabel('Kata sandi', { exact: true }).fill('ShipX-QA-Admin-2026!');
  await page.getByRole('button', { name: 'Masuk', exact: true }).click();
  await expect(page).toHaveURL(/\/admin$/);
  await page.goto('/admin/slots');
  await page.getByRole('button', { name: 'Siapkan jadwal 14 hari', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('slot untuk 14 hari');
  const registered = await page.request.post('/api/v1/auth/register', { data: {
    name: 'QA Trip Schedule', email: `trip-group-${Date.now()}@example.test`, phone: '080000000000',
    password: 'ShipX-QA-Customer-2026!', password_confirmation: 'ShipX-QA-Customer-2026!', device_name: 'Trip Schedule QA',
  }});
  expect(registered.status()).toBe(201);
  const headers = { Authorization: `Bearer ${(await registered.json()).data.token}`, Accept: 'application/json' };
  const settings = (await (await page.request.get('/api/v1/delivery-settings', { headers })).json()).data;
  const date = new Date(`${settings.today}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 3);
  const address = await page.request.post('/api/v1/addresses', { headers, data: {
    label: 'Rumah QA', recipient_name: 'Penerima Express QA', phone: '080000000000', address_text: 'Alamat QA kelompok Express', latitude: -7.25, longitude: 112.75,
  }});
  expect(address.status()).toBe(201);
  const addressId = (await address.json()).data.id;
  const slots = (await (await page.request.get(`/api/v1/delivery-slots?date=${date.toISOString().slice(0, 10)}&address_id=${addressId}&delivery_type=express`, { headers })).json()).data;
  expect(slots.length).toBeGreaterThan(0);
  const products = (await (await page.request.get('/api/v1/catalog?q=QA%20Air', { headers })).json()).data;
  const created = await page.request.post('/api/v1/orders', { headers: { ...headers, 'Idempotency-Key': randomUUID() }, data: {
    address_id: addressId, delivery_slot_id: slots[0].id, delivery_type: 'express', items: [{ product_id: products[0].id, quantity: 1 }], expected_total_rp: 19500,
  }});
  expect(created.status()).toBe(201);
  const order = (await created.json()).data;
  await page.goto(`/admin/orders/${order.id}`);
  await page.getByRole('button', { name: 'Konfirmasi pesanan', exact: true }).click();
  await page.getByRole('button', { name: 'Ya, konfirmasi pesanan', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('Pesanan dikonfirmasi');
  await page.goto('/admin/trips/create');
  const props = JSON.parse((await page.locator('#app').getAttribute('data-page'))!).props;
  const regularOrder = props.orders.find((candidate: { address_text: string }) => candidate.address_text === 'Alamat QA khusus trip');
  const regularGroup = props.deliveryGroups.find((group: { delivery_slot_id: number }) => group.delivery_slot_id === regularOrder.delivery_slot_id);
  const expressGroup = props.deliveryGroups.find((group: { delivery_slot_id: number }) => String(group.delivery_slot_id) === String(slots[0].id));
  const selector = page.getByLabel('Jadwal pengantaran', { exact: true });
  await expect(page.getByRole('checkbox')).toHaveCount(0);
  await selector.selectOption(regularGroup.key);
  await expect(page.getByRole('checkbox')).toHaveCount(2);
  await page.getByRole('checkbox').first().check();
  await selector.selectOption(expressGroup.key);
  await expect(page.getByRole('checkbox')).toHaveCount(1);
  await expect(page.getByRole('checkbox')).not.toBeChecked();
  await expect(page.getByText('Express 1', { exact: true })).toBeVisible();
  await expect(page.getByText('Reguler 0', { exact: true })).toBeVisible();
  await expect(page.getByLabel('Tanggal berangkat kurir', { exact: true })).toHaveValue(expressGroup.service_date);
  await expect(page.getByLabel('Waktu berangkat kurir', { exact: true })).toHaveValue(expressGroup.default_departure_local.slice(11));
  for (const width of [1440, 390, 320]) {
    await page.setViewportSize({ width, height: 1000 });
    await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    await page.screenshot({ path: `test-results/trip-customer-schedule-${width}.png`, fullPage: true });
  }
  const unchanged = (await (await page.request.get(`/api/v1/orders/${order.id}`, { headers })).json()).data;
  expect(unchanged.delivery_type).toBe('express');
  expect(unchanged.window_start_at).toBe(order.window_start_at);
  expect(unchanged.window_end_at).toBe(order.window_end_at);
});
