<?php

// Only the disposable QA launcher may use this router.
if (getenv('SHIPX_QA_HTTP') !== '1' || ! preg_match('/^shipx_qa_ui_[a-f0-9]{20}$/D', getenv('DB_DATABASE') ?: '')) {
    http_response_code(404);
    exit;
}
header('X-ShipX-QA: isolated-checkout');

return require __DIR__.'/../backend/vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php';
