# pickle_businesses v1.0.3

## Fixes

- Validate business permissions, trade amounts, carts and payment methods on the server.
- Prevent duplicate payroll claims and compensate failed item deliveries.
- Bind bills to the intended payer and defer crafting debits until completion.
- Protect business ownership changes, storage access and private management data.
- Improve SQL failure handling, location validation and webhook destination restrictions.

## Upgrade notes

- Role-protected business storage requires ox_inventory. QB/Quasar storage entry points are disabled until a server authorization adapter is available.
- Settle funds, stock, payroll and storage before selling or transferring a business.

## Package and validation

- The ZIP contains one pickle_businesses/ folder with the complete resource, installation files, license and runtime NUI assets where applicable. Unbuilt web/ sources, node_modules/ and Git metadata are excluded.
- Required local NUI scripts and stylesheets were checked before packaging. Prior remediation validation passed targeted mocked regressions and Lua/JavaScript syntax checks; this is not a live FiveM integration test.
- Test the resource with your installed frameworks, inventory, database and other integrations before use. Transactions spanning framework persistence, SQL and local KVP still have crash-recovery boundaries.

Source: [audit remediation PR #2](https://github.com/PickleModsCommunity/pickle_businesses/pull/2), branch `fix/audit-remediation`. This release includes the PR changes without merging the PR.
