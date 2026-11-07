<?php

namespace Tests\Feature;

use App\Http\Middleware\HandleInertiaRequests;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class AdminInertiaTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_pages_are_inertia_and_share_only_safe_identity_fields(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $this->actingAs($admin, 'web');
        foreach ([
            '/admin' => 'Admin/Dashboard',
            '/admin/products' => 'Admin/Products/Index',
            '/admin/products/create' => 'Admin/Products/Form',
            '/admin/depot' => 'Admin/Depot',
            '/admin/slots' => 'Admin/Slots/Index',
            '/admin/slots/create' => 'Admin/Slots/Form',
            '/admin/stock' => 'Admin/Stock/Index',
            '/admin/orders' => 'Admin/Orders/Index',
            '/admin/trips' => 'Admin/Trips/Index',
            '/admin/trips/create' => 'Admin/Trips/Form',
            '/admin/couriers' => 'Admin/Couriers/Index',
            '/admin/couriers/create' => 'Admin/Couriers/Form',
            '/admin/vehicles' => 'Admin/Vehicles/Index',
            '/admin/vehicles/create' => 'Admin/Vehicles/Form',
        ] as $url => $component) {
            $this->get($url)->assertOk()->assertHeader('Cache-Control', 'no-store, private')
                ->assertInertia(fn (Assert $page) => $page->component($component)
                    ->where('auth.user.id', $admin->id)->where('auth.user.role', 'admin')
                    ->missing('auth.user.password')->missing('auth.user.remember_token')
                    ->missing('auth.user.email_verified_at'));
        }
    }

    public function test_inertia_navigation_returns_page_json_and_asset_version_mismatch_reloads(): void
    {
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        $page = $this->get('/admin/products')->viewData('page');
        $this->get('/admin/products?q=sample', ['X-Inertia' => 'true', 'X-Inertia-Version' => $page['version']])
            ->assertOk()->assertHeader('X-Inertia', 'true')
            ->assertJsonPath('component', 'Admin/Products/Index')->assertJsonPath('props.filters.q', 'sample');
        $this->get('/admin/products', ['X-Inertia' => 'true', 'X-Inertia-Version' => 'outdated'])
            ->assertStatus(409)->assertHeader('X-Inertia-Location', url('/admin/products'));
    }

    public function test_inertia_validation_is_returned_to_form_and_failed_login_stays_guest(): void
    {
        $this->from('/admin/login')->post('/admin/login', ['email' => 'unknown@example.test', 'password' => 'wrong'], ['X-Inertia' => 'true'])
            ->assertRedirect('/admin/login')->assertSessionHasErrors('email');
        $this->assertGuest('web');
        $response = $this->withCookie(config('session.cookie'), session()->getId())->get('/admin/login');
        $response->assertInertia(fn (Assert $page) => $page->component('Admin/Login')
            ->where('auth.user', null)->has('errors.email'));
    }

    public function test_logout_clears_inertia_history_and_protects_admin_again(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $this->actingAs($admin, 'web')->post('/admin/logout', [], ['X-Inertia' => 'true'])->assertRedirect('/admin/login');
        $response = $this->get('/admin/login');
        $response->assertInertia(fn (Assert $page) => $page->where('auth.user', null));
        $this->assertTrue($response->viewData('page')['clearHistory']);
        $this->get('/admin/products')->assertRedirect('/admin/login');
    }

    public function test_errors_render_inside_inertia_and_api_keeps_json_contract(): void
    {
        $customer = User::factory()->create();
        $version = app(HandleInertiaRequests::class)->version(Request::create('/admin'));
        $this->actingAs($customer, 'web')->get('/admin/orders', ['X-Inertia' => 'true', 'X-Inertia-Version' => $version])
            ->assertForbidden()->assertHeader('X-Inertia', 'true')
            ->assertJsonPath('component', 'Admin/Error')->assertJsonPath('props.status', 403);
        $this->getJson('/api/v1/health')->assertOk()->assertJsonPath('data.service', 'shipx-api')->assertJsonMissingPath('component');
        $this->getJson('/api/v1/catalog')->assertUnauthorized()->assertJsonMissingPath('component');
    }
}
