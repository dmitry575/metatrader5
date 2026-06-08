# Barishtoltz Channels Deep4

An MQL5 indicator that automatically draws sliding price channels based on Viktor Barishtoltz's algorithm.

## Overview

The indicator detects local extremes (highs and lows) and builds channels using three consecutive pivot points. The base line connects the first and third extremes of the same type; the parallel line passes through the middle extreme of the opposite type and is guaranteed to be strictly parallel (using MQL5 `OBJ_CHANNEL`).

## How it works

1. **Extreme detection** — scans all bars for local minima/maxima confirmed by `ExtrBars` bars on each side (default: 3).
2. **Channel construction** — three consecutive extremes (e.g. Low→High→Low or High→Low→High) form one channel. The baseline goes through p1→p3, the parallel goes through p2.
3. **Signals** — a true cross occurs when the last completed bar's low touches the lower boundary AND closes above it (Buy), or its high touches the upper boundary AND closes below it (Sell).
4. **Dynamic levels** — take-profit (opposite channel boundary) and stop-loss are recalculated on every new bar as the channel extends.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ExtrBars` | `int` | 3 | Bars to confirm an extreme |
| `StopLossPts` | `int` | 100 | Stop loss in points |
| `ShowPrevChan` | `bool` | true | Show previous channel |
| `ChanColor` | `color` | clrDodgerBlue | Active channel color |
| `PrevColor` | `color` | clrDarkGray | Previous channel color |
| `ShowMarks` | `bool` | true | Show entry/exit/SL marks |
| `BuyClr` | `color` | clrLime | Buy mark color |
| `SellClr` | `color` | clrRed | Sell mark color |
| `ExitClr` | `color` | clrGold | Take-profit line color |
| `SLClr` | `color` | clrTomato | Stop-loss line color |

## Chart objects

| Object | Type | Description |
|--------|------|-------------|
| `BCh_CL` | `OBJ_CHANNEL` | Current channel (visible) |
| `BCh_CP` | `OBJ_CHANNEL` | Previous channel (visible, if enabled) |
| `BCh_BL` | `OBJ_TREND` | Base line for EA (hidden, `clrNONE`) |
| `BCh_PL` | `OBJ_TREND` | Parallel line for EA (hidden, `clrNONE`) |
| `BCh_E` | `OBJ_ARROW` | Entry signal mark |
| `BCh_X` | `OBJ_TREND` | Take-profit level (opposite boundary) |
| `BCh_S` | `OBJ_TREND` | Stop-loss level |
| `BCh_TSL` | `OBJ_ARROW` | Stop-loss arrow |
| `BCh_M1-3` | `OBJ_ARROW` | Extreme markers |

## EA integration

The hidden trend lines `BCh_BL` and `BCh_PL` exist solely for the companion Expert Advisor (`Barishtoltz_Channels_Deep4_EA.mq5`) to read channel geometry — slope, anchor points, and current boundary levels — without any visual clutter.

## Requirements

- MetaTrader 5 (build 2000+)
- No external dependencies
