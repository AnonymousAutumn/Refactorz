# Claude Code Prompt: Roblox Luau Codebase Refactoring

## Instructions for Use
Copy this entire prompt into Claude Code (Opus 4.5) at the start of your session.

---

## The Prompt

```
You are tasked with systematically refactoring a Roblox Luau codebase to improve code quality while preserving identical functionality from the player's perspective. This is a production codebase—every change must be carefully considered and verified.

## Core Principles

1. **Zero Functional Regression**: The game must behave identically to players before and after refactoring. No gameplay changes, no timing differences, no edge case breakages.

2. **Production-Level Quality**: All code must meet production standards—proper error handling, clear naming, appropriate documentation, defensive programming, and adherence to Luau/Roblox best practices.

3. **Verify Before Committing**: Before finalizing any change, pause and critically review it. Ask yourself: "Could this break anything? Is this actually an improvement? Am I certain this reference/API exists?"

4. **No Hallucinated References**: Never assume an API, method, property, or service exists. If you're unsure about a Roblox API or Luau feature, search the Roblox documentation or DevForum to verify it exists and understand its correct usage. Do not invent methods or properties.

## Refactoring Scope (Comprehensive)

Evaluate and improve each file across these dimensions:

### Code Structure & Architecture
- Module organization and separation of concerns
- Removal of dead/unreachable code
- Consolidation of duplicate logic
- Appropriate use of ModuleScripts vs Scripts vs LocalScripts
- Clear dependency graphs (no circular dependencies)

### Readability & Maintainability
- Consistent naming conventions (PascalCase for classes/modules, camelCase for variables/functions)
- Meaningful variable and function names
- Appropriate comments for complex logic (not obvious code)
- Logical code ordering within files
- Reasonable function lengths (break up functions over ~50 lines if logical)

### Performance
- Avoid unnecessary table allocations in hot paths
- Cache frequently accessed services and instances
- Use appropriate data structures
- Minimize remote event/function payload sizes
- Avoid memory leaks (disconnect connections, clean up instances)

### Error Handling & Robustness
- Guard against nil values where appropriate
- Use pcall/xpcall for operations that can fail
- Validate inputs at module boundaries
- Handle edge cases (player leaving mid-operation, etc.)
- Appropriate use of assert with meaningful messages

### Roblox-Specific Best Practices
- Proper use of Roblox services (get via game:GetService())
- Correct client/server boundary respect
- Appropriate use of RemoteEvents vs RemoteFunctions
- Safe instance destruction patterns
- Proper signal/connection management

### Type Safety (if using typed Luau)
- Add or improve type annotations
- Use strict mode where beneficial
- Eliminate `any` types where possible

## Work Process

### Phase 1: Interface Mapping (Do This First)
Before modifying any code, complete a full interface audit:

1. **Discover all modules**: List every ModuleScript and identify what it exports
2. **Map dependencies**: Create a dependency graph showing which files require which
3. **Document public interfaces**: For each module, document:
   - Exported functions and their signatures
   - Expected parameters and return types
   - Events/signals it fires or listens to
   - Shared state it reads/writes
4. **Identify interface contracts**: These are the "boundaries" that must remain stable:
   - Function names and parameter order
   - Return value shapes
   - Event names and payload structures
   - Global/shared table keys

Present this interface map to the user for approval before proceeding to refactoring.

**Why this matters**: By locking down interfaces first, you can freely refactor internals without breaking other files. Files changed in batch 1 will remain compatible with files changed in batch 10 because the contracts between them are preserved.

### Phase 2: Refactoring (Batch Processing)
Work in batches of **5 files maximum** at a time. After completing each batch:
1. Summarize the changes made to each file
2. List any concerns or items that need user verification
3. Ask the user: "Ready to continue to the next batch?"
4. Wait for user confirmation before proceeding

### For Each File
1. **Analyze**: Read and understand the file's purpose, dependencies, and how it fits into the larger system
2. **Check interface contract**: Review the interface map—what does this file expose that others depend on?
3. **Plan**: Identify specific improvements (list them before making changes)
4. **Preserve contracts**: Ensure your changes do NOT alter:
   - Function signatures (names, parameter order, return types)
   - Exported table structure
   - Event names or payload shapes
   - Any behavior that dependent files rely on
5. **Research**: If unsure about any Roblox API or best practice, search documentation first
6. **Implement**: Make the changes
7. **Verify**: Review your changes critically—check for:
   - Syntax errors
   - Logic errors
   - Broken references
   - Changed behavior (unintentional)
   - Missing nil checks where needed
   - **Interface contract violations**
8. **Test**: Run/validate the code (see Testing section)

### Ordering
Process files in this order:
1. Core utility modules (shared dependencies)
2. Data management modules
3. Service modules
4. UI modules
5. Script entry points (Scripts/LocalScripts)

This ensures dependencies are refactored before dependents.

### Handling Necessary Interface Changes
Sometimes an interface genuinely needs to change (e.g., a function needs an additional parameter). When this happens:

1. **Flag it immediately**: Do not silently change the interface
2. **Document the change**: Note the old signature vs. new signature
3. **Identify all callers**: List every file that calls this function/uses this export
4. **Propose a plan**: Either:
   - Make the change backward-compatible (optional parameter with default)
   - Update all callers in the same batch
   - Defer to a dedicated "interface update" batch
5. **Get user approval**: Wait for confirmation before proceeding

### Phase 3: Reconciliation (After All Batches)
Once all batches are complete, perform a final compatibility check:

1. **Cross-reference interfaces**: Verify all module calls still match their targets
2. **Check for orphaned code**: Look for functions that are no longer called
3. **Validate event flow**: Ensure all event connections still have matching fires
4. **Run full analysis**: Execute Luau type checker across the entire codebase
5. **Generate test plan**: Provide a comprehensive list of scenarios to manually test in Studio

Present a final summary showing:
- Total files modified
- Interface changes made (if any)
- Potential risk areas for manual testing
- Suggested playtest scenarios

## Testing & Validation

After modifying each file, perform these validations:

### Static Analysis
- Run Luau type checker if types are present: `luau-analyze [file]` or use Roblox Studio's script analysis
- Check for any red/orange underlines in Studio
- Verify no "Unknown global" warnings for legitimate globals

### Functional Verification
For each changed file, create a brief test plan:
```
File: [filename]
Changes: [summary of changes]
Test Cases:
1. [Specific scenario to verify]
2. [Edge case to check]
3. [Integration point to validate]
```

If the file can be tested in isolation (utility functions), write quick inline test calls:
```lua
-- Quick validation (remove before commit)
local function _test()
    assert(MyFunction(input) == expectedOutput, "MyFunction basic case")
    assert(MyFunction(nil) == fallback, "MyFunction nil handling")
    print("✓ Tests passed")
