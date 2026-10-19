---
cursor:
  subagentId: "bc-56b7f21b-6733-5c83-aa9b-464b6ed37d56"
---

# v1.14 delivery — pullback entry + BE trail + flow flip

## Abdi live v1.13 (~12:54)

Sold at bottom after 4187→4167 (late `impulseFollow`), then missed BUY bounce from GARAB zone (~4167→4172). Stats: prop 34 / softRR 1 / EXEC 2. Daily P/L −23.20 is display; daily lock remains OFF (`InpDailyMaxLossPct=0`).

## Three rules (verified in replay)

1. **Entry** at pullback/retest in flow — late-chase veto when extension > `InpMaxExtensionATR` (1.5); prefer EMA/BOS/CHoCH over impulse-at-extreme.
2. **BE @ 1R** then ladder + structure trail; BE-FLOOR / PEAK50 so a win cannot become a loss.
3. **Flow flip** via micro CHoCH/reclaim → BUY↔SELL; flip-now reverse kept.

## Replay

| Case | Result |
|------|--------|
| Late SELL @ bottom | REJECT late-chase 4.9ATR |
| SELL EMA pullback mid-drop | EXECUTED SELL |
| BUY bounce reclaim (flow v13 stuck DOWN → v14 UP) | EXECUTED BUY |
| Flip-now after flow flip | EXECUTED BUY |

## Ship

Loud: `docs/00_KAN_WAA_V114_MASTER_LOAD_THIS.mq5`, `docs/!!!_READ_ME_FIRST_v1_14_ABDIHAKIIM_JAMAAL.mq5`  
Also `EA_BOT_ABDIHAKIIM_JAMAAL_MASTER_v114.mq5`; v113 kept.  
`.ex5`: Wine anti-debug — Abdi F7.
