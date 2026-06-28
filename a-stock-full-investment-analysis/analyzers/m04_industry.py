"""M04 行业周期与产业链景气度分析"""
from __future__ import annotations
from .base import ModuleResult, score_to_stars, fmt, pct_fmt


def analyze_industry(data: dict) -> ModuleResult:
    info = data.get("stock_info") or {}
    peers = data.get("industry_peers") or []
    sentiment = data.get("market_sentiment") or {}

    findings = []
    score = 5.0

    industry = info.get("industry", "未知行业")
    findings.append(f"所属行业：{industry}")

    # ── 行业类型判断 ──
    cycle_type = "均衡型"
    cycle_stage = "不明"
    policy_support = False

    policy_industries = [
        "新能源", "半导体", "芯片", "AI", "人工智能", "光伏", "储能",
        "军工", "国防", "医疗器械", "创新药", "数字经济", "云计算",
    ]
    defensive_industries = [
        "白酒", "食品饮料", "消费", "公用事业", "医药", "水务",
    ]
    cyclical_industries = [
        "钢铁", "煤炭", "化工", "有色金属", "房地产", "建材",
        "航运", "造纸",
    ]

    for k in policy_industries:
        if k in industry:
            cycle_type = "成长赛道"
            policy_support = True
            score += 1.5
            findings.append(f"✅ {industry} 属于政策重点支持成长赛道")
            break

    if cycle_type == "均衡型":
        for k in defensive_industries:
            if k in industry:
                cycle_type = "防御消费"
                score += 0.5
                findings.append(f"✅ {industry} 属于防御型消费行业，抗周期性较强")
                break

    if cycle_type == "均衡型":
        for k in cyclical_industries:
            if k in industry:
                cycle_type = "强周期"
                findings.append(f"⚠️ {industry} 属于强周期行业，需关注景气度拐点")
                break

    # ── 同业对比（判断行业当前景气度） ──
    if peers:
        up_count = sum(1 for p in peers if (p.get("pct") or 0) > 0)
        down_count = sum(1 for p in peers if (p.get("pct") or 0) < 0)
        avg_pct = sum(p.get("pct") or 0 for p in peers) / len(peers)

        findings.append(
            f"行业内 {len(peers)} 只股票：涨{up_count}跌{down_count}，"
            f"行业平均涨幅：{avg_pct:+.2f}%"
        )

        if avg_pct > 2:
            score += 1.5
            cycle_stage = "景气上行"
            findings.append("✅ 行业整体强势上行，板块景气度高")
        elif avg_pct > 0:
            score += 0.5
            cycle_stage = "温和向好"
        elif avg_pct < -2:
            score -= 1.0
            cycle_stage = "景气下行"
            findings.append("⚠️ 行业整体走弱，板块承压")
        else:
            cycle_stage = "震荡整理"

        # 行业PE水平（估值高低反映市场预期）
        pe_vals = [p.get("pe") for p in peers if p.get("pe") and p.get("pe") > 0]
        if pe_vals:
            avg_pe = sum(pe_vals) / len(pe_vals)
            findings.append(f"行业平均PE：{avg_pe:.1f}x")
            if avg_pe > 100:
                findings.append("⚠️ 行业估值偏高，需业绩持续兑现支撑")
            elif avg_pe < 15:
                score += 0.5
                findings.append("✅ 行业低估值，价值洼地机会")

    # ── 大盘情绪对行业的影响 ──
    mood = sentiment.get("mood_score")
    if mood:
        if mood > 60:
            score += 0.5
            findings.append(f"✅ 市场情绪偏多（涨家占比{mood:.0f}%），行业Beta收益可期")
        elif mood < 40:
            score -= 0.5
            findings.append(f"⚠️ 市场情绪偏空（涨家占比{mood:.0f}%），防御为主")

    score = min(10.0, max(1.0, score))

    conclusion = (
        f"{industry}（{cycle_type}）当前景气度：{cycle_stage}。"
        f"{'政策重点支持，行业β向上。' if policy_support else '关注行业库存与需求拐点。'}"
    )

    return ModuleResult(
        module_id="M04",
        module_name="行业周期与产业链景气度分析",
        score=round(score, 1),
        stars=score_to_stars(score),
        key_findings=findings,
        short_advice=f"关注 {industry} 板块联动，景气上行期优先持有行业龙头",
        mid_advice=f"中线重点跟踪 {industry} 行业政策落地进度与产能变化",
        long_advice=f"{'成长赛道长期持有价值显著，关注行业格局集中度提升' if cycle_type == '成长赛道' else '周期类标的中长线需匹配景气周期高点减仓'}",
        conclusion=conclusion,
        detail={"industry": industry, "cycle_type": cycle_type, "cycle_stage": cycle_stage, "peers_count": len(peers)},
    )
