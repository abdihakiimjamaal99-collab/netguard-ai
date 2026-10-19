//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//!!  MJ-MASTER VERSION 1.15c — LATEST FIX BUILD — 2026-10-19       !!
//!!  v1.15c KILLER GATE (Abdi live K −$18.12 / 18 trades):         !!
//!!   K losses = morning BUY chase into BEAR + impulse SELLs → SL  !!
//!!   FIX: Killer = pullback/retest ONLY + chart-flow + MSS/struct !!
//!!        NO impulse-displacement / late-chase K entries          !!
//!!  Keep: BE lock 1.15b | Scalp/CONT OFF | GF untouched | BUY+SELL!!
//!!  Haddii aad aragto sadarkan, waa version-ka ugu dambeeyay      !!
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//+------------------------------------------------------------------+
//|                              EA_BOT_ABDIHAKIIM_JAMAAL_MASTER.mq5 |
//|                     Unified master EA  -  Abdihakiim Jamaal      |
//|  *** VERSION 1.15c — Killer pullback-only + BE lock ***
//+------------------------------------------------------------------+
//|  Single-file MetaTrader 5 Expert Advisor.                        |
//|                                                                  |
//|  Engines  : ICT Unicorn, ICT Killer Start, Multi-tier Scalp,     |
//|             5-in-1 Book engine (CRT / Iskulaab / GARAB /         |
//|             Qawaaniinta / Auto)                                   |
//|  Core     : one central entry gate (arbiter), symbol profiles,   |
//|             strict SL-based risk, send-flight reconciliation,    |
//|             per-ticket ladder protection, on-chart dashboard.    |
//|                                                                  |
//|  Sections :  0 Enums            7 Risk / lot sizing              |
//|              1 Inputs           8 Send tracking & execution      |
//|              2 Structs/globals  9 Signal engines                 |
//|              3 Utilities       10 Entry gate (arbiter)           |
//|              4 Symbol profile  11 Position protection            |
//|              5 Market data     12 Dashboard                      |
//|              6 Filters         13 Event handlers                 |
//+------------------------------------------------------------------+
#property copyright   "Abdihakiim Jamaal"
#property link        ""
#property version     "1.15"
#property description "Unified MT5 EA: ICT Unicorn + Killer Start + Multi-tier Scalp + 5-in-1 Book engine."
#property description "One central entry gate, per-symbol profiles, strict SL-based risk, send reconciliation,"
#property description "v1.15c: Killer pullback+flow+MSS only (no impulse chase). Single file."
#property strict

//==================================================================
//  SECTION 0 : ENUMS
//==================================================================
enum ENUM_BOOK_MODE
  {
   BOOK_AUTO      = 0, // Auto (highest scoring book)
   BOOK_CRT       = 1, // CRT only (Candle Range Theory)
   BOOK_ISKULAAB  = 2, // Iskulaab only (breakout + retest)
   BOOK_GARAB     = 3, // GARAB Law & Order only (OB chain)
   BOOK_QAWAANIIN = 4  // Qawaaniinta only (IC sweep)
  };

enum ENUM_SEND_STATE
  {
   SEND_NONE       = 0,
   SEND_IN_FLIGHT  = 1,
   SEND_DONE       = 2,
   SEND_AMBIGUOUS  = 3,
   SEND_UNRESOLVED = 4,
   SEND_FAILED     = 5
  };

enum ENUM_ENGINE_ID
  {
   ENG_UNICORN = 0,
   ENG_KILLER  = 1,
   ENG_SCALP   = 2,
   ENG_BOOK    = 3,
   ENG_COUNT   = 4
  };

enum ENUM_PROFILE_ID
  {
   PROF_DEFAULT = 0,
   PROF_GOLD    = 1,
   PROF_SILVER  = 2,
   PROF_EURUSD  = 3,
   PROF_BTC     = 4
  };

enum ENUM_ENTRY_MODE
  {
   ENTRY_CONSERVATIVE = 0, // Strict ICT filters
   ENTRY_BALANCED     = 1, // Medium
   ENTRY_AGGRESSIVE   = 2  // Fire on pullback/retest (default)
  };

enum ENUM_TP_MODE
  {
   TP_TRAIL   = 0, // Let winners run: BE + ladder + structure trail (default)
   TP_FIXED_R = 1  // Fixed R-multiple take profit
  };

enum ENUM_TRADE_DIRECTION
  {
   TRADE_BOTH      = 0, // Scan and trade BUY + SELL (default)
   TRADE_BUY_ONLY  = 1, // BUY only
   TRADE_SELL_ONLY = 2  // SELL only
  };

enum ENUM_DIRECTION_SOURCE
  {
   DIR_CHART_TF = 0, // Chart TF drives direction (default — follow this chart)
   DIR_HTF_LEAD = 1  // Legacy: H1/H4 lead, Exec as pullback context
  };

//==================================================================
//  SECTION 1 : INPUTS
//==================================================================
input group "=== 1. General ==="
input long              InpMagic               = 20261013;        // Magic number
input ENUM_TIMEFRAMES   InpExecTF              = PERIOD_CURRENT;  // Execution TF (CURRENT = chart TF — chart has priority)
input ENUM_DIRECTION_SOURCE InpDirectionSource = DIR_CHART_TF;    // Primary direction source
input bool              InpHTFHardFilter       = false;           // If true, HTF must agree (soft filter when false)
input bool              InpRequireCandleFlow   = true;            // Entry dir must match last 2–3 chart/M5 candles
input ENUM_ENTRY_MODE   InpEntryMode           = ENTRY_BALANCED;  // Entry aggressiveness (v1.15: fewer but better)
input ENUM_TRADE_DIRECTION InpTradeDirection   = TRADE_BOTH;      // Trade direction filter
input bool              InpAllowCounterTrend   = false;           // Allow entries against chart flow (default OFF)
input bool              InpUseContinuationFallback = false;       // Impulse CONT (v1.15b OFF — live IMP −$7.7)
input int               InpContWaitBars        = 4;               // Bars of clear chart bias before continuation
input double            InpPullbackMaxATR      = 2.0;             // Pullback deeper than N×Exec ATR → WAIT (no counter)
input double            InpMaxExtensionATR     = 1.5;             // Late-chase veto: no impulse entry if >N×ATR from swing extreme
input bool              InpPreferPullbackEntry = true;            // Prefer EMA/BOS pullback-retest over impulse-at-extreme
input double            InpMinInitialRR        = 1.8;             // Soft RR / expectancy floor: TP ≥ N×SL (avg-win ≥ avg-loss target)
input double            InpTPATRExtension      = 1.5;             // ATR multiple floor for TP when structure is near
input int               InpMinEntryQuality     = 70;              // Min entry location quality 0–100 (Aggressive lowers)
input int               InpFlowAlignQualityFloor = 58;            // With chart-flow: floor quality score (v1.15 tighter)
input int               InpMaxPositions        = 1;               // Max positions (v1.15 default 1; set 2 for serial-add)
input double            InpAddAfterR           = 1.0;             // Same-dir add only after open ticket ≥ this R (or BE+)
input bool              InpAllowHedge          = false;           // Allow opposite position while one is open (never for flip — close first)
input bool              InpBlockReentryInDD    = true;            // Never add to / stack while any same-dir ticket in drawdown
input int               InpCooldownBarsAfterLoss= 10;              // Cooldown Exec bars after a loss (0 = off)
input bool              InpReverseOnFlowFlip   = true;            // Exit + reverse when chart flow flips against position
input bool              InpFlipEnterImmediate  = false;           // After flip exit, enter opposite same bar (v1.15 OFF — less whipsaw)
input int               InpFlipChopBars        = 10;              // Chop window (chart bars; v1.15 tighter)
input int               InpChopPauseBars       = 20;              // Pause entries after chop (chart bars)
input int               InpChopFlipMin         = 2;               // Pause when ≥N flow flips inside ChopBars (was hard 3)
input bool              InpUseRangeChopFilter  = true;            // Block entries in compressed/range chop
input int               InpRangeChopBars       = 24;              // Lookback bars for range-chop filter
input double            InpRangeChopMaxATR     = 2.2;             // If (high-low) ≤ N×ATR → range chop (block)
input bool              InpHardBlockChopCooldown = true;          // v1.15: CHOP + loss-cooldown NEVER soft-bypassed
input double            InpMinExpectancyRR     = 1.0;             // Require TP distance ≥ N×SL before send (1=avg win≥avg loss)
input int               InpIdleWatchBars       = 0;               // IDLE-WATCHDOG relax (0=OFF — v1.15: was forcing weak entries)
input int               InpMaxSpreadOverride   = 0;               // Max spread points (0 = symbol profile)
input int               InpStopFloorExtraPts   = 3;               // Extra points above broker stop/freeze floor
input double            InpMaxSLATR            = 4.0;             // Reject entry if SL distance > N x ATR
input int               InpLogLevel            = 1;               // Experts log: 0 silent, 1 normal, 2 verbose
input bool              InpVerboseLog          = true;            // Legacy verbose (OR'd with LogLevel>=2)
input string            InpCommentTag          = "MJ";            // Order comment tag (max 4 chars)

input group "=== 2. Risk ==="
input double            InpRiskPercent         = 0.5;             // Risk per trade (% of balance) — lot sizing only
input double            InpMaxLossPerTradeMoney= 5.0;             // Max USD loss via SL distance at chosen lot (5 or 10; 0=off)
input int               InpMinStructuralSLPts  = 80;              // Min SL pts when capping SL to money
input double            InpFixedLot            = 0.0;             // Fixed lot (0 = risk-based sizing)
input bool              InpAllowMinLotOverRisk = true;            // Allow min lot even if it exceeds risk % (needed for small balances)
input double            InpMaxRiskPctAtMinLot  = 2.5;             // Cap effective risk % when forced to min lot (0 = off)
input bool              InpTightenSLForRisk    = true;            // Cap SL distance to money max at chosen lot (does NOT shrink lot)
input ENUM_TP_MODE      InpTPMode              = TP_TRAIL;        // Profit exit: Trail (default) or Fixed R
input double            InpTakeProfitR         = 0.0;             // Fixed TP in R (used when TPMode=Fixed R; 0 = none)
input double            InpDailyMaxLossPct     = 0.0;             // Daily max loss % (0 = OFF — no DAY LOCK)
input int               InpMaxTradesPerDay     = 12;              // Max entries per day (v1.15: stop 50-trade days; 0=OFF)
input int               InpMaxConsecLosses     = 4;               // Max consecutive losses (v1.15 ON; 0=OFF)
input int               InpCooldownAfterLossMin= 8;               // Cooldown after loss minutes (v1.15 ON; 0=OFF)
input double            InpEquityDDKillPct     = 0.0;             // Equity DD kill switch % (0 = OFF)
input bool              InpKillCloseAll        = true;            // Kill switch also closes all EA positions (if DD enabled)

input group "=== 3. Engines (priority: 1 = highest) ==="
input bool              InpEnableUnicorn       = true;            // ICT Unicorn (breaker + FVG overlap)
input int               InpPrioUnicorn         = 1;               // Unicorn priority
input bool              InpEnableKiller        = true;            // ICT Killer Start (trend + liquidity run)
input int               InpPrioKiller          = 2;               // Killer priority
input bool              InpKillerPullbackOnly  = true;            // v1.15c: K = EMA/structure pullback ONLY (no impulse disp)
input bool              InpKillerRequireFlow   = true;            // v1.15c: K dir must match chart candle flow
input bool              InpKillerRequireStruct = true;            // v1.15c: require HH/HL or LH/LL (no naked impulse)
input bool              InpKillerRequireMSS    = true;            // v1.15c: need liquidity run / micro MSS reclaim
input bool              InpEnableBook          = true;            // 5-in-1 Book engine
input int               InpPrioBook            = 4;               // Book priority
input ENUM_BOOK_MODE    InpBookMode            = BOOK_AUTO;       // Book mode
input double            InpMinBookScore        = 1.4;             // Book: minimum score to trade (stricter)
input bool              InpEnableScalp         = false;           // Multi-tier scalp (v1.15b OFF — live 0/4, −$7)
input int               InpPrioScalp           = 3;               // Scalp priority (lower = fires sooner; Book is 4)
input double            InpScalpMaxSLATR       = 2.0;             // Scalp: max SL distance (x ATR exec TF)
input int               InpStructLookback      = 80;              // Structure lookback (bars, exec TF)
input int               InpSwingStrength       = 2;               // Swing strength (bars each side)
input int               InpUnicornMaxWaitBars  = 8;               // Unicorn: max bars after MSS (stricter = fresher)

input group "=== 4. HTF bias ==="
input bool              InpUseHTFBias          = true;            // Require HTF bias agreement
input ENUM_TIMEFRAMES   InpBiasTF1             = PERIOD_H1;       // Bias timeframe 1
input ENUM_TIMEFRAMES   InpBiasTF2             = PERIOD_H4;       // Bias timeframe 2 (dominant)
input int               InpBiasEMAPeriod       = 50;              // Bias EMA period
input bool              InpAllowNeutralBias    = false;           // Trade when chart dir unclear (false = wait)
input bool              InpAllowExecPullback   = true;            // Allow pullback retest after confirmation only

input group "=== 5. Sessions / time ==="
input bool              InpUseSessions         = false;           // Trade only inside killzones (false = 24h; turn on for London/NY only)
input int               InpServerGMTOffset     = 99;              // Broker server offset from GMT (hours; 99 = auto-detect)
input string            InpLondonStart         = "07:00";         // London killzone start (GMT)
input string            InpLondonEnd           = "11:00";         // London killzone end (GMT)
input string            InpNYStart             = "12:00";         // New York killzone start (GMT)
input string            InpNYEnd               = "20:00";         // New York killzone end (GMT) — extended for GMT+2/+3 brokers
input bool              InpUseFridayCutoff     = false;           // Friday: stop new trades after cutoff (forex/gold only)
input string            InpFridayNoNewTrades   = "18:00";         // Friday: no new trades after (server time)
input bool              InpFridayCloseAll      = false;           // Friday: close all EA positions (forex/gold only; never BTC)
input string            InpFridayCloseTime     = "21:30";         // Friday: close-all time (server time)

input group "=== 6. News ==="
input bool              InpUseNewsWindows      = false;           // Use manual blackout windows
input string            InpNewsWindows         = "14:25-14:50;15:55-16:10"; // Windows HH:MM-HH:MM;... (server time)
input bool              InpUseCalendarNews     = false;           // Use MQL5 economic calendar (live only)
input int               InpNewsMinBefore       = 15;              // Calendar: blackout minutes before event
input int               InpNewsMinAfter        = 15;              // Calendar: blackout minutes after event
input bool              InpNewsHighOnly        = true;            // Calendar: high importance only

input group "=== 7. Protection ==="
input bool              InpUseBreakEven        = true;            // Instant break-even
input double            InpBreakEvenR          = 0.55;            // BE trigger in R (v1.15 earlier — M1 noise hits SL before 1R)
input double            InpBEProfitPctOfSL     = 55.0;            // BE when floating profit >= N% of SL (55 = 0.55R)
input double            InpBEAccountPct        = 3.0;             // BE when floating profit >= N% of equity (0 = off)
input int               InpBreakEvenPtsOverride= 0;               // BE trigger points (0 = profile)
input int               InpBEBufferOverride    = 0;               // BE buffer points (0 = profile)
input bool              InpBEIncludeSpread     = true;            // BE SL = entry ± (buffer + spread)
input bool              InpLockEmergencyClose  = true;            // If lock modify fails & profit at risk → close market
input int               InpLockModifyRetries   = 3;               // Retries on INVALID_STOPS / FROZEN
input double            InpPeakLockMinR        = 1.0;             // Start peak% lock once peak ≥ this R
input double            InpPeakLockPctAt1R     = 70.0;            // Lock ≥N% of peak once ≥1R (floor)
input bool              InpUseLadder           = true;            // Peak-profit protection ladder (tick peak)
input double            InpTier1R              = 1.0;             // Tier 1 from (R) — lock ≥70% peak at 1R
input double            InpTier1Pct            = 70.0;            // Tier 1 protect % of peak (v1.15b: ≥70%@1R)
input double            InpTier2R              = 2.0;             // Tier 2 from (R) — Abdi: lock hard above 2R
input double            InpTier2Pct            = 85.0;            // Tier 2 protect % of peak (≥85%@2R)
input double            InpTier3R              = 2.5;             // Tier 3 from (R)
input double            InpTier3Pct            = 90.0;            // Tier 3 protect % of peak
input double            InpReversalPeakKeepPct = 90.0;            // On M5 reverse+disp: lock >= N% of peak
input bool              InpUseStructureTrail   = true;            // Trail behind last swing (after 1R / BE)
input bool              InpTrailAfter1RAlways  = true;            // After 1R peak: trail even if BE modify lagged
input int               InpTrailSwingStrength  = 2;               // Structure trail swing strength
input int               InpTrailStepOverride   = 0;               // Min SL improvement step points (0 = profile)
input double            InpPartialClosePct     = 40.0;            // Partial close % at 1R (v1.15: bank wins; 0=off)
input int               InpStaleExitBars       = 12;              // Close near-BE if no progress after N bars (0 = off)
input double            InpStaleMaxR           = 0.15;            // Max |profit| in R to treat as stale

input group "=== 8. Symbol profile overrides (0 = auto) ==="
input int               InpMinSLPtsOverride    = 0;               // Min SL distance points
input double            InpATRMultOverride     = 0.0;             // ATR multiplier for fallback SL
input int               InpDeviationOverride   = 0;               // Max deviation points

input group "=== 9. Dashboard ==="
input bool              InpShowDash            = true;            // Show dashboard
input int               InpDashX               = 10;              // X offset (px)
input int               InpDashY               = 20;              // Y offset (px)
input int               InpDashFont            = 9;               // Font size
input color             InpDashBg              = C'18,22,30';     // Background colour
input color             InpDashText            = clrWhiteSmoke;   // Text colour
input color             InpDashAccent          = clrGold;         // Accent colour

input group "=== 10. Chart analysis (visuals) ==="
input bool              InpShowStructure       = true;            // Draw HH / HL / LH / LL on chart
input int               InpStructLabels        = 8;               // How many swing labels to show
input bool              InpShowZones           = true;            // Draw armed entry zones (rectangle)
input bool              InpShowSignalArrows    = true;            // Draw BUY/SELL arrows + reason
input bool              InpShowPlacement       = true;            // Draw ENTRY / SL / TP placement lines
input bool              InpShowTrendLines      = true;            // Draw HTF-aligned trend lines
input bool              InpShowMarketBoard     = true;            // Right-side market / strategy board
input color             InpBullColor           = clrDodgerBlue;   // Bullish structure / BUY colour
input color             InpBearColor           = clrTomato;       // Bearish structure / SELL colour
input color             InpZoneColor           = clrGoldenrod;    // Armed zone colour
input color             InpEntryColor          = clrAqua;         // Placement ENTRY line
input color             InpSLColor             = clrOrangeRed;    // Placement SL line
input color             InpTPColor             = clrLime;         // Placement TP line

//==================================================================
//  SECTION 2 : STRUCTS & GLOBALS
//==================================================================
#define EA_NAME        "MJ-MASTER"
#define EA_VER         "1.15c"
#define EA_AUTHOR      "Abdihakiim Jamaal"
#define DASH_W_PX      560
#define DASH_LINE_H    16
#define AN_PREFIX      "AN_"
#define SEND_RING      16
#define NO_CAND        (-1.0e300)
#define DASH_FIXED_LINES 20
#define ATR_PERIOD     14

//--- symbol profile -------------------------------------------------
struct SProfile
  {
   ENUM_PROFILE_ID id;
   string          name;
   int             minSLPts;       // minimum initial SL distance (points)
   double          atrMult;        // fallback SL = ATR * atrMult
   int             maxSpreadPts;   // max spread (points)
   int             beBufferPts;    // break-even buffer (points)
   int             beTriggerPts;   // break-even trigger (points)
   int             trailStepPts;   // minimum SL improvement per modify (points)
   int             deviationPts;   // max slippage (points)
   double          slBufferATR;    // buffer beyond structure for SL (x ATR)
  };

//--- engine proposal ----------------------------------------------
struct SSignal
  {
   bool   valid;
   int    dir;        // +1 buy, -1 sell
   double sl;         // proposed SL price (may be widened by gate)
   double score;
   int    priority;   // 1 = highest
   int    engineId;
   string engine;
   string reason;
   int    quality;    // 0–100 entry location quality
   string qualityWhy;
   bool   counterTrend; // true = reversal vs HTF (stricter quality)
   void   Reset()
     {
      valid=false; dir=0; sl=0.0; score=0.0; priority=99; engineId=-1; engine=""; reason="";
      quality=0; qualityWhy=""; counterTrend=false;
     }
  };

//--- send-flight record -------------------------------------------
struct SendRequestRecord
  {
   uint     seq;
   int      state;        // ENUM_SEND_STATE
   datetime sentAt;
   datetime resolvedAt;
   int      dir;
   double   volume;
   double   price;
   double   sl;
   double   tp;
   string   comment;
   string   engine;
   ulong    order;
   ulong    deal;
   ulong    position;
   uint     retcode;
   int      attempts;
   void     Reset()
     {
      seq=0; state=SEND_NONE; sentAt=0; resolvedAt=0; dir=0; volume=0; price=0; sl=0; tp=0;
      comment=""; engine=""; order=0; deal=0; position=0; retcode=0; attempts=0;
     }
  };

//--- per-ticket protection state ----------------------------------
struct STicketProtect
  {
   ulong    ticket;
   int      dir;
   double   entry;
   double   initSL;
   double   initRiskPts;
   double   peakPts;
   int      tier;
   bool     beDone;
   bool     partialDone;
   datetime lastModifyTry;
   datetime lastPartialTry;
   datetime openTime;
   void     Reset()
     {
      ticket=0; dir=0; entry=0; initSL=0; initRiskPts=0; peakPts=0; tier=0;
      beDone=false; partialDone=false; lastModifyTry=0; lastPartialTry=0; openTime=0;
     }
  };

//--- globals --------------------------------------------------------
bool              g_initOK          = false;
ENUM_TIMEFRAMES   g_tf              = PERIOD_M5;
SProfile          g_prof;
double            g_bid             = 0.0;
double            g_ask             = 0.0;
int               g_digits          = 5;
double            g_volStep         = 0.01;
double            g_volMin          = 0.01;
double            g_volMax          = 100.0;
int               g_volDigits       = 2;
ENUM_ORDER_TYPE_FILLING g_filling   = ORDER_FILLING_IOC;

int               g_hATR            = INVALID_HANDLE;
int               g_hEMAExec        = INVALID_HANDLE;
int               g_hEMAM15         = INVALID_HANDLE;
int               g_hEMABias1       = INVALID_HANDLE;
int               g_hEMABias2       = INVALID_HANDLE;

datetime          g_lastExecBar     = 0;
datetime          g_lastM1Bar       = 0;
datetime          g_lastEntryBar    = 0;
datetime          g_lastDay         = 0;
datetime          g_nextSendAllowed = 0;
datetime          g_lastStatsRefresh= 0;
bool              g_statsDirty      = true;

bool              g_paused          = false;
bool              g_halted          = false;     // kill switch / hard stop (manual resume)
string            g_haltReason      = "";
bool              g_dayLocked       = false;     // daily limit reached, resumes next day
string            g_dayLockReason   = "";
bool              g_fridayClosedToday = false;

int               g_htfBias         = 0;     // final trade direction (+1/-1/0)
int               g_bias1           = 0;     // TF1 final (struct+EMA)
int               g_bias2           = 0;     // TF2 final (struct+EMA)
int               g_biasExec        = 0;     // execution TF final
int               g_struct1         = 0, g_ema1 = 0;
int               g_struct2         = 0, g_ema2 = 0;
int               g_structExec      = 0, g_emaExec = 0;
string            g_trendWhy        = "";    // human-readable trend decision
string            g_sessionName     = "";
string            g_gateReason      = "";
string            g_lastError       = "";
datetime          g_lastErrorTime   = 0;

// engines
bool              g_engOn[ENG_COUNT];
int               g_engPrio[ENG_COUNT];
string            g_engName[ENG_COUNT];
string            g_engWhy[ENG_COUNT];
string            g_engWhyBuy[ENG_COUNT];   // per-engine BUY column
string            g_engWhySell[ENG_COUNT];  // per-engine SELL column
datetime          g_engLastFire[ENG_COUNT];
bool              g_unicornWaiting  = false;
int               g_prevFinalBias   = 0;     // log FINAL flips
int               g_chochH1         = 0;
int               g_chochM15        = 0;
string            g_chochEvent      = "";
string            g_buyNeeds        = "";    // what BUY side still needs
string            g_sellNeeds       = "";    // what SELL side still needs
bool              g_h1Weakening     = false;
string            g_tfWhy2          = "";    // H4 reason
string            g_tfWhy1          = "";    // H1 reason
string            g_tfWhyExec       = "";    // Exec reason
string            g_tfWhyM15        = "";    // M15 reason
int               g_impulseExec     = 0;     // live impulse on exec/chart TF (+1/-1/0)
int               g_candleFlow      = 0;     // +1 UP / -1 DOWN / 0 FLAT (chart+M5)
string            g_flowTag         = "FLAT";
string            g_dirSourceTag    = "";    // dashboard: DIR SOURCE line
int               g_m5Agree         = 0;     // M5 structure lean (required when chart is M1)
bool              g_counterImpulseWait = false;
datetime          g_lossCooldownUntilBar = 0; // Exec bar time until which new entries blocked
int               g_lossCooldownBarsLeft = 0;
bool              g_bypassLossCooldown  = false; // flip-exit: allow reverse without cooldown
bool              g_chopPause          = false;
datetime          g_chopUntilBar       = 0;
datetime          g_flipTimes[32];
int               g_flipCount          = 0;
int               g_prevFlow           = 0;
string            g_lastFlipMsg        = "";
string            g_lastFlipExit       = "";
int               g_pendingFlipDir     = 0; // after FLIP EXIT, prefer this dir next signal
bool              g_flipEnterNow       = false; // allow opposite entry this tick (bypass one-per-bar)
int               g_flatBarsInFlow     = 0;     // consecutive chart bars flat while flow clear
string            g_idleWatchMsg       = "";
bool              g_idleRelaxed        = false; // lowest-priority rule relaxed this session window
string            g_idleRelaxedRule    = "";    // which soft rule IDLE-WATCHDOG relaxed
string            g_lastBlockRule      = "";    // last soft gate/engine block (for IDLE-WATCHDOG)

// daily stats
int               g_tradesToday     = 0;
double            g_dailyPL         = 0.0;
int               g_consecLosses    = 0;
datetime          g_lastLossTime    = 0;
double            g_balanceDayStart = 0.0;
double            g_equityPeak      = 0.0;
string            g_gvPeakName      = "";

// send ring
SendRequestRecord g_send[SEND_RING];
int               g_sendHead        = 0;
uint              g_sendSeq         = 0;

// protection
STicketProtect    g_tk[];

// news windows (minutes of day, server time)
int               g_newsStart[];
int               g_newsEnd[];
bool              g_calendarBlocked = false;
datetime          g_calendarLastCheck = 0;
bool              g_calendarFailed  = false;
datetime          g_calendarFailTime= 0;

// session minutes
int               g_lonStart=420, g_lonEnd=660, g_nyStart=720, g_nyEnd=960;
int               g_friNoNew=1080, g_friClose=1290;
int               g_serverGMTOffset = 3;

// dashboard
string            g_prefix          = "";
int               g_dashTicketLines = 2;
int               g_dashLines       = 0;

// chart analysis / visuals
bool              g_zoneActive      = false;
double            g_zoneTop         = 0.0;
double            g_zoneBot         = 0.0;
int               g_zoneDir         = 0;
string            g_zoneName        = "";
string            g_zoneWhy         = "";
int               g_lastSigDir      = 0;
string            g_lastSigEngine   = "";
string            g_lastSigReason   = "";
datetime          g_lastSigTime     = 0;
double            g_lastSigPrice    = 0.0;
double            g_lastSigSL       = 0.0;
double            g_lastSigTP       = 0.0;
bool              g_lastSigTaken    = false;   // true = order sent; false = blocked / waiting
datetime          g_lastAnalysisBar = 0;
int               g_htfClearBars    = 0;      // consecutive exec bars with clear HTF bias
datetime          g_lastContBar     = 0;
string            g_lastBarLogKey   = "";     // dedupe bar analysis log
string            g_lastStructEvent = "-";    // last HH/HL/LH/LL or BOS/MSS tag
int               g_lastQuality     = 0;
string            g_lastQualityWhy  = "";
double            g_lastRiskMoney   = 0.0;    // USD risk of last proposal/entry
// Gate funnel stats (dashboard)
int               g_statPropose     = 0;
int               g_statDropRR      = 0;      // legacy hard-RR drops (should stay 0 in v1.13)
int               g_statDropQuality = 0;
int               g_statDropOther   = 0;
int               g_statDropFlow    = 0;
int               g_statExecuted    = 0;
int               g_statRRSoftExt   = 0;      // trend RR soft → TP extended
string            g_lastDropReason  = "";
string            g_liveActionTag   = "";     // e.g. "SELL ACTIVE (flow BEAR)"

void NoteGateDrop(const string rule, const string detail);
void NoteGatePropose(const int dir, const string engine);

// forward declarations (used by engines / gate before the analysis section)
void ClearArmedZone();
void SetArmedZone(const int dir, const double xTop, const double xBot, const string name, const string why);
void RecordChartSignal(const int dir, const string engine, const string reason, const bool taken, const double sl);
void UpdateChartAnalysis(const bool force);
void AnalysisDelete();
void DrawDash();
bool TryContinuationFallback(const int dir, SSignal &out);
void LogBarAnalysis();
int  ScoreEntryQuality(const int dir, const double price, const double sl, string &why);
int  EffectiveMinQuality();
string DirStr(const int dir);
string TrendTag(const int d);
string Clip(const string s, const int maxLen);
string TFStr(const ENUM_TIMEFRAMES tf);
bool ValidateInitialSL(const int dir, double &sl);

//==================================================================
//  SECTION 3 : UTILITIES
//==================================================================
bool ModeAggressive()   { return (InpEntryMode == ENTRY_AGGRESSIVE); }
bool ModeConservative() { return (InpEntryMode == ENTRY_CONSERVATIVE); }

// Counter-trend (reversal vs HTF): only in Aggressive when InpAllowCounterTrend is on
bool CounterTrendPermitted()
  {
   if(!ModeAggressive()) return false;
   return InpAllowCounterTrend;
  }

bool TradeDirAllows(const int dir)
  {
   if(dir > 0 && InpTradeDirection == TRADE_SELL_ONLY) return false;
   if(dir < 0 && InpTradeDirection == TRADE_BUY_ONLY)  return false;
   return true;
  }

bool TrendFlowAligned(const int dir)
  {
   if(dir == 0) return false;
   if(g_candleFlow != 0 && dir == g_candleFlow) return true;
   if(g_impulseExec != 0 && dir == g_impulseExec) return true;
   if(g_candleFlow == 0 && g_htfBias != 0 && dir == g_htfBias) return true;
   return false;
  }

void NoteGatePropose(const int dir, const string engine)
  {
   g_statPropose++;
   if(dir < 0) g_liveActionTag = "SELL ACTIVE (flow " + g_flowTag + ") via " + engine;
   else if(dir > 0) g_liveActionTag = "BUY ACTIVE (flow " + g_flowTag + ") via " + engine;
  }

void NoteGateDrop(const string rule, const string detail)
  {
   g_lastDropReason = rule + ": " + detail;
   g_lastBlockRule = rule;
   g_gateReason = detail;
   if(rule == "MinInitialRR") g_statDropRR++;
   else if(rule == "MinEntryQuality") g_statDropQuality++;
   else if(rule == "flow") g_statDropFlow++;
   else g_statDropOther++;
   LogMsg("GATE drop rule=[" + rule + "] — " + detail, true);
  }

string DualEngTag(const string b, const string s)
  {
   string bb = (StringLen(b) == 0) ? "idle" : b;
   string ss = (StringLen(s) == 0) ? "idle" : s;
   return "B:" + bb + " S:" + ss;
  }

double EffectiveBookMinScore()
  {
   if(ModeAggressive())   return MathMin(InpMinBookScore, 1.0);
   if(ModeConservative()) return MathMax(InpMinBookScore, 1.6);
   return InpMinBookScore;
  }

void LogMsg(const string s, const bool force=false)
  {
   if(force || InpLogLevel >= 1 || InpVerboseLog)
      Print(EA_NAME, " [", _Symbol, "] ", s);
  }

void LogV(const string s)
  {
   if(InpLogLevel >= 2 || InpVerboseLog)
      Print(EA_NAME, " [", _Symbol, "] ", s);
  }

void LogBarAnalysis()
  {
   if(InpLogLevel < 1) return;
   string zone = "";
   if(g_zoneActive)
      zone = StringFormat(" | waiting %s %s zone %s-%s", g_zoneName, DirStr(g_zoneDir),
                          DoubleToString(g_zoneBot, g_digits), DoubleToString(g_zoneTop, g_digits));
   string key = StringFormat("%s|%d|%s|%s|%s|%s|%s|%s|%s|%s",
                             TimeToString(iTime(_Symbol, g_tf, 0), TIME_DATE|TIME_MINUTES),
                             g_htfBias, g_lastStructEvent, g_chochEvent,
                             DualEngTag(g_engWhyBuy[0], g_engWhySell[0]),
                             DualEngTag(g_engWhyBuy[1], g_engWhySell[1]),
                             DualEngTag(g_engWhyBuy[2], g_engWhySell[2]),
                             DualEngTag(g_engWhyBuy[3], g_engWhySell[3]),
                             g_gateReason, zone);
   if(key == g_lastBarLogKey) return;
   g_lastBarLogKey = key;
   Print(EA_NAME, " [", _Symbol, "] BAR ",
         TFStr(g_tf), " | FINAL=", TrendTag(g_htfBias),
         " H4=", TrendTag(g_bias2), "(S", TrendTag(g_struct2), "/E", TrendTag(g_ema2), ":", Clip(g_tfWhy2, 28), ")",
         " H1=", TrendTag(g_bias1), "(S", TrendTag(g_struct1), "/E", TrendTag(g_ema1), ":", Clip(g_tfWhy1, 28), ")",
         " M15=", Clip(g_tfWhyM15, 24),
         " Exec=", TrendTag(g_biasExec), "(S", TrendTag(g_structExec), "/E", TrendTag(g_emaExec), ":", Clip(g_tfWhyExec, 28), ")",
         " flow=", g_flowTag,
         (g_chopPause ? " CHOP" : ""),
         " | Struct=", g_lastStructEvent,
         " ", g_chochEvent,
         " | UNI ", Clip(DualEngTag(g_engWhyBuy[ENG_UNICORN], g_engWhySell[ENG_UNICORN]), 40),
         " | KIL ", Clip(DualEngTag(g_engWhyBuy[ENG_KILLER], g_engWhySell[ENG_KILLER]), 40),
         " | SCP ", Clip(DualEngTag(g_engWhyBuy[ENG_SCALP], g_engWhySell[ENG_SCALP]), 40),
         " | BOOK ", Clip(DualEngTag(g_engWhyBuy[ENG_BOOK], g_engWhySell[ENG_BOOK]), 40),
         " | Gate: ", Clip(g_gateReason, 48), zone);
  }

