---
name: l850-client-re
description: Dedicated reverse-engineering workflow for the L850 / 850C Lineage 8.5 client project, including Lin.bin2, 850Launcher, AutoHunt, Helper, Ghidra, Capstone, Argus read-only runtime evidence, server/client protocol cross-proof, and frozen ABI authority.
license: MIT
compatibility: Windows-first. Requires the L850 project files plus Python/Capstone and Ghidra. Argus MCP is used read-only when a runtime process exists.
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

# L850 / 850C Client Reverse Engineering

## ACTION REQUIRED（讀完後立刻執行）

1. `NOW`: 讀取 `references/authority-contract.md`，載入 L850 frozen authority 與證據分級。
2. `NOW`: 讀取 `config/l850-profile.json`，不得自行猜測 client hash、runtime-image hash、image base 或核心 anchor。
3. `NEXT`: 執行 `scripts/start-l850-re.ps1`；它會先呼叫 case initializer 驗證權威 SHA256，再強制檢查 Ghidra、Python/Capstone、Argus package，輸出 `l850-tool-audit.json`。
4. `NEXT`: 若 Ghidra/Capstone 缺失，依 package bootstrap/既有安裝規則處理；Argus 使用既有本機路徑，不自動安裝第二份。
5. `ACT`: 從目前最高優先級未閉合項目開始，強制產生新的 Ghidra/Capstone 證據；遇 runtime-only blocker 且遊戲進程存在時，使用 Argus 唯讀驗證。

## 適用範圍

本 skill 專供以下專案／關鍵字：

- L850 / 850C / L1JTW8.5 / Lineage 8.5 client RE
- `Lin.bin2`
- 850Launcher / PotionBridge850 / Helper / AutoHunt
- OwnedSkill、UseItem、Cast、Attack、Move、Inventory、HP/MP、class-code、range、lifecycle
- 381 / 880 → 850C binary-diff / symbol migration

其他一般二進位逆向請走 `reverse-engineering/` 或 `ghidra-reverse/`。

## 核心原則

```text
Ghidra = discovery / bounded decompile / xref / P-code
Capstone = exact instruction / ABI proof
Argus = read-only runtime evidence for facts static analysis cannot close
Server + DB = semantic authority / protocol cross-proof
850C authority = final adjudication
```

### 絕對禁止

```text
whole-image Ghidra analysis
whole-image Capstone scan
memory write
binary patch
packet send
input injection
game action generated for evidence
reset/clean/stash of dirty user worktrees
promoting decompiler output alone to PROVEN
```

### 允許

```text
bounded Ghidra analysis around explicit anchors
hash-pinned focused Capstone probes
read-only Argus process attach / memory read
server source / DB read-only cross-proof
offline evidence workspace when Git is unavailable
```

## Frozen Authority

以下內容預設不得重做，除非出現直接矛盾的機械證據：

### Binary identity

```text
CLIENT_SHA256=FAB9DB971F22BF91D06BB36485AAAABFFAEA795BB0DCC22D2EB4039227F54AD4
RUNTIME_IMAGE_SHA256=DEB116644000DB00BF2A54101AE6F923C89C073FBE3F1CA6FDF231CD2A21FCB3
IMAGE_BASE=0x00400000
```

### OwnedSkill

```text
client learned key = serverSkillId - 1
service=0x01713508
getter=0x005AC3A0
predicate=0x00F8E650
STATUS=PROVEN
```

### Inventory

```text
owner=*(u32*)0x0157A2D8
array root=owner+0x54
ObjectId getter=0x00D5DD60 -> +0x08
Quantity getter=0x00D5DB60 -> +0x20
itemdesc selector getter=0x00D5DDE0 -> +0x26
UseItem entry=0x00AEEFB0
```

`live_item+0x26` MUST NOT be treated as a universal stable server ItemId.

### Entity/status

```text
dead=entity+0x94
entity+0x71=msg119 poison bit
entity+0x74=paralysis bit
entity+0xA0=displayName
entity+0xB0=masterName
local-owner relation=masterName nonempty && masterName == local displayName
```

Historical Pet/Summon guesses based on +0x71/+0x74 are forbidden.

### Classification

```text
code11=DestructableDoor PROVEN
code6=LOCAL_OWNER_MATCH_VARIANT bounded-proven
code5=FOREIGN_OWNER_MATCH_VARIANT bounded-proven
code12=BEHAVIOR_PROVEN_SEMANTIC_UNKNOWN
0x00BA0050=masterName NON-EMPTY gate
```

