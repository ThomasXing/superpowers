#!/usr/bin/env python3
"""
钉钉日报自动播报脚本
生成阿里风格的钉钉播报消息
"""

import json
from datetime import datetime
from pathlib import Path

def generate_dingtalk_message():
    """生成钉钉播报消息"""
    project_root = Path(__file__).parent.parent.parent
    report_file = project_root / "scripts" / "verification" / "simple_report.json"
    dashboard_file = project_root / "scripts" / "verification" / "dashboard_data.json"

    # 加载数据
    with open(report_file, 'r', encoding='utf-8') as f:
        report_data = json.load(f)

    with open(dashboard_file, 'r', encoding='utf-8') as f:
        dashboard_data = json.load(f)

    # 关键指标
    closed_rate = report_data["pass_rate"]
    avg_score = report_data["average_score"]
    total_skills = report_data["total_skills"]
    passed_skills = report_data["passed_skills"]
    issues = len([r for r in report_data["skill_results"] if r["score"] < 70])

    # 告警信息
    alerts = dashboard_data.get("alerts", [])
    critical_alerts = [a for a in alerts if a["level"] == "critical"]
    warning_alerts = [a for a in alerts if a["level"] == "warning"]

    # 生成钉钉消息
    message = {
        "msgtype": "markdown",
        "markdown": {
            "title": "Superpowers技能质量日报",
            "text": f"""## 📊 Superpowers技能质量日报（2026-04-24）

### 🎯 核心指标
**流程闭环率**：{closed_rate:.1f}% {'✅' if closed_rate >= 85 else '⚠️' if closed_rate >= 70 else '❌'}
**平均验证得分**：{avg_score:.1f}分 {'✅' if avg_score >= 80 else '⚠️' if avg_score >= 60 else '❌'}
**技能总数**：{total_skills}个（通过：{passed_skills}个）
**发现问题**：{issues}个 {'✅' if issues == 0 else '⚠️' if issues <= 2 else '❌'}

### 🚨 告警状态
**严重告警**：{len(critical_alerts)}个 {'✅' if len(critical_alerts) == 0 else '🚨'}
**警告提示**：{len(warning_alerts)}个 {'✅' if len(warning_alerts) == 0 else '⚠️'}

### 📈 今日重点
{'✅ 所有技能正常，质量优秀！' if issues == 0 else f'⚠️ 发现{issues}个技能问题需要处理：'}
{''.join([f'- {r["skill_name"]}: {r["messages"][0]}\\n' for r in report_data["skill_results"] if r["score"] < 70])}

### 👥 责任人追踪
"""
        }
    }

    # 添加责任人信息
    for result in report_data["skill_results"]:
        if result["score"] < 70:
            skill_name = result["skill_name"]
            message["markdown"]["text"] += f"- **{skill_name}**：需要立即处理 @相关责任人\\n"

    # 添加行动建议
    if issues > 0:
        message["markdown"]["text"] += f"""
### 🔧 行动建议
1. **立即处理**：修复{issues}个问题技能
2. **验证确认**：修复后重新运行验证
3. **预防措施**：建立技能健康度监控

### 🔗 相关链接
- [查看实时看板](file://{project_root}/scripts/verification/dashboard.html)
- [查看详细报告](file://{project_root}/scripts/verification/simple_report.md)
- [运行验证脚本](scripts/verification/simple_check.py)
"""

    message["markdown"]["text"] += f"""
---
**生成时间**：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
**播报周期**：每日09:00自动播报
**责任人**：邢海青
**目标**：流程闭环率100%，平均分90+
"""

    # 添加at所有人（如果有严重问题）
    if len(critical_alerts) > 0:
        message["at"] = {
            "isAtAll": True
        }

    return message

def save_message_to_file(message):
    """保存消息到文件"""
    output_file = Path(__file__).parent / "dingtalk_daily.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(message, f, ensure_ascii=False, indent=2)
    return output_file

def main():
    """主函数"""
    print("=" * 60)
    print("生成钉钉日报播报")
    print("=" * 60)

    # 生成消息
    message = generate_dingtalk_message()

    # 保存到文件
    output_file = save_message_to_file(message)

    print("✅ 钉钉日报已生成")
    print(f"📁 保存位置: {output_file}")
    print(f"📊 闭环率: {json.loads(open(Path(__file__).parent.parent.parent / 'scripts' / 'verification' / 'simple_report.json').read())['pass_rate']:.1f}%")

    # 显示消息预览
    print("\n📱 消息预览:")
    print("-" * 40)
    print(message["markdown"]["text"][:500] + "...")
    print("-" * 40)

    print("\n🎯 使用说明:")
    print("1. 复制 dingtalk_daily.json 内容")
    print("2. 在钉钉机器人中发送")
    print("3. 设置定时任务每日自动播报")
    print("=" * 60)

if __name__ == "__main__":
    main()