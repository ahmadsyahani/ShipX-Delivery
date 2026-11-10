import { test, expect, type Page } from '@playwright/test';
import { randomUUID } from 'node:crypto';

async function login(page: Page) {
  const response = await page.goto('/admin/login');
  // Refuse every mutation unless served by our disposable QA router.
  expect(response?.headers()['x-shipx-qa']).toBe('isolated-checkout');
  await page.getByLabel('Email', { exact: true }).fill('admin-ui@example.test');
  await page.getByLabel('Kata sandi', { exact: true }).fill('ShipX-QA-Admin-2026!');
  await page.getByRole('button', { name: 'Masuk', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Selamat bekerja, QA.' })).toBeVisible();
  expect(await page.evaluate(async () => (await document.fonts.load('500 16px "Plus Jakarta Sans"')).length)).toBeGreaterThan(0);
}

test('admin React: auth, SPA navigation, products, validation, conflict, stock, depot, slots and orders', async ({ page, context }) => {
  const runtimeErrors: string[] = [];
  page.on('pageerror', error => runtimeErrors.push(error.message));
  const first = await page.goto('/admin/login');
  expect(first?.headers()['x-shipx-qa']).toBe('isolated-checkout');
  await page.getByLabel('Email', { exact: true }).fill('admin-ui@example.test');
  await page.getByLabel('Kata sandi', { exact: true }).fill('wrong-password');
  await page.getByRole('button', { name: 'Masuk', exact: true }).click();
  await expect(page.getByRole('alert')).toContainText('Email atau kata sandi tidak sesuai');
  await expect(page.getByLabel('Email', { exact: true })).toHaveValue('admin-ui@example.test');
  await expect(page.getByLabel('Kata sandi', { exact: true })).toHaveValue('');
  await login(page);
  await page.screenshot({ path: 'test-results/admin-dashboard-desktop.png', fullPage: true });
  await page.evaluate(() => { (window as Window & { shipxNavCheck?: string }).shipxNavCheck = 'inertia'; });
  await page.getByRole('navigation', { name: 'Navigasi utama' }).getByRole('link', { name: 'Produk', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Produk', exact: true })).toBeVisible();
  expect(await page.evaluate(() => (window as Window & { shipxNavCheck?: string }).shipxNavCheck)).toBe('inertia');
  await page.getByRole('link', { name: 'Tambah produk', exact: true }).click();
  const sku = `UI-${Date.now()}`;
  for (const [label, value] of Object.entries({ 'Nama produk': 'Produk uji React', 'Kode SKU': sku, 'Harga per satuan (Rp)': '15000', 'Berat satu item (kg)': '1', 'Panjang kemasan (cm)': '10', 'Lebar kemasan (cm)': '10', 'Tinggi kemasan (cm)': '10' })) {
    await page.getByLabel(label, { exact: true }).fill(value);
  }
  await page.getByLabel('Kategori', { exact: true }).selectOption('new');
  await page.getByLabel('Nama kategori baru', { exact: true }).fill('Pengujian');
  await page.getByRole('switch', { name: 'Produk aktif' }).click();
  const savedPackaging = page.waitForRequest(request => request.method() === 'POST' && new URL(request.url()).pathname === '/admin/products');
  await page.getByRole('button', { name: 'Simpan produk', exact: true }).click();
  const packagingBody = (await savedPackaging).postDataJSON();
  expect(String(packagingBody.shipping_weight_g)).toBe('1000');
  expect(String(packagingBody.length_mm)).toBe('100');
  expect(packagingBody.unit_label).toBe('item');
  await expect(page.getByRole('status')).toContainText('Produk ditambahkan');
  await page.getByRole('link', { name: 'Edit Produk uji React', exact: true }).click();
  await expect(page).toHaveURL(/\/admin\/products\/\d+\/edit$/);
  const editUrl = page.url();
  const staleTab = await context.newPage();
  await staleTab.goto(editUrl);
  await page.getByLabel('Harga per satuan (Rp)', { exact: true }).fill('16000');
  await page.getByRole('button', { name: 'Simpan perubahan', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('Perubahan produk disimpan');
  await staleTab.getByLabel('Harga per satuan (Rp)', { exact: true }).fill('17000');
  await staleTab.getByRole('button', { name: 'Simpan perubahan', exact: true }).click();
  await expect(staleTab.getByRole('heading', { name: 'Perubahan belum disimpan' })).toBeVisible();
  await staleTab.getByRole('link', { name: 'Muat data terbaru' }).click();
  await expect(staleTab.getByLabel('Harga per satuan (Rp)', { exact: true })).toHaveValue('16000');
  await staleTab.close();

  // Server validation retains all input on the React form.
  await page.goto(editUrl);
  await page.getByLabel('Kode SKU', { exact: true }).fill('QA-0');
  await page.getByRole('button', { name: 'Simpan perubahan', exact: true }).click();
  await expect(page.getByRole('alert')).toBeVisible();
  await expect(page.getByLabel('Nama produk', { exact: true })).toHaveValue('Produk uji React');
  await page.getByLabel('Kode SKU', { exact: true }).fill(sku);
  await page.getByRole('button', { name: 'Simpan perubahan', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Produk', exact: true })).toBeVisible();

  await page.getByRole('navigation', { name: 'Navigasi utama' }).getByRole('link', { name: 'Stok', exact: true }).click();
  await page.getByRole('row').filter({ hasText: 'Produk uji React' }).getByRole('link', { name: 'Catat mutasi' }).click();
  for (const [delta, expected] of [['3', '3'], ['2', '5']]) {
    await page.getByLabel('Perubahan jumlah (item)', { exact: true }).fill(delta);
    await page.getByLabel('Alasan perubahan', { exact: true }).fill(`QA React stock ${delta}`);
    await page.getByRole('button', { name: 'Catat mutasi', exact: true }).click();
    await expect(page.getByText('Fisik tersedia', { exact: true }).locator('..').getByText(expected, { exact: true })).toBeVisible();
    await expect(page.getByLabel('Perubahan jumlah (item)', { exact: true })).toHaveValue('');
  }
  await page.screenshot({ path: 'test-results/admin-stock-desktop.png', fullPage: true });

  await page.getByRole('navigation', { name: 'Navigasi utama' }).getByRole('link', { name: 'Depot', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Konfigurasi depot' })).toBeVisible();
  await context.grantPermissions(['geolocation']);
  await context.setGeolocation({ latitude: -7.25, longitude: 112.75 });
  await page.getByRole('button', { name: 'Gunakan lokasi perangkat', exact: true }).click();
  await expect(page.getByRole('status').filter({hasText:'Titik depot sudah dipilih'})).toBeVisible();
  await expect(page.getByLabel('Latitude (lintang)')).toHaveCount(0);
  await expect(page.getByLabel('Zona waktu')).toBeDisabled();
  // Same-page saves must adopt the updated lock_version.
  for (const fee of ['4000', '3000']) {
    await page.getByLabel('Ongkir tetap per order (Rp)').fill(fee);
    await page.getByRole('button', { name: 'Simpan depot' }).click();
    await expect(page.getByRole('status').filter({hasText: 'Konfigurasi depot disimpan'})).toBeVisible();
    await expect(page.getByLabel('Ongkir tetap per order (Rp)')).toHaveValue(fee);
    await page.getByRole('status').filter({hasText: 'Konfigurasi depot disimpan'}).waitFor();
  }
  await page.getByRole('navigation', { name: 'Navigasi utama' }).getByRole('link', { name: 'Slot pengiriman', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Slot pengiriman', exact: true })).toBeVisible();
  const firstEdit = page.getByRole('link', { name: /^Edit slot/ }).first();
  await firstEdit.click();
  await expect(page.getByLabel('Mulai antar')).not.toHaveValue('');
  await expect(page.getByLabel('Batas pemesanan')).not.toHaveValue('');

  // Synthetic customer/order through the unchanged mobile API, on QA only.
  const register = await page.request.post('/api/v1/auth/register', { data: { name: 'QA Browser Customer', email: `browser-${Date.now()}@example.test`, phone: '080000000000', password: 'ShipX-QA-Customer-2026!', password_confirmation: 'ShipX-QA-Customer-2026!', device_name: 'Browser QA' } });
  expect(register.status()).toBe(201);
  const identity = (await register.json()).data;
  const headers = { Authorization: `Bearer ${identity.token}`, Accept: 'application/json' };
  const settings = (await (await page.request.get('/api/v1/delivery-settings', { headers })).json()).data;
  const slots = (await (await page.request.get(`/api/v1/delivery-slots?date=${settings.today}`, { headers })).json()).data;
  const addressResponse = await page.request.post('/api/v1/addresses', { headers, data: { label: 'Rumah QA', recipient_name: 'Penerima QA', phone: '080000000000', address_text: 'Alamat QA browser', latitude: -7.25, longitude: 112.75 } });
  expect(addressResponse.status()).toBe(201);
  const address = (await addressResponse.json()).data;
  const catalog = (await (await page.request.get('/api/v1/catalog?q=QA%20Air', { headers })).json()).data;
  const orderResponse = await page.request.post('/api/v1/orders', { headers: { ...headers, 'Idempotency-Key': randomUUID() }, data: { address_id: address.id, delivery_slot_id: slots[0].id, items: [{ product_id: catalog[0].id, quantity: 1 }], expected_total_rp: 18000 } });
  expect(orderResponse.status()).toBe(201);
  const order = (await orderResponse.json()).data;
  await page.getByRole('navigation', { name: 'Navigasi utama' }).getByRole('link', { name: 'Pesanan', exact: true }).click();
  await page.getByRole('link', { name: order.order_number, exact: true }).click();
  await expect(page.getByText('Alamat QA browser', { exact: true })).toBeVisible();
  await expect(page.getByText('Rp18.000', { exact: true })).toBeVisible();
  await page.screenshot({ path: 'test-results/admin-order-desktop.png', fullPage: true });
  await page.reload();
  await expect(page.getByRole('heading', { name: order.order_number })).toBeVisible();
  const oldDecision = await context.newPage();
  await oldDecision.goto(page.url());
  await expect(oldDecision.getByRole('button', { name: 'Tolak pesanan', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Konfirmasi pesanan', exact: true }).click();
  await expect(page.getByRole('alertdialog')).toBeVisible();
  await page.getByRole('button', { name: 'Ya, konfirmasi pesanan' }).click();
  await expect(page.getByRole('status')).toContainText('Pesanan dikonfirmasi');
  await expect(page.getByText('Dikonfirmasi', { exact: true })).toBeVisible();
  await expect(page.getByText(/Dikonfirmasi oleh QA Admin/)).toBeVisible();
  expect((await (await page.request.get(`/api/v1/orders/${order.id}`, { headers })).json()).data.status).toBe('confirmed');
  expect((await (await page.request.get('/api/v1/catalog?q=QA%20Air', { headers })).json()).data[0].available_quantity).toBe(4);
  await oldDecision.getByRole('button', { name: 'Tolak pesanan', exact: true }).click();
  await oldDecision.getByLabel('Alasan penolakan').fill('Keputusan dari tab lama');
  await oldDecision.getByRole('button', { name: 'Ya, tolak pesanan' }).click();
  await expect(oldDecision.getByRole('heading', { name: 'Perubahan belum disimpan' })).toBeVisible();
  await oldDecision.close();
  await page.screenshot({ path: 'test-results/admin-order-confirmed.png', fullPage: true });
  const another = await page.request.post('/api/v1/orders', { headers: { ...headers, 'Idempotency-Key': randomUUID() }, data: { address_id: address.id, delivery_slot_id: slots[0].id, items: [{ product_id: catalog[0].id, quantity: 1 }], expected_total_rp: 18000 } });
  expect(another.status()).toBe(201);
  const rejectedOrder = (await another.json()).data;
  await page.goto(`/admin/orders/${rejectedOrder.id}`);
  await page.getByRole('button', { name: 'Tolak pesanan', exact: true }).click();
  await page.getByRole('button', { name: 'Ya, tolak pesanan' }).click();
  await expect(page.getByRole('alertdialog')).toBeVisible();
  await page.getByLabel('Alasan penolakan').fill('Slot tidak dapat dilayani');
  await page.getByRole('button', { name: 'Ya, tolak pesanan' }).click();
  await expect(page.getByRole('status')).toContainText('Pesanan ditolak');
  await expect(page.getByText('Ditolak', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Konfirmasi pesanan', exact: true })).toHaveCount(0);
  const customerView = (await (await page.request.get(`/api/v1/orders/${rejectedOrder.id}`, { headers })).json()).data;
  expect(customerView.status).toBe('rejected');
  expect(customerView.status_reason).toBe('Slot tidak dapat dilayani');
  expect(customerView.decision).toBeUndefined();
  expect((await (await page.request.get('/api/v1/catalog?q=QA%20Air', { headers })).json()).data[0].available_quantity).toBe(4);
  await page.screenshot({ path: 'test-results/admin-order-rejected.png', fullPage: true });
  await page.getByRole('button', { name: 'Menu akun' }).click();
  await page.getByRole('menuitem', { name: 'Keluar' }).click();
  await expect(page.getByRole('heading', { name: 'Masuk ke ruang kerja' })).toBeVisible();
  await page.goto('/admin/products');
  await expect(page).toHaveURL(/\/admin\/login$/);
  expect(runtimeErrors).toEqual([]);
});

test('mobile admin: accessible navigation, table containment and direct refresh', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await login(page);
  await page.getByRole('button', { name: 'Buka navigasi' }).click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.getByRole('dialog').getByRole('link', { name: 'Produk', exact: true }).click();
  await expect(page.getByRole('dialog')).not.toBeVisible();
  await expect(page.getByRole('heading', { name: 'Produk', exact: true })).toBeVisible();
  await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  await page.screenshot({ path: 'test-results/admin-products-mobile.png', fullPage: true });
  await page.reload();
  await expect(page.getByRole('heading', { name: 'Produk', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Buka navigasi' }).click();
  await page.getByRole('dialog').getByRole('link', { name: 'Pesanan', exact: true }).click();
  await page.getByRole('link', { name: /^SX-/ }).first().click();
  await expect(page.getByRole('heading', { name: /^SX-/ })).toBeVisible();
  await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  await page.screenshot({ path: 'test-results/admin-order-mobile.png', fullPage: true });
});