### Action protocol

```text
UseItem/Cast/Attack/Repair/Move = PROTOCOL_STATE_ONLY_NO_REQUEST_ID
ACTION_TIMEOUT_RESULT = NOT_REPRESENTED_BY_PROTOCOL
Cast action+0x7C = local boolean only
```

## 工具強制規則

### Ghidra

每個 work cycle MUST 至少使用一次 bounded Ghidra，除非本輪只是在回填已存在的 exact proof。

對每個要升級的候選函式／欄位，記錄：

- function VA
- callers/xrefs
- field/data-flow
- bounded decompile/instruction window
- semantic naming reason

### Capstone

每個要升級成 `PROVEN` 的重要 ABI/function MUST 有 focused Capstone exact proof。

Probe MUST：

- 驗證 runtime-image SHA256
- 明確使用 absolute VA（runtime image base = 0x00400000）
- 有 bounded instruction range
- 不做 whole-image scan

### Argus MCP

預設路徑：

```text
I:\Lineage-tools\argus_mcp_reverse-skill
```

Argus 用於 runtime-only blocker：

- pointer/table value
- runtime selector/index
- loaded module/address mapping
- object identity/replacement
- table_A initialized contents
- lifecycle/reuse observation

如果沒有可自動發現的 850C/Lineage process：

```text
ARGUS_MCP_STATUS=BLOCKED_NO_TARGET_PROCESS
```

此狀態 MUST NOT 阻止可繼續的 static RE。

Argus 僅允許 read-only evidence。

## Priority Queue

### P0-A Action calling context

Anchors：

```text
UseItem=0x00AEEFB0
CastSelf=0x00F906B0
CastTargeted=0x00F908B0
Attack=0x00B9B6F0
Move=0x00B9BFF0
RepairOwner=0x00AEE840
RepairCallback=0x00544EA0
CommonSubmit=0x00B594B0
```

輸出：

```text
COMMON_ACTION_READY
ACTION_THREAD_CONTEXT
ACTION_LOCK_MODEL
REENTRANCY_MODEL
```

### P0-B Range

Anchors：

```text
0x00543CB0
0x00543CCB
0x00BA891D
0x0793254C
0x0159E864
```

閉合 normal attack / weapon / skill / targeted-cast range 與 selector/index/domain。

### P0-C Classification residual

```text
0x0170DFB0
0x0170DF0C
entity+0x86
entity+0x70
raw5->10
code12
```

保留 5/6/11 frozen authority。

### P0-D Lifecycle / freshness

- LocalPlayer create/clear/replace
- same-address reuse
- inventory generation/rebuild
- HP/MP freshness after login/relog/map transition

### P0-E Movement stop

- registration
- disable/unregister
- pending callback drain
- post-stop callback count

### P1

- inventory object lifetime
- HP/MP/buff/transform/repair/teleport/periodic item families
- transform/invisibility/poison/paralysis/cast-delay predicates
- external timebase provider/unit/monotonicity

### P2 Skills

```text
魂體轉換
心靈轉換
魔力奪取
暗影閃爍
暗夜閃爍
初級治癒術
中級治癒術
高級治癒術
全部治癒術
```

每個 skill 必須證明 server skillId、OwnedSkill lookup、cast target mode、range、readiness/cooldown、state/effect result model。

## Git unavailable / dirty checkout mode

Git fetch/switch 失敗時 MUST NOT 停止 RE。

使用：

```text
C:\Tools\850-re-unified-offline
```

目前 checkout 只讀，不做 reset/clean/stash/switch。

所有新 evidence/script/report 存入 offline workspace，Git 恢復後再回填。

## 證據分級

允許：

```text
PROVEN
BOUNDED_RULE_PROVEN
BEHAVIOR_PROVEN_SEMANTIC_UNKNOWN
PROTOCOL_STATE_ONLY_NO_REQUEST_ID
STATIC_EXHAUSTED_LIVE_ONLY
RESOURCE_MISSING
REJECTED
```

不得用模糊的 `PARTIAL` 取代已知的 blocker 類型。

## 共用根目錄配置

L850 reverse-skill 與 Argus MCP 預設共用同一個根目錄：

```text
I:\Lineage-tools\argus_mcp_reverse-skill
```

推薦佈局：

```text
I:\Lineage-tools\argus_mcp_reverse-skill\
├─ <Argus 原始檔>
├─ skills\
│  ├─ l850-client-re\
│  ├─ scripts\
│  └─ ...
└─ L850_REVERSE_SKILL_INSTALL.json
```

