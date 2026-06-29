"""M09 市场分歧与机构预期统计"""
from __future__ import annotations
from .base import ModuleResult, score_to_stars, fmt


def analyze_consensus(data: dict) -> ModuleResult:
    reports = data.get("research_reports") or []
    consensus = data.get("analyst_consensus") or {}
    rt = data.get("realtime") or {}

    findings = []
    score = 5.0

    # ── 机构评级统计 ──
    buy = consensus.get("buy", 0)
    hold = consensus.get("hold", 0)
    sell = consensus.get("sell", 0)
    total = consensus.get("total", 0)
    buy_ratio = consensus.get("buy_ratio", 0)
    avg_target = consensus.get("avg_target")
    max_target = consensus.get("max_target")
    min_target = consensus.get("min_target")

    if total > 0:
        findings.append(
            f"机构评级（近6个月）：买入/增持 {buy}家，中性 {hold}家，减持/卖出 {sell}家"
        )
        findings.append(f"买入评级占比：{buy_ratio:.1f}%")

        if buy_ratio >= 80:
            score += 2.0
            findings.append("✅ 机构高度看多（买入占比>80%），强共识")
        elif buy_ratio >= 60:
            score += 1.0
            findings.append("✅ 机构多数看多（买入占比>60%）")
        elif buy_ratio < 30:
            score -= 1.5
            findings.append("⚠️ 机构看空居多，市场信心不足")

        if sell > 0:
            findings.append(f"⚠️ 有 {sell} 家机构给出减持/卖出评级，注意分歧")

    # ── 目标价分析（预期差） ──
    current_price = rt.get("price")
    if avg_target and current_price and current_price > 0:
        upside = (avg_target - current_price) / current_price * 100
        findings.append(
            f"机构目标价：均值 {fmt(avg_target)}（上行空间 {upside:+.1f}%），"
            f"区间 {fmt(min_target)} ~ {fmt(max_target)}"
        )
        if upside >= 30:
            score += 2.0
            findings.append("✅ 机构目标价上行空间 > 30%，预期差显著")
        elif upside >= 15:
            score += 1.0
            findings.append("✅ 机构目标价上行空间 > 15%，有一定预期差")
        elif upside < 0:
            score -= 1.5
            findings.append(f"⚠️ 当前价格已超机构目标价（下行空间 {abs(upside):.1f}%），高估警示")
        elif upside < 5:
            findings.append(f"ℹ️ 机构目标价上行空间不足 5%，安全边际有限")

    # ── 研报分析 ──
    if reports:
        findings.append(f"近期研报：共 {len(reports)} 篇")
        latest = reports[0]
        findings.append(
            f"最新研报：{latest.get('institution', '')} "
            f"《{latest.get('title', '')[:30]}》"
            f"评级：{latest.get('rating', '')}，"
            f"目标价：{fmt(latest.get('target_price'))}"
        )
        # 近期研报频率判断
        if len(reports) >= 5:
            score += 0.5
            findings.append("✅ 研报覆盖度高（近期≥5篇），机构持续关注")
        elif len(reports) == 0:
            score -= 0.5
            findings.append("⚠️ 机构研报稀缺，关注度不足")

        # 研报密集度（是否有催化事件推动）
        recent_ratings = [r.get("rating", "") for r in reports[:5]]
        buy_ratings = [r for r in recent_ratings if "买入" in r or "增持" in r or "推荐" in r]
        if len(buy_ratings) >= 3:
            score += 0.5
            findings.append("✅ 近5篇研报中多数评级看多，机构共识强")
    else:
        findings.append("ℹ️ 暂未获取到机构研报数据")

    score = min(10.0, max(1.0, score))

    conclusion = (
        f"机构覆盖 {total} 家，买入评级占 {buy_ratio:.0f}%。"
        + (f"平均目标价 {fmt(avg_target)}，上行空间约 {(avg_target - current_price) / current_price * 100:.1f}%。"
           if avg_target and current_price else "")
    )

    return ModuleResult(
        module_id="M09",
        module_name="市场分歧与机构预期统计",
        score=round(score, 1),
        stars=score_to_stars(score),
        key_findings=findings,
        short_advice="关注研报超预期发布或评级上调，短线催化效应明显",
        mid_advice=f"{'机构共识做多，中线持有有支撑' if buy_ratio >= 60 else '机构分歧较大，中线需跟踪业绩兑现'}",
        long_advice=f"目标价空间{'充裕，长线价值显现' if avg_target and current_price and (avg_target - current_price) / current_price > 0.2 else '有限，长线需关注估值水平'}",
        conclusion=conclusion,
        detail={"consensus": consensus, "report_count": len(reports)},
    )
