---
cursor:
  subagentId: "bc-56b7f21b-6733-5c83-aa9b-464b6ed37d56"
---

# v1.12 direction verification — BUY + SELL follow chart flow

**Question (Abdi):** Does the EA enter BUY and SELL, both directions, following the trend?

**Verdict:** Yes for v1.12 source — dual mirrored engines + hard candle-flow gate. Strategy Tester on XAUUSD is **unavailable** in this Wine MT5 (no XAUUSD history). Evidence below = code audit + synthetic mirrored OHLC. One Killer asymmetry was found and fixed before ship.

---

## 1. Code audit — hard-wired direction?

### Global filters (defaults allow both)

| Symbol / input | Default | Role |
|----------------|---------|------|
| `InpTradeDirection` | `TRADE_BOTH` | Only blocks a side if user sets BUY-only / SELL-only |
| `TradeDirAllows(dir)` | allows ±1 | Used by every `TryOpen` / propose path |
| `InpRequireCandleFlow` | `true` | **Hard gate:** BUY only when flow UP, SELL only when flow DOWN |
| `InpAllowCounterTrend` | `false` | CT path off unless Aggressive + explicit ON |
| `InpDirectionSource` | `DIR_CHART_TF` | Chart/M1 flow leads (fixes v1.11 HTF-BULL→BUY on M1 drop) |

### X-space (mirrored BUY/SELL)

All structural scans use `XH/XL/XC/XO` with `dir = +1` or `-1` so SELL is the mathematical mirror of BUY (`x = dir * price`).

### Per-engine dual paths

| Engine | BUY path | SELL path | Same function? |
|--------|----------|-----------|----------------|
| **Unicorn** | `UnicornScan(..., +1, ...)` | `UnicornScan(..., -1, ...)` | Yes — one scan, both called |
| **Killer** | `KillerScan(..., +1, ...)` | `KillerScan(..., -1, ...)` | Yes |
| **Scalp** | `ScalpScan(+1, ...)` | `ScalpScan(-1, ...)` | Yes |
| **Book** (CRT/ISK/GARAB/QAW) | `for (d = -1; d <= 1; d += 2)` | same loop | Yes |
| **ImpulseCont / SerialCont** | `TryContinuationFallback(+desired)` with dir-mirrored BOS/CHoCH/EMA | same | Yes |
| **Flip-reverse** | `g_pendingFlipDir = -dir` after FLIP EXIT; engines re-scan opposite on `g_flipEnterNow` | both | Yes |

Dashboard columns always fill `g_engWhyBuy[*]` and `g_engWhySell[*]` even when FINAL waits.

### Bug found + fixed (pre-ship)

**Killer continuation EMA touch** compared `XL(r,k,dir)` (X-space) to **raw** `ema[1]` (price-space). For `dir = -1`, `XL = -high` is always ≤ raw EMA → SELL “touched EMA” was nearly always true (asymmetric ease).

**Fix:** use `xEma = dir * ema[1]` then `XL <= xEma + 0.20*ATR` (same mirror as CONT’s price-space branch).

No other XL/XH vs raw-price asymmetries found that hard-wire one side.

### Against-flow entries

With defaults, `DirectionAllowed` + `TryOpen` flow gate **reject** `dir != g_candleFlow`. Against-flow is only possible if `InpAllowCounterTrend=true` (and Aggressive) or `InpRequireCandleFlow=false`.

---

## 2. Strategy Tester (Wine MT5)

| Item | Result |
|------|--------|
| `metatester64.exe` | Present |
| XAUUSD history under `Bases/Default/History` | **Missing** (only EURUSD / GBPUSD / USDCHF / USDJPY) |
| Oct 14 / Oct 19 XAUUSD M1/M15 tester run | **Not possible** in this environment |
| MetaEditor `/compile` | Hangs / anti-debug under Wine (no `.ex5` this run) |

**Fallback used:** synthetic mirrored-data check (below).

### Live screenshots (prior builds — context, not v1.12 tester)

| Shot | Version | Observation |
|------|---------|-------------|
| `2026-10-19-0744-v111-m1-history.png` | v1.11 | History pane: **BUY-only** stack while M1 printed LH/LL / Exec=BEAR — **against chart-TF flow** (HTF FINAL BULL lead). This is the defect v1.12 ChartTF + flow gate fixes. |
| `2026-10-14-0733-v110-trade.png` | v1.10 | FINAL BEAR, gate “looking for SELL”, engines show **B:… S:…** dual columns — SELL-side path alive when bias was bear. |

---

## 3. Synthetic mirrored OHLC check

Script: invert every OHLC around first close (`high↔low`), re-run BOS + EMA-pullback + candle-flow gate.

### Unit mirrors

| Test | Result |
|------|--------|
| BOS BUY(up) == BOS SELL(invert) | PASS |
| BOS SELL(up) == BOS BUY(invert) | PASS |
| `flow(up) == -flow(invert)` | PASS |
| CONT EMA-pullback mirror | PASS |
| Killer BUG: SELL touch always-true on uptrend | **Confirmed** |
| Killer FIXED: X-space EMA touch | PASS |

### Mixed session (up-leg + down-leg)

| Metric | Original | Price-inverted series |
|--------|----------|------------------------|
| BUY entries | **6** | **22** |
| SELL entries | **22** | **6** |
| With chart-TF flow | **28 / 28 (100%)** | (mirrored) |
| Against-flow taken | **0** | **0** |
| Flow-flip events | 1 | (mirrored) |
| Mirror deltas \|BUY−origSELL\| / \|SELL−origBUY\| | **0 / 0** | PASS |

Trend-aligned % (synthetic gate): **100%**.  
BUY:SELL on mixed leg ≈ 6:22 then exact swap under invert → both directions fire; imbalance follows which leg is longer/stronger in the synthetic series, not a hard-wired side.

---

## 4. Against-flow flag

| Case | Against chart-TF flow? |
|------|------------------------|
| v1.11 live Oct 19 BUYs into M1 BEAR | **Yes** (HTF lead) — fixed in v1.12 by `DIR_CHART_TF` + `InpRequireCandleFlow` |
| v1.12 synthetic entries | **None** (0 against-flow) |
| v1.12 default CT | Off — cannot open against clear flow |

---

## 5. Ship notes

- Source: `docs/EA_BOT_ABDIHAKIIM_JAMAAL_MASTER_v112.mq5` (+ master `.mq5` / `.txt`)
- Compile `.ex5`: **Abdi F7** on Windows MT5 (Wine MetaEditor blocked here)
- Keep: `$5` SL money cap, BE 1R, peak lock, serial-add / flip-now / IDLE-WATCHDOG

**Somali numbers for Abdi (synthetic evidence):** BUY **6**, SELL **22**, trend-aligned **100%** (invert mirrors 22/6). Live XAUUSD tester not available in this VM.
