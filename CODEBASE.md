# CODEBASE.md — credit-union-2-0-llc/cu2-action-gateway-lint

## Purpose
A composite GitHub Action that enforces Anthropic/OpenAI API key routing through the CU2 LiteLLM gateway. It prevents CI pipelines from passing if provider keys are referenced without a co-located `ANTHROPIC_BASE_URL`, ensuring Presidio anonymization and audit logging are not bypassed.

## Stack
TypeScript-based GitHub Composite Action running on `ubuntu-latest`. Relies on standard shell utilities for file scanning and regex matching. No external npm dependencies or runtime frameworks; executes directly via the GitHub Actions runner environment.

## Entry Points
Execute by referencing `credit-union-2-0-llc/cu2-action-gateway-lint@v1` in a workflow job step. The action automatically scans the repository root for candidate files upon invocation. No local CLI command is provided; it is designed strictly for CI/CD integration.

## Key Directories
- `action.yml`: Defines the composite action inputs, steps, and execution logic.
- `src/`: Contains the TypeScript source code for file scanning and validation logic (if applicable).
- `dist/`: Bundled JavaScript output for production use (if compiled).
- `.github/workflows/`: Example workflow configuration for consumers to copy into their repos.

## External Dependencies
Calls no external APIs or databases during execution. It operates entirely on local repository content. The only external dependency is the GitHub Actions platform itself. Consumers must ensure their deployed environments (e.g., Azure Container Apps) are correctly configured to match the linted source state.

## Development Status
Active production tool used in CI pipelines across the organization. `PASS` and `FAIL` states are stable. `PASS-EMPTY` state is active to handle edge cases where configuration is managed outside source control. Regularly reviewed for new file type coverage needs.

## Gotchas
`PASS-EMPTY` does not verify actual routing; it only confirms no candidate files were found. Consumers must manually verify deployed environment variables for repos returning `PASS-EMPTY`. Exemptions require a `.gateway-exempt` file with specific formatting (3+ lines, @mentions) to avoid failure.