---
name: gopls-mcp
description: >
  Go language server MCP skill for workspace analysis, code navigation,
  editing, and vulnerability checking in Go projects.
---

# gopls MCP Skill

Use this skill when working in a Go workspace or with Go source files. The agent has access to the gopls MCP server, which provides Go-specific language intelligence beyond basic file reading.

## Trigger Conditions

- The user asks about Go code, Go packages, or Go workspace structure.
- You are reading or editing `*.go` files.
- The user asks to refactor, search, or understand Go code.

## Required First Steps

At the start of every session, if you are in a Go workspace, you **must** use `mcp_gopls_go_workspace` to learn about the Go workspace layout. Only after confirming you are in a Go workspace should you run `mcp_gopls_go_vulncheck` to identify any existing security risks.

## Read Workflow

The goal is to understand the codebase.

1. **Understand the workspace layout**: Use `mcp_gopls_go_workspace` to understand the overall structure of the workspace, such as whether it's a module, a workspace, or a GOPATH project.

2. **Find relevant symbols**: If you're looking for a specific type, function, or variable, use `mcp_gopls_go_search`. This is a fuzzy search that will help you locate symbols even if you don't know the exact name or location.
   Example: search for the `Server` type: `mcp_gopls_go_search({"query":"server"})`

3. **Understand a file and its intra-package dependencies**: When you have a file path and want to understand its contents and how it connects to other files **in the same package**, use `mcp_gopls_go_file_context`. This tool shows a summary of declarations from other files in the same package used by the current file. `mcp_gopls_go_file_context` **must** be used immediately after reading any Go file for the first time, and may be re-used if dependencies have changed.
   Example: `mcp_gopls_go_file_context({"file":"/path/to/server.go"})`

4. **Understand a package's public API**: When you need to understand what a package provides to external code, use `mcp_gopls_go_package_api`. This is especially useful for understanding third-party dependencies or other packages in the same monorepo.
   Example: `mcp_gopls_go_package_api({"packagePaths":["example.com/internal/storage"]})`

## Editing Workflow

The editing workflow is iterative. Cycle through these steps until the task is complete.

1. **Read first**: Before making any edits, follow the Read Workflow to understand the user's request and the relevant code.

2. **Find references**: Before modifying the definition of any symbol, use `mcp_gopls_go_symbol_references` to find all references to that identifier. This is critical for understanding the impact of your change.
   Example: `mcp_gopls_go_symbol_references({"file":"/path/to/server.go","symbol":"Server.Run"})`

3. **Make edits**: Make the required edits, including edits to references you identified in the previous step. Don't proceed to the next step until all planned edits are complete.

4. **Check for errors**: After every code modification, you **must** call `mcp_gopls_go_diagnostics`. Pass the paths of the files you have edited. This tool reports build or analysis errors and may provide suggested quick fixes as diffs. Apply them if correct.
   Example: `mcp_gopls_go_diagnostics({"files":["/path/to/server.go"]})`

5. **Fix errors**: If `mcp_gopls_go_diagnostics` reports any errors, fix them. It is OK to ignore 'hint' or 'info' diagnostics if they are not relevant to the current task. Re-run `mcp_gopls_go_diagnostics` after applying fixes to confirm resolution.

6. **Check for vulnerabilities**: If your edits involved adding or updating dependencies in `go.mod`, run a vulnerability check on the entire workspace. Run `mcp_gopls_go_vulncheck` after all build errors are resolved.
   Example: `mcp_gopls_go_vulncheck({"pattern":"./..."})`

7. **Run tests**: Once `mcp_gopls_go_diagnostics` reports no errors (and only then), run tests for the packages you changed. Use `go test [packagePath...]`. Don't run `go test ./...` unless the user explicitly requests it.
