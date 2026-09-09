# CI coverage

The `Validate` workflow runs on every push and pull request.

- Ubuntu: Bash syntax + CLI smoke tests
- macOS: Bash syntax + CLI smoke tests
- Windows: PowerShell parser + CLI smoke tests

This catches platform-specific parser/shell regressions before setup instructions are published.
