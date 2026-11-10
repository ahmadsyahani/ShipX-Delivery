<?php

namespace Tests\Feature;

use App\Models\Depot;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class CatalogTest extends TestCase
{
    use RefreshDatabase;

    private function payload(array $overrides = []): array
    {
        return array_replace(['sku' => 'air-600', 'name' => 'Air mineral 600 ml', 'category' => 'Minuman', 'unit_label' => 'botol', 'unit_price_rp' => 5000, 'shipping_weight_g' => 630, 'length_mm' => 61, 'width_mm' => 61, 'height_mm' => 220, 'is_active' => 1], $overrides);
    }

    private function admin(): User
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $this->actingAs($admin, 'web');

        return $admin;
    }

    public function test_blank_or_missing_create_skus_are_generated_and_edit_keeps_existing_codes(): void
    {
        $this->admin();
        foreach ([null, '', '   '] as $sku) {
            $this->post('/admin/products', $this->payload(['sku' => $sku]))->assertRedirect('/admin/products');
        }
        $payload = $this->payload();
        unset($payload['sku']);
        $this->post('/admin/products', $payload)->assertRedirect('/admin/products');
        $codes = Product::pluck('sku');
        $this->assertCount(4, $codes->unique());
        foreach ($codes as $code) {
            $this->assertMatchesRegularExpression('/^SHX-[0-9A-HJKMNP-TV-Z]{26}$/D', $code);
        }
        $product = Product::firstOrFail();
        $this->put('/admin/products/'.$product->id, $this->payload(['sku' => '', 'lock_version' => 0]))->assertSessionHasErrors('sku');
        $this->assertSame($product->sku, $product->fresh()->sku);
        $this->put('/admin/products/'.$product->id, $this->payload(['sku' => $product->sku, 'name' => 'Nama baru', 'lock_version' => 0]))->assertRedirect('/admin/products');
        $this->assertSame($product->sku, $product->fresh()->sku);
    }

    public function test_category_choices_include_defaults_and_existing_inactive_categories_once(): void
    {
        $this->admin();
        $product = $this->product(['category' => 'Kategori lama', 'is_active' => false]);
        $this->product(['sku' => 'ANOTHER', 'category' => 'Kategori lama']);
        foreach (['/admin/products/create', '/admin/products/'.$product->id.'/edit'] as $url) {
            $this->get($url)->assertOk()->assertInertia(fn (Assert $page) => $page
                ->where('categories', ['Kategori lama', 'Kebutuhan Rumah Tangga', 'Lainnya', 'Makanan', 'Minuman', 'Perawatan Diri']));
        }
    }

    private function product(array $overrides = []): Product
    {
        $product = new Product($this->payload($overrides));
        $product->depot_id = 1;
        $product->calculateVolume();
        $product->save();

        return $product->refresh();
    }

    public function test_admin_creates_product_and_server_calculates_rounded_volume(): void
    {
        $this->admin();
        $this->get('/admin/products')->assertOk()->assertInertia(fn (Assert $page) => $page->component('Admin/Products/Index')->where('total', 0)->has('products.data', 0));
        $this->get('/admin/products/create')->assertOk()->assertInertia(fn (Assert $page) => $page->component('Admin/Products/Form')->where('product', null));
        $this->post('/admin/products', $this->payload())->assertRedirect('/admin/products');
        $this->assertDatabaseHas('products', ['sku' => 'AIR-600', 'shipping_volume_cm3' => 819, 'depot_id' => 1]);
        $this->get('/admin/products')->assertOk()->assertInertia(fn (Assert $page) => $page->where('products.data.0.name', 'Air mineral 600 ml')->where('products.data.0.unit_price_rp', 5000));
    }

    public function test_invalid_metadata_and_duplicate_sku_are_rejected(): void
    {
        $this->admin();
        $this->post('/admin/products', $this->payload())->assertRedirect();
        $this->post('/admin/products', $this->payload(['sku' => ' Air-600 ']))->assertSessionHasErrors('sku');
        foreach (['unit_price_rp', 'shipping_weight_g', 'length_mm', 'width_mm', 'height_mm'] as $field) {
            $this->post('/admin/products', $this->payload(['sku' => 'NEW', $field => 0]))->assertSessionHasErrors($field);
        }
        $this->post('/admin/products', $this->payload(['sku' => 'NEW', 'shipping_volume_cm3' => 1, 'depot_id' => 2]))->assertSessionHasErrors(['shipping_volume_cm3', 'depot_id']);
        $this->assertDatabaseCount('products', 1);
    }

    public function test_update_supports_deactivation_and_rejects_stale_edits(): void
    {
        $this->admin();
        $product = $this->product();
        $this->get('/admin/products/'.$product->id.'/edit')->assertOk();
        $url = '/admin/products/'.$product->id;
        $this->put($url, $this->payload(['lock_version' => 0, 'is_active' => 0]))->assertRedirect('/admin/products');
        $this->assertDatabaseHas('products', ['id' => $product->id, 'is_active' => false, 'lock_version' => 1]);
        $this->put($url, $this->payload(['lock_version' => 0]))->assertStatus(409)->assertInertia(fn (Assert $page) => $page->component('Admin/Conflict')->where('reloadUrl', route('admin.products.edit', $product)));
        $this->patch($url, $this->payload())->assertSessionHasErrors('lock_version');
        $this->patch($url, $this->payload(['lock_version' => 1, 'unit_price_rp' => 6000]))->assertRedirect();
        $this->assertDatabaseHas('products', ['id' => $product->id, 'unit_price_rp' => 6000, 'lock_version' => 2]);
    }

    public function test_customer_and_courier_cannot_manage_products(): void
    {
        $this->get('/admin/products')->assertRedirect('/admin/login');
        $product = $this->product();
        foreach (['customer', 'courier'] as $role) {
            $this->actingAs(User::factory()->create(['role' => $role]), 'web');
            $this->get('/admin/products')->assertForbidden();
            $this->post('/admin/products', $this->payload())->assertForbidden();
            $this->put('/admin/products/'.$product->id, $this->payload(['lock_version' => 0]))->assertForbidden();
        }
    }

    public function test_catalog_returns_active_products_only_with_pagination_and_search(): void
    {
        $visible = $this->product();
        $this->product(['sku' => 'HIDDEN', 'name' => 'Hidden item', 'is_active' => 0]);
        $this->product(['sku' => 'SOAP', 'name' => 'Sabun tangan', 'category' => 'Kebersihan']);
        $customer = User::factory()->create();
        $this->withToken($customer->createToken('test')->plainTextToken);
        $this->getJson('/api/v1/catalog?per_page=1')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('meta.total', 2)->assertJsonPath('meta.last_page', 2)->assertJsonPath('data.0.id', (string) $visible->id);
        $this->getJson('/api/v1/catalog?q=Minuman')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.unit_price_rp', 5000);
        $this->getJson('/api/v1/catalog?q=Hidden')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/catalog?per_page=101')->assertUnprocessable();
        $this->getJson('/api/v1/catalog?page=0')->assertUnprocessable();
        $visible->is_active = false;
        $visible->save();
        $this->getJson('/api/v1/catalog?q=Minuman')->assertJsonCount(0, 'data');
    }

    public function test_catalog_enforces_authentication_role_and_activation(): void
    {
        $this->getJson('/api/v1/catalog')->assertUnauthorized();
        foreach (['courier', 'admin', 'customer'] as $role) {
            $user = User::factory()->create(['role' => $role, 'is_active' => $role !== 'customer']);
            $this->app['auth']->forgetGuards();
            $this->withToken($user->createToken('test')->plainTextToken)->getJson('/api/v1/catalog')->assertForbidden();
        }
    }

    public function test_categories_cover_the_whole_active_catalog_and_filter_before_pagination(): void
    {
        $this->product();
        $soap = $this->product(['sku' => 'SOAP', 'name' => 'Sabun tangan', 'category' => 'Kebersihan']);
        $this->product(['sku' => 'SOAP2', 'name' => 'Sabun wajah', 'category' => 'Kebersihan']);
        $this->product(['sku' => 'HIDDEN', 'category' => 'Kategori tersembunyi', 'is_active' => false]);
        $otherDepot = $this->product(['sku' => 'OTHER', 'category' => 'Depot lain']);
        $depot = new Depot;
        $depot->name = 'Depot lain';
        $depot->save();
        $otherDepot->depot_id = $depot->id;
        $otherDepot->save();
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $this->getJson('/api/v1/catalog?per_page=1')->assertOk()
            ->assertJsonPath('categories', ['Kebersihan', 'Minuman'])
            ->assertJsonPath('meta.total', 3);
        $this->getJson('/api/v1/catalog?category=Kebersihan&per_page=1')->assertOk()
            ->assertJsonPath('data.0.id', (string) $soap->id)->assertJsonPath('meta.total', 2)
            ->assertJsonPath('categories', ['Kebersihan', 'Minuman']);
        $this->getJson('/api/v1/catalog?category=Kebersihan&per_page=1&page=2')->assertOk()
            ->assertJsonPath('data.0.name', 'Sabun wajah')->assertJsonPath('meta.total', 2);
        $this->getJson('/api/v1/catalog?category=Kebersihan&q=mineral')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/catalog?category=Kebersihan&q=wajah')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/catalog?category=ber')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/catalog?category[]=Kebersihan')->assertUnprocessable();
        $this->getJson('/api/v1/catalog?category='.str_repeat('x', 81))->assertUnprocessable();
        $this->getJson('/api/v1/catalog?category=Unknown')->assertJsonCount(0, 'data')
            ->assertJsonPath('categories', ['Kebersihan', 'Minuman']);
    }

    public function test_product_names_are_escaped_and_filters_do_not_mix_status(): void
    {
        $this->admin();
        $this->product(['name' => '<script>alert(1)</script>']);
        $this->product(['sku' => 'INACTIVE', 'name' => 'Nonaktif', 'is_active' => false]);
        $this->get('/admin/products')->assertSee('&lt;script&gt;', false)->assertDontSee('<script>alert(1)</script>', false);
        $this->get('/admin/products?status=active')->assertDontSee('INACTIVE');
        $this->get('/admin/products?q=notfound')->assertInertia(fn (Assert $page) => $page->has('products.data', 0)->where('filters.q', 'notfound'));
    }
}