void SetError(const string s)
  {
   g_lastError     = s;
   g_lastErrorTime = TimeCurrent();
   LogMsg("ERROR: " + s, true);
  }

string DirStr(const int dir) { return (dir > 0) ? "BUY" : ((dir < 0) ? "SELL" : "NONE"); }

string TFStr(const ENUM_TIMEFRAMES tf)
  {
   string s = EnumToString(tf);
   if(StringFind(s, "PERIOD_") == 0) s = StringSubstr(s, 7);
   return s;
  }

double NormPrice(const double p)
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick > 0.0)
      return NormalizeDouble(MathRound(p / tick) * tick, g_digits);
   return NormalizeDouble(p, g_digits);
  }

double NormalizeVolume(double v)
  {
   if(g_volStep <= 0.0) return v;
   v = MathFloor(v / g_volStep + 1e-9) * g_volStep;
   v = NormalizeDouble(v, g_volDigits);
   if(v > g_volMax) v = g_volMax;
   return v;
  }

int VolumeDigits(const double step)
  {
   int d = 0; double s = step;
   while(d < 8 && MathAbs(s - MathRound(s)) > 1e-9) { s *= 10.0; d++; }
   return d;
  }

datetime DayStart(const datetime t)
  {
   return (datetime)(((long)t / 86400) * 86400);
  }

int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt; TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool ParseHHMM(string s, int &minutes)
  {
   StringTrimLeft(s); StringTrimRight(s);
   string p[];
   if(StringSplit(s, ':', p) != 2) return false;
   int h = (int)StringToInteger(p[0]);
   int m = (int)StringToInteger(p[1]);
   if(h < 0 || h > 24 || m < 0 || m > 59) return false;
   minutes = h * 60 + m;
   return true;
  }

bool InMinuteWindow(const int nowMin, const int startMin, const int endMin)
  {
   if(startMin <= endMin) return (nowMin >= startMin && nowMin < endMin);
   return (nowMin >= startMin || nowMin < endMin);   // wraps midnight
  }

bool RefreshPrices()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   if(tick.bid <= 0.0 || tick.ask <= 0.0) return false;
   g_bid = tick.bid;
   g_ask = tick.ask;
   return true;
  }

int SpreadPts()
  {
   return (int)MathRound((g_ask - g_bid) / _Point);
  }

// Reference price used by the broker for SL validation of a position in direction dir
double RefPrice(const int dir) { return (dir > 0) ? g_bid : g_ask; }

// Broker stop floor in points (stops level / freeze level + safety extra)
int BrokerStopFloor()
  {
   int stops  = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int f = (stops > freeze) ? stops : freeze;
   return f + InpStopFloorExtraPts;
  }

// Floor distance in price (for SL modifications)
double FloorDist() { return BrokerStopFloor() * _Point; }

// Minimum initial SL distance in price (broker floor vs profile minimum)
double MinDist()
  {
   int pts = BrokerStopFloor();
   if(g_prof.minSLPts > pts) pts = g_prof.minSLPts;
   return pts * _Point;
  }

bool IsNewBar(const ENUM_TIMEFRAMES tf, datetime &last)
  {
   datetime t = iTime(_Symbol, tf, 0);
   if(t == 0) return false;
   if(t != last) { last = t; return true; }
   return false;
  }

bool TradingAllowedByTerminal(string &why)
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { why = "AutoTrading off (terminal)"; return false; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))           { why = "AutoTrading off (EA)"; return false; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))   { why = "Account trading disabled"; return false; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))    { why = "EA trading disabled on account"; return false; }
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_CLOSEONLY) { why = "Symbol trade mode disabled/close-only"; return false; }
   return true;
  }

int CountOwnPositions(int &buyCount, int &sellCount)
  {
   buyCount = 0; sellCount = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) buyCount++;
      else sellCount++;
     }
   return buyCount + sellCount;
  }

//==================================================================
//  SECTION 4 : SYMBOL PROFILE
//==================================================================
void SetProfile(const ENUM_PROFILE_ID id, const string name, const int minSL, const double atrMult,
                const int maxSpread, const int beBuf, const int beTrig, const int trailStep,
                const int deviation, const double slBufATR)
  {
   g_prof.id           = id;
   g_prof.name         = name;
   g_prof.minSLPts     = minSL;
   g_prof.atrMult      = atrMult;
   g_prof.maxSpreadPts = maxSpread;
   g_prof.beBufferPts  = beBuf;
   g_prof.beTriggerPts = beTrig;
   g_prof.trailStepPts = trailStep;
   g_prof.deviationPts = deviation;
   g_prof.slBufferATR  = slBufATR;
  }

void LoadSymbolProfile()
  {
   string s = _Symbol;
   StringToUpper(s);
   double scale = 1.0;   // point-scale correction when broker digits differ from the profile's reference digits

   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0)
     {
      // reference: 2-digit gold (point = 0.01 USD)
      SetProfile(PROF_GOLD, "Gold", 300, 1.5, 60, 20, 120, 10, 30, 0.15); // v1.15b: BE trig 120pts (~$1.2), buf 20
      if(g_digits == 3) scale = 10.0;
     }
   else if(StringFind(s, "XAG") >= 0 || StringFind(s, "SILVER") >= 0)
     {
      // reference: 3-digit silver (point = 0.001 USD)
      SetProfile(PROF_SILVER, "Silver", 150, 1.5, 40, 10, 120, 10, 30, 0.15);
      if(g_digits == 2) scale = 0.1;
      if(g_digits == 4) scale = 10.0;
     }
   else if(StringFind(s, "EURUSD") >= 0)
     {
      // reference: 5-digit EURUSD (point = 0.00001)
      SetProfile(PROF_EURUSD, "EURUSD", 60, 1.5, 20, 5, 60, 5, 10, 0.15);
      if(g_digits == 4) scale = 0.1;
     }
   else if(StringFind(s, "BTC") >= 0)
     {
      // reference: 2-digit BTCUSD (point = 0.01 USD)
      SetProfile(PROF_BTC, "BTCUSD", 15000, 1.5, 5000, 1000, 12000, 500, 500, 0.15);
      if(g_digits == 1) scale = 0.1;
      if(g_digits == 0) scale = 0.01;
      if(g_digits == 3) scale = 10.0;
     }
   else
     {
      SetProfile(PROF_DEFAULT, "Default", 100, 1.5, 30, 5, 100, 10, 20, 0.15);
     }

   if(scale != 1.0)
     {
      g_prof.minSLPts     = (int)MathRound(g_prof.minSLPts * scale);
      g_prof.maxSpreadPts = (int)MathRound(g_prof.maxSpreadPts * scale);
      g_prof.beBufferPts  = (int)MathRound(g_prof.beBufferPts * scale);
      g_prof.beTriggerPts = (int)MathRound(g_prof.beTriggerPts * scale);
      g_prof.trailStepPts = (int)MathRound(g_prof.trailStepPts * scale);
      g_prof.deviationPts = (int)MathRound(g_prof.deviationPts * scale);
      if(g_prof.trailStepPts < 1) g_prof.trailStepPts = 1;
      if(g_prof.beBufferPts  < 1) g_prof.beBufferPts  = 1;
     }

   // user overrides
   if(InpMinSLPtsOverride   > 0)   g_prof.minSLPts     = InpMinSLPtsOverride;
   if(InpATRMultOverride    > 0.0) g_prof.atrMult      = InpATRMultOverride;
   if(InpMaxSpreadOverride  > 0)   g_prof.maxSpreadPts = InpMaxSpreadOverride;
   if(InpDeviationOverride  > 0)   g_prof.deviationPts = InpDeviationOverride;
   if(InpBEBufferOverride   > 0)   g_prof.beBufferPts  = InpBEBufferOverride;
   if(InpBreakEvenPtsOverride > 0) g_prof.beTriggerPts = InpBreakEvenPtsOverride;
   if(InpTrailStepOverride  > 0)   g_prof.trailStepPts = InpTrailStepOverride;
  }

void DetectFillingMode()
  {
   int fm = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   long ex = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE);
   if(ex == SYMBOL_TRADE_EXECUTION_EXCHANGE || ex == SYMBOL_TRADE_EXECUTION_REQUEST)
     {
      if((fm & SYMBOL_FILLING_FOK) != 0)      g_filling = ORDER_FILLING_FOK;
      else if((fm & SYMBOL_FILLING_IOC) != 0) g_filling = ORDER_FILLING_IOC;
      else                                    g_filling = ORDER_FILLING_RETURN;
      return;
     }
   if((fm & SYMBOL_FILLING_IOC) != 0)      g_filling = ORDER_FILLING_IOC;
   else if((fm & SYMBOL_FILLING_FOK) != 0) g_filling = ORDER_FILLING_FOK;
   else                                    g_filling = ORDER_FILLING_RETURN;
  }

ENUM_ORDER_TYPE_FILLING NextFillingMode(const ENUM_ORDER_TYPE_FILLING cur)
  {
   if(cur == ORDER_FILLING_IOC)    return ORDER_FILLING_FOK;
   if(cur == ORDER_FILLING_FOK)    return ORDER_FILLING_RETURN;
   return ORDER_FILLING_IOC;
  }

//==================================================================
//  SECTION 5 : MARKET DATA HELPERS
//==================================================================
// Loads `count` bars (series order, index 0 = current bar). Returns bars copied (0 on failure).
int LoadRates(const ENUM_TIMEFRAMES tf, const int count, MqlRates &r[])
  {
   ArraySetAsSeries(r, true);
   int got = CopyRates(_Symbol, tf, 0, count, r);
   if(got <= 0) return 0;
   return got;
  }

double ATRValue(const int shift=1)
  {
   if(g_hATR == INVALID_HANDLE) return 0.0;
   double b[];
   ArraySetAsSeries(b, true);
   if(CopyBuffer(g_hATR, 0, shift, 1, b) != 1) return 0.0;
   return b[0];
  }

// Pre-impulse ATR: median of older ATR samples so displacement tests don't inflate mid-drop
double ATRBaseline(const int preferShift=10)
  {
   if(g_hATR == INVALID_HANDLE) return ATRValue(1);
   double b[];
   ArraySetAsSeries(b, true);
   int need = preferShift + 6;
   if(CopyBuffer(g_hATR, 0, 1, need, b) < need) return ATRValue(1);
   // median of shifts preferShift..preferShift+4 (indices preferShift-1 .. preferShift+3)
   double s[5];
   for(int i = 0; i < 5; i++) s[i] = b[preferShift - 1 + i];
   for(int i = 0; i < 4; i++)
      for(int j = i + 1; j < 5; j++)
         if(s[j] < s[i]) { double t = s[i]; s[i] = s[j]; s[j] = t; }
   double med = s[2];
   double cur = b[0];
   if(med <= 0.0) return cur;
   // never use an inflated live ATR for thresholds — prefer the calmer baseline
   if(cur > 1.35 * med) return med;
   return MathMin(cur, med);
  }

// Fixed-point floor for displacement body (gold ~0.80 USD ≈ 80 pts @ 2 digits)
double DispBodyFloor()
  {
   if(g_prof.id == PROF_GOLD)   return 80.0 * _Point;
   if(g_prof.id == PROF_SILVER) return 40.0 * _Point;
   if(g_prof.id == PROF_BTC)    return 80.0;   // absolute USD-ish
   return 15.0 * _Point;
  }

double DispMinBody(const double atrBase, const bool agg)
  {
   // M1: smaller body fraction (noise); still ATR-scaled so gold impulses register
   double frac = 0.28;
   if(PeriodSeconds(g_tf) <= PeriodSeconds(PERIOD_M1)) frac = (agg ? 0.18 : 0.28);
   else if(PeriodSeconds(g_tf) <= PeriodSeconds(PERIOD_M5)) frac = (agg ? 0.22 : 0.35);
   else frac = (agg ? 0.28 : 0.50);
   double m = frac * atrBase;
   double fl = DispBodyFloor();
   // On M1 allow a softer floor (half) so legitimate 0.18*ATR bodies pass
   if(PeriodSeconds(g_tf) <= PeriodSeconds(PERIOD_M1)) fl *= 0.45;
   if(m < fl) m = fl;
   return m;
  }

bool IsM1Chart() { return (PeriodSeconds(g_tf) <= PeriodSeconds(PERIOD_M1)); }

ENUM_TIMEFRAMES FlipDetectTF()
  {
   // Detect flips on chart TF (M1 supported); use chart always
   return g_tf;
  }

bool EMAValues(const int handle, const int count, double &out[])
  {
   if(handle == INVALID_HANDLE) return false;
   ArraySetAsSeries(out, true);
   int got = CopyBuffer(handle, 0, 0, count, out);
   return (got == count);
  }

// Chart/exec impulse must match entry dir (HTF soft — does not force ImpulseCont against live flow)
bool ImpulseAligned(const int dir)
  {
   if(dir == 0) return false;
   if(g_impulseExec != 0 && g_impulseExec != dir) return false;
   if(g_biasExec != 0 && g_biasExec != dir) return false;
   if(g_candleFlow != 0 && g_candleFlow != dir) return false;
   // soft HTF: preferred but not required unless hard filter
   if(InpHTFHardFilter && g_htfBias != 0 && g_htfBias != dir) return false;
   return (g_impulseExec == dir || g_emaExec == dir || g_candleFlow == dir);
  }

string FlowTag(const int f)
  {
   if(f > 0) return "UP";
   if(f < 0) return "DOWN";
   return "FLAT";
  }

// Last 2–3 closed candles on tf: body direction majority + EMA slope
// v1.14: fast flip on micro CHoCH/reclaim so BUY bounce is not stuck waiting "flow UP"
int CandleFlowTF(const ENUM_TIMEFRAMES tf, const int handle)
  {
   MqlRates r[];
   int n = LoadRates(tf, 12, r);
   if(n < 5) return 0;
   int up = 0, dn = 0;
   for(int k = 1; k <= 3; k++)
     {
      double body = r[k].close - r[k].open;
      if(body > 0.0) up++;
      else if(body < 0.0) dn++;
     }
   int flow = 0;
   if(up >= 2 && up > dn) flow = 1;
   else if(dn >= 2 && dn > up) flow = -1;

   // ATR for reclaim threshold
   double atr = 0.0;
   for(int k = 1; k <= 5; k++) atr += (r[k].high - r[k].low);
   atr /= 5.0;
   if(atr <= 0.0) atr = _Point * 50.0;
   // Micro CHoCH / reclaim: bar1 closes beyond prior 3–6 extreme with body — flip immediately
   double priorHi = r[2].high, priorLo = r[2].low;
   for(int k = 3; k <= 6 && k < n; k++)
     { if(r[k].high > priorHi) priorHi = r[k].high; if(r[k].low < priorLo) priorLo = r[k].low; }
   double body1 = r[1].close - r[1].open;
   if(body1 >= 0.30 * atr && r[1].close > priorHi)
      flow = 1;   // bullish reclaim → UP (BUY path)
   else if(body1 <= -0.30 * atr && r[1].close < priorLo)
      flow = -1;  // bearish break → DOWN (SELL path)

   double ema1 = 0.0, ema3 = 0.0; bool haveE = false;
   double e[];
   if(handle != INVALID_HANDLE && EMAValues(handle, 5, e))
     { ema1 = e[1]; ema3 = e[3]; haveE = true; }
   else
     {
      double s1 = 0.0, s3 = 0.0;
      for(int i = 1; i <= 5; i++) s1 += r[i].close;
      for(int i = 3; i <= 7 && i < n; i++) s3 += r[i].close;
      ema1 = s1 / 5.0; ema3 = s3 / 5.0; haveE = true;
     }
   if(haveE)
     {
      bool slopeUp = (ema1 > ema3);
      bool slopeDn = (ema1 < ema3);
      bool sideUp  = (r[1].close > ema1);
      bool sideDn  = (r[1].close < ema1);
      // Do not cancel a strong reclaim flip just because EMA lag disagrees
      bool strongFlip = (MathAbs(body1) >= 0.30 * atr &&
                         ((flow > 0 && r[1].close > priorHi) || (flow < 0 && r[1].close < priorLo)));
      if(!strongFlip)
        {
         if(flow > 0 && slopeDn && sideDn) flow = 0;
         if(flow < 0 && slopeUp && sideUp) flow = 0;
        }
      if(flow == 0)
        {
         if(slopeUp && sideUp && up >= 1) flow = 1;
         if(slopeDn && sideDn && dn >= 1) flow = -1;
        }
     }
   return flow;
  }

// Chart TF is primary (M1 fully supported). M5 is soft confirmation for quality only.
int UpdateCandleFlow()
  {
   int fChart = CandleFlowTF(g_tf, g_hEMAExec);
   int fM5    = CandleFlowTF(PERIOD_M5, INVALID_HANDLE);
   g_m5Agree  = fM5;
   // Chart flow wins. If chart flat, fall back to M5 soft lean.
   if(fChart != 0) g_candleFlow = fChart;
   else            g_candleFlow = fM5;
   g_flowTag = FlowTag(g_candleFlow);
   return g_candleFlow;
  }

void RecordFlowFlip(const int newFlow)
  {
   if(newFlow == 0 || g_prevFlow == 0 || newFlow == g_prevFlow) { g_prevFlow = (newFlow != 0) ? newFlow : g_prevFlow; return; }
   datetime t = iTime(_Symbol, g_tf, 1);
   if(t == 0) t = TimeCurrent();
   // shift
   for(int i = 31; i > 0; i--) g_flipTimes[i] = g_flipTimes[i - 1];
   g_flipTimes[0] = t;
   if(g_flipCount < 32) g_flipCount++;
   g_lastFlipMsg = StringFormat("FLOW: %s→%s flip @%s", FlowTag(g_prevFlow), FlowTag(newFlow),
                                TimeToString(t, TIME_MINUTES));
   LogMsg(g_lastFlipMsg, true);

   // Chop guard: ≥InpChopFlipMin flips inside InpFlipChopBars chart bars (v1.15 stricter)
   if(InpFlipChopBars > 0 && InpChopPauseBars > 0)
     {
      int flips = 0;
      datetime oldest = t - (datetime)(InpFlipChopBars * PeriodSeconds(g_tf));
      for(int i = 0; i < g_flipCount && i < 32; i++)
         if(g_flipTimes[i] >= oldest) flips++;
      int need = (InpChopFlipMin > 0) ? InpChopFlipMin : 3;
      if(flips >= need)
        {
         g_chopPause = true;
         g_chopUntilBar = iTime(_Symbol, g_tf, 0) + (datetime)(InpChopPauseBars * PeriodSeconds(g_tf));
         LogMsg(StringFormat("CHOP pause %d bars (%d flips in %d, need %d) — FINAL WAIT", InpChopPauseBars, flips, InpFlipChopBars, need), true);
        }
     }
   g_prevFlow = newFlow;
  }

// Confirmed flow flip vs position: chart/M1 close against + displacement + (CHoCH or EMA cross)
bool ConfirmedFlowFlipAgainst(const int posDir, string &why)
  {
   why = "";
   if(!InpReverseOnFlowFlip || posDir == 0) return false;
   ENUM_TIMEFRAMES tf = FlipDetectTF();
   MqlRates r[];
   int n = LoadRates(tf, 30, r);
   if(n < 10) return false;
   double atr = ATRBaseline(6);
   if(atr <= 0.0) atr = RatesATR(r, n, 14);
   if(atr <= 0.0) return false;
   double body = r[1].close - r[1].open;
   // against BUY → bearish body; against SELL → bullish body
   bool against = (posDir > 0) ? (body <= -0.60 * atr) : (body >= 0.60 * atr);
   if(!against) return false;

   bool emaCross = false;
   double e[];
   if(EMAValues(g_hEMAExec, 4, e))
     {
      if(posDir > 0) emaCross = (r[2].close >= e[2] && r[1].close < e[1]);
      else           emaCross = (r[2].close <= e[2] && r[1].close > e[1]);
     }
   // micro CHoCH: close beyond prior 3–8 bar extreme against position
   bool choch = false;
   if(posDir > 0)
     {
      double lo = r[2].low;
      for(int k = 3; k <= 8; k++) if(r[k].low < lo) lo = r[k].low;
      choch = (r[1].close < lo);
     }
   else
     {
      double hi = r[2].high;
      for(int k = 3; k <= 8; k++) if(r[k].high > hi) hi = r[k].high;
      choch = (r[1].close > hi);
     }
   if(!(emaCross || choch)) return false;
   // live flow must also have flipped
   if(g_candleFlow != 0 && g_candleFlow == posDir) return false;
   why = StringFormat("flow flip vs %s (disp%s)", DirStr(posDir), emaCross ? "+EMA" : "+CHoCH");
   return true;
  }

// ≥2 consecutive displacement candles against HTF/chart lean → WAIT
bool StrongCounterImpulse(const int againstDir, string &why)
  {
   why = "";
   if(againstDir == 0) return false;
   MqlRates r[];
   int n = LoadRates(g_tf, 20, r);
   if(n < 8) return false;
   double atr = ATRBaseline(8);
   if(atr <= 0.0) atr = ATRValue();
   if(atr <= 0.0) return false;
   int disp = 0;
   for(int k = 1; k <= 3; k++)
     {
      double body = r[k].close - r[k].open;
      // againstDir >0 means we expect bull; counter impulse is bearish bodies
      if(againstDir > 0 && body < -0.80 * atr) disp++;
      if(againstDir < 0 && body >  0.80 * atr) disp++;
     }
   if(disp < 2) return false;
   double e[];
   bool below = false, above = false;
   if(EMAValues(g_hEMAExec, 3, e))
     {
      below = (r[1].close < e[1]);
      above = (r[1].close > e[1]);
     }
   if(againstDir > 0 && below)
     { why = StringFormat("counterIMPULSE BEAR x%d vs BULL — WAIT reclaim", disp); return true; }
   if(againstDir < 0 && above)
     { why = StringFormat("counterIMPULSE BULL x%d vs BEAR — WAIT reclaim", disp); return true; }
   return false;
  }

// Pullback depth in ATR from recent swing extreme on Exec TF
double PullbackDepthATR(const int htfDir)
  {
   if(htfDir == 0) return 0.0;
   MqlRates r[];
   int n = LoadRates(g_tf, 40, r);
   if(n < 15) return 0.0;
   double atr = ATRValue();
   if(atr <= 0.0) return 0.0;
   double px = RefPrice(htfDir);
   if(htfDir > 0)
     {
      double hi = r[1].high;
      for(int k = 2; k <= 20; k++) if(r[k].high > hi) hi = r[k].high;
      return (hi - px) / atr;
     }
   double lo = r[1].low;
   for(int k = 2; k <= 20; k++) if(r[k].low < lo) lo = r[k].low;
   return (px - lo) / atr;
  }

// How far price has run in `dir` from the opposite swing extreme (late-chase meter).
// SELL: (recentHigh - price)/ATR; BUY: (price - recentLow)/ATR.
double TrendExtensionATR(const int dir)
  {
   if(dir == 0) return 0.0;
   MqlRates r[];
   int n = LoadRates(g_tf, 40, r);
   if(n < 12) return 0.0;
   double atr = ATRBaseline(8);
   if(atr <= 0.0) atr = ATRValue();
   if(atr <= 0.0) return 0.0;
   double px = (dir > 0) ? g_ask : g_bid;
   if(px <= 0.0) px = r[0].close;
   if(dir < 0)
     {
      double hi = r[1].high;
      for(int k = 2; k <= 16; k++) if(r[k].high > hi) hi = r[k].high;
      return (hi - px) / atr;
     }
   double lo = r[1].low;
   for(int k = 2; k <= 16; k++) if(r[k].low < lo) lo = r[k].low;
   return (px - lo) / atr;
  }

// True when impulse-at-extreme should be rejected (prefer pullback/retest instead)
bool LateChaseBlocked(const int dir, string &why)
  {
   why = "";
   if(!InpPreferPullbackEntry || InpMaxExtensionATR <= 0.0 || dir == 0) return false;
   double ext = TrendExtensionATR(dir);
   if(ext > InpMaxExtensionATR)
     {
      why = StringFormat("late-chase %.1fATR > max %.1f — wait pullback/retest", ext, InpMaxExtensionATR);
      return true;
     }
   return false;
  }

bool PullbackConfirmed(const int dir, string &why); // after X-helpers
double NearestTargetDist(const int dir, const double price);
bool SameDirOpenInDrawdown(const int dir);

double NearestContSL(const int dir, const MqlRates &r[], const int n, const double atr); // after X-helpers

//--- "X-space" helpers: every engine is written for the bullish case in a
//--- transformed price space x = dir * price.  For dir = -1 highs/lows swap
//--- and the sign flips, so one code path serves both directions.
double XH(const MqlRates &r[], const int i, const int dir) { return (dir > 0) ? r[i].high : -r[i].low;  }
double XL(const MqlRates &r[], const int i, const int dir) { return (dir > 0) ? r[i].low  : -r[i].high; }
double XC(const MqlRates &r[], const int i, const int dir) { return dir * r[i].close; }
double XO(const MqlRates &r[], const int i, const int dir) { return dir * r[i].open;  }
double XReal(const double x, const int dir)                { return dir * x; }

bool IsXSwingHigh(const MqlRates &r[], const int n, const int i, const int s, const int dir)
  {
   if(i - s < 1 || i + s >= n) return false;
   double h = XH(r, i, dir);
   for(int k = 1; k <= s; k++)
     {
      if(XH(r, i + k, dir) >= h) return false;
      if(XH(r, i - k, dir) >  h) return false;
     }
   return true;
  }

bool IsXSwingLow(const MqlRates &r[], const int n, const int i, const int s, const int dir)
  {
   if(i - s < 1 || i + s >= n) return false;
   double l = XL(r, i, dir);
   for(int k = 1; k <= s; k++)
     {
      if(XL(r, i + k, dir) <= l) return false;
      if(XL(r, i - k, dir) <  l) return false;
     }
   return true;
  }

int LastXSwingHigh(const MqlRates &r[], const int n, const int from, const int s, const int dir)
  {
   int start = (from > s + 1) ? from : s + 1;
   for(int i = start; i < n - s; i++)
      if(IsXSwingHigh(r, n, i, s, dir)) return i;
   return -1;
  }

int LastXSwingLow(const MqlRates &r[], const int n, const int from, const int s, const int dir)
  {
   int start = (from > s + 1) ? from : s + 1;
   for(int i = start; i < n - s; i++)
      if(IsXSwingLow(r, n, i, s, dir)) return i;
   return -1;
  }

int XHighestIdx(const MqlRates &r[], const int n, const int from, int to, const int dir)
  {
   if(to > n - 1) to = n - 1;
   if(from < 0 || from > to) return -1;
   int best = from;
   for(int i = from + 1; i <= to; i++)
      if(XH(r, i, dir) > XH(r, best, dir)) best = i;
   return best;
  }

int XLowestIdx(const MqlRates &r[], const int n, const int from, int to, const int dir)
  {
   if(to > n - 1) to = n - 1;
   if(from < 0 || from > to) return -1;
   int best = from;
   for(int i = from + 1; i <= to; i++)
      if(XL(r, i, dir) < XL(r, best, dir)) best = i;
   return best;
  }

// Nearest SL for continuation: trigger candle extreme + buffer, else M5 swing
double NearestContSL(const int dir, const MqlRates &r[], const int n, const double atr)
  {
   double px = RefPrice(dir);
   double buf = atr * g_prof.slBufferATR;
   if(buf < MinDist()) buf = MinDist();
   double nearSL = (dir > 0) ? (r[1].low - buf) : (r[1].high + buf);
   MqlRates m5[];
   int n5 = LoadRates(PERIOD_M5, 40, m5);
   if(n5 >= 20)
     {
      int sw = (dir > 0) ? LastXSwingLow(m5, n5, 3, 2, 1) : LastXSwingHigh(m5, n5, 3, 2, 1);
      if(sw >= 0)
        {
         double swSL = (dir > 0) ? (m5[sw].low - buf) : (m5[sw].high + buf);
         if(dir > 0) { if(swSL < px && swSL > nearSL) nearSL = swSL; }
         else        { if(swSL > px && swSL < nearSL) nearSL = swSL; }
        }
     }
   int ex = XLowestIdx(r, n, 1, 3, dir);
   if(ex >= 0)
     {
      double exSL = XReal(XL(r, ex, dir) - buf, dir);
      if(dir > 0) { if(exSL < px && exSL > nearSL) nearSL = exSL; }
      else        { if(exSL > px && exSL < nearSL) nearSL = exSL; }
     }
   return NormPrice(nearSL);
  }

bool SameDirOpenInDrawdown(const int dir)
  {
   if(!InpBlockReentryInDD || dir == 0) return false;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      int d = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      if(d != dir) continue;
      if(PositionGetDouble(POSITION_PROFIT) < 0.0) return true;
     }
   return false;
  }

// True if every same-dir open ticket is BE+ or profit ≥ InpAddAfterR (allows serial continuation add)
bool SameDirOpenReadyToAdd(const int dir)
  {
   if(dir == 0) return true;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      int d = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      if(d != dir) continue;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double ref   = RefPrice(d);
      double profitPts = d * (ref - entry) / _Point;
      double riskPts = (sl > 0.0) ? MathAbs(entry - sl) / _Point : MinDist() / _Point;
      if(riskPts < 1.0) riskPts = MinDist() / _Point;
      bool bePlus = (sl > 0.0 && d * (sl - entry) >= 0.0);
      double rNow = profitPts / riskPts;
      if(!(bePlus || rNow >= InpAddAfterR)) return false;
     }
   return true;
  }

// Effective max: 1 while any DD ticket; up to InpMaxPositions when open tickets are BE+/AddAfterR
int EffectiveMaxPositions(const int forDir)
  {
   int b = 0, s = 0;
   int open = CountOwnPositions(b, s);
   if(open <= 0) return MathMax(1, InpMaxPositions);
   if(SameDirOpenInDrawdown(forDir != 0 ? forDir : ((b > 0) ? 1 : -1)))
      return 1; // never stack onto DD
   if(forDir != 0 && !SameDirOpenReadyToAdd(forDir))
      return MathMax(1, open); // block add until ready
   return MathMax(1, InpMaxPositions);
  }

double NearestTargetDist(const int dir, const double price)
  {
   MqlRates r[];
   int n = LoadRates(g_tf, 50, r);
   if(n < 20) return 0.0;
   const int s = InpSwingStrength;
   if(dir > 0)
     {
      int h = LastXSwingHigh(r, n, s + 1, s, 1);
      if(h < 0) return 0.0;
      double t = r[h].high;
      if(t <= price) return 0.0;
      return t - price;
     }
   int l = LastXSwingLow(r, n, s + 1, s, 1);
   if(l < 0) return 0.0;
   double t = r[l].low;
   if(t >= price) return 0.0;
   return price - t;
  }

bool PullbackConfirmed(const int dir, string &why)
  {
   why = "";
   if(dir == 0) return false;
   MqlRates m5[], m1[];
   int n5 = LoadRates(PERIOD_M5, 50, m5);
   int n1 = LoadRates(PERIOD_M1, 40, m1);
   if(n5 < 20) { why = "no M5 data"; return false; }
   double atr = ATRBaseline(8);
   if(atr <= 0.0) atr = ATRValue();

   const int s = 2;
   bool bos = false;
   if(dir > 0)
     {
      int lh = LastXSwingHigh(m5, n5, 3, s, 1);
      int pe = XHighestIdx(m5, n5, 2, 12, 1);
      if(pe >= 2 && m5[1].close > m5[pe].high && m5[1].close > m5[1].open) bos = true;
      if(!bos && lh >= 0 && m5[1].close > m5[lh].high && m5[1].close > m5[1].open) bos = true;
     }
   else
     {
      int pe = XLowestIdx(m5, n5, 2, 12, 1);
      if(pe >= 2 && m5[1].close < m5[pe].low && m5[1].close < m5[1].open) bos = true;
      int ll = LastXSwingLow(m5, n5, 3, s, 1);
      if(!bos && ll >= 0 && m5[1].close < m5[ll].low && m5[1].close < m5[1].open) bos = true;
     }

   double e[];
   bool nearEma = false;
   if(EMAValues(g_hEMAExec, 3, e))
     {
      double dist = MathAbs(RefPrice(dir) - e[1]);
      nearEma = (dist <= 0.45 * atr) && (dir * (RefPrice(dir) - e[1]) >= -0.15 * atr);
     }

   if(bos && nearEma)
     { why = "M5 BOS+EMA reclaim"; return true; }

   if(n1 >= 20)
     {
      bool rej = (dir > 0) ? (m1[1].close > m1[1].open && (m1[1].close - m1[1].low) >= 0.45 * (m1[1].high - m1[1].low))
                           : (m1[1].close < m1[1].open && (m1[1].high - m1[1].close) >= 0.45 * (m1[1].high - m1[1].low));
      int pe1 = (dir > 0) ? XHighestIdx(m1, n1, 2, 10, 1) : XLowestIdx(m1, n1, 2, 10, 1);
      bool mss = false;
      if(pe1 >= 2)
        {
         if(dir > 0 && m1[1].close > m1[pe1].high) mss = true;
         if(dir < 0 && m1[1].close < m1[pe1].low)  mss = true;
        }
      if(rej && mss && nearEma)
        { why = "M1 sweep+MSS+reject@EMA"; return true; }
     }
   why = "pullback not confirmed (need M5 BOS/M1 MSS)";
   return false;
  }

//==================================================================
//  SECTION 6 : FILTERS (bias, session, news, spread, daily)
//==================================================================
// EMA-only lean on a timeframe (price side + slope)
int EmaBiasFromHandle(const int handle, const ENUM_TIMEFRAMES tf)
  {
   double e[];
   if(!EMAValues(handle, 5, e)) return 0;
   MqlRates r[];
   if(LoadRates(tf, 3, r) < 2) return 0;
   bool bull = (r[1].close > e[1] && e[1] > e[4]);
   bool bear = (r[1].close < e[1] && e[1] < e[4]);
   if(bull) return 1;
   if(bear) return -1;
   return 0;
  }

