---
cursor:
  subagentId: "bc-56b7f21b-6733-5c83-aa9b-464b6ed37d56"
---

# v1.13 verification — take the trade (Abdi 12:08)

## Live bug (v1.12 screenshot ~12:08)

XAUUSD.m M1: Status RUNNING, Send IDLE, **Gate: RR 0.80 < min 1.50**, Quality 0/min 45, Scalp SELL armed, balance 100.00 / **zero orders**. Price 4187→~4169.6 (GARAB BUY zone) then bounce ~4172. Root cause: hard RR gate before quality (Q stayed 0).

## Fix (v1.13)

| Gate | v1.12 | v1.13 trend-aligned |
|------|-------|---------------------|
| RR ≥ 1.5 | **HARD DROP** | Soft: extend TP = max(struct, 1.5R, 1.5×ATR); log `RR soft … NO DROP` |
| Quality ≥ 45 | Hard drop (often never reached) | Soft-allow + flow floor 50; `Quality soft-allow … NO DROP` |
| Cooldown / chop / spread / one-per-bar / backoff | Could stall | `TREND-TAKE soft-bypass` when flow + proposal agree |
| Session / day lock / halt | Hard | Unchanged (defaults OFF for session/day) |
| $5 SL cap | Keep | Keep (lot unchanged) |

`desired` now prefers `g_candleFlow` over HTF. Dashboard: Action SELL/BUY ACTIVE, Block reason, Stats prop/softRR/drop*/EXEC.

## Replay — Abdi drop + bounce

### v1.12 (reproduced)

```
PROPOSE SCP SELL → GATE drop — RR 0.80 < min 1.50
PROPOSE KIL SELL → GATE drop — RR 0.30 < min 1.50
PROPOSE GRB BUY  → GATE drop — RR 0.43 < min 1.50
COUNTS: propose=3 dropRR=3 EXEC=0
```

### v1.13 (required)

```
PROPOSE SCP SELL → RR soft 0.80 NO DROP → EXECUTED SELL SCP
PROPOSE KIL SELL → RR soft 0.30 NO DROP → EXECUTED SELL KIL
PROPOSE GRB BUY  → RR soft 0.43 NO DROP → EXECUTED BUY GRB
COUNTS: propose=3 softRR=3 dropQ=0 dropOth=0 EXEC=3
```

Mirror rising: EXECUTED BUY + EXECUTED SELL (EXEC=2).

JSON: `/tmp/v113-abdi-replay.json`

## Ship

- Loud: `docs/00_KAN_WAA_V113_MASTER_LOAD_THIS.mq5`, `docs/!!!_READ_ME_FIRST_v1_13_ABDIHAKIIM_JAMAAL.mq5`
- Also: `EA_BOT_ABDIHAKIIM_JAMAAL_MASTER_v113.mq5` (v112 kept)
- `.ex5`: Wine MetaEditor anti-debug/hang in this VM — **Abdi F7** for 0/0 `.ex5`
