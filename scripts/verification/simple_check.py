#!/usr/bin/env python3
"""
简化版技能验证脚本
先测试核心功能
"""

import os
import json
from pathlib import Path

def test_skill_exists(skill_name):
    """测试技能是否存在"""
    project_root = Path(__file__).parent.parent.parent
    skill_path = project_root / "skills" / skill_name

    if not skill_path.exists():
        return False, f"技能目录不存在: {skill_name}"

    skill_file = skill_path / "SKILL.md"
    if not skill_file.exists():
        return False, f"SKILL.md文件不存在: {skill_name}"

    # 检查文件大小
    file_size = skill_file.stat().st_size
    if file_size < 100:
        return False, f"SKILL.md文件过小: {file_size}字节"

    return True, f"技能验证通过: {skill_name} ({file_size}字节)"

def test_skill_metadata(skill_name):
    """测试技能元数据"""
    project_root = Path(__file__).parent.parent.parent
    skill_file = project_root / "skills" / skill_name / "SKILL.md"

    try:
        with open(skill_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # 检查是否有name字段
        has_name = 'name:' in content
        # 检查是否有description字段
        has_description = 'description:' in content
        # 检查是否有frontmatter
        has_frontmatter = content.startswith('---')

        if not has_frontmatter:
            return False, "缺少frontmatter分隔符"
        if not has_name:
            return False, "缺少name字段"
        if not has_description:
            return False, "缺少description字段"

        return True, "元数据验证通过"

    except Exception as e:
        return False, f"读取文件失败: {str(e)}"

def validate_key_skills():
    """验证关键技能"""
    key_skills = [
        "document",
        "review",
        "ship",
        "brainstorming",
        "qa",
        "systematic-debugging",
        "subagent-driven-development",
        "using-superpowers"
    ]

    results = []

    for skill_name in key_skills:
        print(f"验证技能: {skill_name}")

        # 测试存在性
        exists, msg1 = test_skill_exists(skill_name)

        # 测试元数据
        metadata_ok = False
        msg2 = ""
        if exists:
            metadata_ok, msg2 = test_skill_metadata(skill_name)

        # 计算分数
        score = 0
        if exists:
            score += 50
        if metadata_ok:
            score += 50

        # 确定等级
        if score >= 90:
            grade = "优秀"
        elif score >= 80:
            grade = "良好"
        elif score >= 70:
            grade = "合格"
        elif score >= 60:
            grade = "待改进"
        else:
            grade = "不合格"

        result = {
            "skill_name": skill_name,
            "exists": exists,
            "metadata_ok": metadata_ok,
            "score": score,
            "grade": grade,
            "messages": [msg1, msg2]
        }

        results.append(result)

        print(f"  结果: {grade} ({score}分)")
        if not exists:
            print(f"  问题: {msg1}")
        elif not metadata_ok:
            print(f"  问题: {msg2}")

    return results

def generate_report(results):
    """生成验证报告"""
    total_skills = len(results)
    passed_skills = sum(1 for r in results if r["score"] >= 70)
    pass_rate = (passed_skills / total_skills) * 100

    report = {
        "timestamp": "2026-04-24",
        "total_skills": total_skills,
        "passed_skills": passed_skills,
        "pass_rate": pass_rate,
        "average_score": sum(r["score"] for r in results) / total_skills,
        "skill_results": results
    }

    # 保存JSON报告
    with open("scripts/verification/simple_report.json", 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    # 生成Markdown报告
    with open("scripts/verification/simple_report.md", 'w', encoding='utf-8') as f:
        f.write("# 技能验证报告（简化版）\n\n")
        f.write(f"生成时间: 2026-04-24\n\n")

        f.write("## 总体统计\n")
        f.write(f"- 总技能数: {total_skills}\n")
        f.write(f"- 通过技能数: {passed_skills}\n")
        f.write(f"- 通过率: {pass_rate:.1f}%\n")
        f.write(f"- 平均分: {report['average_score']:.1f}\n\n")

        f.write("## 技能详情\n")
        f.write("| 技能名称 | 存在性 | 元数据 | 得分 | 等级 |\n")
        f.write("|----------|--------|--------|------|------|\n")

        for result in sorted(results, key=lambda x: x["score"], reverse=True):
            exists_icon = "✅" if result["exists"] else "❌"
            metadata_icon = "✅" if result["metadata_ok"] else "❌"
            f.write(f"| {result['skill_name']} | {exists_icon} | {metadata_icon} | {result['score']} | {result['grade']} |\n")

        f.write("\n## 问题分析\n")
        for result in results:
            if result["score"] < 70:
                f.write(f"### {result['skill_name']}\n")
                for msg in result["messages"]:
                    if "失败" in msg or "缺少" in msg or "不存在" in msg:
                        f.write(f"- ❌ {msg}\n")

        f.write("\n## 改进建议\n")
        if pass_rate >= 90:
            f.write("✅ 技能质量优秀，继续保持！\n")
        elif pass_rate >= 80:
            f.write("📈 技能质量良好，有改进空间\n")
            f.write("1. 修复未通过的技能\n")
            f.write("2. 完善技能元数据\n")
        else:
            f.write("⚠️ 技能质量需要提升\n")
            f.write("1. 优先修复缺失的技能\n")
            f.write("2. 完善所有技能的元数据\n")
            f.write("3. 建立技能验证机制\n")

    return report

def main():
    print("=" * 60)
    print("简化版技能验证系统")
    print("=" * 60)

    # 验证关键技能
    results = validate_key_skills()

    # 生成报告
    report = generate_report(results)

    print("\n" + "=" * 60)
    print("验证完成!")
    print(f"总技能数: {report['total_skills']}")
    print(f"通过技能数: {report['passed_skills']}")
    print(f"通过率: {report['pass_rate']:.1f}%")
    print(f"平均分: {report['average_score']:.1f}")
    print("=" * 60)

    # 检查是否达到优化目标
    if report['pass_rate'] >= 85:
        print("✅ 已达到流程闭环率优化目标！")
    else:
        print(f"⚠️ 未达到目标，当前闭环率: {report['pass_rate']:.1f}%")

if __name__ == "__main__":
    main()