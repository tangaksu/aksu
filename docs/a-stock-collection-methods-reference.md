# A股数据采集方法完整参考手册

> **文档说明**：按数据类型分类，整合三类采集方法：
> 1. **Web/搜索采集**（来自 `a-stock-analysis-pro/references/data-sources.md`）
> 2. **AKShare Python API**（来自 `docs/a-stock-data-sources-2026.md` 及官方文档）
> 3. **Adapter 封装方法**（来自 `akshare-stock/adapters/akshare_adapter.py`，已有多源容错）
>
> 最后更新：2026-06-29

---

## 目录

1. [数据源优先级总览](#1-数据源优先级总览)
2. [实时行情](#2-实时行情)
3. [历史K线](#3-历史k线)
4. [分时/分钟数据](#4-分时分钟数据)
5. [涨跌停池与连板](#5-涨跌停池与连板)
6. [资金流向](#6-资金流向)
7. [龙虎榜](#7-龙虎榜)
8. [融资融券](#8-融资融券)
9. [财务数据](#9-财务数据)
10. [重大公告与事件](#10-重大公告与事件)
11. [行业/板块/政策景气](#11-行业板块政策景气)
12. [技术指标](#12-技术指标)
13. [ST与退市专项](#13-st与退市专项)
14. [基础信息](#14-基础信息)
15. [北向资金（⚠️已停用）](#15-北向资金已停用)
16. [基金与可转债](#16-基金与可转债)
17. [期货与期权](#17-期货与期权)
18. [港股/美股](#18-港股美股)
19. [快速安装](#19-快速安装)

---

## 1. 数据源优先级总览

### Python 库优先级

| 库 | 推荐等级 | 认证 | 特点 |
|----|---------|------|------|
| **AKShare** | ⭐⭐⭐⭐⭐ 首选 | 免费免注册 | 覆盖最全，东财/新浪/同花顺多源聚合 |
| **BaoStock** | ⭐⭐⭐⭐ 历史数据 | 免费免注册 | 日/分钟K线历史，不提供实时 |
| **efinance** | ⭐⭐⭐ 轻量备源 | 免费免注册 | API极简，适合快速原型 |
| **finshare** | ⭐⭐⭐ 多源容错 | 免费免注册 | 内置自动多源切换 |
| **Tushare Pro** | ⭐⭐⭐⭐ 付费高质 | 注册+积分 | 数据质量高，财务/龙虎榜推荐 |
| **xtquant/miniQMT** | ⭐⭐⭐ 实时合规 | 需券商账户 | 无爬虫，交易所级实时Tick |
| **JoinQuant** | ⭐⭐⭐ 量化平台 | 注册，部分免费 | 2005年至今全品种历史 |

### Web 数据源可用性（2026）

| 来源 | 状态 | 说明 |
|------|------|------|
| 东方财富 `quote.eastmoney.com` | ⚠️ 反爬加强 | 高频限速，建议用 akshare |
| 新浪财经 `hq.sinajs.cn` | ✅ 仍可用 | 实时行情接口稳定 |
| 同花顺 `stockpage.10jqka.com.cn` | ⚠️ CAPTCHA 风险 | 直接抓取难，建议走库 |
| 腾讯财经 `gu.qq.com` | ⚠️ 频繁调整 | 接口结构多次变更 |
| 巨潮资讯 `cninfo.com.cn` | ✅ 官方权威 | 公告/财报原文最权威来源 |
| 上交所/深交所官网 | ✅ 官方 | akshare 已封装 |

---

## 2. 实时行情

> 对应 `a-stock-analysis-pro` 数据源 A。**价格数据权威性规则**：实时采集到的价格是唯一基准，搜索结果中出现的价格不得用于替换。

### Web/搜索采集方法

```
# 主力 Fetch（按优先级）
URL 1（沪市）：https://quote.eastmoney.com/sh{代码}.html
URL 1（深市）：https://quote.eastmoney.com/sz{代码}.html
URL 2：https://finance.sina.com.cn/realstock/company/{交易所}{代码}/nc.shtml
URL 3：https://gu.qq.com/{交易所}{代码}
URL 4：https://stockpage.10jqka.com.cn/{代码}/

# 搜索兜底（fetch 失败时）
搜索词 1："{股票名称} {代码} 今日收盘 {YYYY年M月D日}"
搜索词 2："{股票名称} {代码} 股价 {YYYY年M月D日} 证券之星"
```

**提取字段**：今日价格、涨跌幅、昨收、开盘、今日区间、52周区间、成交量、3月均量、市值、总股本、PE、PB、EV/EBITDA、ROE、ROA、毛利率、EPS、每股净资产、股息率、RSI(14)、技术信号（日/周/月）

**必算衍生指标**：
```
52周定位% = (今日价 - 52周低) / (52周高 - 52周低) × 100%
量比 = 今日成交量 / 3个月日均成交量
较发行价涨跌% = (今日价 - 发行价) / 发行价 × 100%
```

### AKShare API

```python
import akshare as ak

# 全市场 A 股实时行情（最全）
df = ak.stock_zh_a_spot_em()

# 大盘指数实时
df = ak.stock_zh_index_spot_sina()
df = ak.stock_zh_index_spot_em()          # 备选

# 个股实时信息
df = ak.stock_individual_info_em(symbol="600519")
```

### Adapter 封装（含自动容错）

```python
from adapters.akshare_adapter import AkshareAdapter
adapter = AkshareAdapter()

# 指数行情（新浪→东财自动降级）
result = adapter.index_spot(top_n=300)

# 个股综合数据（实时+资金流+财务+涨停统计+研报）
result = adapter.stock_overview(symbol="600519")
```

---

## 3. 历史K线

### Web/搜索采集方法

```
# 东方财富历史 K 线（推荐，akshare 封装来源）
URL：https://push2his.eastmoney.com/api/qt/stock/kline/get?secid={市场}.{代码}&fields1=f1,f2,f3,f4&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61&klt=101&fqt=1&beg={YYYYMMDD}&end={YYYYMMDD}
```

### AKShare API

```python
import akshare as ak

# 日/周/月 K 线（推荐，东财来源）
df = ak.stock_zh_a_hist(
    symbol="600519",
    period="daily",        # daily / weekly / monthly
    start_date="20240101",
    end_date="20261231",
    adjust="qfq"           # qfq 前复权 / hfq 后复权 / "" 不复权
)
```

### BaoStock（历史数据专用）

```python
import baostock as bs
import pandas as pd

lg = bs.login()
rs = bs.query_history_k_data_plus(
    "sh.600519",
    "date,open,high,low,close,volume,amount,adjustflag,turn,tradestatus,pctChg",
    start_date='2024-01-01', end_date='2026-06-01',
    frequency="d",     # d 日线 / w 周线 / m 月线
    adjustflag="3"     # 3 后复权 / 2 前复权 / 1 不复权
)
data_list = []
while (rs.error_code == '0') & rs.next():
    data_list.append(rs.get_row_data())
result = pd.DataFrame(data_list, columns=rs.fields)
bs.logout()
```

### efinance（轻量备源）

```python
import efinance as ef

df = ef.stock.get_quote_history(
    '600519',
    beg='20250101', end='20261231',
    klt=101   # 1/5/15/30/60=分钟, 101=日, 102=周, 103=月
)
```

### Adapter 封装

```python
result = adapter.stock_kline(
    symbol="600519",
    period="daily",        # daily / weekly / monthly
    start_date="20240101",
    end_date="20261231",
    top_n=60
)
```

---

## 4. 分时/分钟数据

### AKShare API

```python
import akshare as ak

# 分钟 K 线（1/5/15/30/60 分钟）
df = ak.stock_zh_a_minute(symbol="600519", period="5", adjust="")

# 今日分时（东财 Tick）
df = ak.stock_intraday_em(symbol="600519")
```

### Adapter 封装（分钟→Tick 自动降级）

```python
result = adapter.stock_intraday(
    symbol="600519",
    period="5",    # "1"/"5"/"15"/"30"/"60"
    top_n=30
)
# 主: stock_zh_a_minute → 备: stock_intraday_em
```

---

## 5. 涨跌停池与连板

### 搜索采集方法

```
搜索词（龙头效应/连板梯队）：
"今日涨停 连板 龙头 {YYYY年M月D日} 东方财富"
"炸板率 涨停板 {YYYY年M月D日}"
```

### AKShare API

```python
import akshare as ak

trade_date = "20260628"

# 涨停池（全部）
df = ak.stock_zt_pool_em(date=trade_date)

# 跌停池
df = ak.stock_dt_pool_em(date=trade_date)

# 连板梯队（炸板情况）
df = ak.stock_zt_pool_dtgc_em(date=trade_date)

# 强势股池（次新/炸板/涨停回调）
df = ak.stock_zt_pool_strong_em(date=trade_date)

# 跌停回封池
df = ak.stock_zt_pool_zbgc_em(date=trade_date)
```

### Adapter 封装（涨跌停一次获取）

```python
result = adapter.limit_pool(date="20260628", top_n=50)
# 返回 up_count / down_count / up_items / down_items
# 自动尝试 stock_zt_pool_dtgc_em → stock_dt_pool_em
```

---

## 6. 资金流向

> 对应 `a-stock-analysis-pro` 数据源 B（B1 资金流向）。

### Web/搜索采集方法

```
# B1：个股资金流向
搜索词："{股票名称} {代码} {M月D日} 主力资金"
来源：证券之星 stock.stockstar.com
提取：主力/游资/散户净流入或流出、换手率、成交量、成交额
```

**换手率解读**：
```
< 1%   成交清淡    1~3%  正常低活跃    3~8%   中度活跃
8~15%  高度活跃    >15%  极度活跃（警惕高位出货）
```

### AKShare API

```python
import akshare as ak

# 个股资金流（近N日，按天）
df = ak.stock_individual_fund_flow(stock="600519", market="sh")
# market: sh=沪市 / sz=深市 / bj=北交所

# 全市场大盘资金流
df = ak.stock_market_fund_flow()

# 行业板块资金流排行
df = ak.stock_sector_fund_flow_rank(indicator="今日", sector_type="行业资金流")
# indicator: 今日 / 5日 / 10日

# 概念板块资金流
df = ak.stock_sector_fund_flow_rank(indicator="今日", sector_type="概念资金流")
```

### Adapter 封装

```python
# 个股资金流
result = adapter.money_flow(symbol="600519", top_n=30)

# 大盘资金流（多候选接口自动容错）
result = adapter.market_money_flow(top_n=20)
# 候选顺序: stock_market_fund_flow → stock_hsgt_fund_flow_summary_em → stock_hsgt_hist_em

# 行业/板块资金流（多候选接口自动容错）
result = adapter.sector_money_flow(top_n=20)
# 候选顺序: stock_sector_fund_flow_rank → stock_fund_flow_industry → stock_sector_fund_flow_summary
```

---

## 7. 龙虎榜

> 对应 `a-stock-analysis-pro` 数据源 B（B2 龙虎榜）。

### 搜索采集方法

```
搜索词："{股票名称} 龙虎榜 {月份}"
来源：新浪财经
提取：机构/游资席位净买入或净卖出、上榜原因
```

### AKShare API

```python
import akshare as ak

# 龙虎榜明细（东财，推荐）
df = ak.stock_lhb_detail_em(start_date="20260601", end_date="20260628")

# 龙虎榜个股统计（新浪备选）
df = ak.stock_lhb_ggtj_sina(symbol="5")   # 5=近5日, 10=近10日, 30=近30日
```

### Adapter 封装

```python
result = adapter.margin_lhb(symbol="600519", date="20260628", top_n=10)
# 同时返回 margin_items（融资融券）和 lhb_items（龙虎榜）
# 候选: stock_lhb_detail_em → stock_lhb_ggtj_sina
```

---

## 8. 融资融券

> 对应 `a-stock-analysis-pro` 数据源 B（B3 融资融券）。

### 搜索采集方法

```
搜索词："{股票名称} 融资余额 {月份}"
提取：融资余额（亿元）、融资净买入额、融资余额/流通市值比
警戒线：融资余额/流通市值 > 5% = 杠杆风险偏高
```

### AKShare API

```python
import akshare as ak

# 上交所融资融券明细
df = ak.stock_margin_detail_sse(date="20260628")

# 深交所融资融券明细
df = ak.stock_margin_detail_szse(date="20260628")

# 全市场融资融券汇总
df = ak.stock_margin_detail_em(date="20260628")

# 两融标的信息
df = ak.stock_margin_underlying_info_sse()   # 沪市两融标的
df = ak.stock_margin_underlying_info_szse()  # 深市两融标的
```

---

## 9. 财务数据

> 对应 `a-stock-analysis-pro` 数据源 C（C1~C3）。

### 搜索采集方法

```
# C1：财报核心摘要
搜索词 1："{股票名称} {代码} 三季报 营收 净利润 同比 {YYYY年}"
搜索词 2："{股票名称} {代码} 年报 营收 净利润 {YYYY年}"

# C2：业绩预告/快报
搜索词："{股票名称} 业绩预告 {YYYY年}"
搜索词："{股票名称} 2025年度 归母净利润 预计"

# C3：主营业务结构
搜索词："{股票名称} 主营业务 营收结构 占比 {YYYY年}"
```

**必须提取的8个财务字段**：
1. 营业收入（本期/同比%）
2. 归母净利润（本期/同比%）← 最重要
3. 扣非净利润（本期/同比%）
4. 非经常性损益（差值>净利20%需解释）
5. 单季度营收和净利润（判断加速/减速趋势）
6. 毛利率（议价能力和成本压力）
7. 资产负债率（<40%=安全，40~60%=一般，>60%=偏高）
8. 财务费用（负值=净存款利息，现金充裕）

### AKShare API

```python
import akshare as ak

# 同花顺财务摘要（推荐）
df = ak.stock_financial_abstract_ths(symbol="600519", indicator="按报告期")
# indicator: 按报告期 / 按单季度 / 按年度

# 利润表（东财）
df = ak.stock_profit_sheet_by_report_em(symbol="600519")

# 资产负债表（东财）
df = ak.stock_balance_sheet_by_report_em(symbol="600519")

# 现金流量表（东财）
df = ak.stock_cash_flow_sheet_by_report_em(symbol="600519")

# 财务分析指标（综合）
df = ak.stock_financial_analysis_indicator(symbol="600519")
```

### Tushare Pro（质量最高，需积分≥2000）

```python
import tushare as ts
ts.set_token('your_token_here')
pro = ts.pro_api()

df = pro.balancesheet(ts_code='600519.SH', period='20251231')
df = pro.income(ts_code='600519.SH', period='20251231')
df = pro.cashflow(ts_code='600519.SH', period='20251231')
```

### Adapter 封装

```python
result = adapter.fundamental(symbol="600519", top_n=20)
# 候选: stock_financial_abstract_ths → stock_financial_analysis_indicator
# 返回 latest（最新期）和 items（历史序列）
```

---

## 10. 重大公告与事件

> 对应 `a-stock-analysis-pro` 数据源 D（D1~D4）。

### 搜索采集方法

```
D1（合同/订单/中标）："{股票名称} 中标 合同 订单 {YYYY年}"
D2（股东变动）："{股票名称} 大股东 减持 增持 {YYYY年}"
D3（监管处罚/立案）："{股票名称} 处罚 违规 立案 证监局 {YYYY年}"
D4（产能/技术进展）："{股票名称} 产能 投产 复产 技术突破 {YYYY年}"
```

### AKShare API（巨潮资讯，官方权威）

```python
import akshare as ak

# 个股公告（巨潮资讯）
df = ak.stock_notice_report(symbol="600519", date="20260601")

# 增减持公告
df = ak.stock_hold_num_cninfo(symbol="600519")

# 业绩预告
df = ak.stock_profit_forecast(symbol="600519", type="预告")

# 大宗交易
df = ak.stock_dzjy_mrmx_ths(symbol="600519")    # 同花顺
df = ak.stock_dzjy_detail_ths(symbol="600519")
```

---

## 11. 行业/板块/政策景气

> 对应 `a-stock-analysis-pro` 数据源 E（E1~E3）。

### 搜索采集方法

```
# E1：产品价格（按主业替换关键词）
盐化工：  "元明粉 工业盐 价格 {YYYY年} 最新"
光纤：    "光纤 G652 价格 涨跌 供需缺口 {YYYY年}"
白酒：    "飞天茅台 批价 渠道价 {YYYY年}"
铜/铝材： "伦铜 铝价 {YYYY年} 最新"
光伏：    "硅料 组件 价格 {YYYY年}"

# E2：行业政策
搜索词："{行业关键词} 政策 补贴 规划 {YYYY年}"

# E3：供需格局
搜索词："{行业关键词} 产能 供给 需求 格局 {YYYY年}"
```

### AKShare API

```python
import akshare as ak

# 行业板块列表及实时涨跌
df = ak.stock_board_industry_name_em()

# 行业板块历史行情
df = ak.stock_board_industry_hist_em(symbol="半导体", period="daily",
                                      start_date="20260101", end_date="20261231")

# 行业板块成分股
df = ak.stock_board_industry_cons_em(symbol="半导体")

# 概念板块列表
df = ak.stock_board_concept_name_em()

# 概念板块成分股
df = ak.stock_board_concept_cons_em(symbol="CPO概念")

# 中证指数成分股
df = ak.index_stock_cons(symbol="000300")   # 沪深300

# 宏观数据（CPI/PPI/PMI等）
df = ak.macro_china_cpi_monthly()
df = ak.macro_china_ppi_monthly()
df = ak.macro_china_pmi_monthly()
```

### Adapter 封装

```python
# 行业板块涨跌分析（含 top_gain / top_drop）
result = adapter.sector_analysis(sector_type="industry", top_n=10)

# 概念板块
result = adapter.sector_analysis(sector_type="concept", top_n=10)

# 板块资金流
result = adapter.sector_money_flow(top_n=20)
```

---

## 12. 技术指标

> 对应 `a-stock-analysis-pro` 数据源 H。

### ⚠️ 2026年推荐方案：本地计算

**直接抓取同花顺/东财技术指标已受限（反爬增强）。2026年最稳定方案为拉取历史K线后本地计算。**

### 搜索采集方法（作为补充/回退）

```
来源 1：https://stockpage.10jqka.com.cn/{代码}/
来源 2：https://quote.eastmoney.com/{交易所}{代码}.html
搜索词："{股票名称} {代码} MACD KDJ RSI 技术指标 {YYYY年M月D日}"

提取字段：
- 各周期信号：30分/1小时/日线/周线/月线（强力买入/买入/中性/卖出/强力卖出）
- RSI(14)：>70超买 | 50~70偏强 | 45~55中性 | 30~45偏弱 | <30超卖
- MACD（DIF/DEA/柱状线）、KDJ（K/D/J值）、BOLL（上轨/中轨/下轨）
```

### 本地计算（推荐）

```python
import akshare as ak
import pandas_ta as ta   # pip install pandas-ta
# 或 import talib        # pip install ta-lib（需编译C库）

# Step 1：获取历史 K 线
df = ak.stock_zh_a_hist(symbol="600519", period="daily",
                         start_date="20250101", end_date="20261231", adjust="qfq")
df = df.rename(columns={"开盘": "open", "收盘": "close", "最高": "high",
                          "最低": "low", "成交量": "volume"})

# Step 2：本地计算指标
df.ta.macd(append=True)          # MACD / DIF / DEA
df.ta.rsi(length=14, append=True) # RSI(14)
df.ta.kdj(append=True)           # KDJ
df.ta.bbands(append=True)        # BOLL 布林带
df.ta.sma(length=5, append=True)  # MA5
df.ta.sma(length=10, append=True) # MA10
df.ta.sma(length=20, append=True) # MA20
df.ta.sma(length=60, append=True) # MA60
```

---

## 13. ST与退市专项

> 对应 `a-stock-analysis-pro` 数据源 F（仅 ST 股执行）。

### 搜索采集方法

```
F1："{公司名称} ST 处罚决定书 摘帽条件 {YYYY年}"
F2："{公司名称} 年报 追溯调整 财务重述"
F3："{公司名称} 退市 强制退市 重大违法"
```

**关键判断点**：
1. 处罚文书类型：「事先告知书」= 尚未定案；「正式决定书」= 12个月倒计时
2. 摘帽最短路径：正式决定书 → 满12个月 + 追溯调整年报经审计确认 → 申请撤销
3. 退市风险：财务造假金额/净资产>50%，或/营业收入>50%，或连续多年造假
4. 可转债：ST后暂停转股；正股价持续低于转股价70%达30交易日触发回售

### AKShare API

```python
import akshare as ak

# 风险警示股列表（ST/*ST）
df = ak.stock_info_a_code_name()   # 全市场代码名称（含ST前缀）

# 退市股列表
df = ak.stock_zh_a_delisted()

# 股票更名历史（摘帽/戴帽记录）
df = ak.stock_info_change_name(symbol="*ST某某")
```

---

## 14. 基础信息

> 对应 `a-stock-analysis-pro` 数据源 G（首次分析必做）。

### 搜索采集方法

```
G1："{股票名称} {代码} 发行价 上市日期 总股本"
G2："{股票名称} 控股股东 实际控制人 持股比例"
G3："{股票名称} 股东户数 {最近日期}"

提取：上市日期、IPO发行价、控股股东名称和持股比例、
      实际控制人类型、最新股东户数及增减
```

### AKShare API

```python
import akshare as ak

# 个股基础信息（东财）
df = ak.stock_individual_info_em(symbol="600519")
# 包含：股票简称、上市日期、总股本、流通股本、所属行业、发行价等

# 十大股东
df = ak.stock_main_stock_holder(symbol="600519")

# 十大流通股东
df = ak.stock_circulating_holder(symbol="600519")

# 股东户数
df = ak.stock_hold_num_cninfo(symbol="600519")

# 全市场股票列表
df = ak.stock_info_a_code_name()

# 研究报告（东财）
df = ak.stock_research_report_em(symbol="600519")
```

### Adapter 封装

```python
# 研究报告
result = adapter.research_report(symbol="600519", top_n=10)

# 选股（热门/板块成分+研报评级综合）
result = adapter.stock_pick(top_n=5, sector="半导体")
```

---

## 15. 北向资金（⚠️已停用）

> **重要**：北向资金（沪深港通）**实时/日频净流入数据已于 2024-08-19 正式停用**，所有相关接口均返回错误。

| 数据类型 | 状态 |
|---------|------|
| 盘中/日频净流入 | ❌ **已停用** |
| 买卖方向拆分 | ❌ **已停用** |
| T+1 成交总额 | ✅ 仍可用（无买卖拆分） |
| 十大活跃股 | ✅ 仍可用 |
| 季度持仓（QFII） | ✅ 仍可用（约3个月延迟） |

**对 Skill 的影响**：移除所有依赖 `stock_hsgt_north_net_flow_in()` 等实时接口的功能；情绪指标改为成交量、涨跌停家数等替代指标。

---

## 16. 基金与可转债

### AKShare API

```python
import akshare as ak

# ETF 实时行情
df = ak.fund_etf_spot_em()

# ETF 历史行情
df = ak.fund_etf_hist_em(symbol="159915", period="daily",
                          start_date="20260101", end_date="20261231")

# 开放式基金净值（日频）
df = ak.fund_open_fund_daily_em()

# 基金详细信息
df = ak.fund_open_fund_info_em(fund="000001", indicator="单位净值走势")

# 可转债实时行情
df = ak.bond_zh_cov()

# 可转债历史行情
df = ak.bond_zh_hs_cov_daily(symbol="sh113527")
```

### Adapter 封装

```python
# 基金（ETF）
result = adapter.fund_bond(scope="fund", symbol="159915", top_n=10)
# 候选: fund_etf_hist_em → fund_etf_spot_em → fund_open_fund_daily_em

# 可转债
result = adapter.fund_bond(scope="bond", symbol="sh113527", top_n=10)
# 候选: bond_zh_hs_cov_spot → bond_zh_hs_cov_daily
```

---

## 17. 期货与期权

### AKShare API

```python
import akshare as ak

# 期货主力合约（新浪，推荐）
df = ak.futures_display_main_sina()

# 个别期货品种行情
df = ak.futures_main_sina(symbol="IF0")   # IF0 沪深300股指期货主力

# 期权行情（东财）
df = ak.option_current_em()

# 沪深300 ETF 期权（中金所）
df = ak.option_cffex_hs300_spot_sina()

# 50ETF 期权
df = ak.option_finance_board(symbol="华夏上证50ETF期权")
```

### Adapter 封装

```python
# 期货
result = adapter.derivatives(scope="futures", symbol="IF0", top_n=10)
# 候选: futures_display_main_sina → match_main_contract → futures_main_sina

# 期权
result = adapter.derivatives(scope="options", top_n=10)
# 候选: option_current_em → option_cffex_hs300_spot_sina → option_finance_board
```

---

## 18. 港股/美股

### AKShare API

```python
import akshare as ak

# 港股实时行情
df = ak.stock_hk_spot_em()

# 美股实时行情
df = ak.stock_us_spot_em()
```

### Adapter 封装

```python
# 港股
result = adapter.hk_us_market(market="hk", top_n=10)

# 美股
result = adapter.hk_us_market(market="us", symbol="NVDA", top_n=10)
```

---

## 19. 快速安装

```bash
# 必装（主数据源）
pip install akshare --upgrade

# 建议安装（备源+技术指标）
pip install efinance baostock finshare

# 技术指标本地计算（二选一）
pip install pandas-ta          # 推荐，纯 Python，无需编译
# pip install ta-lib           # 功能更全，需先编译 C 库

# 量化平台（可选，需注册）
pip install tushare jqdatasdk rqdatac

# 可视化扩展（可选）
pip install qstock
```

---

## 附录：akshare_adapter.py 方法速查

| 方法 | 说明 | 主要 akshare 接口 |
|------|------|-----------------|
| `index_spot(top_n)` | 大盘指数实时 | `stock_zh_index_spot_sina` → `stock_zh_index_spot_em` |
| `stock_kline(symbol, period, ...)` | 历史K线 | `stock_zh_a_hist` |
| `stock_intraday(symbol, period, ...)` | 分时/分钟 | `stock_zh_a_minute` → `stock_intraday_em` |
| `limit_pool(date, top_n)` | 涨跌停池 | `stock_zt_pool_em` + `stock_zt_pool_dtgc_em` |
| `money_flow(symbol, top_n)` | 个股资金流 | `stock_individual_fund_flow` |
| `market_money_flow(top_n, date)` | 大盘资金流 | `stock_market_fund_flow` → 多候选 |
| `sector_money_flow(top_n)` | 板块资金流 | `stock_sector_fund_flow_rank` → 多候选 |
| `fundamental(symbol, top_n)` | 财务摘要 | `stock_financial_abstract_ths` → `stock_financial_analysis_indicator` |
| `margin_lhb(symbol, date, top_n)` | 融资融券+龙虎榜 | `stock_margin_detail_em` + `stock_lhb_detail_em` |
| `sector_analysis(sector_type, top_n)` | 行业/概念板块 | `stock_sector_name_code` → `stock_sector_spot` |
| `fund_bond(scope, symbol, top_n)` | 基金/可转债 | `fund_etf_hist_em` / `bond_zh_hs_cov_spot` |
| `hk_us_market(market, top_n, symbol)` | 港股/美股 | `stock_hk_spot_em` / `stock_us_spot_em` |
| `derivatives(scope, symbol, top_n)` | 期货/期权 | `futures_display_main_sina` / `option_current_em` |
| `research_report(symbol, top_n)` | 个股研报 | `stock_research_report_em` |
| `stock_overview(symbol)` | 个股综合 | 实时+资金流+财务+涨停+研报 |
| `stock_pick(top_n, sector)` | 选股推荐 | 热门/板块成分+研报综合 |
| `news(top_n)` | 财经要闻 | `agent-browser` 抓取东财财经首页 |

---

## 附录：参考文件索引

| 文件 | 说明 |
|------|------|
| `docs/a-stock-data-sources-2026.md` | 数据源全景指南（含有效性评估、反爬策略、各Skill建议） |
| `a-stock-analysis-pro/references/data-sources.md` | 数据源A~H的完整采集规范（URL模板、提取字段、失败兜底） |
| `a-stock-analysis-pro/references/analysis-prompts.md` | 六大章节的LLM分析提示词模板 |
| `a-stock-analysis-pro/references/report-template.md` | HTML报告模板+质量检查清单 |
| `akshare-stock/adapters/akshare_adapter.py` | 封装好的多源容错适配器（Python） |
| `akshare-stock/SKILL.md` | akshare-stock Skill架构和意图路由设计 |

---

> **免责声明**：本文档数据源信息基于 2026 年 6 月公开信息整理，不构成投资建议。各数据源接口可能随时变更，使用前请以官方最新文档为准。
