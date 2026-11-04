<?php

namespace Tests\Feature;

use Tests\TestCase;

class ApiHealthTest extends TestCase
{
    public function test_mobile_health_contract_is_available_without_database(): void
    {
        $this->getJson('/api/v1/health')
            ->assertOk()
            ->assertExactJson(['data' => [
                'service' => 'shipx-api',
                'status' => 'ok',
                'api_version' => 'v1',
            ]]);
    }
}