// Local ATR from rates (for TFs without the exec ATR handle)
double RatesATR(const MqlRates &r[], const int n, const int period=14)
  {
   if(n < period + 2) return 0.0;
   double sum = 0.0;
   for(int i = 1; i <= period; i++)
     {
      double tr = r[i].high - r[i].low;
      double a = MathAbs(r[i].high - r[i + 1].close);
      double b = MathAbs(r[i].low  - r[i + 1].close);
      if(a > tr) tr = a;
      if(b > tr) tr = b;
      sum += tr;
     }
   return sum / period;
  }

// Live impulse: displacement + EMA/SMA side + consecutive LL/LH (flips TF within 1–2 bars)
int ImpulseBiasTF(const ENUM_TIMEFRAMES tf, string &why)
  {
   why = "";
   MqlRates r[];
   int n = LoadRates(tf, 40, r);
   if(n < 20) { why = "no data"; return 0; }
   double atr = RatesATR(r, n, 14);
   if(atr <= 0.0) atr = (r[1].high - r[1].low);
   if(atr <= 0.0) { why = "no atr"; return 0; }

   // SMA(8) as fast trend proxy when EMA handle is elsewhere
   double sma = 0.0;
   for(int i = 1; i <= 8; i++) sma += r[i].close;
   sma /= 8.0;
   bool below = (r[1].close < sma && r[2].close < sma);
   bool above = (r[1].close > sma && r[2].close > sma);
   bool smaDown = (sma < (r[5].close + r[6].close + r[7].close + r[8].close) / 4.0);
   bool smaUp   = (sma > (r[5].close + r[6].close + r[7].close + r[8].close) / 4.0);

   // displacement body in last 1–3 bars
   bool dispBear = false, dispBull = false;
   for(int k = 1; k <= 3; k++)
     {
      double body = r[k].close - r[k].open;
      if(body <= -0.50 * atr) dispBear = true;
      if(body >=  0.50 * atr) dispBull = true;
     }

   // consecutive lower highs / lower lows on raw bars (fast)
   int llN = 0, lhN = 0, hhN = 0, hlN = 0;
   for(int k = 1; k <= 4; k++)
     {
      if(r[k].low  < r[k + 1].low)  llN++;
      if(r[k].high < r[k + 1].high) lhN++;
      if(r[k].low  > r[k + 1].low)  hlN++;
      if(r[k].high > r[k + 1].high) hhN++;
     }
   double lo10 = r[1].low, hi10 = r[1].high;
   for(int k = 2; k <= 10; k++) { if(r[k].low < lo10) lo10 = r[k].low; if(r[k].high > hi10) hi10 = r[k].high; }
   bool newLow  = (r[1].low  <= lo10 + _Point);
   bool newHigh = (r[1].high >= hi10 - _Point);

   int bearScore = 0, bullScore = 0;
   if(dispBear) bearScore += 2;
   if(below && smaDown) bearScore += 2;
   if(llN >= 3) bearScore += 1;
   if(lhN >= 3) bearScore += 1;
   if(newLow) bearScore += 1;
   if(r[1].close < r[5].close - atr) bearScore += 1;

   if(dispBull) bullScore += 2;
   if(above && smaUp) bullScore += 2;
   if(hhN >= 3) bullScore += 1;
   if(hlN >= 3) bullScore += 1;
   if(newHigh) bullScore += 1;
   if(r[1].close > r[5].close + atr) bullScore += 1;

   if(bearScore >= 4 && bearScore > bullScore)
     { why = StringFormat("impulseBEAR d%d sma%d ll%d", dispBear?1:0, (below&&smaDown)?1:0, llN); return -1; }
   if(bullScore >= 4 && bullScore > bearScore)
     { why = StringFormat("impulseBULL d%d sma%d hh%d", dispBull?1:0, (above&&smaUp)?1:0, hhN); return 1; }
   why = StringFormat("noImpulse b%d/u%d", bearScore, bullScore);
   return 0;
  }

// Swing structure lean OR live impulse (so fresh legs are not stuck as RANGE)
int StructureBiasTFEx(const ENUM_TIMEFRAMES tf, string &why)
  {
   why = "";
   MqlRates r[];
   int n = LoadRates(tf, 70, r);
   if(n < 35) { why = "no data"; return 0; }
   const int s = 2;
   int h1 = LastXSwingHigh(r, n, s + 1, s, 1);
   int h2 = (h1 < 0) ? -1 : LastXSwingHigh(r, n, h1 + 1, s, 1);
   int l1 = LastXSwingLow(r, n, s + 1, s, 1);
   int l2 = (l1 < 0) ? -1 : LastXSwingLow(r, n, l1 + 1, s, 1);
   int swing = 0;
   string swingWhy = "swingMix";
   if(h1 >= 0 && h2 >= 0 && l1 >= 0 && l2 >= 0)
     {
      bool hh = (r[h1].high > r[h2].high);
      bool hl = (r[l1].low  > r[l2].low);
      bool lh = (r[h1].high < r[h2].high);
      bool ll = (r[l1].low  < r[l2].low);
      if(hh && hl) { swing = 1;  swingWhy = "HH/HL"; }
      else if(lh && ll) { swing = -1; swingWhy = "LH/LL"; }
      else if(ll && !hh) { swing = -1; swingWhy = "LL lead"; }  // fresh bear impulse: LL before confirmed LH
      else if(hh && !ll) { swing = 1;  swingWhy = "HH lead"; }
     }

   string impWhy = "";
   int impulse = ImpulseBiasTF(tf, impWhy);

   if(swing != 0 && impulse == swing)
     { why = swingWhy + "+" + impWhy; return swing; }
   if(impulse != 0 && swing == 0)
     { why = impWhy; return impulse; }          // KEY: live impulse flips RANGE → BEAR/BULL
   if(impulse != 0 && swing != impulse)
     { why = impWhy + "|swingConflict"; return impulse; } // prefer live impulse
   if(swing != 0)
     { why = swingWhy; return swing; }
   why = swingWhy + "|" + impWhy;
   return 0;
  }

int StructureBiasTF(const ENUM_TIMEFRAMES tf)
  {
   string dummy = "";
   return StructureBiasTFEx(tf, dummy);
  }

// Combine swing/impulse structure with EMA. EMA alone OK when slope+side agree (v1.10).
int CombineTrendEx(const int structB, const int emaB, string &why)
  {
   if(structB != 0 && structB == emaB) { why = "S+E"; return structB; }
   if(structB != 0 && emaB == 0)       { why = "S"; return structB; }
   if(structB != 0 && emaB != structB) { why = "S>E"; return structB; } // structure/impulse leads
   if(structB == 0 && emaB != 0)       { why = "E"; return emaB; }       // v1.10: allow EMA lean
   why = "flat";
   return 0;
  }

int CombineTrend(const int structB, const int emaB)
  {
   string d = "";
   return CombineTrendEx(structB, emaB, d);
  }

string TrendTag(const int d)
  {
   if(d > 0) return "BULL";
   if(d < 0) return "BEAR";
   return "RANGE";
  }

// CHoCH / MSS on a TF: break of prior swing against the old structure within last 6 bars
int DetectChoCH_MSS(const ENUM_TIMEFRAMES tf, string &evt)
  {
   evt = "";
   MqlRates r[];
   int n = LoadRates(tf, 55, r);
   if(n < 28) return 0;
   const int s = 2;
   int h1 = LastXSwingHigh(r, n, s + 1, s, 1);
   int h2 = (h1 < 0) ? -1 : LastXSwingHigh(r, n, h1 + 1, s, 1);
   int l1 = LastXSwingLow(r, n, s + 1, s, 1);
   int l2 = (l1 < 0) ? -1 : LastXSwingLow(r, n, l1 + 1, s, 1);
   if(h1 < 0 || l1 < 0) return 0;

   bool priorBear = (h2 >= 0 && l2 >= 0 && r[h1].high < r[h2].high && r[l1].low < r[l2].low);
   bool priorBull = (h2 >= 0 && l2 >= 0 && r[h1].high > r[h2].high && r[l1].low > r[l2].low);

   for(int k = 1; k <= 6; k++)
     {
      // Bullish CHoCH: was bearish (or mixed with LH), close breaks last swing high
      if((priorBear || (h2 >= 0 && r[h1].high < r[h2].high)) && r[k].close > r[h1].high)
        {
         evt = "CHoCH/MSS BULL @" + TFStr(tf);
         return 1;
        }
      // Bearish CHoCH: was bullish (or mixed with HL), close breaks last swing low
      if((priorBull || (l2 >= 0 && r[l1].low > r[l2].low)) && r[k].close < r[l1].low)
        {
         evt = "CHoCH/MSS BEAR @" + TFStr(tf);
         return -1;
        }
     }
   return 0;
  }

// Exec TF liquidity sweep + MSS against HTF (for counter-trend Unicorn/QAW)
bool ExecReversalAgainst(const int htfDir, string &why)
  {
   why = "";
   if(htfDir == 0) return false;
   const int rev = -htfDir;   // opposite direction we may allow
   MqlRates r[];
   int n = LoadRates(g_tf, 40, r);
   if(n < 25) return false;
   double atr = ATRValue();
   if(atr <= 0.0) return false;
   const int s = InpSwingStrength;
   // sweep of liquidity against HTF then MSS in reverse direction
   bool sweep = false, mss = false;
   if(rev > 0)
     {
      // buy reversal: sweep lows then break swing high
      int l1 = LastXSwingLow(r, n, s + 1, s, 1);
      int h1 = LastXSwingHigh(r, n, s + 1, s, 1);
      if(l1 < 0 || h1 < 0) return false;
      for(int k = 1; k <= 5; k++)
         if(r[k].low < r[l1].low && r[k].close > r[l1].low) { sweep = true; break; }
      for(int k = 1; k <= 4; k++)
         if(r[k].close > r[h1].high) { mss = true; break; }
     }
   else
     {
      int h1 = LastXSwingHigh(r, n, s + 1, s, 1);
      int l1 = LastXSwingLow(r, n, s + 1, s, 1);
      if(l1 < 0 || h1 < 0) return false;
      for(int k = 1; k <= 5; k++)
         if(r[k].high > r[h1].high && r[k].close < r[h1].high) { sweep = true; break; }
      for(int k = 1; k <= 4; k++)
         if(r[k].close < r[l1].low) { mss = true; break; }
     }
   if(sweep && mss)
     {
      why = "Exec sweep+MSS " + DirStr(rev) + " vs HTF " + DirStr(htfDir);
      return true;
     }
   if(sweep) { why = "Exec sweep " + DirStr(rev) + ", waiting MSS"; return false; }
   why = "no Exec reversal vs " + DirStr(htfDir);
   return false;
  }

// v1.10: impulse-aware TF bias; FINAL flips on H1 CHoCH/MSS + M15; H4 lag ≠ hard block.
int ComputeHTFBias()
  {
   string sWhy1 = "", sWhy2 = "", sWhyE = "", sWhyM = "";
   string cWhy1 = "", cWhy2 = "", cWhyE = "", cWhyM = "";

   g_struct1    = StructureBiasTFEx(InpBiasTF1, sWhy1);
   g_ema1       = EmaBiasFromHandle(g_hEMABias1, InpBiasTF1);
   g_bias1      = CombineTrendEx(g_struct1, g_ema1, cWhy1);
   g_tfWhy1     = StringFormat("%s/%s", sWhy1, cWhy1);

   g_struct2    = StructureBiasTFEx(InpBiasTF2, sWhy2);
   g_ema2       = EmaBiasFromHandle(g_hEMABias2, InpBiasTF2);
   g_bias2      = CombineTrendEx(g_struct2, g_ema2, cWhy2);
   g_tfWhy2     = StringFormat("%s/%s", sWhy2, cWhy2);

   // Chart/Exec TF — primary when InpDirectionSource = ChartTF
   g_structExec = StructureBiasTFEx(g_tf, sWhyE);
   g_emaExec    = EmaBiasFromHandle(g_hEMAExec, g_tf);
   g_biasExec   = CombineTrendEx(g_structExec, g_emaExec, cWhyE);
   g_tfWhyExec  = StringFormat("%s/%s", sWhyE, cWhyE);
   string impE = "";
   g_impulseExec = ImpulseBiasTF(g_tf, impE);
   int prevF = g_prevFlow;
   UpdateCandleFlow();
   if(g_candleFlow != 0 && g_candleFlow != prevF) RecordFlowFlip(g_candleFlow);
   else if(g_candleFlow != 0) g_prevFlow = g_candleFlow;

   // Chop pause: force WAIT
   if(g_chopPause)
     {
      datetime bar0 = iTime(_Symbol, g_tf, 0);
      if(bar0 >= g_chopUntilBar) { g_chopPause = false; g_chopUntilBar = 0; }
     }

   int m15Struct = StructureBiasTFEx(PERIOD_M15, sWhyM);
   int m15Ema    = EmaBiasFromHandle(g_hEMAM15, PERIOD_M15);
   int m15Bias   = CombineTrendEx(m15Struct, m15Ema, cWhyM);
   g_tfWhyM15    = StringFormat("%s/%s", sWhyM, cWhyM);

   string e1 = "", e15 = "";
   g_chochH1  = DetectChoCH_MSS(InpBiasTF1, e1);
   g_chochM15 = DetectChoCH_MSS(PERIOD_M15, e15);
   g_chochEvent = e1;
   if(StringLen(e15) > 0)
      g_chochEvent = (StringLen(g_chochEvent) > 0) ? (g_chochEvent + " + " + e15) : e15;

   g_h1Weakening = (g_bias1 == 0) || (g_struct1 != 0 && g_ema1 != 0 && g_struct1 != g_ema1) ||
                   (g_chochH1 != 0 && g_chochH1 != g_bias2);

   // Soft HTF lean (quality/size filter) — not the trade direction when ChartTF source
   int htfLean = 0;
   string htfHow = "";
   if(g_chochH1 != 0 && ((m15Bias == g_chochH1) || (g_chochM15 == g_chochH1) || (m15Struct == g_chochH1)))
     { htfLean = g_chochH1; htfHow = "H1 CHoCH+M15"; }
   else if(g_bias1 != 0)
     { htfLean = g_bias1; htfHow = "H1 lead"; }
   else if(g_bias2 != 0)
     { htfLean = g_bias2; htfHow = "H4"; }

   int finalBias = 0;
   string how = "";
   g_counterImpulseWait = false;

   if(InpDirectionSource == DIR_CHART_TF)
     {
      // Chart TF has priority: structure + EMA + candle flow + impulse
      if(g_candleFlow != 0)
        { finalBias = g_candleFlow; how = "chart flow " + g_flowTag; }
      else if(g_impulseExec != 0)
        { finalBias = g_impulseExec; how = "chart impulse"; }
      else if(g_biasExec != 0)
        { finalBias = g_biasExec; how = "chart S+E"; }
      else if(g_structExec != 0)
        { finalBias = g_structExec; how = "chart struct"; }

      // M5 soft only: note for quality; never hard-block chart direction (M1 fully supported)
      if(IsM1Chart() && g_m5Agree != 0 && finalBias != 0 && g_m5Agree != finalBias)
         how = how + " | M5 soft disagree";
      else if(IsM1Chart() && g_m5Agree == finalBias && finalBias != 0)
         how = how + " | M5 soft agrees";

      // ChartTF: FOLLOW the chart. Soft HTF never forces WAIT / PULLBACK-buy into opposite impulse.
      // Optional hard HTF filter only when user enables it.
      if(finalBias != 0 && InpHTFHardFilter && htfLean != 0 && finalBias != htfLean)
        {
         how = StringFormat("chart %s blocked by HTF hard %s", TrendTag(finalBias), TrendTag(htfLean));
         finalBias = 0;
        }
      else if(finalBias != 0 && htfLean != 0 && finalBias != htfLean)
        {
         // Deep adverse move vs soft HTF → still follow chart, but tag risk
         double depth = PullbackDepthATR(htfLean);
         if(InpPullbackMaxATR > 0.0 && depth > InpPullbackMaxATR)
            how = how + StringFormat(" | deep vs HTF %.1fATR", depth);
        }
     }
   else
     {
      // Legacy HTF-lead path
      if(htfLean != 0) { finalBias = htfLean; how = htfHow; }
      if(finalBias != 0 && g_biasExec != 0 && g_biasExec != finalBias)
        {
         string ciWhy = "";
         if(StrongCounterImpulse(finalBias, ciWhy))
           {
            g_counterImpulseWait = true;
            LogMsg("FINAL WAIT — " + ciWhy, true);
            finalBias = 0;
            how = ciWhy;
           }
         else
           {
            double depth = PullbackDepthATR(finalBias);
            if(InpPullbackMaxATR > 0.0 && depth > InpPullbackMaxATR)
              {
               g_counterImpulseWait = true;
               how = StringFormat("pullback %.1fATR > max — WAIT", depth);
               finalBias = 0;
              }
           }
        }
     }

   string htfSoft = (htfLean > 0) ? "BULL" : ((htfLean < 0) ? "BEAR" : "FLAT");
   g_dirSourceTag = StringFormat("DIR SOURCE: %s chart | flow %s | HTF soft %s%s%s",
                                  TFStr(g_tf), g_flowTag, htfSoft,
                                  InpHTFHardFilter ? " HARD" : "",
                                  g_chopPause ? " | CHOP" : "");

   if(g_chopPause)
     {
      g_trendWhy = StringFormat("FINAL WAIT CHOP | %s | %s", g_dirSourceTag,
                                (StringLen(g_lastFlipMsg) > 0) ? g_lastFlipMsg : "flips");
      g_buyNeeds = "chop pause"; g_sellNeeds = "chop pause";
      if(g_prevFinalBias != 0)
        { LogMsg("FINAL CHANGE " + TrendTag(g_prevFinalBias) + " -> CHOP WAIT", true); g_prevFinalBias = 0; }
      return 0;
     }

   // BUY/SELL needs — mirrored; bounce reclaim flips flow via CandleFlowTF micro-CHoCH
   if(finalBias < 0)
     {
      g_sellNeeds = "pullback/retest in DOWN (not late chase)";
      g_buyNeeds  = (g_candleFlow > 0) ? "pullback/retest in UP" : "UP reclaim/CHoCH (bar close > prior high)";
     }
   else if(finalBias > 0)
     {
      g_buyNeeds  = "pullback/retest in UP (not late chase)";
      g_sellNeeds = (g_candleFlow < 0) ? "pullback/retest in DOWN" : "DOWN break/CHoCH (bar close < prior low)";
     }
   else
     {
      g_buyNeeds  = "flow UP reclaim / pullback";
      g_sellNeeds = "flow DOWN break / pullback";
     }

   if(finalBias == 0)
     {
      g_trendWhy = StringFormat("FINAL WAIT | %s | H4=%s H1=%s Exec=%s | BUY needs: %s | SELL needs: %s",
                                g_dirSourceTag, TrendTag(g_bias2), TrendTag(g_bias1), TrendTag(g_biasExec),
                                g_buyNeeds, g_sellNeeds);
      if(StringLen(how) > 0) g_trendWhy = g_trendWhy + " | " + how;
      if(g_prevFinalBias != 0)
        {
         LogMsg(StringFormat("FINAL CHANGE %s -> RANGE | %s", TrendTag(g_prevFinalBias), g_trendWhy), true);
         g_prevFinalBias = 0;
        }
      return 0;
     }

   // Soft HTF note only — never "PULLBACK look BUY" while chart is printing the opposite impulse
   string softNote = "";
   if(htfLean != 0 && htfLean != finalBias)
      softNote = StringFormat(" | HTF soft %s (quality only)", TrendTag(htfLean));
   else if(htfLean == finalBias && htfLean != 0)
      softNote = " | HTF agrees";

   g_trendWhy = StringFormat("FINAL %s (%s)%s | %s | BUY needs: %s | SELL needs: %s",
                             TrendTag(finalBias), how, softNote, g_dirSourceTag,
                             g_buyNeeds, g_sellNeeds);

   if(finalBias != g_prevFinalBias)
     {
      LogMsg(StringFormat("FINAL CHANGE %s -> %s | %s", TrendTag(g_prevFinalBias), TrendTag(finalBias), g_trendWhy), true);
      g_prevFinalBias = finalBias;
     }
   return finalBias;
  }

bool InSession(string &name)
  {
   if(!InpUseSessions) { name = "ALL"; return true; }
   datetime gmt = TimeCurrent() - (datetime)(g_serverGMTOffset * 3600);
   int m = MinuteOfDay(gmt);
   if(InMinuteWindow(m, g_lonStart, g_lonEnd)) { name = "LONDON"; return true; }
   if(InMinuteWindow(m, g_nyStart,  g_nyEnd))  { name = "NEWYORK"; return true; }
   name = "OFF";
   return false;
  }

void ParseNewsWindows()
  {
   ArrayResize(g_newsStart, 0);
   ArrayResize(g_newsEnd, 0);
   if(StringLen(InpNewsWindows) == 0) return;
   string parts[];
   int n = StringSplit(InpNewsWindows, ';', parts);
   for(int i = 0; i < n; i++)
     {
      string se[];
      if(StringSplit(parts[i], '-', se) != 2) continue;
      int a = 0, b = 0;
      if(!ParseHHMM(se[0], a) || !ParseHHMM(se[1], b)) continue;
      int k = ArraySize(g_newsStart);
      ArrayResize(g_newsStart, k + 1);
      ArrayResize(g_newsEnd, k + 1);
      g_newsStart[k] = a;
      g_newsEnd[k]   = b;
     }
  }

bool InManualNewsWindow()
  {
   if(!InpUseNewsWindows) return false;
   int m = MinuteOfDay(TimeCurrent());
   int n = ArraySize(g_newsStart);
   for(int i = 0; i < n; i++)
      if(InMinuteWindow(m, g_newsStart[i], g_newsEnd[i])) return true;
   return false;
  }

// Economic-calendar blackout. Guarded: disabled in tester, cached 60 s, self-disables for 10 min on API error.
bool CalendarBlock()
  {
   if(!InpUseCalendarNews) return false;
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) return false;
   datetime now = TimeCurrent();
   if(g_calendarFailed && now - g_calendarFailTime < 600) return false;
   if(now - g_calendarLastCheck < 60) return g_calendarBlocked;
   g_calendarLastCheck = now;
   g_calendarBlocked   = false;

   string curs[2];
   curs[0] = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   curs[1] = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   datetime from = now - (datetime)(InpNewsMinAfter * 60);
   datetime to   = now + (datetime)(InpNewsMinBefore * 60);

   for(int c = 0; c < 2; c++)
     {
      if(StringLen(curs[c]) == 0) continue;
      if(c == 1 && curs[1] == curs[0]) continue;
      MqlCalendarValue values[];
      ResetLastError();
      if(!CalendarValueHistory(values, from, to, NULL, curs[c]))
        {
         int err = GetLastError();
         if(err != 0)
           {
            g_calendarFailed   = true;
            g_calendarFailTime = now;
            SetError("Calendar API error " + IntegerToString(err) + " - calendar filter paused 10 min");
            return false;
           }
         continue;
        }
      int nv = ArraySize(values);
      for(int i = 0; i < nv; i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id, ev)) continue;
         if(InpNewsHighOnly && ev.importance != CALENDAR_IMPORTANCE_HIGH) continue;
         if(!InpNewsHighOnly && ev.importance == CALENDAR_IMPORTANCE_NONE) continue;
         if(values[i].time >= from && values[i].time <= to)
           {
            g_calendarBlocked = true;
            return true;
           }
        }
     }
   g_calendarFailed = false;
   return false;
  }

bool NewsBlocked(string &why)
  {
   if(InManualNewsWindow()) { why = "news window"; return true; }
   if(CalendarBlock())      { why = "calendar news"; return true; }
   return false;
  }

bool IsFriday()
  {
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5);
  }

bool IsCryptoSymbol()
  {
   return (g_prof.id == PROF_BTC);
  }

// Forex/gold: 24/5 (broker closes weekends). BTC: 24/7 including Sat/Sun — never apply weekday cutoffs.
bool FridayRulesApply()
  {
   return (!IsCryptoSymbol());
  }

// Broker says the symbol can trade right now (important for BTC weekends)
bool SymbolMarketOpenNow(string &why)
  {
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED) { why = "symbol trade disabled"; return false; }
   if(mode == SYMBOL_TRADE_MODE_CLOSEONLY) { why = "symbol close-only"; return false; }
   // Session quote/trade check from broker calendar (works for crypto weekends)
   datetime now = TimeCurrent();
   MqlDateTime dt; TimeToStruct(now, dt);
   int day = dt.day_of_week;   // 0=Sun .. 6=Sat
   if(day < 0 || day > 6) day = 0;
   datetime from = 0, to = 0;
   if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)day, 0, from, to))
     {
      // No session row — for crypto assume open; for others let OrderSend decide
      if(IsCryptoSymbol()) return true;
      return true;
     }
   // from/to are seconds from midnight of that session day (or 0/0 if closed)
   int sec = dt.hour * 3600 + dt.min * 60 + dt.sec;
   // Some brokers return multiple sessions — scan a few indices
   for(int s = 0; s < 8; s++)
     {
      if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)day, s, from, to)) break;
      if(from == 0 && to == 0) continue;
      int a = (int)from, b = (int)to;
      if(b > a && sec >= a && sec < b) return true;
      if(b < a && (sec >= a || sec < b)) return true;   // wraps midnight
     }
   // If every session is 0/0 the market is closed today
   why = "broker session closed";
   if(IsCryptoSymbol())
     {
      // Crypto: if broker reports no sessions, still allow (many BTC symbols trade 24/7)
      why = "";
      return true;
     }
   return false;
  }

//--- daily statistics from history (magic + symbol) ----------------
void RefreshDailyStats()
  {
   datetime now      = TimeCurrent();
   datetime dayStart = DayStart(now);
   g_tradesToday  = 0;
   g_dailyPL      = 0.0;
   g_consecLosses = 0;
   g_lastLossTime = 0;

   if(!HistorySelect(dayStart - 7 * 86400, now + 86400))
     {
      g_balanceDayStart = AccountInfoDouble(ACCOUNT_BALANCE);
      return;
     }

   ulong    posIds[];
   double   posPL[];
   datetime posT[];
   int      np = 0;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic) continue;
      long dtype = HistoryDealGetInteger(d, DEAL_TYPE);
      if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL) continue;
      long     entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      datetime t     = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      double   pl    = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
      ulong    pid   = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);

      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
         if(t >= dayStart) g_tradesToday++;

      if(t >= dayStart) g_dailyPL += pl;

      int k = -1;
      for(int q = 0; q < np; q++) if(posIds[q] == pid) { k = q; break; }
      if(k < 0)
        {
         np++;
         ArrayResize(posIds, np); ArrayResize(posPL, np); ArrayResize(posT, np);
         k = np - 1;
         posIds[k] = pid; posPL[k] = 0.0; posT[k] = t;
        }
      posPL[k] += pl;
      if(entry != DEAL_ENTRY_IN && t > posT[k]) posT[k] = t;
     }

   // consecutive losses: walk closed positions from most recent backwards (today only, so the
   // lock really does release at the next day); last loss time is taken over the whole window
   bool streakOpen = true;
   for(int q = np - 1; q >= 0; q--)
     {
      if(PositionSelectByTicket(posIds[q])) continue;   // still open -> not a closed result yet
      if(posPL[q] < 0.0)
        {
         if(g_lastLossTime == 0 || posT[q] > g_lastLossTime) g_lastLossTime = posT[q];
         if(streakOpen && posT[q] >= dayStart) g_consecLosses++;
        }
      else streakOpen = false;
      if(posT[q] < dayStart) streakOpen = false;
     }

   g_balanceDayStart = AccountInfoDouble(ACCOUNT_BALANCE) - g_dailyPL;
   g_lastStatsRefresh = now;
   g_statsDirty = false;
  }

void CheckDailyLocks()
  {
   if(g_dayLocked) return;
   if(InpDailyMaxLossPct > 0.0 && g_balanceDayStart > 0.0 && g_dailyPL <= -g_balanceDayStart * InpDailyMaxLossPct / 100.0)
     { g_dayLocked = true; g_dayLockReason = "daily loss cap"; LogMsg("Daily loss cap reached - no new trades until next day", true); return; }
   if(InpMaxTradesPerDay > 0 && g_tradesToday >= InpMaxTradesPerDay)
     { g_dayLocked = true; g_dayLockReason = "max trades/day"; LogMsg("Max trades per day reached", true); return; }
   if(InpMaxConsecLosses > 0 && g_consecLosses >= InpMaxConsecLosses)
     { g_dayLocked = true; g_dayLockReason = "max consecutive losses"; LogMsg("Max consecutive losses reached - paused until next day", true); return; }
  }

void CheckKillSwitch()
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_equityPeak)
     {
      g_equityPeak = eq;
      if(!MQLInfoInteger(MQL_TESTER)) GlobalVariableSet(g_gvPeakName, g_equityPeak);
     }
   if(g_halted || InpEquityDDKillPct <= 0.0 || g_equityPeak <= 0.0) return;
   if(eq <= g_equityPeak * (1.0 - InpEquityDDKillPct / 100.0))
     {
      g_halted     = true;
      g_haltReason = StringFormat("Equity DD kill: %.2f <= %.2f", eq, g_equityPeak * (1.0 - InpEquityDDKillPct / 100.0));
      SetError(g_haltReason);
      if(InpKillCloseAll) CloseAllOwn("kill switch");
     }
  }

//==================================================================
//  SECTION 7 : RISK / LOT SIZING
//==================================================================
double FitLotToMargin(const int dir, double lot, const double price)
  {
   ENUM_ORDER_TYPE ot = (dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.90;
   for(int i = 0; i < 4 && lot >= g_volMin; i++)
     {
      double need = 0.0;
      if(!OrderCalcMargin(ot, _Symbol, lot, price, need)) { SetError("OrderCalcMargin failed " + IntegerToString(GetLastError())); return 0.0; }
      if(need <= freeMargin || need <= 0.0) return lot;
      double scaled = lot * (freeMargin / need);
      scaled = NormalizeVolume(scaled);
      if(scaled >= lot) scaled = NormalizeVolume(lot - g_volStep);
      lot = scaled;
     }
   return (lot >= g_volMin) ? lot : 0.0;
  }

double LossMoneyAt(const double lot, const double slDist)
  {
   if(lot <= 0.0 || slDist <= 0.0) return 0.0;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickVal <= 0.0) tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickVal <= 0.0) return 0.0;
   return lot * (slDist / tickSize) * tickVal;
  }

double EffectiveRiskPct(const double lot, const double price, const double sl)
  {
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0.0) return 0.0;
   return 100.0 * LossMoneyAt(lot, MathAbs(price - sl)) / bal;
  }

// Lot sizing budget from % risk ONLY — USD cap is applied to SL distance, never shrinks lot
double LotRiskBudgetMoney()
  {
   return AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
  }

// Max SL distance (price units) so loss at `lot` stays <= moneyCap
double MaxSLDistForMoneyAtLot(const double moneyCap, const double lot)
  {
   if(moneyCap <= 0.0 || lot <= 0.0) return 0.0;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickVal <= 0.0) tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickVal <= 0.0) return 0.0;
   double lossPerLotPerDist = tickVal / tickSize;
   if(lossPerLotPerDist <= 0.0) return 0.0;
   return moneyCap / (lot * lossPerLotPerDist);
  }

double MinStructuralSLDist()
  {
   double floor = FloorDist();
   if(floor <= 0.0) floor = MinDist();
   double structMin = (InpMinStructuralSLPts > 0) ? InpMinStructuralSLPts * _Point : 0.0;
   return MathMax(floor, structMin);
  }

// Cap SL distance to InpMaxLossPerTradeMoney at the chosen lot.
// Does NOT change lot. Places SL at min(structural, money-cap distance), ≥ broker floor & MinStructuralSLPts.
bool CapSLToMoneyLoss(const int dir, const double price, const double lot, double &sl, string &why)
  {
   why = "";
   if(!InpTightenSLForRisk || InpMaxLossPerTradeMoney <= 0.0 || lot <= 0.0) return false;
   double maxDist = MaxSLDistForMoneyAtLot(InpMaxLossPerTradeMoney, lot);
   if(maxDist <= 0.0) { why = "cannot compute money SL cap"; return false; }
   double minDist = MinStructuralSLDist();
   if(maxDist < minDist)
     {
      why = StringFormat("skipped: USD %.0f SL cap (%.0f pts) < min structural %.0f pts at lot %.2f",
                         InpMaxLossPerTradeMoney, maxDist / _Point, minDist / _Point, lot);
      return false;
     }
   double curDist = MathAbs(price - sl);
   if(curDist <= maxDist + _Point) return false;   // structural already within USD cap
   double newSL = NormPrice(price - dir * maxDist);
   if(dir > 0 && newSL >= price) { why = "cap SL invalid (buy)"; return false; }
   if(dir < 0 && newSL <= price) { why = "cap SL invalid (sell)"; return false; }
   if(!ValidateInitialSL(dir, newSL)) { why = "cap SL fails broker floor"; return false; }
   LogMsg(StringFormat("SL capped to USD %.2f @ lot %.2f: %.*f -> %.*f (%.0f -> %.0f pts)",
                       InpMaxLossPerTradeMoney, lot, g_digits, sl, g_digits, newSL,
                       curDist / _Point, maxDist / _Point), true);
   sl = newSL;
   return true;
  }

double CalcLot(const int dir, const double price, const double sl, string &why)
  {
   double slDist = MathAbs(price - sl);
   if(slDist <= 0.0) { why = "zero SL distance"; return 0.0; }

   double lot = 0.0;
   if(InpFixedLot > 0.0)
     {
      lot = NormalizeVolume(InpFixedLot);
      if(lot < g_volMin) lot = g_volMin;
     }
   else
     {
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(tickVal <= 0.0) tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize <= 0.0 || tickVal <= 0.0) { why = "tick value/size unavailable"; return 0.0; }
      double riskMoney  = LotRiskBudgetMoney();   // % only — never shrink lot for USD SL cap
      if(riskMoney <= 0.0) { why = "risk budget = 0"; return 0.0; }
      double lossPerLot = (slDist / tickSize) * tickVal;
      if(lossPerLot <= 0.0) { why = "loss per lot = 0"; return 0.0; }
      lot = NormalizeVolume(riskMoney / lossPerLot);
      if(lot < g_volMin)
        {
         if(!InpAllowMinLotOverRisk)
           { why = StringFormat("risk lot %.4f < min %.2f (enable InpAllowMinLotOverRisk)", riskMoney / lossPerLot, g_volMin); return 0.0; }
         double eff = EffectiveRiskPct(g_volMin, price, sl);
         // Note: wide structural SL may show high % here; CapSLToMoneyLoss will shrink SL after lot is chosen
         if(InpMaxRiskPctAtMinLot > 0.0 && InpMaxLossPerTradeMoney <= 0.0 && eff > InpMaxRiskPctAtMinLot + 0.05)
           {
            why = StringFormat("min-lot risk %.2f%% > max %.1f%% (SL %.0f pts)",
                               eff, InpMaxRiskPctAtMinLot, slDist / _Point);
            return 0.0;
           }
         LogMsg(StringFormat("Risk lot %.4f < min %.2f — using min lot (eff risk %.2f%% before SL cap)",
                             riskMoney / lossPerLot, g_volMin, eff), true);
         lot = g_volMin;
        }
     }
   if(lot > g_volMax) lot = g_volMax;
   lot = FitLotToMargin(dir, lot, price);
   if(lot <= 0.0) { why = "insufficient margin"; return 0.0; }
   return lot;
  }

