<?php

namespace Tests\Feature;

use App\Models\DeliverySlot;
use App\Models\Depot;
use App\Models\User;
use App\Services\DeliveryArea;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia;
use Tests\TestCase;

class DeliveryTest extends TestCase
{
    use RefreshDatabase;

    private function settings(array $overrides = []): array
    {
        return array_replace(['name' => 'Depot uji', 'address_text' => 'Alamat depot uji', 'latitude' => -7.25, 'longitude' => 112.75, 'timezone' => 'Asia/Jakarta', 'service_radius_m' => 5000, 'delivery_fee_rp' => 3000, 'pending_ttl_minutes' => 30, 'default_service_seconds' => 300, 'lock_version' => 0], $overrides);
    }

    private function configure(array $overrides = []): Depot
    {
        $depot = Depot::findOrFail(1);
        $depot->fill(collect($this->settings($overrides))->except('lock_version')->all())->save();

        return $depot->refresh();
    }

    private function customer(): User
    {
        $user = User::factory()->create();
        $this->app['auth']->forgetGuards();
        $this->withToken($user->createToken('test')->plainTextToken);

        return $user;
    }

    private function address(array $overrides = []): array
    {
        return array_replace(['label' => 'Rumah', 'recipient_name' => 'Penerima', 'phone' => '081234567890', 'address_text' => 'Alamat lengkap uji', 'latitude' => -7.251, 'longitude' => 112.751, 'directions' => 'Pagar biru'], $overrides);
    }

    private function slot(array $overrides = []): array
    {
        return array_replace(['service_date' => '2026-11-05', 'start_time' => '10:00', 'end_time' => '12:00', 'cutoff_local' => '2026-11-05T09:00', 'is_active' => 1], $overrides);
    }

    public function test_depot_admin_form_validation_and_stale_update(): void
    {
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        $this->get('/admin/depot')->assertOk()->assertInertia(fn (AssertableInertia $page) => $page->component('Admin/Depot'));
        $this->put('/admin/depot', $this->settings(['latitude' => 91]))->assertSessionHasErrors('latitude');
        $this->put('/admin/depot', $this->settings(['timezone' => 'UTC']))->assertSessionHasErrors('timezone');
        $this->put('/admin/depot', $this->settings())->assertRedirect('/admin/depot');
        $this->assertDatabaseHas('depots', ['id' => 1, 'lock_version' => 1, 'delivery_fee_rp' => 3000]);
        $this->put('/admin/depot', $this->settings())->assertStatus(409);
    }

