# aksu-stock

融合仓库内多个 A 股分析/监控/研报子项目（akshare-stock、stock-realtime-brief、stock-monitor-pro 等），提供统一的 CLI 和 OpenClaw/Hermes Skill 入口，抽取公共数据适配器、渲染器与配置层，便于复用、测试与运维。

主要目标：
- 保持原子子项目可独立运行（向后兼容），同时提供一个集成的 skill：aksu-stock。
- 抽取公共模块（data_adapters、renderers、utils），减少重复代码。
- 统一配置优先级（CLI > 环境变量 > config file）。

快速开始
```
git clone https://github.com/tangaksu/aksu.git
cd aksu
# 切到合并分支或在主分支上安装（推荐使用 feature/aksu-stock-skill 分支）
# 进入新 skill 目录
cd aksu-stock
pip install -r requirements.txt
python main.py --help
```

更多细节请见 ARCHITECTURE.md。