//==================================================================
//  SECTION 8 : SEND TRACKING & ORDER EXECUTION
//==================================================================
string RetcodeStr(const uint rc)
  {
   switch(rc)
     {
      case TRADE_RETCODE_REQUOTE:            return "REQUOTE";
      case TRADE_RETCODE_REJECT:             return "REJECT";
      case TRADE_RETCODE_CANCEL:             return "CANCEL";
      case TRADE_RETCODE_PLACED:             return "PLACED";
      case TRADE_RETCODE_DONE:               return "DONE";
      case TRADE_RETCODE_DONE_PARTIAL:       return "DONE_PARTIAL";
      case TRADE_RETCODE_ERROR:              return "ERROR";
      case TRADE_RETCODE_TIMEOUT:            return "TIMEOUT";
      case TRADE_RETCODE_INVALID:            return "INVALID";
      case TRADE_RETCODE_INVALID_VOLUME:     return "INVALID_VOLUME";
      case TRADE_RETCODE_INVALID_PRICE:      return "INVALID_PRICE";
      case TRADE_RETCODE_INVALID_STOPS:      return "INVALID_STOPS";
      case TRADE_RETCODE_TRADE_DISABLED:     return "TRADE_DISABLED";
      case TRADE_RETCODE_MARKET_CLOSED:      return "MARKET_CLOSED";
      case TRADE_RETCODE_NO_MONEY:           return "NO_MONEY";
      case TRADE_RETCODE_PRICE_CHANGED:      return "PRICE_CHANGED";
      case TRADE_RETCODE_PRICE_OFF:          return "PRICE_OFF";
      case TRADE_RETCODE_INVALID_EXPIRATION: return "INVALID_EXPIRATION";
      case TRADE_RETCODE_ORDER_CHANGED:      return "ORDER_CHANGED";
      case TRADE_RETCODE_TOO_MANY_REQUESTS:  return "TOO_MANY_REQUESTS";
      case TRADE_RETCODE_NO_CHANGES:         return "NO_CHANGES";
      case TRADE_RETCODE_SERVER_DISABLES_AT: return "SERVER_DISABLES_AT";
      case TRADE_RETCODE_CLIENT_DISABLES_AT: return "CLIENT_DISABLES_AT";
      case TRADE_RETCODE_LOCKED:             return "LOCKED";
      case TRADE_RETCODE_FROZEN:             return "FROZEN";
      case TRADE_RETCODE_INVALID_FILL:       return "INVALID_FILL";
      case TRADE_RETCODE_CONNECTION:         return "CONNECTION";
      case TRADE_RETCODE_ONLY_REAL:          return "ONLY_REAL";
      case TRADE_RETCODE_LIMIT_ORDERS:       return "LIMIT_ORDERS";
      case TRADE_RETCODE_LIMIT_VOLUME:       return "LIMIT_VOLUME";
      case TRADE_RETCODE_INVALID_ORDER:      return "INVALID_ORDER";
      case TRADE_RETCODE_POSITION_CLOSED:    return "POSITION_CLOSED";
      case TRADE_RETCODE_INVALID_CLOSE_VOLUME: return "INVALID_CLOSE_VOLUME";
      case TRADE_RETCODE_CLOSE_ORDER_EXIST:  return "CLOSE_ORDER_EXIST";
      case TRADE_RETCODE_LIMIT_POSITIONS:    return "LIMIT_POSITIONS";
      case TRADE_RETCODE_HEDGE_PROHIBITED:   return "HEDGE_PROHIBITED";
      default:                               return "RC" + IntegerToString((int)rc);
     }
  }

string SendStateStr(const int st)
  {
   switch(st)
     {
      case SEND_IN_FLIGHT:  return "IN_FLIGHT";
      case SEND_DONE:       return "DONE";
      case SEND_AMBIGUOUS:  return "AMBIGUOUS";
      case SEND_UNRESOLVED: return "UNRESOLVED";
      case SEND_FAILED:     return "FAILED";
      default:              return "IDLE";
     }
  }

void SendRingInit()
  {
   for(int i = 0; i < SEND_RING; i++) g_send[i].Reset();
   g_sendHead = 0;
   // seed the sequence from the clock so comment tags do not repeat across EA restarts
   g_sendSeq = (uint)(((long)TimeLocal() % 90000) * 10);
  }

int SendRingAlloc()
  {
   int idx = g_sendHead;
   g_sendHead = (g_sendHead + 1) % SEND_RING;
   g_send[idx].Reset();
   g_sendSeq++;
   g_send[idx].seq = g_sendSeq;
   return idx;
  }

// True while any send is in flight or ambiguous -> no new sends allowed
bool SendBlocked(string &why)
  {
   for(int i = 0; i < SEND_RING; i++)
     {
      if(g_send[i].state == SEND_IN_FLIGHT)  { why = "send in flight #" + IntegerToString((int)g_send[i].seq); return true; }
      if(g_send[i].state == SEND_AMBIGUOUS)  { why = "send ambiguous #" + IntegerToString((int)g_send[i].seq); return true; }
     }
   return false;
  }

string SendFlightSummary()
  {
   int newest = -1; datetime t = 0;
   for(int i = 0; i < SEND_RING; i++)
     {
      if(g_send[i].state == SEND_IN_FLIGHT || g_send[i].state == SEND_AMBIGUOUS)
         return SendStateStr(g_send[i].state) + " #" + IntegerToString((int)g_send[i].seq);
      if(g_send[i].state != SEND_NONE && g_send[i].sentAt >= t) { t = g_send[i].sentAt; newest = i; }
     }
   if(newest < 0) return "IDLE";
   return "IDLE (last #" + IntegerToString((int)g_send[newest].seq) + " " + SendStateStr(g_send[newest].state) + " " + RetcodeStr(g_send[newest].retcode) + ")";
  }

bool FindPositionByComment(const string comment, const datetime notBefore, ulong &ticketOut)
  {
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if((datetime)PositionGetInteger(POSITION_TIME) < notBefore) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), comment) >= 0) { ticketOut = t; return true; }
     }
   return false;
  }

// Timer task: resolve in-flight / ambiguous sends against positions and deal history
void ReconcileSendFlight()
  {
   datetime now = TimeCurrent();
   for(int i = 0; i < SEND_RING; i++)
     {
      int st = g_send[i].state;
      if(st != SEND_IN_FLIGHT && st != SEND_AMBIGUOUS) continue;

      if(st == SEND_IN_FLIGHT && now - g_send[i].sentAt > 30)
        {
         g_send[i].state = SEND_AMBIGUOUS;
         LogMsg("Send #" + IntegerToString((int)g_send[i].seq) + " in-flight timeout -> AMBIGUOUS", true);
        }

      // 1. match an open position by comment tag
      ulong pt = 0;
      if(FindPositionByComment(g_send[i].comment, g_send[i].sentAt - 5, pt))
        {
         g_send[i].position   = pt;
         g_send[i].state      = SEND_DONE;
         g_send[i].resolvedAt = now;
         LogMsg("Send #" + IntegerToString((int)g_send[i].seq) + " reconciled to position #" + IntegerToString((long)pt));
         continue;
        }
      // 2. match an entry deal by order ticket or comment
      if(HistorySelect(g_send[i].sentAt - 5, now + 60))
        {
         int total = HistoryDealsTotal();
         bool matched = false;
         for(int k = total - 1; k >= 0 && !matched; k--)
           {
            ulong d = HistoryDealGetTicket(k);
            if(d == 0) continue;
            if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
            if(HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic) continue;
            if(HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            bool byOrder   = (g_send[i].order != 0 && (ulong)HistoryDealGetInteger(d, DEAL_ORDER) == g_send[i].order);
            bool byComment = (StringFind(HistoryDealGetString(d, DEAL_COMMENT), g_send[i].comment) >= 0);
            if(byOrder || byComment)
              {
               g_send[i].deal       = d;
               g_send[i].position   = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
               g_send[i].state      = SEND_DONE;
               g_send[i].resolvedAt = now;
               matched = true;
               LogMsg("Send #" + IntegerToString((int)g_send[i].seq) + " reconciled via deal #" + IntegerToString((long)d));
              }
           }
         if(matched) continue;
        }
      // 3. give up after timeout: unresolved (no duplicate will be sent while ambiguous)
      if(g_send[i].state == SEND_AMBIGUOUS && now - g_send[i].sentAt > 60)
        {
         g_send[i].state      = SEND_UNRESOLVED;
         g_send[i].resolvedAt = now;
         SetError("Send #" + IntegerToString((int)g_send[i].seq) + " UNRESOLVED (no position/deal found) - check journal");
        }
     }
  }

// Clamp an initial SL so it respects the broker floor and the profile minimum distance.
// Returns false if no valid SL can be produced.
bool ValidateInitialSL(const int dir, double &sl)
  {
   double ref  = RefPrice(dir);
   double minD = MinDist();
   if(dir > 0)
     {
      if(sl <= 0.0 || sl > ref - minD) sl = ref - minD;
     }
   else
     {
      if(sl <= 0.0 || sl < ref + minD) sl = ref + minD;
     }
   sl = NormPrice(sl);
   if(dir > 0 && sl >= g_bid) return false;
   if(dir < 0 && sl <= g_ask) return false;
   return true;
  }

// The only place a market entry is sent. Returns true if the order was filled.
bool SendMarketOrder(const SSignal &sig, double lot, double sl, double tp)
  {
   int idx = SendRingAlloc();
   string tag = InpCommentTag;
   if(StringLen(tag) > 4) tag = StringSubstr(tag, 0, 4);
   string comment = StringFormat("%s%u %s", tag, g_send[idx].seq, sig.engine);
   if(StringLen(comment) > 31) comment = StringSubstr(comment, 0, 31);

   g_send[idx].state   = SEND_IN_FLIGHT;
   g_send[idx].sentAt  = TimeCurrent();
   g_send[idx].dir     = sig.dir;
   g_send[idx].volume  = lot;
   g_send[idx].sl      = sl;
   g_send[idx].tp      = tp;
   g_send[idx].comment = comment;
   g_send[idx].engine  = sig.engine;

   MqlTradeRequest req;
   MqlTradeResult  res;
   ENUM_ORDER_TYPE_FILLING fill = g_filling;
   bool widened = false;
   bool lotCut  = false;

   for(int attempt = 1; attempt <= 4; attempt++)
     {
      if(!RefreshPrices()) { SetError("no tick for send"); break; }
      if(!ValidateInitialSL(sig.dir, sl)) { SetError("SL invalid after floor clamp - trade skipped"); g_send[idx].state = SEND_FAILED; return false; }

      ZeroMemory(req);
      ZeroMemory(res);
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = _Symbol;
      req.volume       = lot;
      req.type         = (sig.dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      req.price        = NormPrice((sig.dir > 0) ? g_ask : g_bid);
      req.sl           = sl;
      req.tp           = (tp > 0.0) ? NormPrice(tp) : 0.0;
      req.deviation    = (ulong)g_prof.deviationPts;
      req.magic        = (ulong)InpMagic;
      req.comment      = comment;
      req.type_filling = fill;
      req.type_time    = ORDER_TIME_GTC;

      g_send[idx].attempts = attempt;
      g_send[idx].price    = req.price;
      g_send[idx].sl       = sl;

      ResetLastError();
      bool ok = OrderSend(req, res);
      g_send[idx].retcode = res.retcode;
      g_send[idx].order   = res.order;
      g_send[idx].deal    = res.deal;

      if(ok && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL || res.retcode == TRADE_RETCODE_PLACED))
        {
         g_send[idx].state      = SEND_DONE;
         g_send[idx].resolvedAt = TimeCurrent();
         if(res.deal != 0 && HistoryDealSelect(res.deal))
            g_send[idx].position = (ulong)HistoryDealGetInteger(res.deal, DEAL_POSITION_ID);
         LogMsg(StringFormat("ENTRY %s %.2f @ %.*f SL %.*f TP %.*f [%s] %s (order %I64u deal %I64u)",
                             DirStr(sig.dir), lot, g_digits, res.price > 0 ? res.price : req.price, g_digits, sl, g_digits, tp,
                             sig.engine, sig.reason, res.order, res.deal), true);
         return true;
        }

      uint rc = res.retcode;
      LogMsg(StringFormat("OrderSend attempt %d -> %s (%u) lasterr %d", attempt, RetcodeStr(rc), rc, GetLastError()), true);

      if(rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED || rc == TRADE_RETCODE_PRICE_OFF)
        {
         if(attempt < 4) { Sleep(250); continue; }
         g_send[idx].state = SEND_FAILED; SetError("Requote/price-off limit reached"); return false;
        }
      if(rc == TRADE_RETCODE_INVALID_STOPS)
        {
         if(!widened)
           {
            widened = true;
            // widen once: at least the broker floor, plus a safety margin of max(floor, 10 pts)
            int    floorPts = BrokerStopFloor();
            double extra    = (floorPts > 10 ? floorPts : 10) * _Point;
            double curDist  = MathAbs(RefPrice(sig.dir) - sl);
            double newDist  = ((curDist > floorPts * _Point) ? curDist : floorPts * _Point) + extra;
            sl = (sig.dir > 0) ? g_bid - newDist : g_ask + newDist;
            continue;
           }
         g_send[idx].state = SEND_FAILED; SetError("INVALID_STOPS twice - trade skipped (never naked)"); return false;
        }
      if(rc == TRADE_RETCODE_INVALID_FILL)
        {
         if(attempt < 4) { fill = NextFillingMode(fill); g_filling = fill; continue; }
         g_send[idx].state = SEND_FAILED; SetError("No accepted filling mode"); return false;
        }
      if(rc == TRADE_RETCODE_NO_MONEY)
        {
         if(!lotCut)
           {
            lotCut = true;
            double half = NormalizeVolume(lot * 0.5);
            if(half >= g_volMin && half < lot) { lot = half; g_send[idx].volume = lot; continue; }
           }
         g_send[idx].state = SEND_FAILED; g_nextSendAllowed = TimeCurrent() + 300; SetError("NO_MONEY - backoff 5 min"); return false;
        }
      if(rc == TRADE_RETCODE_TOO_MANY_REQUESTS)
        { g_send[idx].state = SEND_FAILED; g_nextSendAllowed = TimeCurrent() + 10; SetError("TOO_MANY_REQUESTS - backoff 10 s"); return false; }
      if(rc == TRADE_RETCODE_MARKET_CLOSED)
        { g_send[idx].state = SEND_FAILED; g_nextSendAllowed = TimeCurrent() + 300; SetError("MARKET_CLOSED - backoff 5 min"); return false; }
      if(rc == TRADE_RETCODE_TIMEOUT || rc == TRADE_RETCODE_CONNECTION || rc == 0 || rc == TRADE_RETCODE_ERROR)
        {
         // Outcome unknown: block further sends until reconciled (no duplicate)
         g_send[idx].state = SEND_AMBIGUOUS;
         SetError("Send #" + IntegerToString((int)g_send[idx].seq) + " outcome unknown (" + RetcodeStr(rc) + ") - reconciling");
         return false;
        }
      if(rc == TRADE_RETCODE_INVALID_VOLUME)
        {
         double nv = NormalizeVolume(lot);
         if(nv != lot && nv >= g_volMin && attempt < 4) { lot = nv; g_send[idx].volume = lot; continue; }
        }
      // deterministic rejection
      g_send[idx].state = SEND_FAILED;
      g_nextSendAllowed = TimeCurrent() + 5;
      SetError("Order rejected: " + RetcodeStr(rc));
      return false;
     }
   if(g_send[idx].state == SEND_IN_FLIGHT) g_send[idx].state = SEND_FAILED;
   return false;
  }

bool ModifyPositionSL(const ulong ticket, const double sl, const double tp)
  {
   uint rc = 0;
   return ModifyPositionSLEx(ticket, sl, tp, rc);
  }

bool ModifyPositionSLEx(const ulong ticket, const double sl, const double tp, uint &retcodeOut)
  {
   MqlTradeRequest req; MqlTradeResult res;
   ZeroMemory(req); ZeroMemory(res);
   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = _Symbol;
   req.position = ticket;
   req.sl       = NormPrice(sl);
   req.tp       = (tp > 0.0) ? NormPrice(tp) : 0.0;
   req.magic    = (ulong)InpMagic;
   ResetLastError();
   bool ok = OrderSend(req, res);
   retcodeOut = res.retcode;
   if(ok && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED || res.retcode == TRADE_RETCODE_NO_CHANGES))
      return true;
   return false;
  }

// Clamp desired SL to broker stop/freeze distance from current bid/ask; return false if cannot improve
bool ClampSLToStopFloor(const int dir, double &sl)
  {
   if(!RefreshPrices()) return false;
   double floor = FloorDist();
   // also respect live spread so BE is not inside the spread
   double spr = (g_ask - g_bid);
   if(spr < 0.0) spr = 0.0;
   double minOff = floor;
   if(InpBEIncludeSpread && spr > minOff) minOff = spr;
   if(dir > 0)
     {
      double maxSL = g_bid - minOff;
      if(sl > maxSL) sl = NormPrice(maxSL);
      if(sl >= g_bid) return false;
     }
   else
     {
      double minSL = g_ask + minOff;
      if(sl < minSL) sl = NormPrice(minSL);
      if(sl <= g_ask) return false;
     }
   return true;
  }

// Try SL move with retries; loud log every attempt. On hard fail with profit at risk → emergency close.
bool ProtectMoveSL(const ulong ticket, const int dir, const double entry, const double oldSL,
                   double wantSL, const double tp, const string src,
                   const double profitPts, const double profitMoney, const double peakPts,
                   const bool mustKeepProfit)
  {
   if(!RefreshPrices())
     {
      LogMsg(StringFormat("%s MOVE #%I64u SKIP no-tick want=%.*f", src, ticket, g_digits, wantSL), true);
      return false;
     }
   int retries = (InpLockModifyRetries > 0) ? InpLockModifyRetries : 1;
   double trySL = NormPrice(wantSL);
   for(int attempt = 1; attempt <= retries; attempt++)
     {
      if(!ClampSLToStopFloor(dir, trySL))
        {
         LogMsg(StringFormat("%s MOVE #%I64u attempt %d CLAMP-FAIL SL %.*f -> %.*f (bid=%.*f ask=%.*f floor=%d) — too close",
                             src, ticket, attempt, g_digits, oldSL, g_digits, trySL,
                             g_digits, g_bid, g_digits, g_ask, BrokerStopFloor()), true);
         // pull one more Point inside and retry
         trySL = NormPrice(trySL - dir * _Point);
         if(!ClampSLToStopFloor(dir, trySL))
           {
            if(mustKeepProfit && profitMoney > 0.0 && InpLockEmergencyClose)
              {
               LogMsg(StringFormat("%s EMERGENCY CLOSE #%I64u — cannot place lock SL, profit USD %.2f at risk",
                                   src, ticket, profitMoney), true);
               return ClosePositionVolume(ticket, 0.0, "lock fail close");
              }
            return false;
           }
        }
      // Must not loosen vs old SL
      if(oldSL > 0.0)
        {
         if(dir > 0 && trySL <= oldSL + _Point * 0.1)
           {
            LogMsg(StringFormat("%s MOVE #%I64u NO-IMPROVE old=%.*f try=%.*f", src, ticket, g_digits, oldSL, g_digits, trySL), true);
            return false;
           }
         if(dir < 0 && trySL >= oldSL - _Point * 0.1)
           {
            LogMsg(StringFormat("%s MOVE #%I64u NO-IMPROVE old=%.*f try=%.*f", src, ticket, g_digits, oldSL, g_digits, trySL), true);
            return false;
           }
        }
      uint rc = 0;
      bool ok = ModifyPositionSLEx(ticket, trySL, tp, rc);
      if(ok)
        {
         LogMsg(StringFormat("%s MOVE #%I64u SL %.*f -> %.*f ok retcode=%u (profit %.0f pts / USD %.2f peak %.0f)",
                             src, ticket, g_digits, oldSL, g_digits, trySL, rc, profitPts, profitMoney, peakPts), true);
         return true;
        }
      LogMsg(StringFormat("%s MOVE #%I64u SL %.*f -> %.*f FAIL retcode=%u %s err=%d (attempt %d/%d)",
                          src, ticket, g_digits, oldSL, g_digits, trySL, rc, RetcodeStr(rc), GetLastError(),
                          attempt, retries), true);
      if(rc == TRADE_RETCODE_NO_CHANGES) return true;
      if(rc == TRADE_RETCODE_INVALID_STOPS || rc == TRADE_RETCODE_FROZEN || rc == TRADE_RETCODE_INVALID_PRICE)
        {
         // push SL further from market by another floor step and retry
         trySL = NormPrice(trySL - dir * MathMax(FloorDist(), (g_ask - g_bid)));
         Sleep(50);
         RefreshPrices();
         continue;
        }
      if(rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED || rc == TRADE_RETCODE_PRICE_OFF)
        { Sleep(50); RefreshPrices(); continue; }
      break;
     }
   if(mustKeepProfit && profitMoney > 0.0 && InpLockEmergencyClose)
     {
      LogMsg(StringFormat("%s EMERGENCY CLOSE #%I64u after modify fails — profit USD %.2f peakPts %.0f",
                          src, ticket, profitMoney, peakPts), true);
      return ClosePositionVolume(ticket, 0.0, "lock fail close");
     }
   return false;
  }

bool ClosePositionVolume(const ulong ticket, double volume, const string reason)
  {
   if(!PositionSelectByTicket(ticket)) return false;
   int    dir   = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
   double pvol  = PositionGetDouble(POSITION_VOLUME);
   if(volume <= 0.0 || volume > pvol) volume = pvol;
   volume = NormalizeVolume(volume);
   if(volume < g_volMin) return false;
   if(!RefreshPrices()) return false;

   ENUM_ORDER_TYPE_FILLING fill = g_filling;
   for(int attempt = 1; attempt <= 3; attempt++)
     {
      MqlTradeRequest req; MqlTradeResult res;
      ZeroMemory(req); ZeroMemory(res);
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = _Symbol;
      req.position     = ticket;
      req.volume       = volume;
      req.type         = (dir > 0) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      req.price        = NormPrice((dir > 0) ? g_bid : g_ask);
      req.deviation    = (ulong)g_prof.deviationPts;
      req.magic        = (ulong)InpMagic;
      req.comment      = "close " + reason;
      req.type_filling = fill;
      ResetLastError();
      bool ok = OrderSend(req, res);
      if(ok && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL || res.retcode == TRADE_RETCODE_PLACED))
        {
         LogMsg(StringFormat("CLOSE #%I64u vol %.2f (%s)", ticket, volume, reason), true);
         g_statsDirty = true;
         return true;
        }
      if(res.retcode == TRADE_RETCODE_INVALID_FILL) { fill = NextFillingMode(fill); continue; }
      if(res.retcode == TRADE_RETCODE_REQUOTE || res.retcode == TRADE_RETCODE_PRICE_CHANGED || res.retcode == TRADE_RETCODE_PRICE_OFF)
        { Sleep(200); RefreshPrices(); continue; }
      if(res.retcode == TRADE_RETCODE_POSITION_CLOSED) return true;
      SetError(StringFormat("Close #%I64u failed: %s", ticket, RetcodeStr(res.retcode)));
      return false;
     }
   return false;
  }

void CloseAllOwn(const string reason)
  {
   ulong tickets[];
   int n = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      ArrayResize(tickets, n + 1);
      tickets[n++] = t;
     }
   for(int i = 0; i < n; i++) ClosePositionVolume(tickets[i], 0.0, reason);
  }

//==================================================================
//  SECTION 9 : SIGNAL ENGINES
//==================================================================

//------------------------------------------------------------------
// 9.1 ICT UNICORN : liquidity sweep -> displacement (FVG) -> MSS ->
//     retest of Breaker Block + FVG overlap zone
//------------------------------------------------------------------
bool UnicornScan(const MqlRates &r[], const int n, const double atr, const int dir, bool &waiting, string &why, double &slOut)
  {
   const int s         = InpSwingStrength;
   const int sweepLook = 15;
   const bool agg      = ModeAggressive();
   const double minFvg = agg ? 0.08 * atr : 0.15 * atr;
   const double minOv  = agg ? 0.05 * atr : 0.10 * atr;
   const double minBody= agg ? 0.30 * atr : 0.50 * atr;
   int waitBars = InpUnicornMaxWaitBars;
   if(agg && waitBars < 12) waitBars = 12;
   int scanMax = n - sweepLook - 2;
   if(scanMax > waitBars + 25) scanMax = waitBars + 25;

   for(int i = s + 1; i < scanMax; i++)
     {
      if(!IsXSwingLow(r, n, i, s, dir)) continue;
      // 1. liquidity sweep: swing low below the lowest low of the prior window
      int pl = XLowestIdx(r, n, i + 1, i + sweepLook, dir);
      if(pl < 0) continue;
      double priorLow = XL(r, pl, dir);
      if(XL(r, i, dir) >= priorLow) continue;

      // 2. intermediate (short-term) high between the prior low and the sweep
      int hiTo = pl - 1;
      if(hiTo > i + 10) hiTo = i + 10;
      if(hiTo < i + 1)  hiTo = i + 1;
      int ih = XHighestIdx(r, n, i + 1, hiTo, dir);
      if(ih < 0) continue;
      double mssLevel = XH(r, ih, dir);

      // 3. market structure shift: first completed bar after the sweep closing above that high
      int m = -1;
      for(int k = i - 1; k >= 1; k--)
         if(XC(r, k, dir) > mssLevel) { m = k; break; }
      if(m < 0)
        {
         if(i <= waitBars)
           {
            // Timeout / re-arm: opposite-side WAIT must not freeze the scanner across bars
            if(ImpulseAligned(dir) && i > 3)
              { why = DirStr(dir) + " sweep stale under impulse"; continue; }
            waiting = true; why = DirStr(dir) + " sweep seen, waiting MSS";
           }
         else why = DirStr(dir) + " sweep stale (no MSS)";
         return false;
        }
      if(m > waitBars) { why = DirStr(dir) + " MSS too old"; return false; }
      g_lastStructEvent = "MSS " + DirStr(dir);

      // 4. breaker block: last down-close candle at/just before the intermediate high
      int b = -1;
      int bTo = ih + 4; if(bTo > n - 1) bTo = n - 1;
      for(int k = ih; k <= bTo; k++)
         if(XC(r, k, dir) < XO(r, k, dir)) { b = k; break; }
      if(b < 0) b = ih;
      double bkTop = XH(r, b, dir), bkBot = XL(r, b, dir);

      // 5. zone = FVG∩breaker (strict) OR breaker OR FVG alone (Aggressive)
      double zTop = 0.0, zBot = 0.0; bool found = false; string zKind = "";
      int kFrom = (m > 2) ? m : 2;
      for(int k = kFrom; k <= i && k + 1 < n; k++)
        {
         double fTop = XL(r, k - 1, dir), fBot = XH(r, k + 1, dir);
         if(fTop - fBot < minFvg) continue;
         double oTop = (fTop < bkTop) ? fTop : bkTop;
         double oBot = (fBot > bkBot) ? fBot : bkBot;
         if(oTop - oBot >= minOv) { zTop = oTop; zBot = oBot; found = true; zKind = "breaker+FVG"; break; }
         if(agg && !found) { zTop = fTop; zBot = fBot; found = true; zKind = "FVG"; }
        }
      if(!found && agg)
        { zTop = bkTop; zBot = bkBot; found = true; zKind = "breaker"; }
      if(!found) { why = DirStr(dir) + " MSS ok, no quality FVG/breaker overlap"; return false; }

      // 5b. MSS displacement body
      if(XC(r, m, dir) - XO(r, m, dir) < minBody)
        { why = DirStr(dir) + " MSS weak (no displacement body)"; return false; }

      // 6. invalidation: a close through the zone after the MSS
      for(int k = m - 1; k >= 1; k--)
         if(XC(r, k, dir) < zBot) { why = DirStr(dir) + " unicorn zone invalidated"; return false; }

      // 7. retest: Aggressive allows any touch+close back in zone; else mid rejection
      bool tap1 = (XL(r, 1, dir) <= zTop && XC(r, 1, dir) > zBot && XC(r, 1, dir) > XO(r, 1, dir));
      if(!agg) tap1 = tap1 && (XC(r, 1, dir) >= 0.5 * (zTop + zBot));
      if(!tap1)
        {
         // Re-arm: do not stay WAIT forever — impulse legs skip stale zones
         if(ImpulseAligned(dir) && m > 4)
           { why = DirStr(dir) + " unicorn zone stale (impulse re-arm)"; waiting = false; continue; }
         waiting = true;
         why = StringFormat("%s zone %.*f-%.*f armed, awaiting %s retest", DirStr(dir), g_digits, XReal(dir > 0 ? zBot : zTop, dir), g_digits, XReal(dir > 0 ? zTop : zBot, dir), zKind);
         SetArmedZone(dir, zTop, zBot, "UNICORN", why);
         return false;
        }

      double sweepLow = XL(r, i, dir);
      double xsl = sweepLow - atr * g_prof.slBufferATR;
      if(zBot - sweepLow > 1.5 * atr) xsl = zBot - 0.3 * atr;   // sweep too far: anchor under the zone instead
      slOut = XReal(xsl, dir);
      why   = "Unicorn " + DirStr(dir) + " " + zKind + " retest";
      return true;
     }
   why = DirStr(dir) + " no sweep structure";
   return false;
  }

int UnicornEntrySignal(const int desiredDir, bool &waiting, string &why, double &slOut)
  {
   waiting = false; why = ""; slOut = 0.0;
   MqlRates r[];
   int n = LoadRates(g_tf, InpStructLookback + 10, r);
   if(n < 40)
     {
      why = "no data";
      g_engWhyBuy[ENG_UNICORN] = "no data"; g_engWhySell[ENG_UNICORN] = "no data";
      g_engWhy[ENG_UNICORN] = DualEngTag(g_engWhyBuy[ENG_UNICORN], g_engWhySell[ENG_UNICORN]);
      return 0;
     }
   double atr = ATRValue();
   if(atr <= 0.0)
     {
      why = "no ATR";
      g_engWhyBuy[ENG_UNICORN] = "no ATR"; g_engWhySell[ENG_UNICORN] = "no ATR";
      g_engWhy[ENG_UNICORN] = DualEngTag(g_engWhyBuy[ENG_UNICORN], g_engWhySell[ENG_UNICORN]);
      return 0;
     }

   // Always scan BOTH directions for the BUY/SELL columns (never hard-wire one side)
   string w1 = "", w2 = "";
   bool wait1 = false, wait2 = false;
   double sl1 = 0.0, sl2 = 0.0;
   bool hit1 = UnicornScan(r, n, atr,  1, wait1, w1, sl1);
   bool hit2 = UnicornScan(r, n, atr, -1, wait2, w2, sl2);
   g_engWhyBuy[ENG_UNICORN]  = (StringLen(w1) == 0) ? (hit1 ? "signal" : "idle") : w1;
   g_engWhySell[ENG_UNICORN] = (StringLen(w2) == 0) ? (hit2 ? "signal" : "idle") : w2;
   g_engWhy[ENG_UNICORN] = DualEngTag(g_engWhyBuy[ENG_UNICORN], g_engWhySell[ENG_UNICORN]);
   waiting = (wait1 || wait2);

   // Propose only the requested side (0 = either). Columns already show both.
   if(hit1 && TradeDirAllows(1) && (desiredDir == 0 || desiredDir == 1))
     { why = w1; slOut = sl1; waiting = false; return 1; }
   if(hit2 && TradeDirAllows(-1) && (desiredDir == 0 || desiredDir == -1))
     { why = w2; slOut = sl2; waiting = false; return -1; }
   why = DualEngTag(g_engWhyBuy[ENG_UNICORN], g_engWhySell[ENG_UNICORN]);
   return 0;
  }

