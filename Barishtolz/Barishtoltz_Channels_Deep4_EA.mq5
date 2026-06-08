//+------------------------------------------------------------------+
//|                                   Barishtoltz_Channels_Deep4_EA.mq5 |
//|                                      Uses external indicator        |
//+------------------------------------------------------------------+
#property copyright "Barishtoltz EA Deep4"
#property version   "1.05"
#property description "EA uses Barishtoltz_Channels_Deep4 indicator"

#include <Trade/Trade.mqh>

//--- input parameters
input int     PendDistPts    = 10;       // Pending order distance from current price
input int     StopLossPts    = 100;      // Stop loss in points
input int     TrailPts       = 75;       // Trailing stop distance (points)
input double  RiskPercent    = 1.0;      // Risk % of balance per trade
input int     MaxLosses      = 3;        // Consecutive losses before pause
input int     Magic          = 202406;   // EA magic number
input bool    PrintLog       = true;     // Enable logging

//--- globals
CTrade      _trade;
string      _indPrfx = "BCh_";           // indicator object prefix
string      _indName = "Barishtoltz_Channels_Deep4";
datetime    _lastBar  = 0;
int         _lossStreak = 0;
datetime    _pauseUntil = 0;
ulong       _lastTicket = 0;
int         _indHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit() {
   _trade.SetExpertMagicNumber(Magic);
   _trade.SetDeviationInPoints(10);

   _indHandle = iCustom(_Symbol, _Period, _indName);
   if(_indHandle == INVALID_HANDLE) {
      Print("Indicator ", _indName, " not found. Compile it in MetaEditor first.");
      return INIT_FAILED;
   }

   if(!ChartIndicatorAdd(0, 0, _indHandle)) {
      Print("Failed to add indicator to chart");
      return INIT_FAILED;
   }

   if(PrintLog) Print("Barishtoltz EA v1.05 loaded, indicator: ", _indName);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int) {
   Comment("");
   if(_indHandle != INVALID_HANDLE)
      IndicatorRelease(_indHandle);
}

//+------------------------------------------------------------------+
void OnTick() {
   if(TimeCurrent() < _pauseUntil) return;
   if(_pauseUntil > 0 && TimeCurrent() >= _pauseUntil) {
      _pauseUntil = 0;
      _lossStreak = 0;
      if(PrintLog) Print("Pause ended");
   }

   string pos = PositionSelect(_Symbol) ? "POSITION" : (HasOrder() ? "PENDING" : "flat");
   Comment("Barishtoltz EA v1.05 | Magic: ", Magic,
           "\nState: ", pos,
           "\nLoss streak: ", _lossStreak, "/", MaxLosses,
           "\nPause: ", _pauseUntil > 0 ? "YES" : "no");

   if(PositionSelect(_Symbol)) {
      ManageTrail();
      return;
   }

   datetime barTime = iTime(_Symbol, _Period, 1);
   if(barTime == _lastBar) return;
   _lastBar = barTime;

   CheckCloseResult();
   CheckEntry();
}

//+------------------------------------------------------------------+
void CheckEntry() {
   if(HasOrder()) return;

   double b1, b2, p1, p2;
   datetime bT1, bT2, pT1, pT2;

   if(!GetLine(_indPrfx + "BL", bT1, b1, bT2, b2)) return;
   if(!GetLine(_indPrfx + "PL", pT1, p1, pT2, p2)) return;

   if(bT2 <= bT1) return;
   double slope = (b2 - b1) / (double)(bT2 - bT1);

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, _Period, 0, 3, r) < 3) return;

   // r[1] = last completed bar
   datetime bt = r[1].time;

   double baseAt = b1 + slope * (double)(bt - bT1);
   double parAt  = p1 + slope * (double)(bt - pT1);
   double upper  = MathMax(baseAt, parAt);
   double lower  = MathMin(baseAt, parAt);

   int signal = 0;
   if(r[1].low <= lower && r[1].close > lower) signal = 1;
   else if(r[1].high >= upper && r[1].close < upper) signal = -1;
   else return;

   double lots = CalcLots();
   if(lots <= 0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(signal == 1) {
      double orderPrice = ask + PendDistPts * _Point;
      double sl = orderPrice - StopLossPts * _Point;
      double tp = upper;
      if(sl >= orderPrice || tp <= orderPrice) return;
      if(_trade.BuyStop(lots, orderPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "BCh Buy Stop")) {
         _lastTicket = _trade.ResultOrder();
         if(PrintLog) Print("BuyStop placed at ", orderPrice, " SL: ", sl, " TP: ", tp);
      }
   } else {
      double orderPrice = bid - PendDistPts * _Point;
      double sl = orderPrice + StopLossPts * _Point;
      double tp = lower;
      if(sl <= orderPrice || tp >= orderPrice) return;
      if(_trade.SellStop(lots, orderPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "BCh Sell Stop")) {
         _lastTicket = _trade.ResultOrder();
         if(PrintLog) Print("SellStop placed at ", orderPrice, " SL: ", sl, " TP: ", tp);
      }
   }
}

//+------------------------------------------------------------------+
bool GetLine(string name, datetime &t1, double &pr1, datetime &t2, double &pr2) {
   if(ObjectFind(0, name) < 0) return false;
   t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
   pr1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
   t2 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
   pr2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
   return true;
}

//+------------------------------------------------------------------+
bool HasOrder() {
   for(int i = 0; i < OrdersTotal(); i++) {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0) {
         if(OrderGetInteger(ORDER_MAGIC) == Magic &&
            OrderGetString(ORDER_SYMBOL) == _Symbol)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
void ManageTrail() {
   if(!PositionSelect(_Symbol)) return;
   double open  = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid - open >= TrailPts * _Point) {
         double newSL = bid - TrailPts * _Point;
         if(newSL > curSL)
            _trade.PositionModify(PositionGetInteger(POSITION_TICKET), newSL, curTP);
      }
   } else {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open - ask >= TrailPts * _Point) {
         double newSL = ask + TrailPts * _Point;
         if(newSL < curSL || curSL == 0)
            _trade.PositionModify(PositionGetInteger(POSITION_TICKET), newSL, curTP);
      }
   }
}

//+------------------------------------------------------------------+
void CheckCloseResult() {
   static ulong lastCloseTicket = 0;
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   if(total == 0) return;

   for(int i = total - 1; i >= 0; i--) {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != Magic) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      if(ticket == lastCloseTicket) break;

      lastCloseTicket = ticket;
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

      if(profit < 0) {
         _lossStreak++;
         if(PrintLog) Print("Loss #", _lossStreak);
         if(_lossStreak >= MaxLosses) {
            _pauseUntil = TimeCurrent() + 86400;
            if(PrintLog) Print("3 losses — pause 1 day");
         }
      } else if(profit > 0) _lossStreak = 0;
      break;
   }
}

//+------------------------------------------------------------------+
double CalcLots() {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue <= 0) return 0;

   double lots = riskMoney / (StopLossPts * tickValue);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(step > 0) lots = MathFloor(lots / step) * step;
   if(lots < min) lots = min;
   if(lots > max) lots = max;
   return lots;
}
//+------------------------------------------------------------------+
