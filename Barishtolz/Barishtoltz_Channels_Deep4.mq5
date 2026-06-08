//+------------------------------------------------------------------+
//|                                  Barishtoltz_Channels_deep4.mq5  |
//|                                      Based on V. Barishtoltz     |
//+------------------------------------------------------------------+
#property copyright "Barishtoltz Channel Deep4"
#property version   "1.08"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

//--- input parameters
input int     ExtrBars       = 3;        // Bars to confirm extreme (new extreme after N candles)
input int     StopLossPts    = 100;      // Stop loss in points
input bool    ShowPrevChan   = true;     // Show previous channel
input color   ChanColor      = clrDodgerBlue;
input color   PrevColor      = clrDarkGray;
input bool    ShowMarks      = true;     // Show entry/exit/SL marks
input color   BuyClr         = clrLime;
input color   SellClr        = clrRed;
input color   ExitClr        = clrGold;
input color   SLClr          = clrTomato;

//--- structures
struct SPoint {
   datetime  time;
   double    price;
   bool      is_high;  // true=peak, false=valley
};

string _pfx    = "BCh_";
datetime _lastBar = 0;

//+------------------------------------------------------------------+
int OnInit() {
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int) {
   ObjectsDeleteAll(0, _pfx);
   ChartRedraw();
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {

   if(time[rates_total - 1] == _lastBar)
      return rates_total;
   _lastBar = time[rates_total - 1];

   ObjectsDeleteAll(0, _pfx);

   SPoint pts[];
   FindPivots(rates_total, high, low, time, pts);

   int n = ArraySize(pts);
   if(n >= 3) {
      DrawChan(pts, n - 3, n - 2, n - 1, ChanColor, "L", time[rates_total - 1]);
      if(ShowPrevChan && n >= 5)
         DrawChan(pts, n - 5, n - 4, n - 3, PrevColor, "P");
   }

   ChartRedraw();
   return rates_total;
}

//+------------------------------------------------------------------+
void FindPivots(int total, const double &h[], const double &l[],
                const datetime &t[], SPoint &pts[]) {
   ArrayResize(pts, 0);

   for(int i = ExtrBars; i < total - ExtrBars; i++) {
      bool isHigh = true, isLow = true;

      for(int j = 1; j <= ExtrBars; j++) {
         if(h[i] <= h[i - j] || h[i] <= h[i + j]) isHigh = false;
         if(l[i] >= l[i - j] || l[i] >= l[i + j]) isLow  = false;
         if(!isHigh && !isLow) break;
      }

      if(isHigh == isLow) continue;

      SPoint p;
      p.time   = t[i];
      p.price  = isHigh ? h[i] : l[i];
      p.is_high = isHigh;

      int sz = ArraySize(pts);
      if(sz == 0)               { ArrayResize(pts, 1);   pts[0] = p; }
      else if(pts[sz-1].is_high != p.is_high) {
                                 ArrayResize(pts, sz+1); pts[sz] = p; }
      else if(( p.is_high && p.price > pts[sz-1].price) ||
              (!p.is_high && p.price < pts[sz-1].price)) pts[sz-1] = p;
   }
}

//+------------------------------------------------------------------+
void DrawChan(const SPoint &pts[], int i1, int i2, int i3, color clr, string s, datetime currentTime = 0) {
   if(pts[i1].is_high == pts[i2].is_high || pts[i2].is_high == pts[i3].is_high) return;
   if(pts[i3].time <= pts[i1].time) return;

   double slope = (pts[i3].price - pts[i1].price) / (double)(pts[i3].time - pts[i1].time);
   double ppar1 = pts[i2].price + slope * (double)(pts[i1].time - pts[i2].time);
   double ppar3 = pts[i2].price + slope * (double)(pts[i3].time - pts[i2].time);

   // visual: OBJ_CHANNEL guarantees parallel lines
   ObjectCreate(0, _pfx + "C" + s, OBJ_CHANNEL, 0,
                pts[i1].time, pts[i1].price,
                pts[i3].time, pts[i3].price,
                pts[i2].time, pts[i2].price);
   ObjectSetInteger(0, _pfx + "C" + s, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, _pfx + "C" + s, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, _pfx + "C" + s, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, _pfx + "C" + s, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, _pfx + "C" + s, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, _pfx + "C" + s, OBJPROP_BACK, false);

   // hidden OBJ_TREND lines for EA (clrNONE — invisible, data readable)
   ObjectCreate(0, _pfx + "B" + s, OBJ_TREND, 0,
                pts[i1].time, pts[i1].price,
                pts[i3].time, pts[i3].price);
   ObjCfg(_pfx + "B" + s, clrNONE);

   ObjectCreate(0, _pfx + "P" + s, OBJ_TREND, 0,
                pts[i1].time, ppar1,
                pts[i3].time, ppar3);
   ObjCfg(_pfx + "P" + s, clrNONE);

   // marks only on the last (active) channel
   if(s == "L") {
      DrawArrow(_pfx + "M1", pts[i1].time, pts[i1].price, 241, clr);
      DrawArrow(_pfx + "M2", pts[i2].time, pts[i2].price, 241, clr);
      DrawArrow(_pfx + "M3", pts[i3].time, pts[i3].price, 241, clr);

      if(ShowMarks)
         Signals(pts[i1], pts[i2], pts[i3], slope, currentTime);
   }
}

//+------------------------------------------------------------------+
void Signals(const SPoint &p1, const SPoint &p2, const SPoint &p3, double slope, datetime currentTime) {
   double baseAt = p1.price + slope * (double)(currentTime - p1.time);
   double parAt  = p2.price + slope * (double)(currentTime - p2.time);
   double upper  = MathMax(baseAt, parAt);
   double lower  = MathMin(baseAt, parAt);
   double entryExit, slPrice;

   if(!p3.is_high) {
      // Buy signal: last extreme is low (bottom of channel)
      DrawArrow(_pfx + "E", p3.time, p3.price, 233, BuyClr);

      entryExit = upper;                     // exit at opposite boundary
      slPrice   = lower - StopLossPts * _Point;

      DrawArrow(_pfx + "TSL", p3.time, slPrice, 78, SLClr);
   } else {
      // Sell signal: last extreme is high (top of channel)
      DrawArrow(_pfx + "E", p3.time, p3.price, 234, SellClr);

      entryExit = lower;                     // exit at opposite boundary
      slPrice   = upper + StopLossPts * _Point;

      DrawArrow(_pfx + "TSL", p3.time, slPrice, 78, SLClr);
   }

   // exit level (horizontal ray from current bar)
   ObjectCreate(0, _pfx + "X", OBJ_TREND, 0, currentTime, entryExit,
                currentTime + 86400 * 365, entryExit);
   ObjCfg(_pfx + "X", ExitClr, STYLE_DOT, 1);

   // stop-loss level (horizontal ray from current bar)
   ObjectCreate(0, _pfx + "S", OBJ_TREND, 0, currentTime, slPrice,
                currentTime + 86400 * 365, slPrice);
   ObjCfg(_pfx + "S", SLClr, STYLE_DASH, 1);
}

//+------------------------------------------------------------------+
void ObjCfg(string n, color c, int sty = STYLE_SOLID, int w = 2) {
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
   ObjectSetInteger(0, n, OBJPROP_STYLE, sty);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, w);
   ObjectSetInteger(0, n, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
void DrawArrow(string n, datetime t, double p, int code, color c) {
   ObjectCreate(0, n, OBJ_ARROW, 0, t, p);
   ObjectSetInteger(0, n, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
}
//+------------------------------------------------------------------+
