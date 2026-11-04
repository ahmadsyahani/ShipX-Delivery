"""Compatibility notice: the former Blade-only HTTP check is retired."""

raise SystemExit(
    "Admin now uses React + Inertia. No fixture was created.\n"
    "From the project root, run: php scripts/serve-checkout-qa.php\n"
    "In a second terminal, from backend, run: npm.cmd run test:e2e\n"
    "Finally, from the root, run: php scripts/serve-checkout-qa.php stop\n"
    "See docs/ADMIN_UI_MIGRATION.md."
)
