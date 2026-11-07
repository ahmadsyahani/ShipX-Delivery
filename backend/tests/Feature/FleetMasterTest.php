<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class FleetMasterTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
    }

    private function courierData(array $overrides = []): array
    {
        return array_replace(['name' => 'Kurir QA', 'email' => 'courier@example.test', 'phone' => '080000000000', 'password' => 'Courier-QA-password-2026!', 'password_confirmation' => 'Courier-QA-password-2026!', 'is_active' => true], $overrides);
    }

    private function vehicleData(array $overrides = []): array
    {
        return array_replace(['code' => 'motor-01', 'name' => 'Motor operasional', 'plate_number' => 'b 1234 qa', 'travel_mode' => 'motorcycle', 'max_load_weight_g' => 80000, 'max_load_volume_cm3' => 180000, 'is_active' => true], $overrides);
    }

    private function loginCourier(string $email = 'courier@example.test', string $password = 'Courier-QA-password-2026!')
    {
        return $this->postJson('/api/v1/auth/login', ['email' => $email, 'password' => $password, 'device_name' => 'QA Phone']);
    }

    public function test_admin_creates_courier_with_hashed_password_and_safe_props(): void
    {
        $this->post('/admin/couriers', $this->courierData(['email' => ' COURIER@EXAMPLE.TEST ']))->assertRedirect('/admin/couriers');
        $courier = User::where('role', 'courier')->firstOrFail();
        $this->assertSame('courier@example.test', $courier->email);
        $this->assertTrue(Hash::check('Courier-QA-password-2026!', $courier->password));
        $this->assertSame(0, $courier->lock_version);
        foreach (['/admin/couriers', '/admin/couriers/'.$courier->id.'/edit'] as $url) {
            $this->get($url)->assertOk()->assertDontSee($courier->password)->assertDontSee('Courier-QA-password-2026!');
        }
        $this->get('/admin/couriers')->assertInertia(fn (Assert $page) => $page->component('Admin/Couriers/Index')->has('couriers.data', 1)->missing('couriers.data.0.password')->missing('couriers.data.0.remember_token'));
        $this->loginCourier()->assertOk()->assertJsonPath('data.user.role', 'courier');
    }

    public function test_courier_validation_prevents_public_role_choice_duplicates_and_password_leak(): void
    {
        $this->post('/admin/couriers', $this->courierData(['role' => 'admin']))->assertSessionHasErrors('role');
        $this->post('/admin/couriers', $this->courierData(['password' => 'short', 'password_confirmation' => 'different']))->assertSessionHasErrors('password')->assertSessionMissing('_old_input.password')->assertSessionMissing('_old_input.password_confirmation');
        $this->post('/admin/couriers', $this->courierData())->assertRedirect();
        $this->post('/admin/couriers', $this->courierData(['email' => ' COURIER@example.test ']))->assertSessionHasErrors('email');
        $adminEmail = User::where('role', 'admin')->value('email');
        $this->post('/admin/couriers', $this->courierData(['email' => $adminEmail]))->assertSessionHasErrors('email');
        $this->assertSame(1, User::where('role', 'courier')->count());
        $this->postJson('/api/v1/auth/register', [...$this->courierData(['email' => 'public@example.test']), 'device_name' => 'QA', 'role' => 'courier'])->assertUnprocessable();
    }

    public function test_courier_profile_version_and_empty_password_keep_existing_credentials(): void
    {
        $this->post('/admin/couriers', $this->courierData());
        $courier = User::where('role', 'courier')->firstOrFail();
        $hash = $courier->password;
        $token = $courier->createToken('retained')->plainTextToken;
        $url = '/admin/couriers/'.$courier->id;
        $this->put($url, $this->courierData(['name' => 'Nama baru', 'password' => '', 'password_confirmation' => '', 'lock_version' => 0]))->assertRedirect();
        $this->assertSame($hash, $courier->refresh()->password);
        $this->assertSame(1, $courier->lock_version);
        $this->assertSame(1, $courier->tokens()->count());
        $this->put($url, $this->courierData(['lock_version' => 0]))->assertStatus(409);
        $this->put($url, $this->courierData())->assertSessionHasErrors('lock_version');
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/me')->assertOk()->assertJsonPath('data.name', 'Nama baru');
    }

    public function test_deactivation_revokes_tokens_and_reactivation_does_not_restore_them(): void
    {
        $this->post('/admin/couriers', $this->courierData());
        $courier = User::where('role', 'courier')->firstOrFail();
        $oldToken = $courier->createToken('old')->plainTextToken;
        $url = '/admin/couriers/'.$courier->id;
        $this->put($url, $this->courierData(['lock_version' => 0, 'is_active' => false, 'password' => '', 'password_confirmation' => '']))->assertRedirect();
        $this->assertSame(0, $courier->tokens()->count());
        $this->loginCourier()->assertForbidden();
        $this->put($url, $this->courierData(['lock_version' => 1, 'password' => '', 'password_confirmation' => '']))->assertRedirect();
        $this->app['auth']->forgetGuards();
        $this->withToken($oldToken)->getJson('/api/v1/me')->assertUnauthorized();
        $this->loginCourier()->assertOk();
    }

    public function test_password_and_email_changes_revoke_sessions(): void
    {
        $this->post('/admin/couriers', $this->courierData());
        $courier = User::where('role', 'courier')->firstOrFail();
        $courier->createToken('before-reset');
        $url = '/admin/couriers/'.$courier->id;
        $new = 'New-courier-password-2026!';
        $this->put($url, $this->courierData(['password' => $new, 'password_confirmation' => $new, 'lock_version' => 0]))->assertRedirect();
        $this->assertSame(0, $courier->tokens()->count());
        $this->loginCourier()->assertUnprocessable();
        $this->loginCourier(password: $new)->assertOk();
        $this->put($url, $this->courierData(['email' => ' NEW@example.test ', 'password' => '', 'password_confirmation' => '', 'lock_version' => 1]))->assertRedirect();
        $this->assertSame(0, $courier->tokens()->count());
        $this->loginCourier('new@example.test', $new)->assertOk();
    }

    public function test_courier_routes_never_edit_customers_or_admins_and_filters_are_scoped(): void
    {
        $this->post('/admin/couriers', $this->courierData());
        $this->post('/admin/couriers', $this->courierData(['email' => 'off@example.test', 'name' => 'Off', 'is_active' => false]));
        foreach (['admin', 'customer'] as $role) {
            $target = User::factory()->create(['role' => $role]);
            $this->get('/admin/couriers/'.$target->id.'/edit')->assertNotFound();
            $this->put('/admin/couriers/'.$target->id, $this->courierData(['email' => $target->email, 'lock_version' => 0]))->assertNotFound();
            $this->assertSame($role, $target->refresh()->role);
        }
        $this->get('/admin/couriers?status=active')->assertInertia(fn (Assert $page) => $page->has('couriers.data', 1)->where('couriers.data.0.email', 'courier@example.test'));
        $this->get('/admin/couriers?q=off&status=active')->assertInertia(fn (Assert $page) => $page->has('couriers.data', 0));
    }

    public function test_vehicle_creation_normalizes_code_plate_and_uses_integer_capacity(): void
    {
        $this->post('/admin/vehicles', $this->vehicleData())->assertRedirect('/admin/vehicles');
        $vehicle = Vehicle::firstOrFail();
        $this->assertSame('MOTOR-01', $vehicle->code);
        $this->assertSame('B1234QA', $vehicle->plate_number);
        $this->assertSame(80000, $vehicle->max_load_weight_g);
        $this->assertSame(180000, $vehicle->max_load_volume_cm3);
        $this->assertSame(1, $vehicle->depot_id);
        $this->get('/admin/vehicles')->assertInertia(fn (Assert $page) => $page->component('Admin/Vehicles/Index')->where('vehicles.data.0.max_load_weight_g', 80000));
        $this->get('/admin/vehicles/'.$vehicle->id.'/edit')->assertOk();
        $this->post('/admin/vehicles', $this->vehicleData(['code' => ' MOTOR-01 ', 'plate_number' => 'B9999QA']))->assertSessionHasErrors('code');
        $this->post('/admin/vehicles', $this->vehicleData(['code' => 'other', 'plate_number' => 'B-1234-QA']))->assertSessionHasErrors('plate_number');
        $this->get('/admin/vehicles?q=b%201234%20qa')->assertInertia(fn (Assert $page) => $page->has('vehicles.data', 1));
        $this->get('/admin/vehicles?q=---')->assertInertia(fn (Assert $page) => $page->has('vehicles.data', 0));
    }

    public function test_vehicle_metadata_rejects_invalid_values_and_stale_edits(): void
    {
        foreach ([['max_load_weight_g' => 0], ['max_load_volume_cm3' => -1], ['max_load_weight_g' => 1.5], ['max_load_volume_cm3' => 1000000000001], ['max_load_weight_g' => 1000000001], ['travel_mode' => 'flying'], ['plate_number' => '<script>'], ['depot_id' => 2]] as $invalid) {
            $this->post('/admin/vehicles', $this->vehicleData($invalid))->assertSessionHasErrors(array_key_first($invalid));
        }
        $this->post('/admin/vehicles', $this->vehicleData())->assertRedirect();
        $vehicle = Vehicle::firstOrFail();
        $url = '/admin/vehicles/'.$vehicle->id;
        $this->put($url, $this->vehicleData(['is_active' => false, 'max_load_volume_cm3' => 120000, 'lock_version' => 0]))->assertRedirect();
        $this->put($url, $this->vehicleData(['lock_version' => 0]))->assertStatus(409);
        $this->put($url, $this->vehicleData())->assertSessionHasErrors('lock_version');
        $this->assertDatabaseHas('vehicles', ['id' => $vehicle->id, 'is_active' => false, 'max_load_volume_cm3' => 120000, 'lock_version' => 1]);
        $this->get('/admin/vehicles?status=active')->assertInertia(fn (Assert $page) => $page->has('vehicles.data', 0));
        $this->delete($url)->assertStatus(405);
    }

    public function test_only_active_web_admin_can_manage_masters_and_csrf_is_enforced(): void
    {
        auth('web')->logout();
        foreach (['couriers', 'vehicles'] as $resource) {
            $this->get('/admin/'.$resource)->assertRedirect('/admin/login');
        }
        foreach (['customer', 'courier', 'admin'] as $role) {
            $this->actingAs(User::factory()->create(['role' => $role, 'is_active' => $role !== 'admin']), 'web');
            $this->post('/admin/couriers', $this->courierData())->assertForbidden();
            $this->post('/admin/vehicles', $this->vehicleData())->assertForbidden();
            $this->get('/admin/couriers')->assertForbidden();
            $this->get('/admin/vehicles')->assertForbidden();
        }
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        $this->app['env'] = 'local';
        $this->post('/admin/couriers', $this->courierData())->assertStatus(419);
        $this->post('/admin/vehicles', $this->vehicleData())->assertStatus(419);
    }
}
