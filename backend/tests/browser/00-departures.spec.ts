import {test,expect,type Page} from '@playwright/test';
import {randomUUID} from 'node:crypto';

// This preassigned fixture must run before admin.spec mutates depot versions.
// Production correctly requires replanning when that master changes.

test('departure: manual road review, stale admin, exact SKU load, replay and locked in-progress trip',async({page,context})=>{
  const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
  const guard=await page.goto('/admin/login');expect(guard?.headers()['x-shipx-qa']).toBe('isolated-checkout');
  await page.getByLabel('Email',{exact:true}).fill('departures-admin-ui@example.test');
  await page.getByLabel('Kata sandi',{exact:true}).fill('ShipX-QA-Admin-2026!');
  await page.getByRole('button',{name:'Masuk',exact:true}).click();await expect(page).toHaveURL(/\/admin$/);
  await page.goto('/admin/trips');
  const props=JSON.parse((await page.locator('#app').getAttribute('data-page'))!).props;
  const trip=props.trips.data.find((t:{selected_route:{input_snapshot:{vehicle:{code:string}}}})=>t.selected_route.input_snapshot.vehicle.code==='QA-DEPARTURE');
  expect(trip).toBeTruthy();const url=`/admin/trips/${trip.id}`;
  await page.goto(url);
  const auth=await page.request.post('/api/v1/auth/login',{data:{email:'departures-courier-ui@example.test',password:'ShipX-QA-Courier-2026!',device_name:'Departure QA'}});expect(auth.status()).toBe(200);
  const headers={Accept:'application/json',Authorization:`Bearer ${(await auth.json()).data.token}`};
  const api=()=>page.request.get(`/api/v1/courier/trips/${trip.id}`,{headers});
  expect((await (await api()).json()).data.can_start).toBe(false);
  async function fillReview(target:Page,minutes:string){
    for(let i=0;i<3;i++)await target.locator(`#leg-${i}`).fill(minutes);
    await target.getByLabel('Sumber estimasi jalan',{exact:true}).fill('Peta jalan QA, mode motor; estimasi manual diperiksa admin.');
    await target.getByLabel('Catatan tinjauan',{exact:true}).fill('Dimensi, bentuk barang dan jadwal sudah diperiksa.');
    await target.getByRole('checkbox',{name:/Saya sudah meninjau/}).check();
  }
  await fillReview(page,'1440');await page.getByRole('button',{name:'Simpan tinjauan keberangkatan'}).click();
  await expect(page.getByRole('heading',{name:'Perubahan belum disimpan'})).toBeVisible();
  await expect(page.getByText(/melewati akhir jendela/)).toBeVisible();
  await page.getByRole('link',{name:'Muat data terbaru'}).click();
  await expect(page).toHaveURL(new RegExp(`/admin/trips/${trip.id}$`));
  await expect(page.locator('#leg-0')).toBeVisible();
  const stale=await context.newPage();await stale.goto(page.url());await fillReview(stale,'5');
  await fillReview(page,'5');await page.getByRole('button',{name:'Simpan tinjauan keberangkatan'}).click();
  await expect(page.getByText('Estimasi jadwal manual',{exact:true})).toBeVisible();
  await stale.getByRole('button',{name:'Simpan tinjauan keberangkatan'}).click();await expect(stale.getByRole('heading',{name:'Perubahan belum disimpan'})).toBeVisible();await stale.close();
  await page.screenshot({path:'test-results/departure-review-desktop.png',fullPage:true});
  const ready=(await (await api()).json()).data;expect(ready.can_start).toBe(true);expect(ready.feasibility_status).toBe('feasible_manual');expect(ready.manifest.map((r:{quantity:number})=>r.quantity)).toEqual([4,2]);
  const payload={lock_version:ready.lock_version,route_version_id:ready.route_version_id,departure_review_id:ready.departure_review.id,manifest:ready.manifest.map((r:{product_id:string;quantity:number})=>({product_id:r.product_id,quantity:r.quantity}))};
  const bad=await page.request.post(`/api/v1/courier/trips/${trip.id}/start`,{headers:{...headers,'Idempotency-Key':randomUUID()},data:{...payload,manifest:[{...payload.manifest[0],quantity:3},payload.manifest[1]]}});expect(bad.status()).toBe(409);expect((await bad.json()).code).toBe('LOAD_MISMATCH');
  const customerAuth=await page.request.post('/api/v1/auth/login',{data:{email:'departures-customer-ui@example.test',password:'ShipX-QA-Customer-2026!',device_name:'Departure customer QA'}});expect(customerAuth.status()).toBe(200);
  const customerHeaders={Accept:'application/json',Authorization:`Bearer ${(await customerAuth.json()).data.token}`};
  const catalog=async()=> (await(await page.request.get('/api/v1/catalog?q=QA%20Muatan',{headers:customerHeaders})).json()).data;
  const available=(await catalog()).map((p:{available_quantity:number})=>p.available_quantity);
  const key=randomUUID();
  for(let i=0;i<2;i++){
    const result=await page.request.post(`/api/v1/courier/trips/${trip.id}/start`,{headers:{...headers,'Idempotency-Key':key},data:payload});expect(result.status()).toBe(200);expect((await result.json()).data.status).toBe('in_progress');
  }
  const started=(await(await api()).json()).data;expect(started.can_start).toBe(false);expect(started.loaded_weight_g).toBe(5000);expect(started.loaded_volume_cm3).toBe(6000);expect(started.actual_departure_at).toBeTruthy();
  expect((await catalog()).map((p:{available_quantity:number})=>p.available_quantity)).toEqual(available);
  const order=await page.request.get(`/api/v1/orders/${started.stops[0].order_id}`,{headers:customerHeaders});expect(order.status()).toBe(200);expect((await order.json()).data.status).toBe('out_for_delivery');
  await page.reload();await expect(page.getByText('Muatan sudah diberangkatkan',{exact:true})).toBeVisible();
  await expect(page.getByRole('button',{name:'Buka ulang trip',exact:true})).toHaveCount(0);await expect(page.getByRole('button',{name:'Batalkan trip',exact:true})).toHaveCount(0);
  await page.screenshot({path:'test-results/departure-started-desktop.png',fullPage:true});
  await page.setViewportSize({width:390,height:844});await expect.poll(()=>page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true);await page.screenshot({path:'test-results/departure-started-mobile.png',fullPage:true});
  await page.goto('/admin/trips?status=in_progress');await expect(page.getByRole('link',{name:new RegExp(trip.trip_number)})).toBeVisible();
  const image=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=','base64');
  const current=(await(await api()).json()).data;
  const first=current.stops[0];
  const upload=await page.request.post(`/api/v1/courier/trips/${trip.id}/stops/${first.id}/proofs`,{headers:{...headers,'Idempotency-Key':randomUUID()},multipart:{photo:{name:'proof.png',mimeType:'image/png',buffer:image}}});
  expect(upload.status()).toBe(201);
  const proofId=(await upload.json()).data.id;
  const resultBody={trip_version:current.lock_version,order_version:first.order_version,outcome:'delivered',cash_received_rp:first.total_rp,failure_reason:null,notes:'Barang diterima lengkap',proof_upload_id:proofId};
  const resultKey=randomUUID();
  for(let i=0;i<2;i++)expect((await page.request.post(`/api/v1/courier/trips/${trip.id}/stops/${first.id}/result`,{headers:{...headers,'Idempotency-Key':resultKey},data:resultBody})).status()).toBe(200);
  const delivered=(await(await page.request.get(`/api/v1/orders/${first.order_id}`,{headers:customerHeaders})).json()).data;
  expect(delivered.status).toBe('delivered');expect(delivered.payment_status).toBe('paid');expect(delivered.delivery_result.cash_received_rp).toBe(first.total_rp);
  expect((await page.request.get(`/api/v1/delivery-proofs/${delivered.delivery_result.proof_id}`,{headers:customerHeaders})).status()).toBe(200);
  const progress=(await(await api()).json()).data;
  const second=progress.stops[1];
  const failed=await page.request.post(`/api/v1/courier/trips/${trip.id}/stops/${second.id}/result`,{headers:{...headers,'Idempotency-Key':randomUUID()},data:{trip_version:progress.lock_version,order_version:second.order_version,outcome:'failed',cash_received_rp:0,failure_reason:'Penerima tidak ada di lokasi',notes:null,proof_upload_id:null}});
  expect(failed.status()).toBe(200);expect((await failed.json()).data.trip_status).toBe('awaiting_reconciliation');
  await page.goto(`/admin/orders/${first.order_id}`);await expect(page.getByText('Hasil pengiriman',{exact:true})).toBeVisible();await expect(page.getByRole('link',{name:'Lihat foto bukti'})).toBeVisible();
  await page.screenshot({path:'test-results/delivery-result-desktop.png',fullPage:true});
  await page.setViewportSize({width:390,height:844});await expect.poll(()=>page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true);await page.screenshot({path:'test-results/delivery-result-mobile.png',fullPage:true});
  await page.goto(`/admin/trips/${trip.id}`);await expect(page.getByText(/Menunggu rekonsiliasi/)).toBeVisible();
  expect(errors).toEqual([]);
});
