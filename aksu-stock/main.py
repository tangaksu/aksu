"""
aksu-stock 主入口（路由器）
功能：分发 subcommands 到不同能力：analyze/report/monitor
这是一个轻量骨架；实际分析函数会在 adapters/ 和 services/ 中实现。
"""

import argparse
import sys

VERSION = "0.1.0"


def cmd_analyze(args):
    # placeholder: 调用 adapters/analyze.py 中的接口
    print(f"[aksu-stock] analyze mode: codes={args.codes} mode={args.mode}")


def cmd_portfolio(args):
    print(f"[aksu-stock] portfolio mode: portfolio_file={args.portfolio}")


def cmd_monitor(args):
    print(f"[aksu-stock] monitor action: {args.action}")


def build_parser():
    p = argparse.ArgumentParser(prog="aksu-stock", description="AKSU 综合 A 股 Skill")
    p.add_argument("--version", action="version", version=VERSION)
    sub = p.add_subparsers(dest="command")

    # analyze
    pa = sub.add_parser("analyze", help="单只或多只股票分析")
    pa.add_argument("--codes", help="逗号分隔的股票代码，例如 600519,300750")
    pa.add_argument("--mode", choices=["single","multi"], default="single")
    pa.set_defaults(func=cmd_analyze)

    # portfolio
    pp = sub.add_parser("portfolio", help="持仓简报")
    pp.add_argument("--portfolio", help="持仓文件路径（json）")
    pp.set_defaults(func=cmd_portfolio)

    # monitor
    pm = sub.add_parser("monitor", help="监控/告警子系统")
    pm.add_argument("action", choices=["start","stop","status"], default="status")
    pm.set_defaults(func=cmd_monitor)

    return p


def main(argv=None):
    p = build_parser()
    args = p.parse_args(argv)
    if not hasattr(args, "func"):
        p.print_help()
        return 1
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
