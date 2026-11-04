<?php

namespace App\Exceptions;

use RuntimeException;

class BusinessFailure extends RuntimeException
{
    public function __construct(public string $businessCode, string $message, public int $status = 409)
    {
        parent::__construct($message);
    }

    public function body(): array
    {
        return ['message' => $this->getMessage(), 'code' => $this->businessCode];
    }
}
