# AKSU Stock Skill

这是将仓库内多个 A 股技能撮合成单一 OpenClaw/Hermes Skill 的骨架。包含统一入口、配置层与模块化适配器，方便后续把 akshare-stock、stock-realtime-brief、stock-monitor-pro 的代码迁移/复用。

触发语示例：
- "分析 600519" -> single
- "组合简报" -> portfolio
- "监控 start" -> monitor

将 SKILL.md 填充为 OpenClaw 可识别的技能描述与能力声明。