    public function test_unconfigured_depot_has_explicit_state_and_blocks_address_creation(): void
    {
        $this->customer();
        $this->getJson('/api/v1/delivery-settings')->assertOk()->assertJsonPath('data.configured', false)->assertJsonStructure(['data' => ['server_time', 'today', 'timezone']]);
        $this->postJson('/api/v1/addresses', $this->address())->assertStatus(409)->assertJsonPath('code', 'DELIVERY_NOT_CONFIGURED');
        $this->getJson('/api/v1/delivery-slots?date=2026-11-05')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_radius_boundary_and_zero_coordinates_are_supported(): void
    {
        $depot = $this->configure(['latitude' => 0, 'longitude' => 0, 'service_radius_m' => 1000]);
        $area = app(DeliveryArea::class);
        $this->assertTrue($area->contains($depot, 0, 0));
        $inside = rad2deg(999 / 6371008.8);
        $outside = rad2deg(1001 / 6371008.8);
        $this->assertTrue($area->contains($depot, $inside, 0));
        $this->assertFalse($area->contains($depot, $outside, 0));
        $this->assertEqualsWithDelta(999, $area->distance($depot, $inside, 0), 0.001);
    }

    public function test_customer_can_create_partial_update_and_soft_delete_own_address(): void
    {
        $this->configure();
        $user = $this->customer();
        $data = $this->postJson('/api/v1/addresses', $this->address())->assertCreated()->assertJsonPath('data.within_service_area', true)->json('data');
        $this->assertIsString($data['id']);
        $url = '/api/v1/addresses/'.$data['id'];
        $this->getJson('/api/v1/addresses')->assertJsonCount(1, 'data');
        $this->patchJson($url, ['label' => 'Kantor', 'lock_version' => 0])->assertOk()->assertJsonPath('data.lock_version', 1);
        $this->patchJson($url, ['label' => 'Lama', 'lock_version' => 0])->assertStatus(409)->assertJsonPath('code', 'STALE_VERSION');
        $this->deleteJson($url, ['lock_version' => 0])->assertStatus(409);
        $this->deleteJson($url, ['lock_version' => 1])->assertNoContent();
        $this->deleteJson($url, ['lock_version' => 1])->assertNoContent();
        $this->patchJson($url, ['label' => 'Aktif lagi', 'lock_version' => 2])->assertNotFound();
        $this->getJson('/api/v1/addresses')->assertJsonCount(0, 'data');
        $this->assertDatabaseHas('addresses', ['id' => $data['id'], 'user_id' => $user->id, 'is_active' => false]);
    }

    public function test_address_validation_out_of_area_and_owner_isolation(): void
    {
        $this->configure();
        $first = $this->customer();
        $this->postJson('/api/v1/addresses', $this->address(['latitude' => 0]))->assertUnprocessable()->assertJsonValidationErrors('latitude');
        $this->postJson('/api/v1/addresses', $this->address(['longitude' => 181]))->assertUnprocessable();
        $this->postJson('/api/v1/addresses', $this->address(['user_id' => 99, 'is_active' => true]))->assertUnprocessable()->assertJsonValidationErrors(['user_id', 'is_active']);
        $id = $this->postJson('/api/v1/addresses', $this->address())->assertCreated()->json('data.id');
        $this->customer();
        $this->getJson('/api/v1/addresses')->assertJsonCount(0, 'data');
        $this->patchJson('/api/v1/addresses/'.$id, ['label' => 'Bocor', 'lock_version' => 0])->assertNotFound();
        $this->deleteJson('/api/v1/addresses/'.$id, ['lock_version' => 0])->assertNotFound();
        $this->assertDatabaseHas('addresses', ['id' => $id, 'user_id' => $first->id, 'label' => 'Rumah']);
    }

    public function test_existing_addresses_revalidate_after_depot_moves(): void
    {
        $depot = $this->configure();
        $this->customer();
        $id = $this->postJson('/api/v1/addresses', $this->address())->assertCreated()->json('data.id');
        $depot->latitude = 0;
        $depot->longitude = 0;
        $depot->save();
        $this->getJson('/api/v1/addresses')->assertJsonPath('data.0.within_service_area', false);
        $this->patchJson('/api/v1/addresses/'.$id, ['label' => 'Baru', 'lock_version' => 0])->assertUnprocessable();
    }

    public function test_address_pagination_and_required_version(): void
    {
        $this->configure();
        $this->customer();
        $id = $this->postJson('/api/v1/addresses', $this->address())->json('data.id');
        $this->postJson('/api/v1/addresses', $this->address(['label' => 'Kantor']))->assertCreated();
        $this->getJson('/api/v1/addresses?per_page=1')->assertJsonCount(1, 'data')->assertJsonPath('meta.total', 2);
        $this->getJson('/api/v1/addresses?per_page=101')->assertUnprocessable();
        $this->patchJson('/api/v1/addresses/'.$id, ['label' => 'Baru'])->assertUnprocessable();
    }

    public function test_admin_creates_slots_in_depot_timezone_and_duplicates_are_rejected(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-11-04T01:00:00Z'));
        $this->configure(['timezone' => 'Asia/Makassar']);
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        $this->get('/admin/slots/create')->assertOk();
        $this->post('/admin/slots', $this->slot())->assertRedirect('/admin/slots');
        $this->assertDatabaseHas('delivery_slots', ['service_date' => '2026-11-05', 'window_start_at' => '2026-11-05 02:00:00', 'window_end_at' => '2026-11-05 04:00:00', 'cutoff_at' => '2026-11-05 01:00:00']);
        $this->post('/admin/slots', $this->slot())->assertSessionHasErrors('start_time');
        $this->get('/admin/slots')->assertOk()->assertInertia(fn (AssertableInertia $page) => $page->component('Admin/Slots/Index')->where('depot.timezone', 'Asia/Makassar')->where('slots.data.0.window_start_at', '2026-11-05T02:00:00.000000Z'));
        $this->put('/admin/depot', $this->settings())->assertSessionHasErrors('timezone');
    }

    public function test_slot_chronology_cutoff_inactive_and_conflict(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-11-04T01:00:00Z'));
        $this->configure();
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        $this->post('/admin/slots', $this->slot(['end_time' => '09:00']))->assertSessionHasErrors('end_time');
        $this->post('/admin/slots', $this->slot(['cutoff_local' => '2026-11-05T10:01']))->assertSessionHasErrors('cutoff_local');
        $this->post('/admin/slots', $this->slot(['cutoff_local' => '2026-11-04T07:00']))->assertSessionHasErrors('cutoff_local');
        $this->post('/admin/slots', $this->slot(['service_date' => '2026-02-30']))->assertSessionHasErrors('service_date');
        $this->post('/admin/slots', $this->slot())->assertRedirect();
        $slot = DeliverySlot::first();
        $this->get('/admin/slots/'.$slot->id.'/edit')->assertOk();
        $this->travelTo(CarbonImmutable::parse('2026-11-06T00:00:00Z'));
        $this->put('/admin/slots/'.$slot->id, $this->slot(['lock_version' => 0, 'is_active' => 0]))->assertRedirect();
        $this->put('/admin/slots/'.$slot->id, $this->slot(['lock_version' => 0, 'is_active' => 0]))->assertStatus(409);
        $this->assertDatabaseHas('delivery_slots', ['id' => $slot->id, 'is_active' => false, 'lock_version' => 1]);
    }

    public function test_slot_api_filters_local_date_exact_cutoff_and_inactive_slots(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-11-04T16:00:00Z'));
        $this->configure(['timezone' => 'Asia/Jayapura']);
        $this->customer();
        $this->getJson('/api/v1/delivery-settings')->assertJsonPath('data.today', '2026-11-05');
        foreach ([['2026-11-05 03:00:00', true], ['2026-11-04 16:00:00', true], ['2026-11-05 02:00:00', false]] as $i => [$cutoff,$active]) {
            $slot = new DeliverySlot(['service_date' => '2026-11-05', 'window_start_at' => '2026-11-05 '.(4 + $i).':00:00', 'window_end_at' => '2026-11-05 '.(5 + $i).':00:00', 'cutoff_at' => $cutoff, 'is_active' => $active]);
            $slot->depot_id = 1;
            $slot->save();
        }
        $this->getJson('/api/v1/delivery-slots?date=2026-11-05')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('timezone', 'Asia/Jayapura')->assertJsonPath('data.0.window_start_at', '2026-11-05T04:00:00.000000Z');
        $this->getJson('/api/v1/delivery-slots?date=2026-11-04')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/delivery-slots?date=2026-02-30')->assertUnprocessable();
        $this->getJson('/api/v1/delivery-slots')->assertUnprocessable();
        $this->getJson('/api/v1/delivery-slots?date=2026-11-05&per_page=101')->assertUnprocessable();
    }

    public function test_roles_and_inactive_accounts_cannot_use_delivery_operations(): void
    {
        $this->getJson('/api/v1/addresses')->assertUnauthorized();
        foreach (['courier', 'admin'] as $role) {
            $user = User::factory()->create(['role' => $role]);
            $this->app['auth']->forgetGuards();
            $this->withToken($user->createToken('test')->plainTextToken);
            $this->getJson('/api/v1/delivery-settings')->assertForbidden();
            $this->postJson('/api/v1/addresses', $this->address())->assertForbidden();
            $this->getJson('/api/v1/delivery-slots?date=2026-11-05')->assertForbidden();
        }
        $user = User::factory()->create(['is_active' => false]);
        $this->app['auth']->forgetGuards();
        $this->withToken($user->createToken('test')->plainTextToken)->getJson('/api/v1/addresses')->assertForbidden();
        $this->actingAs(User::factory()->create(), 'web');
        $this->get('/admin/depot')->assertForbidden();
        $this->post('/admin/slots', $this->slot())->assertForbidden();
    }
}
