# L850 specialization validation — 2026-10-04

## Scope

Validation of the L850/850C specialization added on branch:

```text
work/l850-client-re-specialized-20261004
```

## Static validation results

```text
ROUTING_BENCHMARK_CASES=182
ROUTING_BENCHMARK_FAILURES=0
R46_PRIORITY_FIRST=YES
L850_ROUTE_CASES=4/4 PASS
L850_PROFILE_JSON=PASS
CAPSTONE_PYTHON_SYNTAX=PASS
CAPSTONE_HASH_GUARD=PRESENT
CAPSTONE_MODE=x86/32
GHIDRA_BOUNDED_RUNNER=-noanalysis
ARGUS_STATUS_SPLIT=PACKAGE/SERVER_PROCESS/TARGET_PROCESS
OFFLINE_IMPORT_PS51_COMPAT=YES
DIRTY_WORKTREE_FAIL_CLOSED=YES
WHOLE_IMAGE_ANALYSIS=NO
MEMORY_WRITE=NO
PACKET_SEND=NO
GAME_ACTION=NO
```

## Added execution-hardening tools

```text
scripts/smoke-l850.ps1
scripts/check-argus-status.ps1
scripts/run-l850-bounded.ps1
scripts/bounded-capstone.py
scripts/ghidra/L850BoundedWindow.java
scripts/import-offline-evidence.ps1
```

## Notes

- The current assistant execution container has no PowerShell runtime, so Windows-local execution of `smoke-l850.ps1` was not performed here.
- The smoke script is intended to run on the user's Windows host and includes the real R46 router invocation plus local Ghidra/Capstone/Argus discovery.
- Existing repository CI workflows were not observed running for this fork branch at validation time.
- The Python bounded Capstone helper was independently syntax-compiled successfully.
- The offline importer avoids `System.IO.Path.GetRelativePath` to retain Windows PowerShell 5.1 compatibility.

## Local acceptance command

Run on the L850 Windows host after installing this branch:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\skills\l850-client-re\scripts\smoke-l850.ps1
```

Expected terminal result:

```text
STATUS=PASS
```

If Argus has no target process, that runtime-only condition is reported separately and does not invalidate static RE readiness.
