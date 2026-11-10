import { test, expect } from '@playwright/test';

test('admin uploads, replaces and removes a product photo', async ({ page }) => {
  const response = await page.goto('/admin/login');
  expect(response?.headers()['x-shipx-qa']).toBe('isolated-checkout');
  await page.getByLabel('Email', { exact: true }).fill('departures-admin-ui@example.test');
  await page.getByLabel('Kata sandi', { exact: true }).fill('ShipX-QA-Admin-2026!');
  await page.getByRole('button', { name: 'Masuk', exact: true }).click();
  await expect(page).toHaveURL(/\/admin$/);
  await page.goto('/admin/products/create');
  const productName = `Produk foto QA ${Date.now()}`;
  const photo = { name: 'produk.png', mimeType: 'image/png', buffer: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64') };
  await page.getByLabel('Pilih foto produk').setInputFiles(photo);
  await expect(page.getByAltText('Preview foto produk')).toHaveAttribute('src', /^blob:/);
  for (const [label, value] of Object.entries({ 'Nama produk': productName, 'Harga per satuan (Rp)': '15000', 'Berat satu item (kg)': '1', 'Panjang kemasan (cm)': '10', 'Lebar kemasan (cm)': '10', 'Tinggi kemasan (cm)': '10' })) {
    await page.getByLabel(label, { exact: true }).fill(value);
  }
  await page.getByLabel('Kategori', { exact: true }).selectOption({ label: 'Minuman' });
  await page.getByRole('button', { name: 'Simpan produk', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('Produk ditambahkan');
  await page.getByRole('link', { name: `Edit ${productName}`, exact: true }).click();
  await expect(page.getByLabel('Kode SKU', { exact: true })).toHaveValue(/^SHX-[0-9A-HJKMNP-TV-Z]{26}$/);
  await expect(page.getByLabel('Kategori', { exact: true })).toHaveValue('category:Minuman');
  const oldUrl = await page.getByAltText('Preview foto produk').getAttribute('src');
  expect(oldUrl).toMatch(/^\/product-photos\//);
  await expect.poll(() => page.getByAltText('Preview foto produk').evaluate((img: HTMLImageElement) => img.naturalWidth)).toBeGreaterThan(0);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.screenshot({ path: 'test-results/product-photo-mobile.png', fullPage: true });
  await page.getByLabel('Pilih foto produk').setInputFiles(photo);
  await page.getByRole('button', { name: 'Simpan perubahan', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('Perubahan produk disimpan');
  await page.getByRole('link', { name: `Edit ${productName}`, exact: true }).click();
  await expect(page.getByAltText('Preview foto produk')).not.toHaveAttribute('src', oldUrl!);
  expect((await page.request.get(oldUrl!)).status()).toBe(404);
  await page.getByRole('button', { name: 'Hapus foto', exact: true }).click();
  await expect(page.getByAltText('Preview foto produk')).toHaveCount(0);
  await page.getByRole('button', { name: 'Simpan perubahan', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('Perubahan produk disimpan');
  await page.getByRole('link', { name: `Edit ${productName}`, exact: true }).click();
  await expect(page.getByAltText('Preview foto produk')).toHaveCount(0);
});
