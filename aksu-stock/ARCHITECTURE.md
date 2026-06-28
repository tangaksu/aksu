# AKSU Stock Architecture & 撮合方案

本文件描述将现有子项目（akshare-stock、stock-realtime-brief、stock-monitor-pro 以及 a-stock-analysis-pro 等）撮合为统一 skill 的详细计划、分工与实现细节。

1. 目标
- 在不破坏现有独立运行能力的前提下，建立一个名为 aksu-stock 的 skill，提供统一 CLI、统一配置层和共享库。
- 抽取公共适配器：数据抓取（data_adapters）、渲染（renderers）、共用工具（utils）。
- 提供向后兼容的适配器，逐步替换各子项目中的重复代码。

2. 首发包含的子项目（建议）
- akshare-stock -- 实时行情、K 线、资金流、基础面指标
- stock-realtime-brief -- 单股/多股/持仓简报逻辑、渲染模板、持仓示例
- stock-monitor-pro -- 监控/告警脚本和配置示例
- a-stock-analysis-pro（按需）-- 研报生成相关的 prompt 与 report 模板

3. 高层设计
- 顶层 skill：aksu-stock/
  - aksu_stock/               # Python 包（最终代码会放在这里）
  - adapters/                 # 各子模块适配器（akshare_adapter, ths_adapter, report_adapter）
  - services/                 # 高层业务逻辑（analyzer, monitor, report_generator）
  - renderers/                # HTML/Markdown/PDF 渲染模板与工具
  - config/                   # 配置解析（优先级：CLI > ENV > config.yaml）
  - tests/                    # 单元/集成测试
  - SKILL.md
  - main.py                   # 统一入口与路由

4. 关键接口与契约
- DataAdapter interface (adapters/base.py)
  - fetch_realtime(code) -> dict
  - fetch_history(code, period, adjust) -> DataFrame
  - fetch_fund_flow(code) -> dict
  - fetch_financials(code) -> dict

- Analyzer service (services/analyzer.py)
  - analyze_single(code, options) -> AnalysisResult
  - analyze_multi(codes, options) -> MultiAnalysisResult
  - analyze_portfolio(portfolio_file) -> PortfolioReport

- Monitor service (services/monitor.py)
  - start_monitor(config)
  - stop_monitor()
  - status() -> dict

- Renderer (renderers/html.py, renderers/markdown.py)
  - render_analysis(result, template) -> {html, markdown}
  - export_pdf(html) -> bytes/file

5. 配置管理
- 采用 YAML（config/config.yaml）作为默认配置
- 支持环境变量覆盖（以 STOCK_* 前缀）
- CLI 参数优先级最高
- 示例字段：data_source_priority, request_timeout, parallel_workers, output_dir

6. 数据源优先级与容错
- 优先顺序：腾讯 -> 新浪 -> AKShare -> THS
- 每个 adapter 实现重试与超时（requests timeout + backoff）
- 公共的 fetch 工具封装降级策略和速率限制

7. 渐进迁移策略（步骤）
- 步骤 0：创建骨架（本次提交）
- 步骤 1：在 adapters/ 中实现 akshare_adapter，复用 akshare-stock 的抓取逻辑
- 步骤 2：把 stock-realtime-brief 的 analyzers/renderer 迁入 services/ 与 renderers/
- 步骤 3：把 stock-monitor-pro 中的 scripts 转为 monitor service，并提供 systemd/容器化样例
- 步骤 4：重构重复代码，增加单元测试（每个 adapter + analyzer + renderer）
- 步骤 5：更新 SKILL.md 与 skill-card，并在主分支合并

8. CI 与测试
- 新增 GitHub Actions workflow：
  - lint (flake8/mypy)
  - unit tests (pytest)
  - build package (optional)
- 在 actions 中建议加入 matrix: python 3.10, 3.11

9. 发布与兼容性
- 先在 feature/aksu-stock-skill 分支完成整合与测试
- 发布规则：Tag v0.1.0 首发功能集

10. 估时（粗略）
- 骨架与接口设计：1 天（已完成 skeleton）
- akshare_adapter 实现 + tests：2-3 天
- analyzer + renderer 迁移与适配：3-5 天
- monitor service 重构：2 天
- 测试、CI 和修复：2 天
- 总计：大约 10-14 个工作日（由单人完成并包含修正）

11. 安全与合规
- 注意数据抓取遵守目标站点 Robots/使用条款；避免短时间内大量并发拉取
- 不在仓库中提交 API keys 或凭证；示例配置中使用占位符

12. 下一步（我可以立即为你做）
- 在 feature 分支中进一步添加 adapters/akshare_adapter.py，迁入 akshare-stock 的主要抓取逻辑并运行 smoke test
- 或者我把上述接口模板和示例实现补齐到仓库中（需要你确认优先包含的子项目）

如需我现在继续，把第一批 adapter（akshare）和 analyzer 的迁移代码放到 feature/aksu-stock-skill 分支，请回复“继续迁移 akshare”。