//------------------------------------------------------------------
// 9.2 ICT KILLER START : HH/HL (or LH/LL) structure + liquidity run
//     + displacement trigger aligned with EMA
//------------------------------------------------------------------
bool KillerScan(const MqlRates &r[], const int n, const double atr, const int dir, string &why, double &slOut)
  {
   const int s = InpSwingStrength;
   const bool agg = ModeAggressive();
   const double atrBase = ATRBaseline(10);
   const double atrUse  = (atrBase > 0.0) ? atrBase : atr;
   // v1.15c: live K −$18 — never fire Killer against chart flow (morning BUY into BEAR)
   if(InpKillerRequireFlow && g_candleFlow != 0 && dir != g_candleFlow)
     {
      why = DirStr(dir) + " K blocked: flow " + g_flowTag + " (need pullback with flow)";
      return false;
     }
   double ema[];
   bool emaOK = EMAValues(g_hEMAExec, 3, ema) && (dir * (r[1].close - ema[1]) > 0.0) && (dir * (ema[1] - ema[2]) > 0.0);

   int h1 = LastXSwingHigh(r, n, s + 1, s, dir);
   int h2 = (h1 < 0) ? -1 : LastXSwingHigh(r, n, h1 + 1, s, dir);
   int l1 = LastXSwingLow(r, n, s + 1, s, dir);
   int l2 = (l1 < 0) ? -1 : LastXSwingLow(r, n, l1 + 1, s, dir);
   bool haveSwings = (h1 >= 0 && h2 >= 0 && l1 >= 0 && l2 >= 0);
   bool structOK = haveSwings && (XH(r, h1, dir) > XH(r, h2, dir) && XL(r, l1, dir) > XL(r, l2, dir));
   if(structOK && (XH(r, h1, dir) - XH(r, h2, dir) < 0.25 * atrUse || XL(r, l1, dir) - XL(r, l2, dir) < 0.15 * atrUse))
      structOK = false;

   // v1.15c: optional hard MSS/structure — no naked impulse without HH/HL or LH/LL
   if(InpKillerRequireStruct && !structOK)
     {
      if(!haveSwings) why = DirStr(dir) + " K wait: insufficient structure";
      else why = DirStr(dir) + ((dir > 0) ? " K wait: no HH/HL" : " K wait: no LH/LL");
      return false;
     }

   // No-structure path: EMA pullback bounce ONLY (impulse displacement disabled when PullbackOnly)
   if(!structOK)
     {
      if(!agg && !ImpulseAligned(dir))
        {
         if(!haveSwings) why = DirStr(dir) + " insufficient structure";
         else why = DirStr(dir) + ((dir > 0) ? " no HH/HL" : " no LH/LL");
         return false;
        }
      if(!emaOK)
        {
         why = DirStr(dir) + " K wait: EMA not aligned (pullback only)";
         return false;
        }
      bool touched = false;
      double xEma = dir * ema[1];
      for(int k = 1; k <= 5; k++)
         if(XL(r, k, dir) <= xEma + 0.20 * atrUse) { touched = true; break; }
      double body1 = XC(r, 1, dir) - XO(r, 1, dir);
      bool bounce = (touched && body1 >= 0.20 * atrUse && XC(r, 1, dir) > XO(r, 1, dir));
      // late-chase veto even on bounce if already extended
      string lateWhy = "";
      if(LateChaseBlocked(dir, lateWhy))
        { why = DirStr(dir) + " K " + lateWhy; return false; }
      if(!bounce)
        {
         // legacy impulse path — OFF by default in v1.15c (live K chase losses)
         if(InpKillerPullbackOnly)
           { why = DirStr(dir) + " K wait: EMA pullback/retest only (impulse OFF)"; return false; }
         double bodySum = 0.0;
         for(int k = 1; k <= 3; k++)
           {
            double b = XC(r, k, dir) - XO(r, k, dir);
            if(b > 0.0) bodySum += b;
           }
         double minB = DispMinBody(atrUse, true);
         bool impDisp = ImpulseAligned(dir) && body1 > 0.0 &&
                        (body1 >= minB || bodySum >= 0.70 * atrUse) &&
                        (XC(r, 1, dir) > XH(r, 2, dir) || dir * (r[1].close - r[3].close) > 0.5 * atrUse);
         if(!impDisp)
           { why = DirStr(dir) + " cont: waiting EMA pullback bounce"; return false; }
         if(InpPreferPullbackEntry)
           { why = DirStr(dir) + " cont: prefer pullback/retest (not late impulse)"; return false; }
         slOut = NearestContSL(dir, r, n, atrUse);
         why   = "KillerStart " + DirStr(dir) + " impulse displacement";
         g_lastStructEvent = "CONT " + DirStr(dir);
         return true;
        }
      slOut = NearestContSL(dir, r, n, atrUse);
      why   = "KillerStart " + DirStr(dir) + " continuation EMA bounce";
      g_lastStructEvent = "CONT-PB " + DirStr(dir);
      return true;
     }

   // Structure path: liquidity run (sweep) + reclaim — NOT raw impulse break substitute when MSS required
   int j = -1;
   int runMax = agg ? 8 : 4;
   for(int k = 1; k <= runMax; k++)
     {
      int pl = XLowestIdx(r, n, k + 1, k + 5, dir);
      if(pl < 0) break;
      double prior = XL(r, pl, dir);
      if(XL(r, k, dir) < prior && XC(r, k, dir) > prior) { j = k; break; }
     }
   // Impulse break-as-run: only if MSS not required (v1.15c default OFF — caused late K entries)
   if(j < 0 && !InpKillerRequireMSS && ImpulseAligned(dir))
     {
      int pe = XHighestIdx(r, n, 2, 8, dir);
      if(pe >= 0 && XC(r, 1, dir) > XH(r, pe, dir)) j = 1;
     }
   if(j < 0)
     {
      why = DirStr(dir) + (InpKillerRequireMSS
                           ? " K wait: need liquidity sweep/MSS reclaim (no impulse sub)"
                           : " structure ok, no fresh liquidity run");
      return false;
     }

   // After sweep: require pullback-style reclaim close (body with trend), not extreme chase
   string lateWhy2 = "";
   if(LateChaseBlocked(dir, lateWhy2))
     { why = DirStr(dir) + " K " + lateWhy2; return false; }

   double minBody = DispMinBody(atrUse, false); // stricter than Aggressive for K
   double body1 = XC(r, 1, dir) - XO(r, 1, dir);
   double bodySum = 0.0;
   for(int k = 1; k <= 3; k++)
     {
      double b = XC(r, k, dir) - XO(r, k, dir);
      if(b > 0.0) bodySum += b;
     }
   bool strong1 = (body1 > 0.0 && XC(r, 1, dir) > XH(r, 2, dir) && body1 >= minBody);
   bool strongN = (bodySum >= 0.75 * atrUse && XC(r, 1, dir) > XO(r, 1, dir) &&
                   dir * (r[1].close - r[3].close) > 0.0);
   // Prefer reclaim after sweep: close back above swept level (already in j loop) + EMA touch
   bool emaTouch = false;
   if(emaOK)
     {
      double xEma = dir * ema[1];
      for(int k = 1; k <= 5; k++)
         if(XL(r, k, dir) <= xEma + 0.25 * atrUse) { emaTouch = true; break; }
     }
   if(InpKillerPullbackOnly && !emaTouch && !strong1)
     { why = DirStr(dir) + " K wait: pullback/retest after sweep (no naked disp)"; return false; }
   if(!strong1 && !strongN)
     { why = DirStr(dir) + " run seen, waiting strong displacement"; return false; }

   if(!emaOK)
     { why = DirStr(dir) + " K wait: price/EMA not aligned"; return false; }

   slOut = NearestContSL(dir, r, n, atrUse);
   why   = "KillerStart " + DirStr(dir) + " structure+sweep+pullback";
   g_lastStructEvent = (dir > 0) ? "HH/HL+MSS" : "LH/LL+MSS";
   return true;
  }

int KillerDirectionStartSignal(const int desiredDir, string &why, double &slOut)
  {
   why = ""; slOut = 0.0;
   MqlRates r[];
   int n = LoadRates(g_tf, InpStructLookback + 10, r);
   if(n < 40)
     {
      why = "no data";
      g_engWhyBuy[ENG_KILLER] = "no data"; g_engWhySell[ENG_KILLER] = "no data";
      g_engWhy[ENG_KILLER] = DualEngTag("no data", "no data");
      return 0;
     }
   double atr = ATRValue();
   if(atr <= 0.0)
     {
      why = "no ATR";
      g_engWhyBuy[ENG_KILLER] = "no ATR"; g_engWhySell[ENG_KILLER] = "no ATR";
      g_engWhy[ENG_KILLER] = DualEngTag("no ATR", "no ATR");
      return 0;
     }
   string w1 = "", w2 = "";
   double sl1 = 0.0, sl2 = 0.0;
   bool hit1 = KillerScan(r, n, atr,  1, w1, sl1);
   bool hit2 = KillerScan(r, n, atr, -1, w2, sl2);
   g_engWhyBuy[ENG_KILLER]  = (StringLen(w1) == 0) ? (hit1 ? "signal" : "idle") : w1;
   g_engWhySell[ENG_KILLER] = (StringLen(w2) == 0) ? (hit2 ? "signal" : "idle") : w2;
   g_engWhy[ENG_KILLER] = DualEngTag(g_engWhyBuy[ENG_KILLER], g_engWhySell[ENG_KILLER]);

   if(desiredDir > 0 && hit1) { why = w1; slOut = sl1; return 1; }
   if(desiredDir < 0 && hit2) { why = w2; slOut = sl2; return -1; }
   if(desiredDir == 0)
     {
      if(hit1) { why = w1; slOut = sl1; return 1; }
      if(hit2) { why = w2; slOut = sl2; return -1; }
     }
   why = DualEngTag(g_engWhyBuy[ENG_KILLER], g_engWhySell[ENG_KILLER]);
   return 0;
  }

//------------------------------------------------------------------
// 9.3 MULTI-TIER SCALP : M15 bias -> M5 BOS/CHoCH -> M1 trigger
//------------------------------------------------------------------
bool ScalpScan(const int dir, const double atr, string &why, double &slOut)
  {
   MqlRates r15[], r5[], r1[];
   int n15 = LoadRates(PERIOD_M15, 80, r15);
   int n5  = LoadRates(PERIOD_M5,  80, r5);
   int n1  = LoadRates(PERIOD_M1,  40, r1);
   if(n15 < 40 || n5 < 40 || n1 < 20) { why = "scalp: no data"; return false; }
   const int s = 2;

   // M15: aligned OR (pullback allowed — HTF already chose dir; M15 may print opposite HH/HL)
   double e[];
   if(!EMAValues(g_hEMAM15, 5, e)) { why = "scalp: no M15 EMA"; return false; }
   bool emaOK = (dir * (e[1] - e[4]) > 0.0) && (dir * (r15[1].close - e[1]) > 0.0);
   int h1 = LastXSwingHigh(r15, n15, s + 1, s, dir);
   int h2 = (h1 < 0) ? -1 : LastXSwingHigh(r15, n15, h1 + 1, s, dir);
   bool structOK = (h1 >= 0 && h2 >= 0 && XH(r15, h1, dir) > XH(r15, h2, dir));
   bool m15Aligned = (emaOK && structOK);
   if(!m15Aligned && !InpAllowExecPullback)
     { why = "scalp " + DirStr(dir) + ": M15 bias not aligned"; return false; }
   // pullback mode: continue — M5 BOS + M1 trigger must still fire in HTF direction

   // M5 BOS: close beyond last swing OR rolling prior extreme (cascading impulses rarely print fractals)
   int sh = LastXSwingHigh(r5, n5, 3, s, dir);
   bool bos = false;
   double bosLvl = 0.0;
   if(sh >= 0)
     {
      bosLvl = XH(r5, sh, dir);
      int kmax = (sh - 1 < 12) ? sh - 1 : 12;
      for(int k = 1; k <= kmax; k++)
         if(XC(r5, k, dir) > bosLvl) { bos = true; break; }
     }
   if(!bos)
     {
      // rolling prior extreme bars 2..15 (exclude bar 1) — re-arms every bar on new closes
      int pe = XHighestIdx(r5, n5, 2, (n5 - 1 < 15) ? n5 - 1 : 15, dir);
      if(pe >= 2)
        {
         bosLvl = XH(r5, pe, dir);
         if(XC(r5, 1, dir) > bosLvl) bos = true;
         // tip wick beyond level + close holds near/through it
         else if(XH(r5, 1, dir) > bosLvl && XC(r5, 1, dir) > bosLvl - 0.10 * atr)
            bos = true;
        }
     }
   // Impulse shortcut: new M5 close extreme vs last 8 bars
   if(!bos && ImpulseAligned(dir))
     {
      int pe2 = XHighestIdx(r5, n5, 2, 8, dir);
      if(pe2 >= 2 && XC(r5, 1, dir) > XH(r5, pe2, dir)) bos = true;
     }
   if(!bos) { why = "scalp " + DirStr(dir) + ": waiting M5 BOS"; return false; }
   g_lastStructEvent = "M5 BOS " + DirStr(dir);

   // M1 trigger: Aggressive makes M1 optional (fire on M5 BOS); Balanced/Conservative still want M1
   const bool agg = ModeAggressive();
   bool trig = false; string t = "";
   for(int k = 2; k <= 10 && k + 1 < n1; k++)
     {
      double fTop = XL(r1, k - 1, dir), fBot = XH(r1, k + 1, dir);
      if(fTop <= fBot) continue;
      if(XL(r1, 1, dir) <= fTop && XC(r1, 1, dir) > fBot && XC(r1, 1, dir) > XO(r1, 1, dir)) { trig = true; t = "M1 FVG tap"; break; }
     }
   if(!trig)
     {
      bool opp2 = (XC(r1, 2, dir) < XO(r1, 2, dir));
      if(opp2 && XC(r1, 1, dir) > XO(r1, 1, dir) && XC(r1, 1, dir) > XH(r1, 2, dir)) { trig = true; t = "M1 engulfing"; }
     }
   if(!trig)
     {
      int ph = XHighestIdx(r1, n1, 2, 4, dir);
      double body = XC(r1, 1, dir) - XO(r1, 1, dir);
      if(ph >= 0 && body > 0.0 && XC(r1, 1, dir) > XH(r1, ph, dir) && body >= 0.20 * atr)
        { trig = true; t = "M1 micro-displacement"; }
     }
   if(!trig)
     {
      if(agg)
        {
         // Aggressive: M5 BOS alone is enough; M1 is optional / time-boxed skip
         trig = true; t = "M5 BOS (M1 optional)";
        }
      else
        {
         why = "scalp " + DirStr(dir) + ": M5 BOS ok, waiting M1 trigger";
         if(g_zoneActive == false)
           {
            int shZ = LastXSwingLow(r5, n5, s + 1, s, dir);
            if(shZ >= 0)
               SetArmedZone(dir, XH(r5, 1, dir), XL(r5, shZ, dir), "SCALP", why);
           }
         return false;
        }
     }

   // SL: prefer tight M1/M5 structure; Aggressive also allows ATR-capped SL if structure is wide
   double xref = dir * RefPrice(dir);
   int    li   = XLowestIdx(r1, n1, 1, 5, dir);
   double xsl  = XL(r1, (li >= 0 ? li : 1), dir) - atr * g_prof.slBufferATR;
   int sl5 = LastXSwingLow(r5, n5, s + 1, s, dir);
   if(sl5 >= 0)
     {
      double x5 = XL(r5, sl5, dir) - atr * g_prof.slBufferATR;
      // prefer the tighter of M1 vs M5 when both fit
      if(xref - x5 <= InpScalpMaxSLATR * atr)
        {
         if(x5 > xsl || (xref - xsl > InpScalpMaxSLATR * atr)) xsl = x5;
        }
     }
   if(xref - xsl > InpScalpMaxSLATR * atr)
     {
      if(agg)
        {
         xsl = xref - InpScalpMaxSLATR * atr;   // ATR cap as fallback SL
         t = t + "+ATRcapSL";
        }
      else
        { why = "scalp: SL too wide"; return false; }
     }
   slOut = XReal(xsl, dir);
   why   = "Scalp " + DirStr(dir) + (m15Aligned ? " M15+M5 BOS+" : " pullback M5 BOS+") + t;
   return true;
  }

SSignal g_scalpSig;

bool TryScalpEntry(const int dir)
  {
   g_scalpSig.Reset();
   double atr = ATRValue();
   if(atr <= 0.0)
     {
      g_engWhyBuy[ENG_SCALP] = "no ATR"; g_engWhySell[ENG_SCALP] = "no ATR";
      g_engWhy[ENG_SCALP] = DualEngTag("no ATR", "no ATR");
      return false;
     }
   string w1 = "", w2 = "";
   double sl1 = 0.0, sl2 = 0.0;
   bool hit1 = ScalpScan(1, atr, w1, sl1);
   bool hit2 = ScalpScan(-1, atr, w2, sl2);
   g_engWhyBuy[ENG_SCALP]  = (StringLen(w1) == 0) ? (hit1 ? "signal" : "idle") : w1;
   g_engWhySell[ENG_SCALP] = (StringLen(w2) == 0) ? (hit2 ? "signal" : "idle") : w2;
   g_engWhy[ENG_SCALP] = DualEngTag(g_engWhyBuy[ENG_SCALP], g_engWhySell[ENG_SCALP]);

   int got = 0; double sl = 0.0; string wr = "";
   if(dir > 0 && hit1) { got = 1; sl = sl1; wr = w1; }
   else if(dir < 0 && hit2) { got = -1; sl = sl2; wr = w2; }
   else if(dir == 0)
     {
      if(hit1) { got = 1; sl = sl1; wr = w1; }
      else if(hit2) { got = -1; sl = sl2; wr = w2; }
     }
   if(got == 0) return false;
   if(!TradeDirAllows(got)) return false;

   g_scalpSig.valid    = true;
   g_scalpSig.dir      = got;
   g_scalpSig.sl       = sl;
   g_scalpSig.score    = 1.0;
   g_scalpSig.priority = g_engPrio[ENG_SCALP];
   g_scalpSig.engineId = ENG_SCALP;
   g_scalpSig.engine   = "SCP";
   g_scalpSig.reason   = wr;
   return true;
  }

//------------------------------------------------------------------
// 9.4 5-IN-1 BOOK ENGINE (Forex Somali books)
//------------------------------------------------------------------
// CRT : previous H4 candle range; M15 purge of the range low/high, close back inside, CSD confirmation
bool BookCRT(const int dir, const double atr, string &why, double &score, double &slOut)
  {
   MqlRates h4[], m15[];
   if(LoadRates(PERIOD_H4, 4, h4) < 3 || LoadRates(PERIOD_M15, 24, m15) < 12) { why = "CRT: no data"; return false; }
   double rangeLow = XL(h4, 1, dir), rangeHigh = XH(h4, 1, dir);
   if(rangeHigh <= rangeLow) { why = "CRT: bad range"; return false; }

   int p = -1;
   for(int k = 1; k <= 4; k++)
      if(XL(m15, k, dir) < rangeLow && XC(m15, k, dir) > rangeLow) { p = k; break; }
   if(p < 0) { why = "CRT " + DirStr(dir) + ": no H4 purge"; return false; }

   bool conf = (XC(m15, 1, dir) > XO(m15, 1, dir));
   for(int k = 1; k < p; k++) if(XL(m15, k, dir) < XL(m15, p, dir)) conf = false;
   if(p > 1 && XC(m15, 1, dir) <= rangeLow) conf = false;
   if(!conf) { why = "CRT " + DirStr(dir) + ": purge seen, waiting CSD"; return false; }

   double xref = dir * RefPrice(dir);
   if(xref > rangeLow + 0.5 * (rangeHigh - rangeLow) && !ImpulseAligned(dir))
     { why = "CRT " + DirStr(dir) + ": too far from purge"; return false; }

   double depth = (rangeLow - XL(m15, p, dir)) / atr;
   if(depth > 1.5) depth = 1.5;
   score = 1.0 + depth;
   slOut = XReal(XL(m15, p, dir) - atr * g_prof.slBufferATR, dir);
   why   = "CRT " + DirStr(dir) + " H4 purge+CSD";
   return true;
  }

// Iskulaab : breakout of a key level (previous day high/low or H1 swing) then retest
bool BookIskulaab(const MqlRates &r[], const int n, const int dir, const double atr, string &why, double &score, double &slOut)
  {
   double levels[2]; int nl = 0;
   MqlRates d1[];
   if(LoadRates(PERIOD_D1, 3, d1) >= 2) { levels[nl] = XH(d1, 1, dir); nl++; }
   MqlRates h1r[];
   int nh = LoadRates(PERIOD_H1, 60, h1r);
   if(nh >= 20)
     {
      int sh = LastXSwingHigh(h1r, nh, 3, 2, dir);
      if(sh >= 0) { levels[nl] = XH(h1r, sh, dir); nl++; }
     }
   if(nl == 0) { why = "ISK: no levels"; return false; }
   double tol = 0.2 * atr;

   for(int li = 0; li < nl; li++)
     {
      double L = levels[li];
      int b = -1;
      for(int k = 2; k <= 12 && k + 1 < n; k++)
         if(XC(r, k, dir) > L && XC(r, k + 1, dir) <= L) { b = k; break; }
      if(b < 0) continue;
      bool held = true;
      for(int k = b - 1; k >= 1; k--) if(XC(r, k, dir) < L - tol) { held = false; break; }
      if(!held) continue;
      if(!(XL(r, 1, dir) <= L + tol && XC(r, 1, dir) > L)) continue;

      double strength = (XC(r, b, dir) - L) / atr; if(strength > 1.0) strength = 1.0;
      score = 1.0 + strength + ((li == 0) ? 0.3 : 0.0);
      double anchor = (XL(r, 1, dir) < L) ? XL(r, 1, dir) : L;
      slOut = XReal(anchor - atr * g_prof.slBufferATR, dir);
      why   = "Iskulaab " + DirStr(dir) + " break+retest " + ((li == 0) ? "PDH/PDL" : "H1 swing");
      return true;
     }
   why = "ISK " + DirStr(dir) + ": no break+retest";
   return false;
  }

// GARAB "Law & Order" : chain of order blocks in trend direction, entry on retest of the latest OB
bool BookGarab(const MqlRates &r[], const int n, const int dir, const double atr, string &why, double &score, double &slOut)
  {
   int obIdx[3]; int cnt = 0;
   int jmax = (n - 1 < 60) ? n - 1 : 60;
   for(int j = 2; j < jmax && cnt < 3; j++)
     {
      if(!(XC(r, j, dir) < XO(r, j, dir))) continue;
      double hj = XH(r, j, dir);
      bool disp = false;
      if(XC(r, j - 1, dir) > hj && (XH(r, j - 1, dir) - XL(r, j - 1, dir)) >= 0.8 * atr) disp = true;
      else if(j >= 3 && XC(r, j - 2, dir) > hj && (XC(r, j - 2, dir) - XO(r, j - 1, dir)) >= 1.0 * atr) disp = true;
      if(!disp) continue;
      obIdx[cnt] = j; cnt++;
     }
   if(cnt < 2) { why = "GARAB " + DirStr(dir) + ": <2 order blocks"; return false; }

   int chain = 1;
   for(int c = 0; c < cnt - 1; c++)
     {
      if(XL(r, obIdx[c], dir) > XL(r, obIdx[c + 1], dir)) chain++;
      else break;
     }
   if(chain < 2) { why = "GARAB " + DirStr(dir) + ": OBs not chained"; return false; }

   int ob = obIdx[0];
   double obTop = XH(r, ob, dir), obBot = XL(r, ob, dir);
   for(int k = ob - 1; k >= 1; k--)
      if(XC(r, k, dir) < obBot) { why = "GARAB " + DirStr(dir) + ": latest OB violated"; return false; }

   double xref = dir * RefPrice(dir);
   bool tap1 = (XL(r, 1, dir) <= obTop && XC(r, 1, dir) > obBot && XC(r, 1, dir) > XO(r, 1, dir));
   bool tap0 = (XL(r, 0, dir) <= obTop && xref > obBot && xref <= obTop + 0.2 * atr);
   if(!tap1 && !tap0)
     {
      why = "GARAB " + DirStr(dir) + ": chain x" + IntegerToString(chain) + " armed, awaiting OB retest";
      SetArmedZone(dir, obTop, obBot, "GARAB", why);
      return false;
     }

   score = 1.0 + 0.5 * chain;
   slOut = XReal(obBot - atr * g_prof.slBufferATR, dir);
   why   = "GARAB " + DirStr(dir) + " OB chain x" + IntegerToString(chain);
   return true;
  }

// Qawaaniinta : internal-liquidity sweep inside the dealing range, then reversal candle
bool BookQawaaniin(const MqlRates &r[], const int n, const int dir, const double atr, string &why, double &score, double &slOut)
  {
   int H  = LastXSwingHigh(r, n, 4, 3, dir);
   int Lo = LastXSwingLow(r, n, 4, 3, dir);
   if(H < 0 || Lo < 0) { why = "QAW: no dealing range"; return false; }
   double rH = XH(r, H, dir), rL = XL(r, Lo, dir);
   if(rH <= rL) { why = "QAW: invalid range"; return false; }

   int j = -1; double iLow = 0.0;
   for(int k = 1; k <= 3 && j < 0; k++)
     {
      for(int i = k + 2; i < Lo; i++)
        {
         if(!IsXSwingLow(r, n, i, 1, dir)) continue;
         if(XL(r, i, dir) <= rL + 0.1 * atr) continue;
         double il = XL(r, i, dir);
         if(XL(r, k, dir) < il && XC(r, k, dir) > il) { j = k; iLow = il; }
         break;   // only the most recent internal low before bar k counts
        }
     }
   if(j < 0) { why = "QAW " + DirStr(dir) + ": no internal sweep"; return false; }

   bool conf = (XC(r, 1, dir) > XO(r, 1, dir));
   if(j == 1) conf = conf && ((XC(r, 1, dir) - XO(r, 1, dir)) >= 0.3 * atr);
   else       conf = conf && (XC(r, 1, dir) > 0.5 * (XH(r, j, dir) + XL(r, j, dir)));
   if(!conf) { why = "QAW " + DirStr(dir) + ": sweep seen, waiting reversal"; return false; }

   double xref = dir * RefPrice(dir);
   // Impulse continuation: do NOT veto "too deep" — trend follow uses nearest SL instead
   if(xref > rL + 0.6 * (rH - rL) && !ImpulseAligned(dir))
     { why = "QAW " + DirStr(dir) + ": too deep into range"; return false; }

   double depth = (iLow - XL(r, j, dir)) / atr; if(depth > 1.0) depth = 1.0;
   score = 1.3 + depth;
   if(ImpulseAligned(dir))
     {
      slOut = NearestContSL(dir, r, n, atr);
      why   = "Qawaaniin " + DirStr(dir) + " impulse continuation";
      score = MathMax(score, EffectiveBookMinScore());
     }
   else
     {
      slOut = XReal(XL(r, j, dir) - atr * g_prof.slBufferATR, dir);
      why   = "Qawaaniin " + DirStr(dir) + " IC sweep+reversal";
     }
   return true;
  }

string AppendWhy(const string acc, const string w)
  {
   if(StringLen(w) == 0) return acc;
   if(StringLen(acc) > 110) return acc;
   return (StringLen(acc) == 0) ? w : acc + " | " + w;
  }

bool BookEngineSignal(const int desiredDir, SSignal &out)
  {
   out.Reset();
   MqlRates r[];
   int n = LoadRates(g_tf, InpStructLookback + 10, r);
   if(n < 40)
     {
      g_engWhyBuy[ENG_BOOK] = "no data"; g_engWhySell[ENG_BOOK] = "no data";
      g_engWhy[ENG_BOOK] = DualEngTag("no data", "no data");
      return false;
     }
   double atr = ATRValue();
   if(atr <= 0.0)
     {
      g_engWhyBuy[ENG_BOOK] = "no ATR"; g_engWhySell[ENG_BOOK] = "no ATR";
      g_engWhy[ENG_BOOK] = DualEngTag("no ATR", "no ATR");
      return false;
     }

   double bestScore = -1.0; string bestWhy = ""; double bestSL = 0.0; int bestDir = 0; string bestBook = "";
   string buyWhy = "idle", sellWhy = "idle";
   double minSc = EffectiveBookMinScore();

   // Always evaluate both directions for the BUY/SELL columns
   for(int d = -1; d <= 1; d += 2)
     {
      string sideBest = "idle"; double sideSc = -1.0;
      for(int bk = 1; bk <= 4; bk++)
        {
         if(InpBookMode != BOOK_AUTO && bk != (int)InpBookMode) continue;
         string why = ""; double sc = 0.0, sl = 0.0; bool ok = false; string name = "";
         switch(bk)
           {
            case 1: name = "CRT"; ok = BookCRT(d, atr, why, sc, sl); break;
            case 2: name = "ISK"; ok = BookIskulaab(r, n, d, atr, why, sc, sl); break;
            case 3: name = "GRB"; ok = BookGarab(r, n, d, atr, why, sc, sl); break;
            case 4: name = "QAW"; ok = BookQawaaniin(r, n, d, atr, why, sc, sl); break;
           }
         if(!ok)
           {
            if(sideSc < 0.0 && StringLen(why) > 0) sideBest = why;
            continue;
           }
         if(sc > sideSc)
           {
            sideSc = sc;
            sideBest = (sc >= minSc) ? (name + " " + DoubleToString(sc, 2)) : (name + " low " + DoubleToString(sc, 2));
           }
         // proposal: respect desiredDir filter (0 = either; CT path passes opposite)
         if(desiredDir != 0 && d != desiredDir) continue;
         if(!TradeDirAllows(d)) continue;
         if(sc >= minSc && sc > bestScore)
           { bestScore = sc; bestWhy = why; bestSL = sl; bestDir = d; bestBook = name; }
        }
      if(d > 0) buyWhy = sideBest; else sellWhy = sideBest;
     }
   g_engWhyBuy[ENG_BOOK]  = buyWhy;
   g_engWhySell[ENG_BOOK] = sellWhy;
   g_engWhy[ENG_BOOK] = DualEngTag(buyWhy, sellWhy);

   if(bestDir == 0) return false;
   out.valid    = true;
   out.dir      = bestDir;
   out.sl       = bestSL;
   out.score    = bestScore;
   out.priority = g_engPrio[ENG_BOOK];
   out.engineId = ENG_BOOK;
   out.engine   = bestBook;
   out.reason   = bestWhy + " (score " + DoubleToString(bestScore, 2) + ")";
   return true;
  }

//==================================================================
//  SECTION 10 : ENTRY GATE (single arbiter)
//==================================================================
int EffectiveMinQuality()
  {
   int q = InpMinEntryQuality;
   if(q < 0) q = 0;
   if(q > 100) q = 100;
   if(ModeAggressive())   q = MathMax(40, q - 15);   // lower bar, never bypass
   if(ModeConservative()) q = MathMin(95, q + 10);
   return q;
  }

// Location quality: premium/discount on the *recent pullback leg*; impulse continuations rewarded.
int ScoreEntryQuality(const int dir, const double price, const double sl, string &why)
  {
   why = "";
   MqlRates r[];
   int n = LoadRates(g_tf, 60, r);
   if(n < 20) { why = "no data for quality"; return 0; }
   const int s = InpSwingStrength;

   // Active impulse / chart-flow aligned with trade direction? (do not punish deep trend follow)
   bool impulseAlign = (g_impulseExec == dir) || (g_biasExec == dir) ||
                       (g_candleFlow == dir) ||
                       (g_htfBias == dir && g_emaExec == dir);

   // Recent pullback window (last 8 bars) — not the entire ancient swing range
   double rangeHigh = r[1].high, rangeLow = r[1].low;
   for(int k = 2; k <= 8; k++)
     {
      if(r[k].high > rangeHigh) rangeHigh = r[k].high;
      if(r[k].low  < rangeLow)  rangeLow  = r[k].low;
     }
   // expand with nearest swings if available
   int hi = LastXSwingHigh(r, n, s + 1, s, 1);
   int lo = LastXSwingLow(r, n, s + 1, s, 1);
   if(hi >= 0 && hi <= 20 && r[hi].high > rangeHigh) rangeHigh = r[hi].high;
   if(lo >= 0 && lo <= 20 && r[lo].low  < rangeLow)  rangeLow  = r[lo].low;

   double rng = rangeHigh - rangeLow;
   if(rng <= _Point) { why = "flat range"; return 15; }

   double pos = (price - rangeLow) / rng;
   if(pos < 0.0) pos = 0.0;
   if(pos > 1.0) pos = 1.0;

   int locScore = 0;
   string locWhy = "";
   if(impulseAlign)
     {
      // Continuations: reward alignment with the live leg (EMA bounce / follow-through)
      if(dir < 0)
        {
         if(pos >= 0.45)      { locScore = 90; locWhy = "impulseCont"; }
         else if(pos >= 0.25) { locScore = 75; locWhy = "impulseFollow"; }
         else                 { locScore = 65; locWhy = "impulseExt"; } // deep but still with trend
        }
      else
        {
         if(pos <= 0.55)      { locScore = 90; locWhy = "impulseCont"; }
         else if(pos <= 0.75) { locScore = 75; locWhy = "impulseFollow"; }
         else                 { locScore = 65; locWhy = "impulseExt"; }
        }
     }
   else if(dir < 0)
     {
      if(pos >= 0.70)      { locScore = 95; locWhy = "premium"; }
      else if(pos >= 0.55) { locScore = 75; locWhy = "upper mid"; }
      else if(pos >= 0.40) { locScore = 45; locWhy = "mid-range"; }
      else                 { locScore = 25; locWhy = "lateDiscount"; }
     }
   else
     {
      if(pos <= 0.30)      { locScore = 95; locWhy = "discount"; }
      else if(pos <= 0.45) { locScore = 75; locWhy = "lower mid"; }
      else if(pos <= 0.60) { locScore = 45; locWhy = "mid-range"; }
      else                 { locScore = 25; locWhy = "latePremium"; }
     }

   // trigger candle (bar 1)
   double o = r[1].open, c = r[1].close, h = r[1].high, l = r[1].low;
   double body = MathAbs(c - o);
   double range1 = h - l;
   int candleScore = 30;
   string candleWhy = "weak candle";
   bool closeWith = (dir > 0) ? (c > o) : (c < o);
   if(closeWith && range1 > 0.0)
     {
      double rej = (dir > 0) ? (MathMin(o, c) - l) : (h - MathMax(o, c));
      double closePos = (dir > 0) ? ((c - l) / range1) : ((h - c) / range1);
      if(rej >= 0.25 * range1 && closePos >= 0.55)
        { candleScore = 90; candleWhy = "reject+close"; }
      else if(body >= 0.35 * range1)
        { candleScore = 70; candleWhy = "dir close"; }
      else
        { candleScore = 55; candleWhy = "soft close"; }
     }

   // Score the *proposed* SL (after nearest/cap), not the far ancient invalidation
   double slDist = MathAbs(price - sl);
   int slScore = 40;
   string slWhy = "SL ok";
   if(dir > 0 && sl < price) slScore = 70;
   if(dir < 0 && sl > price) slScore = 70;
   if(dir > 0 && sl >= price) { slScore = 10; slWhy = "SL invalid side"; }
   if(dir < 0 && sl <= price) { slScore = 10; slWhy = "SL invalid side"; }
   if(slDist <= 1.2 * ATRValue() && slScore >= 70) { slScore = 90; slWhy = "SL near struct"; }

   int moneyScore = 80;
   string moneyWhy = "";
   if(InpMaxLossPerTradeMoney > 0.0)
     {
      double capDist = MaxSLDistForMoneyAtLot(InpMaxLossPerTradeMoney, g_volMin);
      if(capDist > 0.0)
        {
         if(slDist <= capDist * 1.05)
           { moneyScore = 95; moneyWhy = StringFormat("SLok/%.0fpts", slDist / _Point); }
         else if(slDist <= capDist * 1.35)
           { moneyScore = 60; moneyWhy = StringFormat("SLwide/%.0f>cap%.0f", slDist / _Point, capDist / _Point); }
         else
           {
            moneyScore = impulseAlign ? 45 : 20; // impulse: CapSL will tighten — soft penalty
            moneyWhy = StringFormat("SLfar/%.0f>cap%.0f", slDist / _Point, capDist / _Point);
            if(ModeConservative() && !impulseAlign)
              { why = moneyWhy + " — skip (Conservative)"; return 10; }
           }
        }
     }

   int total = (int)MathRound(0.40 * locScore + 0.25 * candleScore + 0.15 * slScore + 0.20 * moneyScore);
   if(impulseAlign) total = MathMax(total, 50); // floor for aligned impulse continuations
   // v1.15: mid-range / late chase locations get no flow floor gift
   bool midOrLate = (StringFind(locWhy, "mid-range") >= 0 || StringFind(locWhy, "late") >= 0 || StringFind(locWhy, "impulseExt") >= 0);
   if(g_candleFlow == dir && InpFlowAlignQualityFloor > 0 && !midOrLate)
      total = MathMax(total, InpFlowAlignQualityFloor);
   else if(g_candleFlow == dir && InpFlowAlignQualityFloor > 0 && midOrLate)
      total = MathMax(total, MathMin(InpFlowAlignQualityFloor, 45)); // weaker gift in chop mid
   if(total < 0) total = 0;
   if(total > 100) total = 100;
   why = StringFormat("%s(%.0f%%) %s %s %s", locWhy, pos * 100.0, candleWhy, slWhy, moneyWhy);
   return total;
  }

