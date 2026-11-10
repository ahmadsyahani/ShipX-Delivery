<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProductPhotoTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
    }

    private function data(array $changes = []): array
    {
        return array_replace(['sku' => 'PHOTO-QA', 'name' => 'Barang foto', 'category' => 'QA', 'unit_label' => 'item', 'unit_price_rp' => 15000, 'shipping_weight_g' => 1000, 'length_mm' => 100, 'width_mm' => 100, 'height_mm' => 100, 'is_active' => 1, 'lock_version' => 0], $changes);
    }

    private function photo(): UploadedFile
    {
        return UploadedFile::fake()->createWithContent('produk.png', base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='));
    }

    private function createProduct(bool $photo = true): Product
    {
        $this->post('/admin/products', $this->data($photo ? ['photo' => $this->photo()] : []))->assertRedirect('/admin/products');

        return Product::firstOrFail();
    }

    public function test_admin_uploads_photo_and_customer_catalog_exposes_usable_photo_url(): void
    {
        $product = $this->createProduct();
        $this->assertMatchesRegularExpression('~^product-photos/[a-f0-9-]{36}\.png$~', $product->photo_path);
        Storage::disk('local')->assertExists($product->photo_path);
        $this->get($product->photo_url)->assertOk()->assertHeader('Content-Type', 'image/png')->assertHeader('X-Content-Type-Options', 'nosniff');
        $this->app['auth']->forgetGuards();
        $customer = User::factory()->create();
        $this->withToken($customer->createToken('QA')->plainTextToken)->getJson('/api/v1/catalog')->assertOk()->assertJsonPath('data.0.photo_url', $product->photo_url)->assertJsonMissingPath('data.0.photo_path');
    }

    public function test_products_without_photo_remain_editable_and_keep_null_url(): void
    {
        $product = $this->createProduct(false);
        $this->assertNull($product->photo_url);
        $this->put('/admin/products/'.$product->id, $this->data(['name' => 'Diubah']))->assertRedirect();
        $this->assertNull($product->refresh()->photo_path);
        $this->assertCount(0, Storage::disk('local')->allFiles('product-photos'));
    }

    public function test_metadata_only_update_keeps_photo_and_multipart_replace_removes_old_file_after_commit(): void
    {
        $product = $this->createProduct();
        $oldPath = $product->photo_path;
        $this->put('/admin/products/'.$product->id, $this->data(['name' => 'Nama baru']))->assertRedirect();
        $this->assertSame($oldPath, $product->refresh()->photo_path);
        $this->post('/admin/products/'.$product->id, $this->data(['_method' => 'PUT', 'lock_version' => 1, 'photo' => $this->photo()]))->assertRedirect();
        $this->assertNotSame($oldPath, $product->refresh()->photo_path);
        Storage::disk('local')->assertMissing($oldPath);
        Storage::disk('local')->assertExists($product->photo_path);
        $this->assertCount(1, Storage::disk('local')->allFiles('product-photos'));
    }

    public function test_admin_can_remove_photo_and_old_public_url_stops_resolving(): void
    {
        $product = $this->createProduct();
        $oldPath = $product->photo_path;
        $oldUrl = $product->photo_url;
        $this->put('/admin/products/'.$product->id, $this->data(['remove_photo' => true]))->assertRedirect();
        $this->assertNull($product->refresh()->photo_url);
        Storage::disk('local')->assertMissing($oldPath);
        $this->get($oldUrl)->assertNotFound();
    }

    public function test_stale_photo_replacement_does_not_write_or_delete_any_photo(): void
    {
        $product = $this->createProduct();
        $this->put('/admin/products/'.$product->id, $this->data(['name' => 'Pemenang']))->assertRedirect();
        $this->post('/admin/products/'.$product->id, $this->data(['_method' => 'PUT', 'photo' => $this->photo()]))->assertStatus(409);
        $this->assertSame('Pemenang', $product->refresh()->name);
        Storage::disk('local')->assertExists($product->photo_path);
        $this->assertCount(1, Storage::disk('local')->allFiles('product-photos'));
    }

    public function test_invalid_files_conflicting_actions_and_internal_photo_fields_are_rejected(): void
    {
        $invalid = UploadedFile::fake()->createWithContent('fake.png', '<svg xmlns="http://www.w3.org/2000/svg"></svg>');
        $this->post('/admin/products', $this->data(['photo' => $invalid]))->assertSessionHasErrors('photo');
        $this->post('/admin/products', $this->data(['photo' => UploadedFile::fake()->create('large.png', 2049, 'image/png')]))->assertSessionHasErrors('photo');
        $this->post('/admin/products', $this->data(['photo' => $this->photo(), 'remove_photo' => true]))->assertSessionHasErrors('photo');
        $this->post('/admin/products', $this->data(['photo_path' => 'forged', 'photo_url' => 'https://example.test/fake.png']))->assertSessionHasErrors(['photo_path', 'photo_url']);
        $this->assertDatabaseCount('products', 0);
        $this->assertCount(0, Storage::disk('local')->allFiles('product-photos'));
    }

    public function test_database_failure_after_photo_write_cleans_new_file_and_preserves_old_photo(): void
    {
        $product = $this->createProduct();
        $oldPath = $product->photo_path;
        DB::unprepared("CREATE TRIGGER qa_product_photo_failure BEFORE UPDATE ON products BEGIN SELECT RAISE(ABORT, 'QA photo failure'); END");
        $this->withoutExceptionHandling();
        try {
            $this->put('/admin/products/'.$product->id, $this->data(['photo' => $this->photo()]));
            $this->fail('Expected database failure.');
        } catch (QueryException $error) {
            $this->assertStringContainsString('QA photo failure', $error->getMessage());
        } finally {
            DB::unprepared('DROP TRIGGER qa_product_photo_failure');
        }
        $this->assertSame($oldPath, $product->refresh()->photo_path);
        Storage::disk('local')->assertExists($oldPath);
        $this->assertCount(1, Storage::disk('local')->allFiles('product-photos'));
    }

    public function test_only_active_admin_can_upload_and_unreferenced_files_are_not_served(): void
    {
        foreach ([['role' => 'customer'], ['role' => 'courier'], ['role' => 'admin', 'is_active' => false]] as $attributes) {
            $this->actingAs(User::factory()->create($attributes), 'web')->post('/admin/products', $this->data(['photo' => $this->photo()]))->assertForbidden();
        }
        $path = 'product-photos/00000000-0000-4000-8000-000000000000.png';
        Storage::disk('local')->put($path, 'unreferenced');
        $this->get('/'.$path)->assertNotFound();
        $this->assertDatabaseCount('products', 0);
    }
}
