# A股/沪深股票数据采集源全景指南（2026年版）

> **文档说明**：本文档面向本仓库所有 A 股 Skill（akshare-stock、a-stock-analysis-pro、stock-realtime-brief、agent-stock、stock-monitor-pro 等），系统梳理 2026 年当前各类数据采集源的有效性、适用场景及补充建议，帮助维护者快速判断接口是否仍可使用，并了解可补充的新源。
>
> 最后更新：2026-06-29

---

## 目录

1. [现有规则 2026 年有效性评估](#1-现有规则-2026-年有效性评估)
2. [主流 Python 数据库现状](#2-主流-python-数据库现状)
3. [网页/API 数据源现状](#3-网页api-数据源现状)
4. [量化平台数据接口](#4-量化平台数据接口)
5. [2024–2026 新增/崛起数据源](#5-20242026-新增崛起数据源)
6. [数据类型覆盖矩阵](#6-数据类型覆盖矩阵)
7. [多源冗余推荐架构](#7-多源冗余推荐架构)
8. [反爬与限流应对策略](#8-反爬与限流应对策略)
9. [各 Skill 补充建议清单](#9-各-skill-补充建议清单)

---

## 1. 现有规则 2026 年有效性评估

本仓库各 Skill 中沉淀了大量数据采集规则，以下逐类评估其 2026 年可用性。

### 1.1 实时行情数据源规则

| 规则/来源 | 原有优先级 | 2026 年状态 | 说明 |
|-----------|-----------|------------|------|
| 东方财富个股页 `quote.eastmoney.com` | 来源 1 | ✅ **仍可用（需注意限速）** | 反爬加强，高频抓取易被封 IP；建议配合 Session 级 UA 和请求间隔 |
| 新浪财经实时接口 | 来源 2 | ⚠️ **可用但不稳定** | 接口为非官方、文档不明确，可能随时变更；适合低频/备用 |
| 腾讯财经 `gu.qq.com` | 来源 3 | ⚠️ **可用但频繁调整** | 非官方开放接口，2025 年以来有多次结构变更 |
| 同花顺 `stockpage.10jqka.com.cn` | 来源 3 | ⚠️ **可用，有 CAPTCHA 风险** | 反爬明显增强，直接抓取难度上升 |
| 搜索引擎兜底 | 来源 4 | ✅ **仍有效** | 可用于低频或失败回退 |

**评估结论**：行情数据源规则整体仍有效，但需为每个来源配置**请求间隔 + 指数退避**，并保留多源自动切换逻辑。

### 1.2 资金流向 / 龙虎榜规则（数据源 B）

| 规则/来源 | 2026 年状态 | 说明 |
|-----------|------------|------|
| 证券之星资金流 | ⚠️ **可用** | 非结构化 HTML 抓取，页面结构偶有变化 |
| 新浪龙虎榜 | ✅ **akshare 已封装** | 建议直接使用 `akshare` 封装，更稳定 |
| 融资融券 | ✅ **akshare 已封装** | `stock_margin_detail_sse/szse` 等接口仍可用 |

### 1.3 财务数据规则（数据源 C）

| 规则/来源 | 2026 年状态 | 说明 |
|-----------|------------|------|
| 三季报/年报搜索采集 | ✅ **仍有效** | LLM 搜索+结构化提取路线依然可行 |
| akshare 财务接口 | ✅ **仍可用** | `stock_financial_*` 系列接口保持更新 |
| Tushare Pro 财务 | ✅ **付费可用** | 积分≥2000 可获取全量财务数据，质量高 |

### 1.4 技术指标规则（数据源 H）

| 规则/来源 | 2026 年状态 | 说明 |
|-----------|------------|------|
| 同花顺技术指标抓取 | ⚠️ **受限** | 反爬增强，直接抓取建议改为 akshare 计算 |
| 东方财富技术面 | ⚠️ **受限** | 同上 |
| LLM 自主搜索技术信号 | ✅ **可继续** | 作为补充/回退依然有效 |
| **本地计算（ta-lib / pandas-ta）** | ✅ **推荐** | 2026 年最稳定方案：拉取历史 K 线后本地算指标 |

> **重要补充建议**：技术指标（MACD、KDJ、RSI、BOLL 等）**建议改为本地基于历史 K 线数据计算**，不依赖第三方技术面接口，彻底规避抓取风险。

---

## 2. 主流 Python 数据库现状

### 2.1 AKShare ⭐⭐⭐⭐（**首要推荐**）

| 属性 | 详情 |
|------|------|
| 项目地址 | https://github.com/akfamily/akshare |
| 文档 | https://akshare.akfamily.xyz |
| 2026 年维护状态 | ✅ **积极维护**，版本更新频繁（1.18.x+） |
| 认证要求 | 无需注册，完全免费 |
| Python 要求 | 3.9+ |
| 数据类型 | 实时行情、历史 K 线、财务、资金流、龙虎榜、板块、期货/期权、基金、可转债、港股/美股、宏观数据 |
| 数据覆盖 | **最全面**，覆盖东方财富、新浪、同花顺、上交所/深交所官方等多源 |

**注意事项**：
- 接口随上游网站变更可能改名或废弃，需保持最新版本（`pip install akshare --upgrade`）
- **2026 年起 AKShare 依赖 `curl_cffi`（TLS 指纹伪装）和 `mini-racer`/`akracer`（JS 引擎）**来绕过东方财富等网站的反爬机制，安装时会自动下载这些依赖
- 高频调用仍易触发源站限速，建议合理设置请求间隔（≥ 1秒）和短缓存（30~120 秒）
- 当前已知约 28 个 open issue 均为上游 API 端点变更所致，维护者通常数天内修复
- 接口变动查阅：https://akshare.akfamily.xyz/changelog.html
- 遇到问题第一时间查阅 Issues：https://github.com/akfamily/akshare/issues

**仓库内现有封装**：`akshare-stock/adapters/akshare_adapter.py`（已有良好抽象，后续变更只需改此文件）

**2026 年仍可用的核心接口列举**：

```python
import akshare as ak

# 实时行情
ak.stock_zh_index_spot_sina()                          # 指数实时
ak.stock_zh_a_spot_em()                                # A股全市场实时行情

# 历史 K 线（日/周/月）
ak.stock_zh_a_hist(symbol, period, start_date, end_date, adjust)

# 分时数据
ak.stock_zh_a_minute(symbol, period)                   # 分钟 K 线

# 涨跌停
ak.stock_zt_pool_em(date)                              # 涨停池
ak.stock_dt_pool_em(date)                              # 跌停池
ak.stock_zt_pool_dtgc_em(date)                         # 连板梯队

# 资金流向
ak.stock_individual_fund_flow(stock, market)           # 个股资金流
ak.stock_market_fund_flow()                            # 大盘资金流
ak.stock_sector_fund_flow_rank(sector_type, period)   # 行业资金流

# 龙虎榜
ak.stock_lhb_detail_em(start_date, end_date)

# 融资融券
ak.stock_margin_detail_sse(date)
ak.stock_margin_detail_szse(date)

# 财务数据
ak.stock_financial_abstract_ths(symbol, indicator)     # 同花顺财务摘要
ak.stock_profit_sheet_by_report_em(symbol)             # 利润表
ak.stock_balance_sheet_by_report_em(symbol)            # 资产负债表
ak.stock_cash_flow_sheet_by_report_em(symbol)          # 现金流量表

# 行业/概念板块
ak.stock_board_industry_name_em()                      # 行业板块列表
ak.stock_board_concept_name_em()                       # 概念板块列表
ak.stock_board_industry_hist_em(symbol, period)        # 行业历史行情

# 北向资金
ak.stock_connect_hist_sina(start_date, end_date)

# 可转债
ak.bond_zh_cov()                                       # 可转债实时行情

# 期货
ak.futures_zh_spot(symbol, market_type)

# 基金
ak.fund_open_fund_info_em(fund, indicator)

# 港股/美股
ak.stock_hk_spot_em()                                  # 港股实时
ak.stock_us_spot_em()                                  # 美股实时
```

---

### 2.2 BaoStock（证券宝）⭐⭐⭐（**历史数据推荐**）

| 属性 | 详情 |
|------|------|
| 项目地址 | https://github.com/shimencaiji/baostock |
| 官网 | https://www.baostock.com |
| 2026 年维护状态 | ✅ **活跃**（PyPI 最新版 2026-06-06 发布） |
| 认证要求 | 无需注册，完全免费 |
| 数据时间范围 | 历史数据（日线 15:30 更新，延迟 30~60 分钟） |
| 强项 | **日/周/月 K 线、分钟 K 线（5m/15m/30m/60m）、财务数据** |
| 弱项 | **不提供实时数据**，Tick 级、Level-2、委比不支持 |

**适用场景**：量化回测、策略研究、历史数据补全、财务指标批量下载。

**使用示例**：

```python
import baostock as bs
import pandas as pd

lg = bs.login()
rs = bs.query_history_k_data_plus(
    "sh.600519",
    "date,open,high,low,close,volume,amount,adjustflag,turn,tradestatus,pctChg",
    start_date='2024-01-01', end_date='2026-06-01',
    frequency="d", adjustflag="3"   # 3=后复权
)
data_list = []
while (rs.error_code == '0') & rs.next():
    data_list.append(rs.get_row_data())
result = pd.DataFrame(data_list, columns=rs.fields)
bs.logout()
```

---

### 2.3 Tushare Pro ⭐⭐⭐⭐（**高质量付费推荐**）

| 属性 | 详情 |
|------|------|
| 官网 | https://tushare.pro |
| 2026 年维护状态 | ✅ **稳定维护** |
| 认证要求 | 注册 + 积分制（免费起步 120 积分，部分接口需 2000+ 积分） |
| 积分获取 | 社区贡献、推荐用户、付费充值（积分有效期 1 年） |
| 数据类型 | A/B/港/美/基金/期货/债券，实时、历史、财务、公告、指数 |

**2026 年积分门槛说明**：
- 基础接口（日线行情、IPO 列表等）：120 积分
- 历史分钟数据、财务报表：≥ 2000 积分
- 港美股实时、特色数据：独立权限（需额外付费）

**使用示例**：

```python
import tushare as ts
ts.set_token('your_token_here')
pro = ts.pro_api()

# 日线行情
df = pro.daily(ts_code='600519.SH', start_date='20240101', end_date='20260601')

# 资产负债表
df = pro.balancesheet(ts_code='600519.SH', period='20251231')

# 龙虎榜
df = pro.top_list(trade_date='20260628')
```

---

### 2.4 efinance ⭐⭐⭐（**轻量免费推荐**）

| 属性 | 详情 |
|------|------|
| 项目地址 | https://github.com/Micro-sheep/efinance |
| 文档 | https://efinance.readthedocs.io |
| 2026 年维护状态 | ✅ **活跃**（v0.5.8，2026-03 更新） |
| 认证要求 | 无需注册，完全免费 |
| 数据来源 | 主要爬取东方财富 |
| 数据类型 | A股/基金/债券/期货历史行情、实时行情、财务、资金流、龙虎榜 |

**特点**：API 极简，适合快速开发原型，不适合高频/实盘。

```python
import efinance as ef

# 日 K 线
df = ef.stock.get_quote_history('600519', beg='20250101', end='20261231', klt=101)
# klt: 1/5/15/30/60=分钟, 101=日, 102=周, 103=月

# 实时行情（全市场）
df = ef.stock.get_realtime_quotes()

# 财务指标
df = ef.stock.get_base_info('600519')
```

---

### 2.5 qstock ⭐⭐（**量化研究补充**）

| 属性 | 详情 |
|------|------|
| 项目地址 | https://github.com/tkfy920/qstock |
| 2026 年维护状态 | ✅ **活跃**（v1.3.8，2025-03 更新） |
| 认证要求 | 基础功能免费；高级功能需付费（知识星球） |
| 数据类型 | A股实时/历史行情、财务、资金流、板块、选股框架 |
| 特色 | 聚合多数据源，提供 plotly/pyecharts 可视化 |

```python
import qstock as qs

# 全市场实时行情
df = qs.realtime_data(market='沪深A')

# 历史日线
df = qs.get_data('600519', start='2025-01-01', end='2026-06-01', fqt=1)

# 板块数据
df = qs.sector_data(sector='行业', period='单日')
```

---

### 2.6 mootdx（通达信协议）⭐⭐（**分钟级/历史数据**）

| 属性 | 详情 |
|------|------|
| 项目地址 | https://github.com/mootdx/mootdx |
| 2026 年维护状态 | ⚠️ **低活跃**，最后 PyPI 上传 2024-05，GitHub 最后提交 2024-07 |
| 特色 | 通达信服务器协议，支持**分钟 K 线**（历史）、财务、指数；支持本地离线文件读取 |
| 限制 | 需连接通达信行情服务器，实时数据质量一般 |

> ⚠️ **pytdx 已彻底废弃**：`rainx/pytdx` 已于 2020-04-15 被存档（archived），**禁止继续使用**。请改用 `mootdx`（pytdx 的社区继承版）。

```python
from mootdx.reader import Reader
# 读取本地通达信数据文件（离线模式）
reader = Reader.factory(market='std')
data = reader.daily(symbol='600519')
```

**使用场景**：已有本地通达信安装，读取离线历史数据，适合量化回测。

---

## 3. 网页/API 数据源现状

### 3.1 东方财富（东财 Choice / 东财行情）

| 接口类型 | 2026 年状态 | 说明 |
|----------|------------|------|
| 网页爬取 `quote.eastmoney.com` | ⚠️ **反爬加强** | 仍可用，高频需降速+UA 轮换 |
| Choice 数据（官方 API） | ✅ **机构级稳定** | 收费，个人用户申请繁琐，适合量化团队 |
| 东财 API（公开接口） | ⚠️ **非官方，随时失效** | akshare/efinance 已封装，建议走库 |

**akshare 对应接口**：`stock_zh_a_spot_em()`、`stock_board_industry_hist_em()` 等，均来自东财。

### 3.2 新浪财经

| 接口类型 | 2026 年状态 | 说明 |
|----------|------------|------|
| 实时行情 `hq.sinajs.cn` | ✅ **仍可用** | 经典接口，稳定性一般，调用频率需控制 |
| 大盘指数 | ✅ **akshare 封装** | `stock_zh_index_spot_sina()` 仍正常 |
| 历史 K 线 | ⚠️ **部分失效** | 建议改用 akshare 的东财历史接口 |

### 3.3 同花顺（10jqka）

| 接口类型 | 2026 年状态 | 说明 |
|----------|------------|------|
| OpenAPI（官方） | ✅ **付费可用** | 基础行情免费额度有限（≈3000次/月），Level-2/分钟线需付费 |
| 网页爬取 | ⚠️ **反爬增强** | 有 CAPTCHA 和 Token 验证，直接爬取风险高 |
| akshare 封装 | ✅ **部分接口可用** | `stock_financial_abstract_ths()` 等仍正常 |

### 3.4 雪球（Snowball）

| 接口类型 | 2026 年状态 | 说明 |
|----------|------------|------|
| 网页接口 | ⚠️ **需登录态** | 2025 年起强制登录，接口频繁变动 |
| 舆情/情绪数据 | ✅ **有参考价值** | 适合做情绪分析辅助，**不建议作为行情主数据源** |

### 3.5 上交所/深交所官方数据

| 数据 | 来源 | 说明 |
|------|------|------|
| 融资融券汇总 | `http://www.szse.cn/api/report/ShowReport?` | akshare 已封装 |
| 龙虎榜 | 深交所官网 | akshare 已封装 |
| 大宗交易 | 上交所/深交所 | akshare `stock_dzjy_*` 系列 |
| 限售解禁 | 两所公告 | Tushare Pro `top_inst` |
| 公告/披露 | `https://www.cninfo.com.cn` | **巨潮资讯**，公告原文权威来源 |

**补充推荐：巨潮资讯网（cninfo.com.cn）**

巨潮资讯是中国证监会指定的官方信息披露平台，可直接抓取公告 PDF/正文，适合：
- 财报原文（年报/中报/季报）
- 重大事项公告
- 增减持公告

```python
# akshare 封装的巨潮公告接口
import akshare as ak
df = ak.stock_notice_report(symbol="600519", date="20260601")
```

---

## 4. 量化平台数据接口

### 4.1 聚宽 JoinQuant（jqdata）

| 属性 | 详情 |
|------|------|
| 官网 | https://www.joinquant.com |
| 2026 年状态 | ✅ **活跃运营** |
| 数据范围 | 2005 年至今 A 股全品种（日/分钟/Tick）、财务、指数、基金、期货 |
| 接入方式 | 在线研究平台 + 本地 `jqdatasdk` |
| 收费情况 | 基础免费（有限额），付费会员数据更全 |

```python
import jqdatasdk as jq
jq.auth('your_mobile', 'your_password')

# 历史 K 线（日线）
df = jq.get_price('600519.XSHG', start_date='2025-01-01', end_date='2026-06-01', frequency='daily')

# 财务数据
q = jq.query(jq.valuation).filter(jq.valuation.code == '600519.XSHG')
df = jq.get_fundamentals(q)
```

### 4.2 米筐 RiceQuant（rqdata）

| 属性 | 详情 |
|------|------|
| 官网 | https://www.ricequant.com |
| 2026 年状态 | ✅ **活跃运营** |
| 数据范围 | A 股/期货/期权/基金/债券，日线/分钟/Tick |
| 接入方式 | `rqdatac`（需申请 License） |
| 收费情况 | 基础接口试用，全量数据付费 |

```python
import rqdatac as rq
rq.init()  # 需配置 License

# 日线历史
df = rq.get_price('600519.XSHG', start_date='2025-01-01', end_date='2026-06-01', frequency='1d')
```

### 4.3 万得 Wind（windpy）

| 属性 | 详情 |
|------|------|
| 2026 年状态 | ✅ **机构主流** |
| 接入要求 | 需购买 Wind 终端（个人版年费较高） |
| 数据质量 | **行业最高**，覆盖最全 |
| 适用对象 | 机构投资者、私募基金 |

---

## 5. 2024–2026 新增/崛起数据源

### 5.1 TickFlow（新晋商业 API）⭐⭐⭐

| 属性 | 详情 |
|------|------|
| 官网 | https://tickflow.org |
| 定位 | 工程化稳定 A 股数据 API，不依赖网页爬虫 |
| 数据类型 | 实时行情、历史 K 线、财务、板块 |
| 特点 | 标准 REST API，稳定性高，有免费层（限额） |

**适用场景**：实盘系统、长期数据管道，不想自己维护反爬逻辑的项目。**efinance 官方 README 也推荐此服务作为遭遇限速时的替代方案。**

### 5.2 finshare（米波量化）⭐⭐⭐（**2026 新推荐**）

| 属性 | 详情 |
|------|------|
| 项目地址 | https://github.com/finvfamily/finshare |
| 2026 年维护状态 | ✅ **活跃**（最后提交 2026-04-05） |
| 安装 | `pip install finshare` |
| 认证要求 | 无需注册，完全免费 |
| 数据类型 | A股历史/实时行情、板块、资金流、龙虎榜、融资融券、基金、期货 |

**核心亮点**：内置 `DataSourceManager` 自动多源容错切换，优先级：东方财富 → 新浪 → 通达信 → BaoStock，任一源失败自动降级。

```python
import finshare as fs

# 历史 K 线（自动容错）
df = fs.get_stock_history('600519', period='daily', start='20250101', end='20261231')

# 全市场实时行情（自动容错）
df = fs.get_realtime_quotes()
```

**生态**：配套 `finboard`（行情看板）、`finscreener`（选股器）、`finquant`（回测框架）。

### 5.3 xtquant / miniQMT（迅投量化）⭐⭐⭐（**最接近"官方"的免费实时数据**）

| 属性 | 详情 |
|------|------|
| 安装 | `pip install xtquant` |
| 最新版本 | `250516.1.1`（2025-06 发布） |
| 认证要求 | 需开通券商 miniQMT 功能（光大、华鑫、太平洋、方正等） |
| 数据类型 | **实时 Tick/逐笔**、历史 K 线（1m/5m/日线）、盘口、账户数据 |
| 优势 | **数据来自券商官方行情，非爬虫，无限速、合规、准确** |

**重要说明**：如果你拥有券商账户并开通了 miniQMT，这是目前**对个人投资者最友好的合规实时数据方案**，不需要付费、不需要对抗反爬，数据质量等同交易所级别。正成为量化开发者的主流数据获取方式。

```python
from xtquant import xtdata

# 订阅实时行情
xtdata.subscribe_quote('600519.SH', period='tick', count=-1)

# 历史 K 线
data = xtdata.get_market_data(['close', 'open', 'high', 'low', 'volume'],
    ['600519.SH'], period='1d', start_time='20250101')
```

### 5.4 MCP Server 方案（2025–2026 兴起）⭐⭐⭐

随着 AI 助手生态发展，多个基于 MCP（Model Context Protocol）的 A 股数据服务在 GitHub 上出现，可作为 Skill 的底层数据层：

| 项目 | 地址 | 数据源 | 特点 |
|------|------|--------|------|
| china-stock-mcp | https://github.com/wax0629/china-stock-mcp | akshare | FastMCP，适合 AI 工作流 |
| astock-mcp-server | https://github.com/jiangyj545/astock-mcp-server | BaoStock + 新浪 | 零 API Key，实时+K线 |
| magpie | https://github.com/SymbolStar/magpie | akshare | TypeScript，价格+资金流预警，含 HTTP API |

**补充建议**：本仓库 Skill 可考虑接入 MCP Server 方案（尤其是 `ashare-mcp`），让 AI 助手直接调用结构化数据端点，减少提示词中的抓取逻辑。

### 5.5 AKShare Dify 插件

| 项目 | 地址 | 说明 |
|------|------|------|
| akshare-stockdata-plugin | https://github.com/shaoxing-xie/akshare-stockdata-plugin | 封装为 Dify 平台插件，⭐102，2026 年仍活跃维护 |

适合基于 Dify 的 AI 工作流，覆盖实时行情、历史数据、财务分析、资金流向、技术分析、沪深港通等。

### 5.6 东方财富 Choice 数据官方 API（逐步开放）

2025–2026 年，东方财富 Choice 开始面向机构/个人开发者提供标准化 REST API，逐步合规化。个人开发者可申请试用，但流程仍繁琐、定价不透明。关注官方开发者文档：https://quantapi.eastmoney.com

### 5.7 国证指数 / 中证指数官方数据

| 来源 | 类型 | 2026 年状态 |
|------|------|------------|
| 中证指数 `www.csindex.com.cn` | 指数成分/权重/历史 | ✅ 仍开放，akshare 已封装 |
| 国证指数 `www.cnindex.com.cn` | 深证系列指数 | ✅ 部分可直接下载 |

```python
# akshare 中证指数成分
import akshare as ak
df = ak.index_stock_cons(symbol="000300")  # 沪深 300 成分
```

---

## ⚠️ 重大监管变化（必读）

### 北向资金（北向资金实时/日频数据）——2024-08-19 起已停用

> 这是 2024 年以来 **最重要的监管变化**，直接影响所有使用北向资金数据的 Skill。

**变化时间**：2024 年 8 月 19 日

**变化内容**：沪深交易所官方宣布，**取消北向资金（沪深港通）盘中和日频买卖明细数据的公开披露**。

| | 变化前 | 变化后 |
|---|---|---|
| 盘中/日频净流入 | ✅ 公开可用 | ❌ **已停用** |
| 买卖方向拆分 | ✅ 可获取 | ❌ **已停用** |
| T+1 成交总额 | ✅ | ✅ 仍可用（无买卖拆分） |
| 十大活跃股 | ✅ | ✅ 仍可用（无买卖拆分） |
| 季度持仓（QFII） | ✅ | ✅ 仍可用（约 3 个月延迟） |

**对 Skill 的影响**：
- `ak.stock_hsgt_north_net_flow_in()` 等实时/日频北向资金接口已返回"已停用"错误
- **所有仓库内依赖北向资金净流入数据的功能需要移除或改为展示"T+1 汇总"**
- 情绪指标中的"北向资金"维度已失去实时性，建议替换为成交量、涨跌停家数等替代指标

---

## 6. 数据类型覆盖矩阵

> ✅ 完全支持 | ⚠️ 部分支持/需付费 | ❌ 不支持 | 🔒 机构专用

| 数据类型 | akshare | BaoStock | Tushare Pro | efinance | qstock | JoinQuant | 东财网页 | 新浪 |
|----------|:-------:|:--------:|:-----------:|:--------:|:------:|:---------:|:--------:|:----:|
| A股实时行情 | ✅ | ❌ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 历史日K线 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| 历史分钟K线 | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ | ⚠️ | ❌ |
| Tick/逐笔数据 | ❌ | ❌ | ⚠️ | ❌ | ❌ | ⚠️ | ❌ | ❌ |
| 涨跌停池/连板 | ✅ | ❌ | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ❌ |
| 主力资金流向 | ✅ | ❌ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ❌ |
| 龙虎榜 | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 融资融券 | ✅ | ❌ | ✅ | ✅ | ⚠️ | ✅ | ✅ | ❌ |
| 财务报表（年报/季报） | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | ❌ |
| 个股公告 | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| 行业/概念板块 | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| 北向资金（沪深港通） | ⚠️ T+1仅 | ❌ | ⚠️ T+1仅 | ⚠️ T+1仅 | ⚠️ T+1仅 | ⚠️ T+1仅 | ⚠️ T+1仅 | ❌ |
| 期货行情 | ✅ | ❌ | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | ❌ |
| 期权行情 | ✅ | ❌ | ⚠️ | ❌ | ❌ | ✅ | ⚠️ | ❌ |
| 基金净值 | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| 可转债行情 | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| 港股行情 | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| 美股行情 | ✅ | ❌ | ✅ | ⚠️ | ⚠️ | ❌ | ✅ | ⚠️ |
| 指数成分/权重 | ✅ | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ | ❌ |
| 宏观经济数据 | ✅ | ❌ | ✅ | ❌ | ⚠️ | ✅ | ⚠️ | ❌ |
| 技术指标（本地计算） | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |

> **注**：北向资金（沪深港通）实时/日频净流入数据已于 **2024-08-19 正式停用**，各库均无法获取，仅余 T+1 成交总额和季度持仓（延迟约 3 个月）。
>
> **新增推荐源**：`finshare`（多源容错 A 股）、`xtquant`（券商级实时 Tick+历史，无限速）未列入上表，请参见第 5 节。

---

## 7. 多源冗余推荐架构

2026 年最佳实践：**主源 + 备源 + 本地缓存** 三层架构。

```
┌──────────────────────────────────────────────────────┐
│                   数据请求入口                         │
└──────────────────────┬───────────────────────────────┘
                       │
         ┌─────────────▼─────────────┐
         │      本地短缓存（30~120秒） │  ← Redis / 内存字典
         └─────────────┬─────────────┘
                  缓存未命中
                       │
         ┌─────────────▼─────────────┐
         │   主数据源（AKShare）       │  ← 覆盖最全，实时更新
         └─────────────┬─────────────┘
                  主源失败/限速
                       │
         ┌─────────────▼─────────────┐
         │  备用源（efinance / 新浪）  │  ← 自动降级
         └─────────────┬─────────────┘
                  备源失败
                       │
         ┌─────────────▼─────────────┐
         │  历史缓存（BaoStock/本地DB）│  ← 最后兜底，标注"非实时"
         └───────────────────────────┘
```

**代码示意（akshare_adapter.py 改进版）**：

```python
import akshare as ak
import efinance as ef
import time
import functools

def with_fallback(primary_fn, fallback_fn, max_retries=2):
    """主源失败时自动切换备源"""
    for attempt in range(max_retries):
        try:
            return primary_fn()
        except Exception as e:
            if attempt == max_retries - 1:
                try:
                    return fallback_fn()
                except Exception:
                    raise
            time.sleep(1.5 ** attempt)  # 指数退避

class AkAdapter:
    def stock_kline(self, symbol, period="daily", start_date="", end_date="", adjust="qfq"):
        primary = lambda: ak.stock_zh_a_hist(
            symbol=symbol, period=period,
            start_date=start_date, end_date=end_date, adjust=adjust
        )
        # efinance 备源（klt 映射：daily→101）
        klt_map = {"daily": 101, "weekly": 102, "monthly": 103}
        klt = klt_map.get(period, 101)
        fallback = lambda: ef.stock.get_quote_history(
            symbol, beg=start_date.replace("-",""), end=end_date.replace("-",""), klt=klt
        )
        return with_fallback(primary, fallback)
```

---

## 8. 反爬与限流应对策略

2026 年各平台反爬措施普遍增强，以下策略可有效应对：

### 8.1 请求频率控制

```python
import time
import random

def rate_limited_get(fn, *args, min_interval=1.0, jitter=0.5, **kwargs):
    """加入随机抖动的请求间隔"""
    result = fn(*args, **kwargs)
    time.sleep(min_interval + random.uniform(0, jitter))
    return result
```

### 8.2 UA 轮换

```python
import random

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ...",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ...",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 ...",
]

def get_random_ua():
    return random.choice(USER_AGENTS)
```

### 8.3 数据缓存策略

| 数据类型 | 推荐缓存时间 | 说明 |
|----------|------------|------|
| 实时大盘/个股行情 | 30~60 秒 | 盘中每分钟更新即可 |
| 板块资金流排行 | 60~120 秒 | 变化较慢 |
| 财务报告/财务指标 | 当天缓存 | 财报发布才更新 |
| 历史 K 线（已收盘日） | 永久缓存 | 历史数据不变 |
| 涨跌停池 | 30~60 秒 | 盘中实时变化 |

### 8.4 容错降级标注

```python
def fetch_with_label(fn, label="实时"):
    try:
        data = fn()
        return data, label
    except Exception:
        # 降级：返回本地缓存 + 标注"非实时"
        cached = load_from_cache()
        return cached, "非实时（缓存数据，接口暂不可用）"
```

---

## 9. 各 Skill 补充建议清单

### 9.1 akshare-stock

| 补充项 | 优先级 | 说明 |
|--------|--------|------|
| 添加 efinance/finshare 备源层 | 高 | 当 akshare 限速时自动切换；finshare 自带多源容错 |
| 接入巨潮资讯公告 | 中 | `ak.stock_notice_report()` 获取官方公告 |
| 本地计算技术指标（ta-lib/pandas-ta） | 高 | 避免依赖第三方技术面抓取 |
| 添加 BaoStock 历史数据备源 | 中 | 当主源历史数据失败时降级 |
| ~~加入北向资金接口~~ | ~~中~~ | ⚠️ **2024-08-19 已停用**，实时/日频数据不再可用，移除或改为 T+1 汇总 |
| 大宗交易数据 | 低 | `ak.stock_dzjy_mrmx_ths()` |

### 9.2 a-stock-analysis-pro（data-sources.md 更新建议）

| 数据源 | 现有规则 | 补充建议 |
|--------|---------|---------|
| 数据源 A（实时行情） | 东财→新浪→腾讯→同花顺 | 补充 akshare 作为第一优先（结构化输出，不需要 HTML 解析）；或接入 finshare（自带容错） |
| 数据源 B（资金/龙虎榜） | 证券之星 | 补充 akshare 封装接口（`stock_lhb_detail_em`），更稳定 |
| 数据源 C（财务） | 搜索采集 | 补充 Tushare Pro（质量最高）、akshare 财务接口 |
| 数据源 D（公告） | 搜索关键词 | 补充巨潮资讯直接抓取（`ak.stock_notice_report()`） |
| 数据源 H（技术面） | 同花顺/东财抓取 | **改为本地 pandas-ta/ta-lib 计算**，不再依赖网页抓取 |
| ~~新增数据源 I（北向资金）~~ | ~~无~~ | ⚠️ **2024-08-19 已停用**，实时/日频净流入不再可用，移除此数据源 |
| 新增数据源 J（ST/退市判断） | 已有 F | 补充 akshare `stock_info_a_code_name()`、Tushare `namechange` 接口 |

### 9.3 stock-realtime-brief

| 补充项 | 优先级 | 说明 |
|--------|--------|------|
| 七步法数据源增加备源（finshare/efinance） | 高 | 主源失败时自动降级，不影响用户体验 |
| 接入 BaoStock 历史数据 | 中 | 用于回测和历史分析 |
| ~~北向资金实时推送~~ | ~~中~~ | ⚠️ **2024-08-19 已停用**，不可再推送实时/日频净流入 |
| 可转债溢价率监控 | 低 | 可转债价格/溢价率偏高/偏低预警 |

### 9.4 stock-monitor-pro

| 补充项 | 优先级 | 说明 |
|--------|--------|------|
| efinance/finshare 作为备源 | 高 | 当前单一依赖有风险；finshare 自带多源容错 |
| ~~加入沪深港通资金监控~~ | ~~中~~ | ⚠️ **2024-08-19 已停用**，实时/日频北向资金数据不再可用 |
| 期权 PCR 监控 | 低 | 50ETF/300ETF 期权 PCR 作为市场情绪指标 |

---

## 附录：快速安装命令

```bash
# 必装（主数据源）
pip install akshare --upgrade

# 建议安装（备源+技术指标）
pip install efinance baostock finshare

# 技术指标本地计算（二选一）
pip install pandas-ta   # 推荐，纯 Python，无需编译
# pip install ta-lib    # 功能更全，需先编译 C 库

# 量化平台（可选，需注册）
pip install tushare jqdatasdk rqdatac

# 进阶（可选）
pip install qstock
```

---

## 附录：参考链接

| 资源 | 地址 |
|------|------|
| AKShare 官方文档 | https://akshare.akfamily.xyz |
| AKShare 接口更新日志 | https://akshare.akfamily.xyz/changelog.html |
| AKShare GitHub Issues | https://github.com/akfamily/akshare/issues |
| BaoStock 官网 | https://www.baostock.com |
| Tushare Pro 接口权限表 | https://tushare.pro/document/1?doc_id=108 |
| efinance GitHub | https://github.com/Micro-sheep/efinance |
| efinance 文档 | https://efinance.readthedocs.io |
| finshare GitHub | https://github.com/finvfamily/finshare |
| qstock GitHub | https://github.com/tkfy920/qstock |
| xtquant / miniQMT PyPI | https://pypi.org/project/xtquant/ |
| 聚宽数据接口 | https://www.joinquant.com/data |
| 米筐文档 | https://www.ricequant.com/doc |
| 巨潮资讯（公告下载） | https://www.cninfo.com.cn |
| 中证指数官网 | https://www.csindex.com.cn |
| TickFlow | https://tickflow.org |
| ashare-mcp（MCP Server） | https://github.com/CharmYue/ashare-mcp |
| china-stock-mcp | https://github.com/wax0629/china-stock-mcp |
| akshare-stockdata-plugin (Dify) | https://github.com/shaoxing-xie/akshare-stockdata-plugin |
| 北向资金停用公告参考 | https://github.com/CharmYue/ashare-mcp （README 中有说明） |

---

> **免责声明**：本文档中的数据源信息基于 2026 年 6 月公开信息整理，不构成投资建议。各数据源接口可能随时变更，使用前请以官方最新文档为准。数据仅供研究和学习使用。