// ImpulseCont: MUST match chart flow + exec impulse (never buy into DOWN / sell into UP)
bool TryContinuationFallback(const int dir, SSignal &out)
  {
   out.Reset();
   if(!InpUseContinuationFallback || dir == 0) return false;
   // Flip reverse may re-fire same bar; serial add still one CONT per bar
   if(!g_flipEnterNow && g_lastContBar == iTime(_Symbol, g_tf, 0)) return false;
   if(!TradeDirAllows(dir)) return false;
   if(g_chopPause) return false;

   // Hard: candle flow + impulse must agree with entry dir
   if(InpRequireCandleFlow && g_candleFlow != 0 && g_candleFlow != dir) return false;
   if(g_impulseExec != 0 && g_impulseExec != dir) return false;
   if(g_biasExec != 0 && g_biasExec != dir && g_impulseExec != dir) return false;
   if(!ImpulseAligned(dir) && g_candleFlow != dir) return false;

   // Serial continuation add: only when open same-dir is BE+/≥AddAfterR (never DD)
   int buys = 0, sells = 0;
   CountOwnPositions(buys, sells);
   int sameOpen = (dir > 0) ? buys : sells;
   bool serialAdd = (sameOpen > 0);
   if(serialAdd)
     {
      if(SameDirOpenInDrawdown(dir)) return false;
      if(!SameDirOpenReadyToAdd(dir)) return false;
     }

   int needBars = (g_impulseExec == dir || g_candleFlow == dir || g_flipEnterNow || g_idleRelaxed) ? 0 : InpContWaitBars;
   if(g_htfClearBars < needBars)
     {
      g_lastBlockRule = "ContWaitBars";
      return false;
     }

   MqlRates r[], r5[];
   int n  = LoadRates(g_tf, 40, r);
   int n5 = LoadRates(PERIOD_M5, 50, r5);
   if(n < 15) return false;
   double atr = ATRBaseline(8);
   if(atr <= 0.0) atr = ATRValue();
   if(atr <= 0.0) return false;

   double emaExec[];
   bool emaOK = EMAValues(g_hEMAExec, 5, emaExec);
   string trig = "";
   bool fire = false;
   bool pullbackResume = false; // fresh pullback-and-resume on chart TF

   // (1) Chart-TF EMA pullback bounce with flow (required path for serial adds)
   if(emaOK)
     {
      double emaLvl = emaExec[1];
      bool touched = false;
      for(int k = 1; k <= 6; k++)
         if((dir > 0 && r[k].low <= emaLvl + 0.25 * atr) ||
            (dir < 0 && r[k].high >= emaLvl - 0.25 * atr))
           { touched = true; break; }
      bool closeWith = (dir * (r[1].close - r[1].open) > 0.0);
      bool sideOK = (dir * (r[1].close - emaLvl) > 0.0);
      if(touched && closeWith && sideOK)
        { fire = true; pullbackResume = true; trig = TFStr(g_tf) + " EMA pullback"; }
     }

   // (2) Chart-TF BOS / CHoCH close with flow (+ displacement preferred)
   if(!fire || g_flipEnterNow)
     {
      int pe = XHighestIdx(r, n, 2, 12, dir);
      bool bos = (pe >= 2 && XC(r, 1, dir) > XH(r, pe, dir) && XC(r, 1, dir) > XO(r, 1, dir));
      // micro CHoCH: close beyond prior 3–8 bar extreme in trade direction
      bool choch = false;
      if(dir > 0)
        {
         double hi = r[2].high;
         for(int k = 3; k <= 8; k++) if(r[k].high > hi) hi = r[k].high;
         choch = (r[1].close > hi);
        }
      else
        {
         double lo = r[2].low;
         for(int k = 3; k <= 8; k++) if(r[k].low < lo) lo = r[k].low;
         choch = (r[1].close < lo);
        }
      double minB = DispMinBody(atr, ModeAggressive());
      double body1 = XC(r, 1, dir) - XO(r, 1, dir);
      bool disp = (body1 >= minB);
      if((bos || choch) && (disp || g_flipEnterNow || !serialAdd))
        {
         fire = true;
         pullbackResume = true; // structure resume counts as fresh trigger
         if(!StringLen(trig)) trig = TFStr(g_tf) + (choch ? " CHoCH" : " BOS") + (disp ? "+disp" : "");
        }
     }

   // (3) M5 soft BOS (flat / first entries only — not for serial add stacking)
   if(!fire && !serialAdd && n5 >= 20)
     {
      int pe = XHighestIdx(r5, n5, 2, 12, dir);
      if(pe >= 2 && XC(r5, 1, dir) > XH(r5, pe, dir) && XC(r5, 1, dir) > XO(r5, 1, dir))
        { fire = true; trig = "M5 soft BOS"; }
     }

   // (4) Live impulse bar — only if NOT late-chase; prefer pullback (v1.14)
   if(!fire && !serialAdd && (g_impulseExec == dir || g_candleFlow == dir || g_flipEnterNow))
     {
      string lateWhy = "";
      if(LateChaseBlocked(dir, lateWhy))
        { g_lastBlockRule = lateWhy; /* skip impulse-at-extreme */ }
      else if(!InpPreferPullbackEntry || g_flipEnterNow)
        {
         double minB = DispMinBody(atr, ModeAggressive());
         double body1 = XC(r, 1, dir) - XO(r, 1, dir);
         if(body1 >= minB && XC(r, 1, dir) > XO(r, 1, dir))
           { fire = true; trig = "impulse bar"; }
        }
     }

   // Serial add / first entry: require pullback-and-resume when PreferPullback (except flip-now)
   if(InpPreferPullbackEntry && !g_flipEnterNow && fire && !pullbackResume)
     {
      g_lastBlockRule = "prefer pullback/retest (skip late extreme)";
      return false;
     }
   if(serialAdd && (!fire || !pullbackResume))
     {
      g_lastBlockRule = "serial-add needs chart pullback/BOS-CHoCH";
      return false;
     }

   if(!fire) return false;

   double sl = NearestContSL(dir, r, n, atr);
   out.valid    = true;
   out.dir      = dir;
   out.sl       = sl;
   out.score    = serialAdd ? 1.55 : 1.6;
   // M5 soft agree → slight score bump; disagree → slight cut (still allowed)
   if(g_m5Agree == dir) out.score += 0.15;
   else if(g_m5Agree != 0 && g_m5Agree != dir) out.score -= 0.20;
   out.priority = 2;
   out.engineId = ENG_KILLER;
   out.engine   = serialAdd ? "IMP-ADD" : "IMP";
   out.reason   = (serialAdd ? "SerialCont " : "ImpulseCont ") + DirStr(dir) + " " + trig +
                  " flow=" + g_flowTag + (g_flipEnterNow ? " FLIP-NOW" : "");
   g_lastContBar = iTime(_Symbol, g_tf, 0);
   g_lastStructEvent = out.engine + " " + DirStr(dir);
   return true;
  }

// Soft gates: may delay but must NOT permanently block a chart-flow-aligned proposal (v1.13)
// v1.15: CHOP / range-chop / loss-cooldown / day caps are HARD — never TREND-TAKE bypass
bool IsSoftGateReason(const string why)
  {
   if(InpHardBlockChopCooldown)
     {
      if(StringFind(why, "cooldown") >= 0) return false;
      if(StringFind(why, "CHOP") >= 0) return false;
      if(StringFind(why, "range-chop") >= 0) return false;
      if(StringFind(why, "max trades") >= 0) return false;
      if(StringFind(why, "consec") >= 0) return false;
     }
   if(StringFind(why, "cooldown") >= 0) return true;
   if(StringFind(why, "one entry per bar") >= 0) return true;
   if(StringFind(why, "CHOP") >= 0) return true;
   if(StringFind(why, "spread") >= 0) return true;
   if(StringFind(why, "backoff") >= 0) return true;
   if(StringFind(why, "outside session") >= 0) return true;
   if(StringFind(why, "MinInitialRR") >= 0) return true;
   if(StringFind(why, "quality") >= 0) return true;
   return false;
  }

// v1.15: compressed range / chop — high-low of lookback ≤ N×ATR → do not trade
bool IsRangeChopMarket(string &why)
  {
   why = "";
   if(!InpUseRangeChopFilter || InpRangeChopBars < 8 || InpRangeChopMaxATR <= 0.0) return false;
   MqlRates r[];
   int n = LoadRates(g_tf, InpRangeChopBars + 5, r);
   if(n < InpRangeChopBars) return false;
   double hi = r[1].high, lo = r[1].low;
   int flips = 0;
   int prevDir = 0;
   for(int i = 1; i <= InpRangeChopBars && i < n; i++)
     {
      if(r[i].high > hi) hi = r[i].high;
      if(r[i].low  < lo) lo = r[i].low;
      int d = 0;
      if(r[i].close > r[i].open) d = 1;
      else if(r[i].close < r[i].open) d = -1;
      if(d != 0 && prevDir != 0 && d != prevDir) flips++;
      if(d != 0) prevDir = d;
     }
   double atr = ATRValue();
   if(atr <= 0.0) atr = RatesATR(r, n, 14);
   if(atr <= 0.0) return false;
   double span = hi - lo;
   bool compressed = (span <= InpRangeChopMaxATR * atr);
   bool whippy = (flips >= MathMax(6, InpRangeChopBars / 3));
   if(compressed && whippy)
     {
      why = StringFormat("range-chop span=%.1fATR flips=%d/%d", span / atr, flips, InpRangeChopBars);
      return true;
     }
   return false;
  }

bool GateAllows(string &why)
  {
   why = "";
   // Hard: only true kill-switches (manual / terminal / broker closed / day lock when enabled)
   if(g_halted)  { why = "HALTED: " + g_haltReason; return false; }
   if(g_paused)  { why = "paused"; return false; }
   if(!TradingAllowedByTerminal(why)) return false;
   if(SendBlocked(why)) return false;
   if(g_dayLocked) { why = "day locked: " + g_dayLockReason; return false; }
   string mktWhy = "";
   if(!SymbolMarketOpenNow(mktWhy)) { why = mktWhy; return false; }

   // Soft (trend-take may bypass these in EvaluateEntryGate) — v1.15: CHOP/cooldown hard when flag ON
   if(g_chopPause) { why = "CHOP pause"; return false; }
   string rcWhy = "";
   if(IsRangeChopMarket(rcWhy))
     {
      g_chopPause = true;
      g_chopUntilBar = iTime(_Symbol, g_tf, 0) + (datetime)(MathMax(InpChopPauseBars, 5) * PeriodSeconds(g_tf));
      why = rcWhy;
      return false;
     }
   if(TimeCurrent() < g_nextSendAllowed) { why = "backoff " + IntegerToString((int)(g_nextSendAllowed - TimeCurrent())) + "s"; return false; }
   // Bar cooldown after full-SL loss (flip exits / trend-take bypass)
   if(!g_bypassLossCooldown && InpCooldownBarsAfterLoss > 0 && g_lossCooldownBarsLeft > 0)
     {
      datetime bar0 = iTime(_Symbol, g_tf, 0);
      if(g_lossCooldownUntilBar != 0 && bar0 != 0 && bar0 < g_lossCooldownUntilBar)
        { why = "cooldown " + IntegerToString(g_lossCooldownBarsLeft) + " exec bars after loss"; return false; }
      if(bar0 >= g_lossCooldownUntilBar) { g_lossCooldownBarsLeft = 0; g_lossCooldownUntilBar = 0; }
     }
   if(!g_bypassLossCooldown && InpCooldownAfterLossMin > 0 && g_lastLossTime > 0 && TimeCurrent() - g_lastLossTime < InpCooldownAfterLossMin * 60)
     { why = "cooldown after loss"; return false; }
   if(FridayRulesApply() && InpUseFridayCutoff && IsFriday() && MinuteOfDay(TimeCurrent()) >= g_friNoNew)
     { why = "Friday: no new trades"; return false; }
   string sess = "";
   if(!InSession(sess)) { why = "outside session"; return false; }
   string nw = "";
   if(NewsBlocked(nw)) { why = nw; return false; }
   int sp = SpreadPts();
   // Soft spread: allow up to 1.35× profile when flow is clear (still logged)
   int spMax = g_prof.maxSpreadPts;
   if(g_candleFlow != 0) spMax = (int)MathRound(spMax * 1.35);
   if(sp > spMax) { why = "spread " + IntegerToString(sp) + " > " + IntegerToString(spMax); return false; }
   int b = 0, s = 0;
   int open = CountOwnPositions(b, s);
   int maxPos = EffectiveMaxPositions(g_pendingFlipDir != 0 ? g_pendingFlipDir : g_htfBias);
   if(open >= maxPos) { why = "max positions (" + IntegerToString(maxPos) + ")"; return false; }
   datetime bar = iTime(_Symbol, g_tf, 0);
   // One-per-bar is soft for trend: flip-now always bypasses; trend-take may bypass after failed attempt same bar
   if(!g_flipEnterNow && bar != 0 && bar == g_lastEntryBar) { why = "one entry per bar"; return false; }
   return true;
  }

bool DirectionAllowed(const int dir, string &why)
  {
   if(InpRequireCandleFlow && g_candleFlow != 0 && dir != g_candleFlow && !InpAllowCounterTrend)
     { why = "flow " + g_flowTag + " blocks " + DirStr(dir); return false; }
   if(SameDirOpenInDrawdown(dir))
     { why = "same-dir open in drawdown"; return false; }
   if(InpAllowHedge) return true;
   int b = 0, s = 0;
   CountOwnPositions(b, s);
   if(dir > 0 && s > 0) { why = "sell open, no hedge"; return false; }
   if(dir < 0 && b > 0) { why = "buy open, no hedge"; return false; }
   return true;
  }

// Builds the final SL/TP/lot from a proposal and sends it. Never sends without a valid SL.
// Lot from % risk; SL then capped to InpMaxLossPerTradeMoney at that lot (lot never shrinks for USD cap).
bool TryOpen(const SSignal &sig)
  {
   if(!RefreshPrices()) { g_gateReason = "no tick"; return false; }
   int    dir   = sig.dir;
   double price = (dir > 0) ? g_ask : g_bid;
   double atr   = ATRValue();
   double sl    = sig.sl;          // structural SL from engine

   // fallback SL if the engine did not provide one
   if(sl <= 0.0 && atr > 0.0) sl = price - dir * atr * g_prof.atrMult;
   if(sl <= 0.0) { g_gateReason = "no SL available"; return false; }
   if(dir > 0 && sl >= price) sl = price - MinDist();
   if(dir < 0 && sl <= price) sl = price + MinDist();

   if(!ValidateInitialSL(dir, sl)) { g_gateReason = "SL cannot satisfy broker floor"; return false; }
   if(!TradeDirAllows(dir))
     {
      g_gateReason = "TradeDirection filter blocks " + DirStr(dir);
      return false;
     }
   // Candle flow hard gate — BUY only when flow UP, SELL only when flow DOWN
   if(InpRequireCandleFlow && g_candleFlow != 0 && dir != g_candleFlow && !InpAllowCounterTrend)
     {
      NoteGateDrop("flow", "flow " + g_flowTag + " rejects " + DirStr(dir));
      return false;
     }
   if(g_impulseExec != 0 && g_impulseExec != dir && StringFind(sig.engine, "IMP") >= 0)
     {
      NoteGateDrop("impulse", "ImpulseCont against chart impulse");
      return false;
     }
   if(SameDirOpenInDrawdown(dir))
     { NoteGateDrop("drawdown", "same-dir open in drawdown"); return false; }

   // v1.14: late-chase veto for impulse-style reasons (allow pullback/retest / flip-now)
   {
    string lateWhy = "";
    bool looksImpulse = (StringFind(sig.reason, "impulse") >= 0 ||
                         StringFind(sig.reason, "displacement") >= 0 ||
                         StringFind(sig.engine, "IMP") >= 0);
    bool looksPullback = (StringFind(sig.reason, "pullback") >= 0 ||
                          StringFind(sig.reason, "retest") >= 0 ||
                          StringFind(sig.reason, "bounce") >= 0 ||
                          StringFind(sig.reason, "BOS") >= 0 ||
                          StringFind(sig.reason, "CHoCH") >= 0 ||
                          StringFind(sig.reason, "EMA") >= 0);
    if(looksImpulse && !looksPullback && !g_flipEnterNow && LateChaseBlocked(dir, lateWhy))
      {
       NoteGateDrop("late-chase", lateWhy);
       return false;
      }
   }

   // v1.13: RR is SOFT for trend-aligned — never hard-drop; extend TP instead.
   // (v1.12 bug: every SELL into BEAR died on "RR 0.27 < min 1.50" while structure was near.)
   const bool flowOK = TrendFlowAligned(dir);
   double structDistPre = MathAbs(price - sl);
   double structTgt = NearestTargetDist(dir, price);
   double rrStruct = (structDistPre > 0.0 && structTgt > 0.0) ? (structTgt / structDistPre) : 0.0;
   double wantTgtPts = 0.0;
   if(InpMinInitialRR > 0.0 && structDistPre > 0.0)
      wantTgtPts = InpMinInitialRR * structDistPre;
   if(atr > 0.0 && InpTPATRExtension > 0.0)
      wantTgtPts = MathMax(wantTgtPts, InpTPATRExtension * atr);
   if(structTgt > wantTgtPts) wantTgtPts = structTgt;
   // Soft score penalty only (applied to quality later via g_rrSoftPenalty)
   int rrSoftPenalty = 0;
   if(InpMinInitialRR > 0.0 && rrStruct > 0.0 && rrStruct < InpMinInitialRR)
     {
      rrSoftPenalty = (int)MathRound((InpMinInitialRR - rrStruct) * 8.0);
      if(rrSoftPenalty > 15) rrSoftPenalty = 15;
      g_statRRSoftExt++;
      g_lastBlockRule = "MinInitialRR-soft";
      LogMsg(StringFormat("RR soft %.2f < min %.2f — NO DROP; extend TP to max(struct,%.1fR,%.1fATR)=%.0f pts | flowAlign=%s",
                          rrStruct, InpMinInitialRR, InpMinInitialRR, InpTPATRExtension,
                          wantTgtPts / _Point, flowOK ? "Y" : "N"), true);
     }
   // v1.13: NEVER hard-drop RR — always extend TP (flow-aligned must take the trade)

   double structDist = MathAbs(price - sl);
   if(atr > 0.0 && InpMaxSLATR > 0.0 && structDist > InpMaxSLATR * atr)
     {
      // Trend follow: tighten SL to ATR cap instead of dropping
      double tight = NormPrice(price - dir * InpMaxSLATR * atr);
      if(ValidateInitialSL(dir, tight))
        {
         sl = tight; structDist = MathAbs(price - sl);
         LogMsg(StringFormat("SL tighten to %.1f ATR (was wide) — NO DROP flowAlign=%s", InpMaxSLATR, flowOK ? "Y" : "N"), true);
        }
      else if(!flowOK)
        { NoteGateDrop("SLwide", StringFormat("SL too wide (%.1f ATR)", structDist / atr)); return false; }
      else
        {
         // Last resort for trend: use broker floor distance
         sl = NormPrice(price - dir * MathMax(MinDist(), FloorDist() + _Point));
         structDist = MathAbs(price - sl);
         LogMsg("SL floor fallback for trend-aligned — NO DROP", true);
        }
     }

   // 1) Lot from % risk (never shrink for money SL cap)
   string lotWhy = "";
   double lot = CalcLot(dir, price, sl, lotWhy);
   if(lot <= 0.0)
     {
      if(flowOK && InpAllowMinLotOverRisk)
        {
         lot = g_volMin;
         lotWhy = "min-lot trend force";
         LogMsg("Lot force min for trend-aligned — NO DROP", true);
        }
      else
        { NoteGateDrop("lot", "lot: " + lotWhy); return false; }
     }

   // 2) Cap SL to money max at chosen lot — BEFORE quality scoring (lot unchanged)
   string capWhy = "";
   if(InpMaxLossPerTradeMoney > 0.0)
     {
      bool capped = CapSLToMoneyLoss(dir, price, lot, sl, capWhy);
      if(StringLen(capWhy) > 0 && StringFind(capWhy, "skipped:") == 0)
        {
         // Trend: force-cap anyway if possible
         if(flowOK)
           {
            CapSLToMoneyLoss(dir, price, lot, sl, capWhy);
            LogMsg("SL money-cap forced for trend — NO DROP | " + capWhy, true);
           }
         else
           { NoteGateDrop("SLcap", capWhy); return false; }
        }
      if(!capped && LossMoneyAt(lot, MathAbs(price - sl)) > InpMaxLossPerTradeMoney + 0.01)
         CapSLToMoneyLoss(dir, price, lot, sl, capWhy);
      if(!ValidateInitialSL(dir, sl))
        {
         if(flowOK)
           {
            sl = NormPrice(price - dir * MathMax(MinDist(), FloorDist() + _Point));
            LogMsg("SL broker-floor after cap for trend — NO DROP", true);
           }
         else
           { NoteGateDrop("SLcap", "SL cannot satisfy broker floor after money cap"); return false; }
        }
     }

   // 3) Quality on final SL — soft for chart-flow aligned (never permanent DROP)
   string qWhy = "";
   int q = ScoreEntryQuality(dir, price, sl, qWhy);
   if(rrSoftPenalty > 0) q = MathMax(0, q - rrSoftPenalty); // soft RR penalty only
   if(flowOK && InpFlowAlignQualityFloor > 0) q = MathMax(q, InpFlowAlignQualityFloor);
   g_lastQuality = q;
   g_lastQualityWhy = qWhy;
   int qMin = EffectiveMinQuality();
   if(sig.counterTrend) qMin = MathMin(95, qMin + 10);
   if(g_idleRelaxed && (g_idleRelaxedRule == "MinEntryQuality" || g_idleRelaxedRule == "minRR/quality"))
      qMin = MathMax(35, qMin - 10);
   if(q < qMin)
     {
      if(flowOK)
        {
         LogMsg(StringFormat("Quality soft-allow %d < min %d — NO DROP (flow %s) | %s",
                             q, qMin, g_flowTag, qWhy), true);
         g_lastBlockRule = "MinEntryQuality-soft";
         // bump display floor so dashboard is not stuck at 0
         g_lastQuality = MathMax(q, MathMin(qMin, InpFlowAlignQualityFloor));
        }
      else
        {
         NoteGateDrop("MinEntryQuality", StringFormat("quality %d < min %d (%s)", q, qMin, qWhy));
         return false;
        }
     }

   double dist = MathAbs(price - sl);
   double riskUsd = LossMoneyAt(lot, dist);
   g_lastRiskMoney = riskUsd;

   // 4) TP = max(structure, MinInitialRR×SL, ATR extension) — even in TRAIL mode set floor TP
   //    BE / peak-lock / ladder still manage the winner; TP is the RR floor so we never "DROP for RR"
   if(InpMinInitialRR > 0.0) wantTgtPts = MathMax(wantTgtPts, InpMinInitialRR * dist);
   if(atr > 0.0 && InpTPATRExtension > 0.0) wantTgtPts = MathMax(wantTgtPts, InpTPATRExtension * atr);
   if(structTgt > wantTgtPts) wantTgtPts = structTgt;
   // v1.15 expectancy: TP distance must be ≥ MinExpectancyRR × SL (default 1.0 → avg-win target ≥ avg-loss)
   double expFloor = MathMax(1.0, InpMinExpectancyRR);
   if(InpMinInitialRR > 0.0) expFloor = MathMax(expFloor, InpMinInitialRR);
   if(wantTgtPts < dist * expFloor) wantTgtPts = dist * expFloor;
   double tp = NormPrice(price + dir * wantTgtPts);
   if(InpTPMode == TP_FIXED_R && InpTakeProfitR > 0.0)
     {
      double tpFixed = NormPrice(price + dir * dist * InpTakeProfitR);
      if(dir > 0) tp = MathMax(tp, tpFixed); else tp = MathMin(tp, tpFixed);
     }

   string tpTag = StringFormat("TP %.*f (%.1fR)", g_digits, tp, (dist > 0.0) ? (wantTgtPts / dist) : 0.0);
   LogMsg(StringFormat("GATE -> EXECUTE %s %s lot %.2f SL %.*f (%.0f pts) %s | risk USD %.2f cap USD %.0f | Q=%d/%d (%s) | flow %s | %s",
                       sig.engine, DirStr(dir), lot, g_digits, sl, dist / _Point, tpTag,
                       riskUsd, InpMaxLossPerTradeMoney, g_lastQuality, qMin, qWhy, g_flowTag, sig.reason), true);
   bool ok = SendMarketOrder(sig, lot, sl, tp);
   if(ok)
     {
      g_statExecuted++;
      g_lastEntryBar = iTime(_Symbol, g_tf, 0);
      g_engLastFire[sig.engineId] = TimeCurrent();
      g_tradesToday++;
      g_statsDirty = true;
      g_bypassLossCooldown = false;
      g_pendingFlipDir = 0;
      g_flipEnterNow = false;
      g_idleRelaxed = false;
      g_idleRelaxedRule = "";
      g_flatBarsInFlow = 0;
      g_lastBlockRule = "";
      g_lastDropReason = "";
      g_liveActionTag = StringFormat("EXECUTED %s %s", DirStr(dir), sig.engine);
      g_gateReason = StringFormat("sent %s %s Q=%d risk USD %.2f/%s flow %s",
                                  sig.engine, DirStr(dir), g_lastQuality, riskUsd,
                                  (InpMaxLossPerTradeMoney > 0.0) ? DoubleToString(InpMaxLossPerTradeMoney, 0) : "off",
                                  g_flowTag);
      LogMsg(StringFormat("EXECUTED %s %s ticket-pending lot=%.2f | proposes=%d softRR=%d dropQ=%d dropOther=%d done=%d",
                          DirStr(dir), sig.engine, lot, g_statPropose, g_statRRSoftExt,
                          g_statDropQuality, g_statDropOther, g_statExecuted), true);
     }
   else
     {
      NoteGateDrop("send", "OrderSend failed — " + g_lastError);
     }
   return ok;
  }

void EvaluateEntryGate(const bool newExecBar, const bool newM1Bar)
  {
   if(g_halted || g_paused) return;
   if(newExecBar) ClearArmedZone();   // engines re-arm the zone this bar if still valid
   // Always refresh bias before the gate decision (timer may have newer FINAL than last bar)
   g_htfBias = ComputeHTFBias();
   if(newExecBar)
     {
      if(g_htfBias != 0) g_htfClearBars++;
      else               g_htfClearBars = 0;
      // Idle watchdog: no engine/gate may block > InpIdleWatchBars while flow is clear
      int b0 = 0, s0 = 0;
      int openN = CountOwnPositions(b0, s0);
      if(openN == 0 && g_candleFlow != 0 && !g_chopPause)
        {
         g_flatBarsInFlow++;
         if(InpIdleWatchBars > 0 && g_flatBarsInFlow >= InpIdleWatchBars)
           {
            // Lowest-priority soft rule first: MinEntryQuality → MinInitialRR → ContWaitBars
            string block = (StringLen(g_lastBlockRule) > 0) ? g_lastBlockRule : "MinEntryQuality";
            string relax = "MinEntryQuality";
            if(block == "MinInitialRR" || block == "RR")
               relax = "MinInitialRR";
            else if(block == "ContWaitBars" || StringFind(block, "pullback") >= 0 || StringFind(block, "serial-add") >= 0)
               relax = "ContWaitBars";
            else
               relax = "MinEntryQuality";
            g_idleRelaxedRule = relax;
            g_idleRelaxed = true;
            g_idleWatchMsg = StringFormat("IDLE-WATCHDOG flat %d bars flow=%s block=[%s] relax=[%s]",
                                          g_flatBarsInFlow, g_flowTag, block, relax);
            LogMsg(g_idleWatchMsg, true);
            g_flatBarsInFlow = 0;
           }
        }
      else
        {
         g_flatBarsInFlow = 0;
         if(openN > 0) { g_idleRelaxed = false; g_idleRelaxedRule = ""; }
        }
     }

   // ChartTF / live candle flow is desired. Prefer pending flip dir after FLIP EXIT.
   // v1.13: never leave desired stuck on HTF while M1 flow is clear the other way.
   int desired = 0;
   if(g_pendingFlipDir != 0 && TradeDirAllows(g_pendingFlipDir))
      desired = g_pendingFlipDir;
   else if(g_candleFlow != 0)
      desired = g_candleFlow;
   else if(InpUseHTFBias)
      desired = g_htfBias;
   // Dual-scan status only when truly flat (no flow, no bias, no flip)
   const bool statusOnly = (desired == 0 && !InpAllowNeutralBias);

   SSignal sigs[8];
   int cnt = 0;

   // Refresh dual BUY/SELL engine columns every gate call (bar-based from OnTick)
   if(g_engOn[ENG_UNICORN] || g_engOn[ENG_KILLER] || g_engOn[ENG_BOOK] || g_engOn[ENG_SCALP])
     {
      if(g_engOn[ENG_UNICORN])
        {
         bool waiting = false; string why = ""; double sl = 0.0;
         int scanDir = statusOnly ? 0 : desired;
         int d = UnicornEntrySignal(scanDir, waiting, why, sl);   // always fills B+S columns
         g_unicornWaiting = waiting;
         if(!statusOnly && (newExecBar || g_flipEnterNow) && d != 0 && TradeDirAllows(d))
           {
            sigs[cnt].Reset();
            sigs[cnt].valid = true; sigs[cnt].dir = d; sigs[cnt].sl = sl; sigs[cnt].score = 2.0;
            sigs[cnt].priority = g_engPrio[ENG_UNICORN]; sigs[cnt].engineId = ENG_UNICORN;
            sigs[cnt].engine = "UNI"; sigs[cnt].reason = why;
            cnt++;
            NoteGatePropose(d, "UNI");
            LogMsg("PROPOSE UNI " + DirStr(d) + " | " + why + (g_flipEnterNow ? " [FLIP-NOW]" : ""));
           }
         if(!statusOnly && (newExecBar || g_flipEnterNow) && CounterTrendPermitted() && desired != 0 && g_h1Weakening)
           {
            string revWhy = "";
            if(ExecReversalAgainst(desired, revWhy))
              {
               int opp = -desired;
               if(TradeDirAllows(opp))
                 {
                  bool w2 = false; string wy2 = ""; double sl2 = 0.0;
                  int d2 = UnicornEntrySignal(opp, w2, wy2, sl2);
                  if(d2 == opp)
                    {
                     sigs[cnt].Reset();
                     sigs[cnt].valid = true; sigs[cnt].dir = d2; sigs[cnt].sl = sl2; sigs[cnt].score = 1.8;
                     sigs[cnt].priority = g_engPrio[ENG_UNICORN]; sigs[cnt].engineId = ENG_UNICORN;
                     sigs[cnt].engine = "UNI-CT"; sigs[cnt].reason = wy2 + " | CT " + revWhy;
                     sigs[cnt].counterTrend = true;
                     cnt++;
                     LogMsg("PROPOSE UNI-CT " + DirStr(d2) + " | " + sigs[cnt-1].reason, true);
                    }
                 }
              }
           }
        }
      if(g_engOn[ENG_KILLER])
        {
         string why = ""; double sl = 0.0;
         int d = KillerDirectionStartSignal(statusOnly ? 0 : desired, why, sl);
         string kLate = "";
         bool kOk = (d != 0 && TradeDirAllows(d) && !LateChaseBlocked(d, kLate));
         if(!kOk && d != 0 && StringLen(kLate) > 0)
            LogMsg("KIL DROP late-chase " + DirStr(d) + " | " + kLate, true);
         if(!statusOnly && (newExecBar || g_flipEnterNow) && kOk)
           {
            // v1.15c: never propose raw impulse-displacement K (live −$18 bucket)
            if(InpKillerPullbackOnly && StringFind(why, "impulse displacement") >= 0)
               LogMsg("KIL DROP impulse-disp " + DirStr(d) + " | " + why, true);
            else
              {
               sigs[cnt].Reset();
               sigs[cnt].valid = true; sigs[cnt].dir = d; sigs[cnt].sl = sl; sigs[cnt].score = 1.55;
               sigs[cnt].priority = g_engPrio[ENG_KILLER]; sigs[cnt].engineId = ENG_KILLER;
               sigs[cnt].engine = "KIL"; sigs[cnt].reason = why;
               cnt++;
               NoteGatePropose(d, "KIL");
               LogMsg("PROPOSE KIL " + DirStr(d) + " | " + why + (g_flipEnterNow ? " [FLIP-NOW]" : ""));
              }
           }
        }
      if(g_engOn[ENG_BOOK])
        {
         SSignal bs;
         if(statusOnly)
            BookEngineSignal(0, bs);
         else if(newExecBar || g_flipEnterNow)
           {
            if(BookEngineSignal(desired, bs) && TradeDirAllows(bs.dir))
              {
               sigs[cnt] = bs; cnt++;
               NoteGatePropose(bs.dir, bs.engine);
               LogMsg("PROPOSE BOOK " + bs.engine + " " + DirStr(bs.dir) + " | " + bs.reason +
                      (g_flipEnterNow ? " [FLIP-NOW]" : ""));
              }
            if(CounterTrendPermitted() && desired != 0 && g_h1Weakening)
              {
               string revWhy = "";
               if(ExecReversalAgainst(desired, revWhy))
                 {
                  int opp = -desired;
                  SSignal ct;
                  if(BookEngineSignal(opp, ct) && ct.dir == opp &&
                     (ct.engine == "QAW" || ct.engine == "CRT"))
                    {
                     ct.counterTrend = true;
                     ct.engine = ct.engine + "-CT";
                     ct.reason = ct.reason + " | CT " + revWhy;
                     ct.score = MathMax(0.5, ct.score - 0.2);
                     sigs[cnt] = ct; cnt++;
                     LogMsg("PROPOSE BOOK-CT " + ct.engine + " " + DirStr(ct.dir) + " | " + ct.reason, true);
                    }
                 }
              }
           }
         else
            BookEngineSignal(0, bs);   // M1-only bar: refresh columns
        }
      if(g_engOn[ENG_SCALP])
        {
         if(!statusOnly && (newM1Bar || g_flipEnterNow || (newExecBar && ModeAggressive())) && TryScalpEntry(desired) && TradeDirAllows(g_scalpSig.dir))
           {
            bool dup = false;
            for(int i = 0; i < cnt; i++)
               if(sigs[i].engineId == ENG_SCALP && sigs[i].dir == g_scalpSig.dir) dup = true;
            if(!dup)
              {
               sigs[cnt] = g_scalpSig; cnt++;
               NoteGatePropose(g_scalpSig.dir, "SCP");
               LogMsg("PROPOSE SCP " + DirStr(g_scalpSig.dir) + " | " + g_scalpSig.reason +
                      (g_flipEnterNow ? " [FLIP-NOW]" : ""));
              }
           }
         else
            TryScalpEntry(0);   // status fill
        }
     }
   // Impulse CONT: chart bars + immediate flip reverse tick
   if(!statusOnly && cnt == 0 && (newExecBar || newM1Bar || g_flipEnterNow))
     {
      SSignal cont;
      if(TryContinuationFallback(desired, cont) && TradeDirAllows(cont.dir))
        {
         sigs[cnt] = cont; cnt++;
         NoteGatePropose(cont.dir, cont.engine);
         LogMsg("PROPOSE IMP " + DirStr(cont.dir) + " | " + cont.reason +
                (g_flipEnterNow ? " [FLIP-NOW]" : ""), true);
        }
     }

   // Live action tag from chart flow even before send
   if(g_candleFlow < 0) g_liveActionTag = "SELL ACTIVE (flow BEAR)";
   else if(g_candleFlow > 0) g_liveActionTag = "BUY ACTIVE (flow BULL)";
   else if(StringLen(g_liveActionTag) == 0) g_liveActionTag = "WAIT (flow FLAT)";

   // Gate line always shows both sides
   if(statusOnly)
     {
      g_gateReason = StringFormat("FINAL WAIT | BUY needs: %s | SELL needs: %s", g_buyNeeds, g_sellNeeds);
      if(newExecBar) LogBarAnalysis();
      return;
     }

   if(cnt == 0)
     {
      // Prefer chart-flow for "looking for" (v1.13 — BEAR → looking for SELL)
      int look = (g_candleFlow != 0) ? g_candleFlow : g_htfBias;
      if(look != 0)
         g_gateReason = StringFormat("looking for %s (flow %s) | opp needs: %s",
                                     DirStr(look), g_flowTag,
                                     (look < 0) ? g_buyNeeds : g_sellNeeds);
      else
         g_gateReason = StringFormat("idle | BUY needs: %s | SELL needs: %s", g_buyNeeds, g_sellNeeds);
      // Audit: every idle exec bar — engines + silent guard check (no hidden veto)
      if(newExecBar)
        {
         string gWhy = "";
         bool gOk = GateAllows(gWhy);
         LogMsg(StringFormat("ENGINES idle dir=%s | UNI %s | KIL %s | SCP %s | BOOK %s | guards=%s",
                             DirStr(desired),
                             Clip(DualEngTag(g_engWhyBuy[ENG_UNICORN], g_engWhySell[ENG_UNICORN]), 36),
                             Clip(DualEngTag(g_engWhyBuy[ENG_KILLER],  g_engWhySell[ENG_KILLER]),  36),
                             Clip(DualEngTag(g_engWhyBuy[ENG_SCALP],   g_engWhySell[ENG_SCALP]),   36),
                             Clip(DualEngTag(g_engWhyBuy[ENG_BOOK],    g_engWhySell[ENG_BOOK]),    36),
                             gOk ? "OK" : ("VETO:" + gWhy)), true);
         LogBarAnalysis();
        }
      return;
     }

   // arbiter FIRST — prefer chart-flow aligned; then soft-bypass gates if needed
   int best = -1;
   for(int i = 0; i < cnt; i++)
     {
      if(!sigs[i].valid) continue;
      if(!TradeDirAllows(sigs[i].dir)) continue;
      string dwhy = "";
      if(!DirectionAllowed(sigs[i].dir, dwhy)) { g_gateReason = dwhy; continue; }
      // Chart-TF flow wins over HTF hard-filter for arbiter (v1.13 take-the-trade)
      if(g_candleFlow != 0 && sigs[i].dir != g_candleFlow && !sigs[i].counterTrend)
        { g_gateReason = "signal against chart flow " + g_flowTag; continue; }
      if(InpUseHTFBias && InpHTFHardFilter && g_htfBias != 0 && sigs[i].dir != g_htfBias && !sigs[i].counterTrend)
        { g_gateReason = "signal against HTF bias (hard filter)"; continue; }
      if(best < 0) { best = i; continue; }
      bool iFlow = TrendFlowAligned(sigs[i].dir);
      bool bFlow = TrendFlowAligned(sigs[best].dir);
      if(iFlow && !bFlow) { best = i; continue; }
      if(sigs[i].priority < sigs[best].priority ||
         (sigs[i].priority == sigs[best].priority && sigs[i].score > sigs[best].score) ||
         (sigs[i].priority == sigs[best].priority && sigs[i].score == sigs[best].score &&
          !sigs[i].counterTrend && sigs[best].counterTrend))
         best = i;
     }
   if(best < 0)
     {
      int look = (g_candleFlow != 0) ? g_candleFlow : g_htfBias;
      g_gateReason = StringFormat("looking for %s (flow %s) | no valid side after filter",
                                  DirStr(look), g_flowTag);
      if(newExecBar) LogBarAnalysis();
      return;
     }

   string why = "";
   bool gateOK = GateAllows(why);
   if(!gateOK)
     {
      bool trendTake = TrendFlowAligned(sigs[best].dir);
      if(trendTake && IsSoftGateReason(why))
        {
         // Soft bypass — Abdi: must take the trade within 1–2 bars when flow + proposal agree
         LogMsg(StringFormat("TREND-TAKE soft-bypass gate=[%s] best=%s %s — WILL EXECUTE",
                             why, sigs[best].engine, DirStr(sigs[best].dir)), true);
         // v1.15: never clear CHOP / loss-cooldown via soft-bypass
         if(!InpHardBlockChopCooldown && StringFind(why, "cooldown") >= 0) g_bypassLossCooldown = true;
         if(StringFind(why, "one entry per bar") >= 0) g_lastEntryBar = 0;
         if(!InpHardBlockChopCooldown && StringFind(why, "CHOP") >= 0) g_chopPause = false;
         if(StringFind(why, "backoff") >= 0) g_nextSendAllowed = 0;
         gateOK = true;
         g_gateReason = "soft-bypass: " + why;
        }
      else
        {
         NoteGateDrop(IsSoftGateReason(why) ? "soft-held" : "hard-gate", why);
         RecordChartSignal(sigs[best].dir, sigs[best].engine, sigs[best].reason + " | blocked: " + why, false, sigs[best].sl);
         LogMsg("GATE VETO rule=[" + why + "] dropped " + IntegerToString(cnt) +
                " signal(s) best=" + sigs[best].engine + " " + DirStr(sigs[best].dir), true);
         if(newExecBar) LogBarAnalysis();
         return;
        }
     }

   RecordChartSignal(sigs[best].dir, sigs[best].engine, sigs[best].reason, false, sigs[best].sl);
   if(TryOpen(sigs[best]))
      RecordChartSignal(sigs[best].dir, sigs[best].engine, sigs[best].reason, true, sigs[best].sl);
   if(newExecBar) LogBarAnalysis();
  }

