<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthenticationTest extends TestCase
{
    use RefreshDatabase;

    private function registration(array $extra = []): array
    {
        return array_replace([
            'name' => 'Customer', 'email' => ' Customer@Example.com ', 'phone' => '08123456789',
            'password' => 'long-password-123', 'password_confirmation' => 'long-password-123',
            'device_name' => 'test-phone',
        ], $extra);
    }

    public function test_registration_normalizes_identity_and_issues_expiring_hashed_token(): void
    {
        $data = $this->postJson('/api/v1/auth/register', $this->registration())
            ->assertCreated()->assertJsonPath('data.user.role', 'customer')
            ->assertJsonPath('data.user.email', 'customer@example.com')
            ->assertJsonPath('data.token_type', 'Bearer')->json('data');
        $this->assertIsString($data['user']['id']);
        $this->assertArrayNotHasKey('password', $data['user']);
        $user = User::first();
        $this->assertTrue(Hash::check('long-password-123', $user->password));
        $this->assertNotEquals($data['token'], $user->tokens()->first()->token);
        $this->assertEqualsWithDelta(now()->addDays(30)->timestamp, strtotime($data['expires_at']), 2);
        $this->assertDatabaseHas('users', ['is_active' => true, 'role' => 'customer']);
    }

    public function test_public_registration_cannot_set_role_or_activation(): void
    {
        foreach (['admin', 'courier', 'customer'] as $role) {
            $this->postJson('/api/v1/auth/register', $this->registration(['role' => $role]))
                ->assertUnprocessable()->assertJsonValidationErrors('role');
        }
        $this->postJson('/api/v1/auth/register', $this->registration(['is_active' => false]))
            ->assertUnprocessable()->assertJsonValidationErrors('is_active');
        $this->postJson('/api/v1/auth/register', $this->registration(['role' => null]))
            ->assertUnprocessable()->assertJsonValidationErrors('role');
        $this->assertDatabaseCount('users', 0);
    }

    public function test_registration_validates_password_confirmation_and_normalized_uniqueness(): void
    {
        $this->postJson('/api/v1/auth/register', $this->registration(['password' => 'short']))->assertUnprocessable();
        User::factory()->create(['email' => 'customer@example.com']);
        $this->postJson('/api/v1/auth/register', $this->registration())->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_all_server_roles_can_login_and_me_exposes_only_public_identity(): void
    {
        foreach (['customer', 'courier', 'admin'] as $role) {
            $user = User::factory()->create(['role' => $role]);
            $token = $this->postJson('/api/v1/auth/login', [
                'email' => strtoupper($user->email), 'password' => 'password', 'device_name' => 'test',
            ])->assertOk()->assertJsonPath('data.user.role', $role)->json('data.token');
            $this->app['auth']->forgetGuards();
            $this->withToken($token)->getJson('/api/v1/me')->assertOk()
                ->assertExactJson(['data' => ['id' => (string) $user->id, 'name' => $user->name,
                    'email' => $user->email, 'phone' => null, 'role' => $role]]);
        }
    }

    public function test_bad_credentials_have_generic_errors_and_are_rate_limited(): void
    {
        $user = User::factory()->create();
        $payload = ['email' => $user->email, 'password' => 'wrong', 'device_name' => 'test'];
        $known = $this->postJson('/api/v1/auth/login', $payload)->assertUnprocessable()->json('errors');
        $unknown = $this->postJson('/api/v1/auth/login', [...$payload, 'email' => 'missing@example.com'])
            ->assertUnprocessable()->json('errors');
        $this->assertSame($known, $unknown);
        for ($i = 0; $i < 4; $i++) {
            $this->postJson('/api/v1/auth/login', $payload)->assertUnprocessable();
        }
        $this->postJson('/api/v1/auth/login', $payload)->assertStatus(429);
    }

    public function test_missing_invalid_and_expired_tokens_are_rejected(): void
    {
        $this->getJson('/api/v1/me')->assertUnauthorized();
        $this->withToken('invalid')->getJson('/api/v1/me')->assertUnauthorized();
        $user = User::factory()->create();
        $token = $user->createToken('expired', ['*'], now()->subSecond())->plainTextToken;
        $this->withToken($token)->getJson('/api/v1/me')->assertUnauthorized();
    }

    public function test_logout_revokes_only_current_token(): void
    {
        $user = User::factory()->create();
        $current = $user->createToken('current')->plainTextToken;
        $other = $user->createToken('other')->plainTextToken;
        $this->withToken($current)->deleteJson('/api/v1/auth/token')->assertNoContent();
        $this->app['auth']->forgetGuards();
        $this->withToken($current)->getJson('/api/v1/me')->assertUnauthorized();
        $this->app['auth']->forgetGuards();
        $this->withToken($other)->getJson('/api/v1/me')->assertOk();
    }

    public function test_inactive_accounts_cannot_login_or_use_existing_token(): void
    {
        $user = User::factory()->create(['is_active' => false]);
        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'password', 'device_name' => 'test'])->assertForbidden();
        $this->withToken($user->createToken('test')->plainTextToken)->getJson('/api/v1/me')->assertForbidden();
    }

    public function test_admin_requires_active_admin_session_and_does_not_accept_bearer_tokens(): void
    {
        $this->get('/admin')->assertRedirect('/admin/login');
        $bearerAdmin = User::factory()->create(['role' => 'admin']);
        $this->withToken($bearerAdmin->createToken('mobile')->plainTextToken)->get('/admin')->assertRedirect('/admin/login');
        foreach (['customer', 'courier'] as $role) {
            $user = User::factory()->create(['role' => $role]);
            $this->actingAs($user, 'web')->get('/admin')->assertForbidden();
        }
        $admin = User::factory()->create(['role' => 'admin']);
        $this->actingAs($admin, 'web')->get('/admin')->assertOk();
        $admin->forceFill(['is_active' => false])->save();
        $this->get('/admin')->assertForbidden();
    }

    public function test_admin_login_and_logout_use_session_and_enforce_role(): void
    {
        $customer = User::factory()->create();
        $this->post('/admin/login', ['email' => $customer->email, 'password' => 'password'])->assertSessionHasErrors('email');
        $this->assertGuest('web');
        $admin = User::factory()->create(['role' => 'admin']);
        $this->post('/admin/login', ['email' => strtoupper($admin->email), 'password' => 'password'])->assertRedirect('/admin');
        $this->assertAuthenticatedAs($admin, 'web');
        $this->get('/api/v1/me', ['Accept' => 'application/json'])->assertUnauthorized();
        $this->post('/admin/logout')->assertRedirect('/admin/login');
        $this->assertGuest('web');
    }

    public function test_admin_posts_require_csrf_outside_test_bypass(): void
    {
        $this->app['env'] = 'local';
        $this->post('/admin/login', ['email' => 'a@example.com', 'password' => 'password'])->assertStatus(419);
    }
}
