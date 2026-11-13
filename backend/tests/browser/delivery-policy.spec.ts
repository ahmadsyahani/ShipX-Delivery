import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';

test('delivery hours, automatic schedule and Express price reach the admin order', async ({ page }) => {
  const response = await page.goto('/admin/login');
  expect(response?.headers()['x-shipx-qa']).toBe('isolated-checkout');
  await page.getByLabel('Email', { exact: true }).fill('admin-ui@example.test');
  await page.getByLabel('Kata sandi', { exact: true }).fill('ShipX-QA-Admin-2026!');
  await page.getByRole('button', { name: 'Masuk', exact: true }).click();
  await expect(page).toHaveURL(/\/admin$/);
  await page.goto('/admin/depot');
  await expect(page.getByLabel('Tambahan setiap km berikutnya (Rp)', { exact: true })).toHaveValue('1000');
  await expect(page.getByLabel('Tambahan Express (%)', { exact: true })).toHaveValue('50');
  await page.goto('/admin/slots/create');
  for (const [date, start, end] of [
    ['2026-11-16', '08:00', '17:00'],
    ['2026-11-14', '09:00', '16:00'],
    ['2026-12-25', '09:00', '16:00'],
  ]) {
    await page.getByLabel('Tanggal pengiriman', { exact: true }).fill(date);
    await expect(page.getByLabel('Mulai antar', { exact: true })).toHaveValue(start);
    await expect(page.getByLabel('Selesai antar', { exact: true })).toHaveAttribute('max', end);
  }
  await page.setViewportSize({ width: 390, height: 844 });
  await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: 'test-results/delivery-policy-mobile.png', fullPage: true });
  await page.goto('/admin/slots');
  await page.getByRole('button', { name: 'Siapkan jadwal 14 hari', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('slot untuk 14 hari');

  const registered = await page.request.post('/api/v1/auth/register', { data: {
    name: 'QA Delivery Policy', email: `delivery-${Date.now()}@example.test`, phone: '080000000000',
    password: 'ShipX-QA-Customer-2026!', password_confirmation: 'ShipX-QA-Customer-2026!', device_name: 'Delivery QA',
  }});
  expect(registered.status()).toBe(201);
  const headers = { Authorization: `Bearer ${(await registered.json()).data.token}`, Accept: 'application/json' };
  const address = await page.request.post('/api/v1/addresses', { headers, data: {
    label: 'Rumah QA', recipient_name: 'Penerima QA', phone: '080000000000',
    address_text: 'Alamat QA delivery policy', latitude: -7.251, longitude: 112.751,
  }});
  expect(address.status()).toBe(201);
  const addressId = (await address.json()).data.id;
  const settings = (await (await page.request.get('/api/v1/delivery-settings', { headers })).json()).data;
  const tomorrow = new Date(`${settings.today}T12:00:00Z`);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  const slotsResponse = await page.request.get(`/api/v1/delivery-slots?date=${tomorrow.toISOString().slice(0, 10)}&address_id=${addressId}&delivery_type=express`, { headers });
  expect(slotsResponse.status()).toBe(200);
  const slots = await slotsResponse.json();
  expect(slots.data.length).toBeGreaterThan(0);
  expect(slots.delivery_options[1].delivery_fee_rp).toBe(4500);
  const products = (await (await page.request.get('/api/v1/catalog?q=QA%20Air', { headers })).json()).data;
  const payload = { address_id: addressId, delivery_slot_id: slots.data[0].id, delivery_type: 'express', items: [{ product_id: products[0].id, quantity: 1 }] };
  const quoted = await page.request.post('/api/v1/order-quotes', { headers, data: payload });
  expect(quoted.status()).toBe(200);
  const quote = (await quoted.json()).data;
  expect(quote.total_rp).toBe(19500);
  const created = await page.request.post('/api/v1/orders', { headers: { ...headers, 'Idempotency-Key': randomUUID() }, data: { ...payload, expected_total_rp: quote.total_rp } });
  expect(created.status()).toBe(201);
  const order = (await created.json()).data;
  expect(order.delivery_type).toBe('express');
  await page.goto(`/admin/orders/${order.id}`);
  await expect(page.getByText('Express · jadwal terdekat', { exact: false })).toBeVisible();
  await page.screenshot({ path: 'test-results/delivery-policy-express-order.png', fullPage: true });
});