//==================================================================
//  SECTION 11 : POSITION PROTECTION (per ticket)
//==================================================================
int TkFind(const ulong ticket)
  {
   int n = ArraySize(g_tk);
   for(int i = 0; i < n; i++) if(g_tk[i].ticket == ticket) return i;
   return -1;
  }

int TkFindOrCreate(const ulong ticket, const int dir, const double entry, const double curSL, const datetime openTime)
  {
   int idx = TkFind(ticket);
   if(idx >= 0) return idx;
   int n = ArraySize(g_tk);
   for(int i = 0; i < n; i++) if(g_tk[i].ticket == 0) { idx = i; break; }
   if(idx < 0) { ArrayResize(g_tk, n + 1); idx = n; }
   g_tk[idx].Reset();
   g_tk[idx].ticket   = ticket;
   g_tk[idx].dir      = dir;
   g_tk[idx].entry    = entry;
   g_tk[idx].openTime = openTime;
   double atr = ATRValue();
   double initSL = curSL;
   // no SL, or SL already at/after entry (EA restarted on a protected ticket): estimate the original risk from ATR
   if(initSL <= 0.0 || dir * (initSL - entry) >= 0.0)
     {
      initSL = (atr > 0.0) ? entry - dir * atr * g_prof.atrMult : entry - dir * MinDist();
      if(curSL > 0.0) g_tk[idx].beDone = true;
     }
   g_tk[idx].initSL      = initSL;
   g_tk[idx].initRiskPts = MathAbs(entry - initSL) / _Point;
   if(g_tk[idx].initRiskPts < 1.0) g_tk[idx].initRiskPts = MinDist() / _Point;
   return idx;
  }

void TkPurge()
  {
   int n = ArraySize(g_tk);
   for(int i = 0; i < n; i++)
     {
      if(g_tk[i].ticket == 0) continue;
      if(!PositionSelectByTicket(g_tk[i].ticket)) g_tk[i].Reset();
     }
  }

// --- candidate producers: return a candidate SL in X-space (x = dir*price) or NO_CAND

// Instant break-even: earliest of profile pts, InpBEProfitPctOfSL (or InpBreakEvenR), or InpBEAccountPct of equity
double ApplyInstantBreakEven(const STicketProtect &tk, const double profitPts, const double profitMoney)
  {
   if(!InpUseBreakEven || tk.beDone) return NO_CAND;
   bool trig = (profitPts >= g_prof.beTriggerPts);
   // % of SL distance (default 30% = 0.3R) OR legacy InpBreakEvenR — use the earlier of the two
   double rTrig = 0.0;
   if(InpBEProfitPctOfSL > 0.0) rTrig = InpBEProfitPctOfSL / 100.0;
   if(InpBreakEvenR > 0.0 && (rTrig <= 0.0 || InpBreakEvenR < rTrig)) rTrig = InpBreakEvenR;
   if(rTrig > 0.0 && tk.initRiskPts > 0.0 && profitPts >= rTrig * tk.initRiskPts) trig = true;
   // floating profit >= N% of equity (default 3%)
   if(InpBEAccountPct > 0.0)
     {
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(eq > 0.0 && profitMoney >= eq * InpBEAccountPct / 100.0) trig = true;
     }
   if(!trig) return NO_CAND;
   double bufPts = (double)g_prof.beBufferPts;
   if(InpBEIncludeSpread)
     {
      double sprPts = (g_ask - g_bid) / _Point;
      if(sprPts > bufPts) bufPts = sprPts;
     }
   // X-space: lock at least entry + buffer (BUY) / entry - buffer (SELL)
   return tk.dir * tk.entry + bufPts * _Point;
  }

// Peak-profit ladder: protect a rising share of peak profit as R multiples grow
double ProtectOpenStops(STicketProtect &tk)
  {
   if(!InpUseLadder || tk.initRiskPts <= 0.0) { return NO_CAND; }
   double peakR = tk.peakPts / tk.initRiskPts;
   int tier = 0; double pct = 0.0;
   if(peakR >= InpTier3R)      { tier = 3; pct = InpTier3Pct; }
   else if(peakR >= InpTier2R) { tier = 2; pct = InpTier2Pct; }
   else if(peakR >= InpTier1R) { tier = 1; pct = InpTier1Pct; }
   tk.tier = tier;
   if(tier == 0) return NO_CAND;
   return tk.dir * tk.entry + tk.peakPts * pct / 100.0 * _Point;
  }

// Structure trail: behind the last confirmed swing low/high (fractal) on the execution TF
// v1.14: after 1R peak, trail even if BE modify lagged (InpTrailAfter1RAlways)
double TrailStructureStops(const STicketProtect &tk, const MqlRates &r[], const int n, const double atr)
  {
   if(!InpUseStructureTrail || n < 10) return NO_CAND;
   bool past1R = (tk.initRiskPts > 0.0 && tk.peakPts >= tk.initRiskPts);
   if(!tk.beDone && !(InpTrailAfter1RAlways && past1R)) return NO_CAND;
   int sw = LastXSwingLow(r, n, InpTrailSwingStrength + 1, InpTrailSwingStrength, tk.dir);
   if(sw < 0) return NO_CAND;
   return XL(r, sw, tk.dir) - atr * g_prof.slBufferATR;
  }

// Orchestrator: tick-level peak lock + flow-flip reverse + at most one modify per ticket/tick
void ManageOpen()
  {
   int total = PositionsTotal();
   if(total == 0) return;

   MqlRates r[]; int n = 0;
   bool ratesLoaded = false;
   double atr = ATRValue();
   datetime now = TimeCurrent();
   int barSec = PeriodSeconds(g_tf);
   if(barSec <= 0) barSec = 60;
   static datetime s_lastFlipBar = 0;
   datetime bar1 = iTime(_Symbol, g_tf, 1);

   for(int i = total - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      int      dir    = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double   entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      double   curSL  = PositionGetDouble(POSITION_SL);
      double   curTP  = PositionGetDouble(POSITION_TP);
      double   vol    = PositionGetDouble(POSITION_VOLUME);
      datetime otime  = (datetime)PositionGetInteger(POSITION_TIME);
      double   profitMoney = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      int ti = TkFindOrCreate(ticket, dir, entry, curSL, otime);

      double ref       = RefPrice(dir);
      double profitPts = dir * (ref - entry) / _Point;
      // Tick-level peak update (critical on M1)
      if(profitPts > g_tk[ti].peakPts) g_tk[ti].peakPts = profitPts;

      // --- Flow flip reaction (once per closed chart bar) ---
      if(InpReverseOnFlowFlip && bar1 != 0 && bar1 != s_lastFlipBar)
        {
         string flipWhy = "";
         if(ConfirmedFlowFlipAgainst(dir, flipWhy))
           {
            s_lastFlipBar = bar1;
            double peakR = (g_tk[ti].initRiskPts > 0.0) ? (g_tk[ti].peakPts / g_tk[ti].initRiskPts) : 0.0;
            if(profitMoney > 0.0 || peakR >= 1.0 || g_tk[ti].beDone)
              {
               // In profit / past 1R: tighten to ≥90% of peak immediately
               double keep = InpReversalPeakKeepPct;
               if(keep < 80.0) keep = 90.0;
               double lockPts = g_tk[ti].peakPts * keep / 100.0;
               double newSL = NormPrice(entry + dir * lockPts * _Point);
               {
                  double oldSL = curSL;
                  bool moved = ProtectMoveSL(ticket, dir, entry, oldSL, newSL, curTP, "FLIP-PEAK",
                                             profitPts, profitMoney, g_tk[ti].peakPts, true);
                  if(moved)
                    {
                     g_tk[ti].beDone = true;
                     g_lastFlipExit = StringFormat("PEAK LOCK %s keep %.0f%%", DirStr(dir), keep);
                     g_pendingFlipDir = -dir;
                     if(profitMoney >= 0.0) g_bypassLossCooldown = true;
                     LogMsg(StringFormat("FLIP-PEAK done #%I64u keep %.0f%% (%s)", ticket, keep, flipWhy), true);
                    }
               }
              }
            else
              {
               // Not yet BE: market FLIP EXIT. v1.15: do NOT bypass cooldown (whipsaw was a live leak)
               LogMsg(StringFormat("FLIP EXIT #%I64u %s (not at BE) — %s", ticket, DirStr(dir), flipWhy), true);
               g_lastFlipExit = StringFormat("FLIP EXIT %s @%s", DirStr(dir), TimeToString(now, TIME_SECONDS));
               if(ClosePositionVolume(ticket, 0.0, "flip exit"))
                 {
                  g_bypassLossCooldown = false;
                  g_pendingFlipDir = -dir;
                  g_flipEnterNow = InpFlipEnterImmediate; // default OFF in v1.15
                  if(InpFlipEnterImmediate)
                    {
                     g_lastEntryBar = 0;
                     g_lastContBar  = 0;
                     LogMsg(StringFormat("FLIP-NOW armed dir=%s (user enabled immediate)", DirStr(-dir)), true);
                    }
                  else
                     LogMsg(StringFormat("FLIP EXIT done — reverse prefers %s after cooldown (no immediate)", DirStr(-dir)), true);
                 }
               continue;
              }
           }
        }

      // stale exit
      if(InpStaleExitBars > 0 && g_tk[ti].initRiskPts > 0.0 && now - otime >= (datetime)(InpStaleExitBars * barSec))
        {
         double curR = profitPts / g_tk[ti].initRiskPts;
         if(MathAbs(curR) <= InpStaleMaxR && g_tk[ti].peakPts < InpBreakEvenR * g_tk[ti].initRiskPts)
           {
            LogMsg(StringFormat("STALE EXIT #%I64u after %d bars (R=%.2f)", ticket, InpStaleExitBars, curR), true);
            ClosePositionVolume(ticket, 0.0, "stale");
            continue;
           }
        }

      if(InpPartialClosePct > 0.0 && !g_tk[ti].partialDone && g_tk[ti].initRiskPts > 0.0 &&
         profitPts >= g_tk[ti].initRiskPts && now - g_tk[ti].lastPartialTry >= 5)
        {
         g_tk[ti].lastPartialTry = now;
         double part = NormalizeVolume(vol * InpPartialClosePct / 100.0);
         if(part >= g_volMin && vol - part >= g_volMin)
           {
            if(ClosePositionVolume(ticket, part, "partial 1R")) g_tk[ti].partialDone = true;
            continue;
           }
         g_tk[ti].partialDone = true;
        }

      double xCur  = (curSL > 0.0) ? dir * curSL : NO_CAND;
      double best  = xCur;
      string src   = "";
      double peakR = (g_tk[ti].initRiskPts > 0.0) ? (g_tk[ti].peakPts / g_tk[ti].initRiskPts) : 0.0;
      double c1 = ApplyInstantBreakEven(g_tk[ti], profitPts, profitMoney);
      if(c1 > best) { best = c1; src = "BE"; }
      double c2 = ProtectOpenStops(g_tk[ti]);
      if(c2 > best)
        {
         best = c2;
         src = "LADDER T" + IntegerToString(g_tk[ti].tier);
        }
      // Structure trail after 1R / BE — trails behind price so winners stay locked
      bool past1R = (g_tk[ti].initRiskPts > 0.0 && g_tk[ti].peakPts >= InpPeakLockMinR * g_tk[ti].initRiskPts);
      if(InpUseStructureTrail && (g_tk[ti].beDone || past1R))
        {
         if(!ratesLoaded) { n = LoadRates(g_tf, 40, r); ratesLoaded = true; }
         double c3 = TrailStructureStops(g_tk[ti], r, n, atr);
         if(c3 <= NO_CAND / 2.0 && past1R && n >= 10)
           {
            int sw = LastXSwingLow(r, n, InpTrailSwingStrength + 1, InpTrailSwingStrength, dir);
            if(sw >= 0) c3 = XL(r, sw, dir) - atr * g_prof.slBufferATR;
           }
         if(c3 > best) { best = c3; src = "TRAIL"; }
        }
      // v1.15b: NEVER give back a win — BE floor + peak% lock (70%@1R, ladder handles 85%@2R)
      if(g_tk[ti].beDone || past1R || src == "BE")
        {
         double bufPts = (double)g_prof.beBufferPts;
         if(InpBEIncludeSpread)
           {
            double sprPts = (g_ask - g_bid) / _Point;
            if(sprPts > bufPts) bufPts = sprPts;
           }
         double beFloor = dir * entry + bufPts * _Point;
         if(best < beFloor) { best = beFloor; if(StringLen(src) == 0) src = "BE-FLOOR"; }
         if(past1R && g_tk[ti].peakPts > 0.0)
           {
            double keepPct = InpPeakLockPctAt1R;
            if(keepPct < 70.0) keepPct = 70.0;
            if(peakR >= InpTier2R && InpTier2Pct > keepPct) keepPct = InpTier2Pct;
            if(peakR >= InpTier3R && InpTier3Pct > keepPct) keepPct = InpTier3Pct;
            double lockPeak = dir * entry + g_tk[ti].peakPts * keepPct / 100.0 * _Point;
            if(lockPeak > best) { best = lockPeak; src = StringFormat("PEAK%.0f", keepPct); }
           }
        }

      // Max SL toward market = price − stop floor (never place inside freeze)
      double spr = MathMax(0.0, g_ask - g_bid);
      double xMax = dir * ref - MathMax(FloorDist(), InpBEIncludeSpread ? spr : 0.0);
      if(best > xMax) best = xMax;

      bool improve = false;
      double minStep = g_prof.trailStepPts * _Point;
      if(src == "BE" || StringFind(src, "LADDER") == 0 || StringFind(src, "PEAK") == 0 || src == "BE-FLOOR")
         minStep = _Point;
      if(xCur <= NO_CAND / 2.0) improve = (best > NO_CAND / 2.0 && best < dir * ref);
      else improve = (best - xCur >= minStep);
      if(!improve) continue;
      // BE / peak-lock: allow every tick; other trails keep 1s throttle
      int coolSec = (src == "BE" || StringFind(src, "PEAK") == 0 || StringFind(src, "LADDER") == 0) ? 0 : 1;
      if(coolSec > 0 && now - g_tk[ti].lastModifyTry < coolSec) continue;

      double newSL = NormPrice(XReal(best, dir));
      g_tk[ti].lastModifyTry = now;
      double oldSL = curSL;
      bool mustKeep = (g_tk[ti].beDone || past1R || src == "BE" || profitMoney > 0.0);
      bool moved = ProtectMoveSL(ticket, dir, entry, oldSL, newSL, curTP, src,
                                 profitPts, profitMoney, g_tk[ti].peakPts, mustKeep);
      if(moved)
        {
         g_tk[ti].lastModifyTry = 0;
         // Re-read SL after successful modify / possible emergency close
         if(PositionSelectByTicket(ticket))
           {
            double slNow = PositionGetDouble(POSITION_SL);
            if(dir * (slNow - entry) >= 0.0) g_tk[ti].beDone = true;
           }
         else
           {
            // closed by emergency
            g_tk[ti].beDone = true;
           }
        }
     }
  }

void CheckFridayClose()
  {
   if(!InpFridayCloseAll) return;
   if(!FridayRulesApply()) return;   // BTC: never force Friday close — trades Sat/Sun too
   if(!IsFriday()) { g_fridayClosedToday = false; return; }
   if(g_fridayClosedToday) return;
   if(MinuteOfDay(TimeCurrent()) >= g_friClose)
     {
      g_fridayClosedToday = true;
      int b = 0, s = 0;
      if(CountOwnPositions(b, s) > 0) { LogMsg("Friday close-out", true); CloseAllOwn("friday"); }
     }
  }

//==================================================================
//  SECTION 12 : CHART ANALYSIS (HH/HL/LH/LL, zones, signals, board)
//==================================================================
void ClearArmedZone()
  {
   g_zoneActive = false; g_zoneTop = 0; g_zoneBot = 0; g_zoneDir = 0; g_zoneName = ""; g_zoneWhy = "";
  }

void SetArmedZone(const int dir, const double xTop, const double xBot, const string name, const string why)
  {
   double p1 = XReal(xTop, dir), p2 = XReal(xBot, dir);
   g_zoneActive = true;
   g_zoneDir    = dir;
   g_zoneTop    = (p1 > p2) ? p1 : p2;
   g_zoneBot    = (p1 < p2) ? p1 : p2;
   g_zoneName   = name;
   g_zoneWhy    = why;
  }

void RecordChartSignal(const int dir, const string engine, const string reason, const bool taken, const double sl)
  {
   g_lastSigDir    = dir;
   g_lastSigEngine = engine;
   g_lastSigReason = reason;
   g_lastSigTime   = TimeCurrent();
   g_lastSigPrice  = (dir > 0) ? g_ask : g_bid;
   g_lastSigSL     = sl;
   g_lastSigTaken  = taken;
   g_lastSigTP     = 0.0;
   if(sl > 0.0 && InpTPMode == TP_FIXED_R && InpTakeProfitR > 0.0)
     {
      double risk = MathAbs(g_lastSigPrice - sl);
      g_lastSigTP = NormPrice(g_lastSigPrice + dir * risk * InpTakeProfitR);
     }
   // if SL missing, estimate from ATR so placement still draws
   if(g_lastSigSL <= 0.0)
     {
      double atr = ATRValue();
      if(atr > 0.0) g_lastSigSL = NormPrice(g_lastSigPrice - dir * atr * g_prof.atrMult);
     }
  }

string AnName(const string key) { return g_prefix + AN_PREFIX + key; }

// True if chart text would land under the left dashboard panel — skip drawing
bool LabelUnderDash(const datetime t, const double price)
  {
   if(!InpShowDash) return false;
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, t, price, x, y)) return false;
   int lineH = InpDashFont + 7;
   int dashH = 10 + (DASH_FIXED_LINES + g_dashTicketLines + 1) * lineH + 60;
   int x0 = InpDashX, y0 = InpDashY;
   return (x >= x0 - 4 && x <= x0 + DASH_W_PX + 8 && y >= y0 - 4 && y <= y0 + dashH + 8);
  }

void AnText(const string key, const datetime t, const double price, const string text, const color clr, const int fontSz, const ENUM_ANCHOR_POINT anchor)
  {
   string name = AnName(key);
   // Structure labels under the dashboard: delete if present and skip recreate
   if(LabelUnderDash(t, price) &&
      (StringFind(key, "SH") == 0 || StringFind(key, "SL") == 0 || StringFind(key, "TR") == 0))
     {
      if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
      return;
     }
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_TIME, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSz);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);   // behind dashboard labels
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
  }

void AnHLine(const string key, const double price, const color clr, const int style, const int width)
  {
   string name = AnName(key);
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
  }

void AnRect(const string key, const datetime t1, const double p1, const datetime t2, const double p2, const color clr)
  {
   string name = AnName(key);
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   color fill = clr;
   // soft fill via drawing style; MT5 uses COLOR for border — keep light
   ObjectSetInteger(0, name, OBJPROP_COLOR, fill);
  }

void AnArrow(const string key, const datetime t, const double price, const int dir, const color clr)
  {
   string name = AnName(key);
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_TIME, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (dir > 0) ? 233 : 234); // Wingdings up/down
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, (dir > 0) ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void AnLabel(const string key, const int x, const int y, const string text, const color clr, const int fontSz)
  {
   string name = AnName(key);
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSz);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

void AnalysisDelete()
  {
   ObjectsDeleteAll(0, g_prefix + AN_PREFIX);
  }

// Confirmed fractal with tip prominence — skips mid-impulse noise labels
bool IsPromSwingHigh(const MqlRates &r[], const int n, const int i, const int s, const double atr)
  {
   if(!IsXSwingHigh(r, n, i, s, 1)) return false;
   // stricter shoulders: both sides must be strictly below
   if(r[i - 1].high >= r[i].high || r[i + 1].high >= r[i].high) return false;
   double tip = r[i].high - MathMax(r[i - 1].high, r[i + 1].high);
   if(atr > 0.0 && tip < 0.12 * atr) return false;
   // window range must be meaningful
   double lo = r[i].low, hi = r[i].high;
   for(int k = i - s; k <= i + s; k++)
     { if(r[k].low < lo) lo = r[k].low; if(r[k].high > hi) hi = r[k].high; }
   if(atr > 0.0 && (hi - lo) < 0.35 * atr) return false;
   return true;
  }

bool IsPromSwingLow(const MqlRates &r[], const int n, const int i, const int s, const double atr)
  {
   if(!IsXSwingLow(r, n, i, s, 1)) return false;
   if(r[i - 1].low <= r[i].low || r[i + 1].low <= r[i].low) return false;
   double tip = MathMin(r[i - 1].low, r[i + 1].low) - r[i].low;
   if(atr > 0.0 && tip < 0.12 * atr) return false;
   double lo = r[i].low, hi = r[i].high;
   for(int k = i - s; k <= i + s; k++)
     { if(r[k].low < lo) lo = r[k].low; if(r[k].high > hi) hi = r[k].high; }
   if(atr > 0.0 && (hi - lo) < 0.35 * atr) return false;
   return true;
  }

// HH / HL / LH / LL labels on the execution timeframe (prominent fractals only)
void DrawSwingStructure()
  {
   if(!InpShowStructure) return;
   MqlRates r[];
   int n = LoadRates(g_tf, InpStructLookback + 10, r);
   if(n < 30) return;
   const int s = (InpSwingStrength > 2) ? InpSwingStrength : 2;   // at least 2 bars each side
   int want = InpStructLabels; if(want < 2) want = 2; if(want > 20) want = 20;
   double atr = RatesATR(r, n, 14);
   if(atr <= 0.0) atr = ATRValue();

   int hiIdx[]; ArrayResize(hiIdx, 0);
   int loIdx[]; ArrayResize(loIdx, 0);
   for(int i = s + 1; i < n - s; i++)
     {
      if(IsPromSwingHigh(r, n, i, s, atr))
        { int k = ArraySize(hiIdx); ArrayResize(hiIdx, k + 1); hiIdx[k] = i; }
      if(IsPromSwingLow(r, n, i, s, atr))
        { int k = ArraySize(loIdx); ArrayResize(loIdx, k + 1); loIdx[k] = i; }
      if(ArraySize(hiIdx) >= want + 2 && ArraySize(loIdx) >= want + 2) break;
     }

   int nh = ArraySize(hiIdx);
   int shown = 0;
   for(int k = 0; k < nh - 1 && shown < want; k++)
     {
      int cur = hiIdx[k], prev = hiIdx[k + 1];
      bool isHH = (r[cur].high > r[prev].high);
      string lab = isHH ? "HH" : "LH";
      color  clr = isHH ? InpBullColor : InpBearColor;
      // anchor below the high tip so label sits above the wick
      AnText("SH" + IntegerToString(shown), r[cur].time, r[cur].high, lab, clr, 9, ANCHOR_LOWER);
      if(shown == 0) g_lastStructEvent = lab;
      shown++;
     }
   int nl = ArraySize(loIdx);
   shown = 0;
   for(int k = 0; k < nl - 1 && shown < want; k++)
     {
      int cur = loIdx[k], prev = loIdx[k + 1];
      bool isHL = (r[cur].low > r[prev].low);
      string lab = isHL ? "HL" : "LL";
      color  clr = isHL ? InpBullColor : InpBearColor;
      AnText("SL" + IntegerToString(shown), r[cur].time, r[cur].low, lab, clr, 9, ANCHOR_UPPER);
      if(shown == 0)
         g_lastStructEvent = (StringLen(g_lastStructEvent) > 0 && g_lastStructEvent != "-")
                             ? (g_lastStructEvent + "/" + lab) : lab;
      shown++;
     }
  }

void DrawArmedZone()
  {
   if(!InpShowZones || !g_zoneActive || g_zoneTop <= g_zoneBot) return;
   datetime t1 = iTime(_Symbol, g_tf, 12);
   datetime t2 = iTime(_Symbol, g_tf, 0) + PeriodSeconds(g_tf) * 4;
   if(t1 == 0) t1 = TimeCurrent() - PeriodSeconds(g_tf) * 12;
   if(t2 == 0) t2 = TimeCurrent() + PeriodSeconds(g_tf) * 4;
   color clr = (g_zoneDir > 0) ? InpBullColor : InpBearColor;
   AnRect("ZONE", t1, g_zoneTop, t2, g_zoneBot, clr);
   AnHLine("ZT", g_zoneTop, InpZoneColor, STYLE_DOT, 1);
   AnHLine("ZB", g_zoneBot, InpZoneColor, STYLE_DOT, 1);
   AnText("ZL", t2, g_zoneTop, g_zoneName + " " + DirStr(g_zoneDir) + " ZONE", InpZoneColor, 8, ANCHOR_LEFT_UPPER);
  }

void DrawLastSignal()
  {
   if(g_lastSigDir == 0 || g_lastSigTime == 0) return;
   color clr = (g_lastSigDir > 0) ? InpBullColor : InpBearColor;
   datetime t = iTime(_Symbol, g_tf, 1);
   if(t == 0) t = g_lastSigTime;
   double price = g_lastSigPrice;
   if(price <= 0.0) price = (g_lastSigDir > 0) ? g_ask : g_bid;

   if(InpShowSignalArrows)
     {
      AnArrow("SIG", t, price, g_lastSigDir, clr);
      string tag = (g_lastSigTaken ? "ENTRY " : "SIGNAL ") + g_lastSigEngine + " " + DirStr(g_lastSigDir);
      AnText("SIGT", t, price, tag, clr, 8, (g_lastSigDir > 0) ? ANCHOR_UPPER : ANCHOR_LOWER);
      AnText("SIGR", t, price, Clip(g_lastSigReason, 48), clrWhiteSmoke, 7, (g_lastSigDir > 0) ? ANCHOR_LEFT_UPPER : ANCHOR_LEFT_LOWER);
     }

   // placement: ENTRY / SL / TP lines + labels (so the user sees where the trade would sit)
   if(InpShowPlacement)
     {
      AnHLine("ENT", price, InpEntryColor, STYLE_SOLID, 1);
      AnText("ENTL", t, price, "ENTRY " + DirStr(g_lastSigDir) + " " + DoubleToString(price, g_digits), InpEntryColor, 8, ANCHOR_LEFT);
      if(g_lastSigSL > 0.0)
        {
         AnHLine("SL", g_lastSigSL, InpSLColor, STYLE_DASH, 2);
         AnText("SLL", t, g_lastSigSL, "SL " + DoubleToString(g_lastSigSL, g_digits), InpSLColor, 8, ANCHOR_LEFT);
        }
      if(g_lastSigTP > 0.0)
        {
         AnHLine("TP", g_lastSigTP, InpTPColor, STYLE_DASH, 2);
         AnText("TPL", t, g_lastSigTP, "TP " + DoubleToString(g_lastSigTP, g_digits), InpTPColor, 8, ANCHOR_LEFT);
        }
     }
  }

void AnTrend(const string key, const datetime t1, const double p1, const datetime t2, const double p2, const color clr)
  {
   string name = AnName(key);
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
  }

// HTF-aligned trend: bearish = falling highs; bullish = rising lows
void DrawTrendLines()
  {
   if(!InpShowTrendLines) return;
   // only draw when FINAL bias is clear — never paint a fake TREND BEAR/BULL
   if(g_htfBias == 0) return;
   MqlRates r[];
   int n = LoadRates(g_tf, InpStructLookback + 10, r);
   if(n < 40) return;
   const int s = InpSwingStrength;
   int dir = g_htfBias;

   if(dir < 0)
     {
      int h1 = LastXSwingHigh(r, n, s + 1, s, 1);
      int h2 = (h1 < 0) ? -1 : LastXSwingHigh(r, n, h1 + 1, s, 1);
      if(h1 >= 0 && h2 >= 0)
        {
         AnTrend("TRH", r[h2].time, r[h2].high, r[h1].time, r[h1].high, InpBearColor);
         AnText("TRHT", r[h1].time, r[h1].high, "TREND BEAR", InpBearColor, 9, ANCHOR_LOWER);
        }
     }
   else
     {
      int l1 = LastXSwingLow(r, n, s + 1, s, 1);
      int l2 = (l1 < 0) ? -1 : LastXSwingLow(r, n, l1 + 1, s, 1);
      if(l1 >= 0 && l2 >= 0)
        {
         AnTrend("TRL", r[l2].time, r[l2].low, r[l1].time, r[l1].low, InpBullColor);
         AnText("TRLT", r[l1].time, r[l1].low, "TREND BULL", InpBullColor, 9, ANCHOR_UPPER);
        }
     }
  }