end
_test()
```

### Integration Awareness
Note which other files depend on the modified file. Flag these for the user:
"⚠️ Files that may need manual testing after this change: [list]"

## Output Format

For each batch, provide:

```
## Batch [N]: [File names]

### [Filename 1]
**Purpose**: [Brief description]
**Changes Made**:
- [Change 1 with rationale]
- [Change 2 with rationale]

**Verification**:
- [x] Syntax valid
- [x] No hallucinated APIs
- [x] Behavior preserved
- [x] Interface contract honored
- [x] Error handling adequate

**Test Cases**:
1. [Test scenario]

**Dependencies affected**: [List or "None"]

---

[Repeat for each file in batch]

---

## Batch Summary
- Files modified: [count]
- Key improvements: [bullets]
- Items needing user attention: [any concerns]

**Ready to continue to the next batch?**
```

## Important Reminders

- **When in doubt, don't change it.** If you're unsure whether a change preserves behavior, leave a comment noting the potential improvement and flag it for the user.

- **Preserve intentional patterns.** Some code that looks "wrong" may be intentional (workarounds for Roblox quirks, etc.). If something seems odd, note it rather than blindly "fixing" it.

- **Check your work.** After writing any code, reread it. Look for typos, off-by-one errors, forgotten nil checks, and incorrect assumptions.

- **Search before assuming.** If you need to use a Roblox API you're not 100% certain about, search the Roblox Creator Documentation or DevForum first.

## Begin

Start by exploring the codebase structure. List all Lua/Luau files and then complete **Phase 1: Interface Mapping**:

1. Build the complete dependency graph
2. Document all module interfaces (exports, function signatures, events)
3. Identify the interface contracts that must be preserved
4. Present this map to me for review

After I approve the interface map, propose your first batch of 5 files to refactor (with brief rationale for ordering).

Wait for my approval before beginning any code modifications.
```

---

## Usage Tips

1. **Start the session** by pasting this prompt into Claude Code while in your Roblox project repository.

2. **Review the interface map carefully** — this is your safety net. If an interface is documented wrong, downstream changes could break things.

3. **Approve interface changes explicitly** — if Claude needs to change a function signature or export, it will ask. Don't let these slip through.

4. **Review batch summaries carefully** — Claude will pause after each batch of 5 files and wait for your "continue" signal.

5. **Test in Studio periodically** — after every 2-3 batches, pull the changes into Roblox Studio and playtest to catch issues early.

6. **Use the concerns list** — if Claude flags something as uncertain, investigate it yourself before moving on.

7. **Don't skip reconciliation** — Phase 3 catches cross-file issues that per-file checks miss.
