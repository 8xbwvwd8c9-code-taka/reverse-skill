# reverse-skill WORKLOG

DATE_UPDATED=2026-10-04
POLICY=APPEND_ONLY

## 2026-10-04 — L850 integrated package

### Productized L850 specialization

The L850 route/skill package is integrated into reverse-skill main and installed under one Argus root:

```text
I:\Lineage-tools\argus_mcp_reverse-skill
```

L850 skill:

```text
skills/l850-client-re/SKILL.md
```

Routing authority:

```text
R46=L850 / 850C Client RE
R46_PRIORITY_FIRST=YES
ROUTING_BENCHMARK_CASES=182
ROUTING_BENCHMARK_FAILURES=0
L850_ROUTE_CASES=4/4 PASS
```

Tool model:

```text
Ghidra=bounded discovery/xref/decompile
Capstone=exact instruction/ABI proof
Argus=read-only runtime-only evidence
server+DB=semantic/protocol cross-proof
850C authority=final adjudication
```

### Safe installer evolution

Final safe install strategy:

```text
fixed 23-file allowlist
raw.githubusercontent.com downloads
no recursive GitHub Contents API walk
backup existing skills tree before install
marker=L850_REVERSE_SKILL_INSTALL.json
automatic smoke disabled
```

Final successful user-side install:

```text
INSTALL_STATUS=PASS
MANIFEST_COUNT=23
DOWNLOADED_COUNT=23
READY=YES
INSTALLER_EXIT=0
FINAL_STATUS=PASS
NO_SMOKE_RUN=YES
```

Latest main at completion:

```text
3c6c321f0bcab4cb19841d779d39bfe4b83bf7a8
```

### Operational contract

Client RE agents must use:

```text
I:\Lineage-tools\argus_mcp_reverse-skill
I:\Lineage-tools\argus_mcp_reverse-skill\skills\l850-client-re\SKILL.md
```

Do not silently substitute the retired `I:\L共通工具\argus_mcp_reverse-skill` path or clone a second Argus package.