void DrawMarketBoard()
  {
   if(!InpShowMarketBoard) return;
   string biasS = (g_htfBias > 0) ? "BULLISH" : ((g_htfBias < 0) ? "BEARISH" : "NEUTRAL");
   color  biasC = (g_htfBias > 0) ? InpBullColor : ((g_htfBias < 0) ? InpBearColor : clrOrange);
   string sess = ""; InSession(sess);
   int y = 20, x = 12, lh = InpDashFont + 6;

   AnLabel("B0", x, y, "══ MARKET BOARD | © " + EA_AUTHOR + " ══", InpDashAccent, InpDashFont); y += lh;
   AnLabel("B1", x, y, "FINAL: " + biasS, biasC, InpDashFont + 1); y += lh;
   AnLabel("B1a", x, y, StringFormat("%s: %s (S%s E%s) %s", TFStr(InpBiasTF2), TrendTag(g_bias2), TrendTag(g_struct2), TrendTag(g_ema2), Clip(g_tfWhy2, 22)),
           (g_bias2 > 0) ? InpBullColor : ((g_bias2 < 0) ? InpBearColor : clrOrange), InpDashFont); y += lh;
   AnLabel("B1b", x, y, StringFormat("%s: %s (S%s E%s) %s", TFStr(InpBiasTF1), TrendTag(g_bias1), TrendTag(g_struct1), TrendTag(g_ema1), Clip(g_tfWhy1, 22)),
           (g_bias1 > 0) ? InpBullColor : ((g_bias1 < 0) ? InpBearColor : clrOrange), InpDashFont); y += lh;
   AnLabel("B1c", x, y, StringFormat("Exec %s: %s (S%s E%s) %s", TFStr(g_tf), TrendTag(g_biasExec), TrendTag(g_structExec), TrendTag(g_emaExec), Clip(g_tfWhyExec, 20)),
           (g_biasExec > 0) ? InpBullColor : ((g_biasExec < 0) ? InpBearColor : clrOrange), InpDashFont); y += lh;
   AnLabel("B1d", x, y, Clip(g_trendWhy, 58), InpDashText, InpDashFont); y += lh;
   AnLabel("B1e", x, y, Clip(g_dirSourceTag, 56) + (g_chopPause ? " CHOP" : ""),
           g_chopPause ? clrOrange : ((g_candleFlow > 0) ? InpBullColor : ((g_candleFlow < 0) ? InpBearColor : InpDashText)), InpDashFont); y += lh;
   if(StringLen(g_lastFlipMsg) > 0)
     { AnLabel("B1f", x, y, Clip(g_lastFlipMsg + " | " + g_lastFlipExit, 56), InpDashText, InpDashFont); y += lh; }
   AnLabel("B2", x, y, "Scalp TFs: M15/M5/M1 | Session: " + sess, InpDashText, InpDashFont); y += lh;
   AnLabel("BA", x, y, "Action: " + Clip((StringLen(g_liveActionTag) > 0) ? g_liveActionTag : ("flow " + g_flowTag), 50),
           (g_candleFlow < 0) ? clrTomato : ((g_candleFlow > 0) ? clrLightGreen : InpDashText), InpDashFont); y += lh;
   AnLabel("B3", x, y, "Gate: " + Clip(g_gateReason == "" ? "ready" : g_gateReason, 52), InpDashText, InpDashFont); y += lh;
   AnLabel("BB", x, y, "Block: " + Clip(g_lastDropReason == "" ? "-" : g_lastDropReason, 52),
           (StringLen(g_lastDropReason) > 0) ? clrOrange : InpDashText, InpDashFont); y += lh;
   AnLabel("BS2", x, y, StringFormat("Stats: prop %d softRR %d dropQ %d dropOth %d EXEC %d",
                                     g_statPropose, g_statRRSoftExt, g_statDropQuality, g_statDropOther, g_statExecuted),
           (g_statExecuted > 0) ? clrLightGreen : InpDashText, InpDashFont); y += lh;
   AnLabel("BN", x, y, StringFormat("BUY needs: %s | SELL needs: %s | Dir %s | CT %s",
                                    Clip(g_buyNeeds, 18), Clip(g_sellNeeds, 18),
                                    EnumToString(InpTradeDirection),
                                    CounterTrendPermitted() ? "ON" : "off"), InpDashText, InpDashFont); y += lh;
   AnLabel("BQ", x, y, StringFormat("Q=%d/%d %s | risk USD %.2f / cap USD %s | Mode %s",
                                    g_lastQuality, EffectiveMinQuality(), Clip(g_lastQualityWhy, 28),
                                    g_lastRiskMoney,
                                    (InpMaxLossPerTradeMoney > 0.0) ? DoubleToString(InpMaxLossPerTradeMoney, 0) : "off",
                                    EnumToString(InpEntryMode)), InpDashText, InpDashFont); y += lh;
   AnLabel("B4", x, y, "Profile: " + g_prof.name + " | Spread " + IntegerToString(SpreadPts()) + "/" + IntegerToString(g_prof.maxSpreadPts), InpDashText, InpDashFont); y += lh + 4;

   AnLabel("B5", x, y, "── Strategies (BUY | SELL) ──", InpDashAccent, InpDashFont); y += lh;
   for(int e = 0; e < ENG_COUNT; e++)
     {
      string st = g_engOn[e] ? "ON " : "OFF";
      string w  = DualEngTag(g_engWhyBuy[e], g_engWhySell[e]);
      if(e == ENG_UNICORN && g_unicornWaiting) w = "[WAIT] " + w;
      AnLabel("BE" + IntegerToString(e), x, y, StringFormat("%s [%s] %s", g_engName[e], st, Clip(w, 44)), g_engOn[e] ? InpDashText : clrGray, InpDashFont);
      y += lh;
     }
   y += 4;
   if(g_zoneActive)
      AnLabel("BZ", x, y, "ZONE: " + g_zoneName + " " + DirStr(g_zoneDir) + " " + DoubleToString(g_zoneBot, g_digits) + "-" + DoubleToString(g_zoneTop, g_digits), InpZoneColor, InpDashFont);
   else
      AnLabel("BZ", x, y, "ZONE: none armed", clrGray, InpDashFont);
   y += lh;
   if(g_lastSigDir != 0)
      AnLabel("BS", x, y, "Last signal: " + (g_lastSigTaken ? "TAKEN " : "SEEN ") + g_lastSigEngine + " " + DirStr(g_lastSigDir) + " | " + Clip(g_lastSigReason, 36),
              (g_lastSigDir > 0) ? InpBullColor : InpBearColor, InpDashFont);
   else
      AnLabel("BS", x, y, "Last signal: -", clrGray, InpDashFont);
  }

void UpdateChartAnalysis(const bool force)
  {
   if(!g_initOK) return;
   datetime bar = iTime(_Symbol, g_tf, 0);
   if(!force && bar != 0 && bar == g_lastAnalysisBar && !InpShowMarketBoard) return;
   // market board + zone refresh every timer; structure on new bar or force
   bool newBar = (bar != 0 && bar != g_lastAnalysisBar);
   if(newBar || force)
     {
      // wipe previous structure / trend drawings then redraw (placement + board are upserted)
      for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
        {
         string nm = ObjectName(0, i, 0, -1);
         if(StringFind(nm, g_prefix + AN_PREFIX + "SH") == 0 ||
            StringFind(nm, g_prefix + AN_PREFIX + "SL") == 0 ||
            StringFind(nm, g_prefix + AN_PREFIX + "ZONE") == 0 ||
            StringFind(nm, g_prefix + AN_PREFIX + "ZT") == 0 ||
            StringFind(nm, g_prefix + AN_PREFIX + "ZB") == 0 ||
            StringFind(nm, g_prefix + AN_PREFIX + "ZL") == 0 ||
            StringFind(nm, g_prefix + AN_PREFIX + "TR") == 0)
            ObjectDelete(0, nm);
        }
      DrawSwingStructure();
      DrawTrendLines();
      g_lastAnalysisBar = bar;
     }
   DrawArmedZone();
   DrawLastSignal();
   DrawMarketBoard();
  }

//==================================================================
//  SECTION 13 : DASHBOARD
//==================================================================
void CreateRect(const string name, const int x, const int y, const int w, const int h)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, InpDashBg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpDashAccent);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);   // above chart structure texts
  }

void CreateLabel(const string name, const int x, const int y, const string text, const color clr)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpDashFont);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 101);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

void CreateButton(const string name, const int x, const int y, const int w, const int h, const string text)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpDashFont);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 2);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

void SetLabel(const int line, const string text, const color clr)
  {
   string name = g_prefix + "L" + IntegerToString(line);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

void SetButtonColor(const string shortName, const bool on, const string text)
  {
   string name = g_prefix + shortName;
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, on ? clrDarkGreen : clrDimGray);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
  }

void DashCreate()
  {
   if(!InpShowDash) return;
   g_dashLines = DASH_FIXED_LINES + g_dashTicketLines + 1;   // +1 copyright footer
   int lineH = InpDashFont + 7;
   int w = 560;
   int h = 10 + g_dashLines * lineH + 36;
   CreateRect(g_prefix + "bg", InpDashX, InpDashY, w, h);
   for(int i = 0; i < g_dashLines; i++)
      CreateLabel(g_prefix + "L" + IntegerToString(i), InpDashX + 8, InpDashY + 6 + i * lineH, "", InpDashText);
   int by = InpDashY + 6 + g_dashLines * lineH + 4;
   int bw = 84, bh = 22, bx = InpDashX + 8;
   CreateButton(g_prefix + "btnPause", bx, by, bw, bh, "Pause");     bx += bw + 6;
   CreateButton(g_prefix + "btnClose", bx, by, bw, bh, "Close All"); bx += bw + 6;
   CreateButton(g_prefix + "btnUni",   bx, by, bw, bh, "UNICORN");   bx += bw + 6;
   CreateButton(g_prefix + "btnKil",   bx, by, bw, bh, "KILLER");    bx += bw + 6;
   CreateButton(g_prefix + "btnScp",   bx, by, bw, bh, "SCALP");     bx += bw + 6;
   CreateButton(g_prefix + "btnBook",  bx, by, bw, bh, "BOOK");
   DrawDash();
  }

void DashDelete()
  {
   AnalysisDelete();
   ObjectsDeleteAll(0, g_prefix);
   ChartRedraw();
  }

string Clip(const string s, const int maxLen)
  {
   if(StringLen(s) <= maxLen) return s;
   return StringSubstr(s, 0, maxLen - 1) + "~";
  }

void DrawDash()
  {
   if(!InpShowDash || g_dashLines == 0) return;
   int line = 0;
   color ok = clrLightGreen, warn = clrOrange, bad = clrTomato;

   SetLabel(line++, StringFormat("%s | %s v%s | %s | %s | TF %s | Magic %I64d | MaxSL USD %s | TP %s",
                                 EA_AUTHOR, EA_NAME, EA_VER, _Symbol, g_prof.name, TFStr(g_tf), InpMagic,
                                 (InpMaxLossPerTradeMoney > 0.0) ? DoubleToString(InpMaxLossPerTradeMoney, 0) : "off",
                                 (InpTPMode == TP_TRAIL) ? "TRAIL" : "FixedR"), InpDashAccent);

   string st = "RUNNING"; color stc = ok;
   if(g_halted)         { st = "HALTED - " + g_haltReason; stc = bad; }
   else if(g_paused)    { st = "PAUSED (manual)"; stc = warn; }
   else if(g_dayLocked) { st = "DAY LOCKED - " + g_dayLockReason; stc = warn; }
   else if(g_candleFlow < 0) { st = "RUNNING — SELL ACTIVE (BEAR flow)"; stc = bad; }
   else if(g_candleFlow > 0) { st = "RUNNING — BUY ACTIVE (BULL flow)"; stc = ok; }
   SetLabel(line++, "Status : " + Clip(st, 70), stc);

   string biasS = (g_candleFlow != 0) ? ((g_candleFlow > 0) ? "BULL" : "BEAR")
                : ((g_htfBias > 0) ? "BULL" : ((g_htfBias < 0) ? "BEAR" : "WAIT"));
   SetLabel(line++, StringFormat("Trend  : %s (live flow) | %s=%s %s=%s Exec=%s",
                                 biasS, TFStr(InpBiasTF2), TrendTag(g_bias2), TFStr(InpBiasTF1), TrendTag(g_bias1), TrendTag(g_biasExec)),
            (g_candleFlow > 0 || g_htfBias > 0) ? ok : ((g_candleFlow < 0 || g_htfBias < 0) ? bad : warn));
   SetLabel(line++, "Action : " + Clip((StringLen(g_liveActionTag) > 0) ? g_liveActionTag : ("flow " + g_flowTag), 70),
            (g_candleFlow < 0) ? bad : ((g_candleFlow > 0) ? ok : warn));
   SetLabel(line++, "Why    : " + Clip(g_trendWhy, 70), InpDashText);
   SetLabel(line++, Clip((StringLen(g_dirSourceTag) > 0) ? g_dirSourceTag : ("DIR SOURCE: " + TFStr(g_tf) + " | flow " + g_flowTag), 72)
            + (g_chopPause ? " CHOP" : ""),
            g_chopPause ? warn : ((g_candleFlow > 0) ? ok : ((g_candleFlow < 0) ? bad : warn)));
   if(StringLen(g_lastFlipMsg) > 0 || StringLen(g_lastFlipExit) > 0)
      SetLabel(line++, Clip(g_lastFlipMsg + ((StringLen(g_lastFlipExit) > 0) ? (" | " + g_lastFlipExit) : ""), 72), InpDashText);

   int sp = SpreadPts();
   string nw = ""; bool news = NewsBlocked(nw);
   string sess = ""; bool inS = InSession(sess);
   SetLabel(line++, StringFormat("Spread : %d / %d pts | Session: %s (srv GMT%+d) | News: %s | Floor %d pts", sp, g_prof.maxSpreadPts, sess, g_serverGMTOffset, news ? "BLOCK" : "ok", BrokerStopFloor()),
            (sp > g_prof.maxSpreadPts || news || !inS) ? warn : InpDashText);

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (g_equityPeak > 0.0) ? (1.0 - eq / g_equityPeak) * 100.0 : 0.0;
   SetLabel(line++, StringFormat("Daily  : today P/L %.2f (lock %s) | Trades %d/%s | Consec %d/%s | DD %.1f%% | %s",
                                 g_dailyPL,
                                 (InpDailyMaxLossPct > 0.0) ? (DoubleToString(InpDailyMaxLossPct, 1) + "%") : "OFF",
                                 g_tradesToday,
                                 (InpMaxTradesPerDay > 0) ? IntegerToString(InpMaxTradesPerDay) : "off",
                                 g_consecLosses,
                                 (InpMaxConsecLosses > 0) ? IntegerToString(InpMaxConsecLosses) : "off",
                                 dd,
                                 IsCryptoSymbol() ? "BTC 24/7" : "FX 24/5"),
            (g_dayLocked) ? bad : ((g_dailyPL < 0.0) ? warn : InpDashText));

   SetLabel(line++, "Send   : " + Clip(SendFlightSummary(), 70), (SendBlocked(nw)) ? warn : InpDashText);
   SetLabel(line++, "Gate   : " + Clip(g_gateReason == "" ? "ready" : g_gateReason, 70),
            (StringFind(g_gateReason, "drop") >= 0 || StringFind(g_gateReason, "VETO") >= 0) ? warn : InpDashText);
   SetLabel(line++, "Block  : " + Clip(g_lastDropReason == "" ? (g_lastBlockRule == "" ? "-" : g_lastBlockRule) : g_lastDropReason, 70),
            (StringLen(g_lastDropReason) > 0) ? warn : InpDashText);
   SetLabel(line++, StringFormat("Stats  : prop %d | softRR %d | dropQ %d | dropFlow %d | dropOth %d | EXEC %d",
                                 g_statPropose, g_statRRSoftExt, g_statDropQuality, g_statDropFlow, g_statDropOther, g_statExecuted),
            (g_statExecuted > 0) ? ok : InpDashText);
   SetLabel(line++, StringFormat("Quality: %d / min %d | %s | last risk USD %.2f (cap USD %s)",
                                 g_lastQuality, EffectiveMinQuality(),
                                 Clip(g_lastQualityWhy == "" ? "-" : g_lastQualityWhy, 40),
                                 g_lastRiskMoney,
                                 (InpMaxLossPerTradeMoney > 0.0) ? DoubleToString(InpMaxLossPerTradeMoney, 0) : "off"),
            (g_lastQuality > 0 && g_lastQuality < EffectiveMinQuality()) ? warn : InpDashText);
   SetLabel(line++, "LastErr: " + Clip(g_lastError == "" ? "-" : TimeToString(g_lastErrorTime, TIME_MINUTES) + " " + g_lastError, 70), (g_lastError == "") ? InpDashText : warn);

   for(int e = 0; e < ENG_COUNT; e++)
     {
      string w = DualEngTag(g_engWhyBuy[e], g_engWhySell[e]);
      if(e == ENG_UNICORN && g_unicornWaiting) w = "[WAIT] " + w;
      SetLabel(line++, StringFormat("%-7s[%s] %s", g_engName[e], g_engOn[e] ? "ON " : "OFF", Clip(w, 58)), g_engOn[e] ? InpDashText : clrGray);
     }

   SetLabel(line++, "Tickets:", InpDashAccent);
   int shown = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total && shown < g_dashTicketLines; i++)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      int dir = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP);
      double pts = dir * (RefPrice(dir) - entry) / _Point;
      int ti = TkFind(t);
      int tier = (ti >= 0) ? g_tk[ti].tier : 0;
      bool be = (ti >= 0) ? g_tk[ti].beDone : false;
      SetLabel(line++, StringFormat(" #%I64u %s %.2f @%.*f SL %.*f TP %s | %+.0f pts | T%d%s | %.2f",
                                    t, DirStr(dir), PositionGetDouble(POSITION_VOLUME), g_digits, entry, g_digits, sl,
                                    (tp > 0.0) ? DoubleToString(tp, g_digits) : "-", pts, tier, be ? " BE" : "", PositionGetDouble(POSITION_PROFIT)),
               (pts >= 0.0) ? ok : bad);
      shown++;
     }
   for(; shown < g_dashTicketLines; shown++) SetLabel(line++, " -", clrGray);

   SetLabel(line++, "© " + EA_AUTHOR, InpDashAccent);

   SetButtonColor("btnPause", !g_paused && !g_halted, (g_paused || g_halted) ? "Resume" : "Pause");
   SetButtonColor("btnClose", false, "Close All");
   SetButtonColor("btnUni",  g_engOn[ENG_UNICORN], "UNICORN");
   SetButtonColor("btnKil",  g_engOn[ENG_KILLER],  "KILLER");
   SetButtonColor("btnScp",  g_engOn[ENG_SCALP],   "SCALP");
   SetButtonColor("btnBook", g_engOn[ENG_BOOK],    "BOOK");
   ChartRedraw();
  }

//==================================================================
//  SECTION 14 : EVENT HANDLERS
//==================================================================
int OnInit()
  {
   g_initOK = false;
   g_tf     = (InpExecTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : InpExecTF;
   g_prefix = "MJM_" + IntegerToString(InpMagic) + "_";
   if(PeriodSeconds(g_tf) <= PeriodSeconds(PERIOD_M1))
      Print(EA_NAME, ": M1 chart mode — direction from M1 flow/impulse (M5 soft quality only); tick peak-lock + flip on M1 close");

   if(!SymbolInfoInteger(_Symbol, SYMBOL_SELECT)) SymbolSelect(_Symbol, true);
   g_digits    = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_volStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   g_volMin    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_volMax    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(g_volStep <= 0.0) g_volStep = 0.01;
   if(g_volMin  <= 0.0) g_volMin  = g_volStep;
   if(g_volMax  <= 0.0) g_volMax  = 100.0;
   g_volDigits = VolumeDigits(g_volStep);

   if(InpMaxPositions < 1)                       { Print(EA_NAME, ": InpMaxPositions must be >= 1"); return INIT_PARAMETERS_INCORRECT; }
   if(InpFixedLot <= 0.0 && InpRiskPercent <= 0.0) { Print(EA_NAME, ": set InpRiskPercent > 0 or InpFixedLot > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(InpSwingStrength < 1 || InpStructLookback < 40) { Print(EA_NAME, ": InpSwingStrength >= 1 and InpStructLookback >= 40 required"); return INIT_PARAMETERS_INCORRECT; }
   if(InpTier1Pct < 0 || InpTier1Pct > 100 || InpTier2Pct < 0 || InpTier2Pct > 100 || InpTier3Pct < 0 || InpTier3Pct > 100)
     { Print(EA_NAME, ": tier percents must be 0..100"); return INIT_PARAMETERS_INCORRECT; }
   if(InpPartialClosePct < 0.0 || InpPartialClosePct >= 100.0) { Print(EA_NAME, ": InpPartialClosePct must be 0..99"); return INIT_PARAMETERS_INCORRECT; }

   long tmode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tmode == SYMBOL_TRADE_MODE_DISABLED) { Print(EA_NAME, ": trading disabled for ", _Symbol); return INIT_FAILED; }
   if(tmode != SYMBOL_TRADE_MODE_FULL) Print(EA_NAME, ": warning - symbol trade mode is restricted (", tmode, ")");

   LoadSymbolProfile();
   DetectFillingMode();

   // sessions
   if(!ParseHHMM(InpLondonStart, g_lonStart) || !ParseHHMM(InpLondonEnd, g_lonEnd) ||
      !ParseHHMM(InpNYStart, g_nyStart) || !ParseHHMM(InpNYEnd, g_nyEnd) ||
      !ParseHHMM(InpFridayNoNewTrades, g_friNoNew) || !ParseHHMM(InpFridayCloseTime, g_friClose))
     { Print(EA_NAME, ": invalid HH:MM time input"); return INIT_PARAMETERS_INCORRECT; }
   ParseNewsWindows();

   // broker server offset from GMT: explicit input, or auto-detected from server clock vs GMT
   g_serverGMTOffset = InpServerGMTOffset;
   if(InpServerGMTOffset == 99)
     {
      if(MQLInfoInteger(MQL_TESTER)) g_serverGMTOffset = 3;   // TimeGMT() == server time inside the tester
      else
        {
         long diff = (long)TimeTradeServer() - (long)TimeGMT();
         g_serverGMTOffset = (int)MathRound(diff / 3600.0);
         if(g_serverGMTOffset < -12 || g_serverGMTOffset > 14) g_serverGMTOffset = 3;
        }
      Print(EA_NAME, ": server GMT offset auto-detected = ", g_serverGMTOffset);
     }

   // indicators
   g_hATR      = iATR(_Symbol, g_tf, ATR_PERIOD);
   g_hEMAExec  = iMA(_Symbol, g_tf, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMAM15   = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMABias1 = iMA(_Symbol, InpBiasTF1, InpBiasEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMABias2 = iMA(_Symbol, InpBiasTF2, InpBiasEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hATR == INVALID_HANDLE || g_hEMAExec == INVALID_HANDLE || g_hEMAM15 == INVALID_HANDLE ||
      g_hEMABias1 == INVALID_HANDLE || g_hEMABias2 == INVALID_HANDLE)
     { Print(EA_NAME, ": indicator handle creation failed, err ", GetLastError()); return INIT_FAILED; }

   // engines
   g_engOn[ENG_UNICORN] = InpEnableUnicorn; g_engPrio[ENG_UNICORN] = InpPrioUnicorn; g_engName[ENG_UNICORN] = "Unicorn";
   g_engOn[ENG_KILLER]  = InpEnableKiller;  g_engPrio[ENG_KILLER]  = InpPrioKiller;  g_engName[ENG_KILLER]  = "Killer";
   g_engOn[ENG_SCALP]   = InpEnableScalp;   g_engPrio[ENG_SCALP]   = InpPrioScalp;   g_engName[ENG_SCALP]   = "Scalp";
   g_engOn[ENG_BOOK]    = InpEnableBook;    g_engPrio[ENG_BOOK]    = InpPrioBook;    g_engName[ENG_BOOK]    = "Book";
   for(int e = 0; e < ENG_COUNT; e++)
     {
      g_engWhy[e] = DualEngTag("idle", "idle");
      g_engWhyBuy[e] = "idle";
      g_engWhySell[e] = "idle";
      g_engLastFire[e] = 0;
     }
   g_prevFinalBias = 0;
   g_buyNeeds = "scan"; g_sellNeeds = "scan";
   g_scalpSig.Reset();

   // state
   SendRingInit();
   ArrayResize(g_tk, InpMaxPositions);
   for(int i = 0; i < InpMaxPositions; i++) g_tk[i].Reset();
   g_paused = false; g_halted = false; g_haltReason = ""; g_dayLocked = false; g_dayLockReason = "";
   g_lastDay = DayStart(TimeCurrent());
   g_gvPeakName = "MJM_" + IntegerToString(InpMagic) + "_" + _Symbol + "_eqpeak";
   g_equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(g_gvPeakName))
     {
      double saved = GlobalVariableGet(g_gvPeakName);
      if(saved > g_equityPeak) g_equityPeak = saved;
     }
   RefreshPrices();
   RefreshDailyStats();
   CheckDailyLocks();
   g_htfBias = ComputeHTFBias();
   g_lastExecBar = iTime(_Symbol, g_tf, 0);
   g_lastM1Bar   = iTime(_Symbol, PERIOD_M1, 0);

   // dashboard
   g_dashTicketLines = (InpMaxPositions < 6) ? InpMaxPositions : 6;
   DashCreate();
   UpdateChartAnalysis(true);

   EventSetTimer(1);
   g_initOK = true;
   PrintFormat("%s v%s initialised on %s (%s) profile=%s digits=%d minSL=%d pts maxSpread=%d filling=%s | mode=%s MaxSL_USD=%.0f TP=%s LogLevel=%d Qmin=%d",
               EA_NAME, EA_VER, _Symbol, TFStr(g_tf), g_prof.name, g_digits, g_prof.minSLPts, g_prof.maxSpreadPts, EnumToString(g_filling),
               EnumToString(InpEntryMode), InpMaxLossPerTradeMoney,
               (InpTPMode == TP_TRAIL) ? "TRAIL" : "FixedR", InpLogLevel, EffectiveMinQuality());
   LogMsg(StringFormat("v%s dual-direction ON — each %s bar logs BUY+SELL per engine; FINAL flips on H1 CHoCH+M15; TradeDir=%s CT=%s",
                       EA_VER, TFStr(g_tf), EnumToString(InpTradeDirection),
                       CounterTrendPermitted() ? "ON" : "off"), true);
   LogMsg(StringFormat("v1.15c CORE: K=pullback+flow+MSS | BE+LOCK | cool %db/%dm | maxDay=%d | BE@%.2fR | expRR>=%.1f | flipImm=%s | MaxSL_USD=%.0f | MaxPos=%d",
                       InpCooldownBarsAfterLoss, InpCooldownAfterLossMin, InpMaxTradesPerDay,
                       InpBreakEvenR, InpMinExpectancyRR,
                       InpFlipEnterImmediate ? "ON" : "off",
                       InpMaxLossPerTradeMoney, InpMaxPositions), true);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   DashDelete();
   if(g_hATR      != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hEMAExec  != INVALID_HANDLE) IndicatorRelease(g_hEMAExec);
   if(g_hEMAM15   != INVALID_HANDLE) IndicatorRelease(g_hEMAM15);
   if(g_hEMABias1 != INVALID_HANDLE) IndicatorRelease(g_hEMABias1);
   if(g_hEMABias2 != INVALID_HANDLE) IndicatorRelease(g_hEMABias2);
   g_hATR = g_hEMAExec = g_hEMAM15 = g_hEMABias1 = g_hEMABias2 = INVALID_HANDLE;
   g_initOK = false;
   LogMsg("deinit reason " + IntegerToString(reason));
  }

void OnTick()
  {
   if(!g_initOK) return;
   if(!RefreshPrices()) return;

   // 1. protect what is open (always, even when paused)
   ManageOpen();
   CheckFridayClose();

   // 2. new-bar driven signal evaluation through the single gate
   //    Instant reverse: also run mid-bar when FLIP-NOW is armed (no wait for next bar)
   bool newExec = IsNewBar(g_tf, g_lastExecBar);
   bool newM1   = IsNewBar(PERIOD_M1, g_lastM1Bar);
   bool flipNow = (g_flipEnterNow && g_pendingFlipDir != 0);
   if(!newExec && !newM1 && !flipNow) return;

   if(newExec || newM1 || flipNow) g_htfBias = ComputeHTFBias();
   if(g_statsDirty) { RefreshDailyStats(); CheckDailyLocks(); }
   // Keep real new-bar flags (idle/clear counters); engines gate on g_flipEnterNow
   EvaluateEntryGate(newExec, newM1);
   if(newExec)
     {
      UpdateChartAnalysis(true);
      // bar analysis also called inside EvaluateEntryGate; ensure at least one line per exec bar
      LogBarAnalysis();
     }
  }

void OnTimer()
  {
   if(!g_initOK) return;
   RefreshPrices();

   // day rollover
   datetime today = DayStart(TimeCurrent());
   if(today != g_lastDay)
     {
      g_lastDay = today;
      g_dayLocked = false; g_dayLockReason = "";
      g_fridayClosedToday = false;
      g_statsDirty = true;
      LogMsg("New trading day - daily locks reset");
     }

   ReconcileSendFlight();
   TkPurge();
   if(g_statsDirty || TimeCurrent() - g_lastStatsRefresh >= 30) { RefreshDailyStats(); CheckDailyLocks(); }
   CheckKillSwitch();
   CheckFridayClose();
   DrawDash();
   UpdateChartAnalysis(false);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(!g_initOK) return;

   if(trans.type == TRADE_TRANSACTION_REQUEST)
     {
      if(request.symbol != _Symbol || request.magic != (ulong)InpMagic) return;
      if(request.action != TRADE_ACTION_DEAL || request.position != 0) return;
      for(int i = 0; i < SEND_RING; i++)
        {
         if(g_send[i].state == SEND_NONE) continue;
         if(StringLen(g_send[i].comment) == 0 || request.comment != g_send[i].comment) continue;
         if(result.retcode != 0) g_send[i].retcode = result.retcode;
         if(result.order != 0)   g_send[i].order   = result.order;
         if(result.deal  != 0)   g_send[i].deal    = result.deal;
         if((g_send[i].state == SEND_IN_FLIGHT || g_send[i].state == SEND_AMBIGUOUS) &&
            (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL || result.retcode == TRADE_RETCODE_PLACED))
           {
            g_send[i].state = SEND_DONE;
            g_send[i].resolvedAt = TimeCurrent();
           }
         break;
        }
      return;
     }

   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      if(trans.symbol != _Symbol) return;
      if(!HistoryDealSelect(trans.deal)) return;
      if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic) return;
      long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
        {
         ulong  order   = (ulong)HistoryDealGetInteger(trans.deal, DEAL_ORDER);
         string comment = HistoryDealGetString(trans.deal, DEAL_COMMENT);
         for(int i = 0; i < SEND_RING; i++)
           {
            if(g_send[i].state == SEND_NONE || g_send[i].state == SEND_FAILED) continue;
            bool byOrder   = (g_send[i].order != 0 && g_send[i].order == order);
            bool byComment = (StringLen(g_send[i].comment) > 0 && StringFind(comment, g_send[i].comment) >= 0);
            if(!byOrder && !byComment) continue;
            g_send[i].deal     = trans.deal;
            g_send[i].position = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
            if(g_send[i].state != SEND_DONE) { g_send[i].state = SEND_DONE; g_send[i].resolvedAt = TimeCurrent(); }
            break;
           }
        }
      else
        {
         double pl = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_SWAP) + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
         string cmt = HistoryDealGetString(trans.deal, DEAL_COMMENT);
         bool flipExit = (StringFind(cmt, "flip") >= 0 || StringFind(cmt, "FLIP") >= 0);
         if(pl < 0.0)
           {
            g_lastLossTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
            // v1.15: cooldown after ANY loss including flip-whipsaw (was: flip exits skipped cooldown)
            if(InpCooldownBarsAfterLoss > 0)
              {
               g_bypassLossCooldown = false;
               g_lossCooldownBarsLeft = InpCooldownBarsAfterLoss;
               datetime bar0 = iTime(_Symbol, g_tf, 0);
               g_lossCooldownUntilBar = bar0 + (datetime)(InpCooldownBarsAfterLoss * PeriodSeconds(g_tf));
               LogMsg(StringFormat("Loss cooldown %d %s bars (flipExit=%s pl=%.2f)", InpCooldownBarsAfterLoss, TFStr(g_tf), flipExit ? "Y" : "N", pl), true);
              }
           }
         // Only a profitable flip-exit may arm immediate reverse; losing flips must cool down
         if(flipExit && pl >= 0.0) g_bypassLossCooldown = true;
         else if(flipExit && pl < 0.0) { g_bypassLossCooldown = false; g_flipEnterNow = false; }
        }
      g_statsDirty = true;
     }
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(StringFind(sparam, g_prefix) != 0) return;
   string btn = StringSubstr(sparam, StringLen(g_prefix));

   if(btn == "btnPause")
     {
      if(g_halted)
        {
         g_halted = false; g_haltReason = "";
         g_equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
         if(!MQLInfoInteger(MQL_TESTER)) GlobalVariableSet(g_gvPeakName, g_equityPeak);
         g_paused = false;
         LogMsg("Manual RESUME after halt (equity peak reset)", true);
        }
      else
        {
         g_paused = !g_paused;
         LogMsg(g_paused ? "Manual PAUSE" : "Manual RESUME", true);
        }
     }
   else if(btn == "btnClose") { LogMsg("Manual CLOSE ALL", true); CloseAllOwn("manual"); }
   else if(btn == "btnUni")   { g_engOn[ENG_UNICORN] = !g_engOn[ENG_UNICORN]; }
   else if(btn == "btnKil")   { g_engOn[ENG_KILLER]  = !g_engOn[ENG_KILLER];  }
   else if(btn == "btnScp")   { g_engOn[ENG_SCALP]   = !g_engOn[ENG_SCALP];   }
   else if(btn == "btnBook")  { g_engOn[ENG_BOOK]    = !g_engOn[ENG_BOOK];    }

   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   DrawDash();
  }
//+------------------------------------------------------------------+
