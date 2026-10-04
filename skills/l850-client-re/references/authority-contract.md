# L850 Evidence Authority Contract

This file is the compact carry-forward contract for the L850/850C project. The skill entry remains operational; this document defines what counts as evidence.

## Promotion rules

### PROVEN

Use only when the strongest applicable chain is present:

```text
bounded discovery
+ exact instruction proof
+ producer/consumer or server/protocol semantic join
+ runtime read-only evidence when the fact is inherently runtime-only
```

A decompiler label, a single string, or behavior resemblance is insufficient.

### BOUNDED_RULE_PROVEN

Use when the exact rule is mechanically established inside a bounded domain, but an exhaustive family/domain mapping is not available.

### BEHAVIOR_PROVEN_SEMANTIC_UNKNOWN

Use when consumers/producers prove behavior but no trustworthy semantic name exists.

### STATIC_EXHAUSTED_LIVE_ONLY

Use when all bounded static sources are exhausted and the missing fact depends on initialized runtime state, identity, allocator behavior, module mapping, or live lifecycle.

### RESOURCE_MISSING

Use when the algorithm/format is known but the required authoritative resource payload is absent.

## Address rule

Known 850C addresses are absolute runtime VAs, not RVAs.

```text
runtime image base = 0x00400000
raw offset = VA - 0x00400000
```

Never add 0x00400000 twice.

## Frozen examples

- OwnedSkill client key = serverSkillId - 1.
- entity+0x94 = dead flag.
- entity+0x71 = msg119 poison bit.
- entity+0x74 = paralysis bit.
- entity+0xB0 = masterName.
- code11 = DestructableDoor.
- code6 = local-owner match variant.
- code5 = foreign-owner match variant.
- action RX for UseItem/Cast/Attack/Repair/Move is state-only, no request id.
- item +0x26 is native itemdesc selector, not universal server ItemId.

## Fail-closed rules

- Unknown family mapping => do not promote to product authority.
- Cached live_item pointer after inventory RX => re-resolve before action.
- Missing request id => do not infer per-request success solely from timing/state.
- Missing runtime process => continue static RE; mark runtime-only subproblem blocked.
- Missing Git access => continue in offline workspace; do not modify dirty checkout.