不要另外建立 `reverse-skill-L850` 目錄。

若要把 reverse-skill checkout 併入既有 Argus 根目錄，執行：

```powershell
powershell -ExecutionPolicy Bypass -File .\skills\l850-client-re\scripts\install-integrated-argus-root.ps1
```

安裝器只替換／備份 `skills\`，不刪除 Argus 原始檔。

### Defender-safe minimal install

When Windows Defender blocks generic security content from the full reverse-skill repository, use:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-integrated-safe-subset.ps1
```

This installer downloads only:

```text
skills/l850-client-re/
skills/config/routing.json
skills/scripts/master-route.ps1
skills/scripts/lib/WorkRoot.ps1
skills/scripts/lib/ToolDiscovery.ps1
skills/MASTER-ROUTING.md
skills/SKILL.md
skills/INDEX.md
skills/routing.md
```

It intentionally does **not** download generic pentest/malware/exploit payload material. Optional generic reverse-engineering modules can remain outside this integrated Argus root; L850 operation does not depend on them.

## 專案執行工具

### 一鍵 smoke

```powershell
powershell -ExecutionPolicy Bypass -File scripts\smoke-l850.ps1
```

用途：

- 驗證 R46 專案路由
- 驗證 L850 profile/必要檔案
- 執行 mandatory tool gate
- 區分 Argus package / server process / target process 狀態

只測 package 結構可用：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\smoke-l850.ps1 -StaticOnly
```

### bounded RE runner

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-l850-bounded.ps1 -VA 0x00AEEFB0
```

預設一定產出 hash-pinned Capstone bounded window。

若已有隔離 Ghidra project，可同時要求 Ghidra `-noanalysis` bounded evidence：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-l850-bounded.ps1 \
  -VA 0x00AEEFB0 \
  -GhidraProjectDir "C:\Tools\850-re\projects" \
  -GhidraProjectName "L850" \
  -GhidraProgramName "Lin.bin2"
```

### Argus 狀態

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check-argus-status.ps1
```

MUST 區分：

```text
package exists
Argus server process detected
850C target process detected
runtime evidence actually available
```

不得以「資料夾存在」代替 runtime availability。

### offline evidence 回填

只允許回填到**乾淨、正確 branch 的隔離 worktree**：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\import-offline-evidence.ps1 \
  -TargetRepo "C:\Tools\850-re\client-re-unified" \
  -Commit -Push
```

dirty worktree 或 branch 不符時 MUST fail-closed。

## 381 / 880 migration

當 hash-identifiable 381/880 binary/evidence 存在時 MAY 使用 `binary-diff` 方法遷移候選。

所有遷移候選 MUST 回到 850C Ghidra + Capstone 驗證。

## 產物

每一輪 MUST 更新：

```text
report
focused evidence
focused probe/script
tool usage audit
NEXT priority
```

Tool audit：

```text
GHIDRA_USED=
GHIDRA_ANCHORS=
CAPSTONE_USED=
CAPSTONE_PROBES=
ARGUS_MCP_STATUS=
ARGUS_MCP_USED=
ARGUS_EVIDENCE=
SERVER_CROSS_PROOF_USED=
WHOLE_IMAGE_ANALYSIS=NO
MEMORY_WRITE=NO
PACKET_SEND=NO
GAME_ACTION=NO
```

## 語言行為契約

- 內部工具選擇與 phase control：English。
- 使用者可見回報與報告：繁體中文。
- 地址、函式名、狀態常數維持原始英文/十六進位格式。

## 路由上下文

**上游**: MASTER R46  
**下游**: `ghidra-reverse/`, `protocol-reverse/`, `binary-diff/`, `case-review/`  
**同級**: `reverse-engineering/`, `thick-client/`

## 任務完成自檢

- [ ] 是否先驗證 client/runtime-image SHA256？
- [ ] 是否真的使用 bounded Ghidra，而不是只讀舊報告？
- [ ] 重要 PROVEN 是否有 focused Capstone exact proof？
- [ ] runtime-only blocker 若 process 存在，是否使用 Argus 唯讀證據？
- [ ] 是否保持 server/client semantic cross-proof？
- [ ] 是否沒有 whole-image analysis / memory write / packet send / game action？
- [ ] 是否沒有破壞 dirty worktree？
- [ ] 是否把 blocker 精確分類，而不是泛稱 PARTIAL？
- [ ] 是否追加報告/evidence 而非刪除歷史？
