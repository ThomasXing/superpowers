#!/usr/bin/env python3
"""
技能验证自动化检查脚本
版本：v1.0
责任人：邢海青
功能：自动检查所有技能的质量指标并生成报告
"""

import os
import sys
import yaml
import subprocess
import json
from datetime import datetime
from pathlib import Path

class SkillValidator:
    def __init__(self, metrics_file="metrics_simple.yaml"):
        self.project_root = Path(__file__).parent.parent.parent
        self.skills_dir = self.project_root / "skills"
        self.metrics_file = Path(__file__).parent / metrics_file

        # 加载验证指标
        with open(self.metrics_file, 'r', encoding='utf-8') as f:
            self.metrics = yaml.safe_load(f)

        # 验证结果存储
        self.results = {
            "timestamp": datetime.now().isoformat(),
            "total_skills": 0,
            "checked_skills": 0,
            "skill_scores": {},
            "summary": {},
            "issues": []
        }

    def get_skill_type(self, skill_name):
        """根据技能名称判断技能类型"""
        skill_type_map = {
            "document": "document",
            "review": "quality",
            "ship": "development",
            "qa": "quality",
            "brainstorming": "development",
            "systematic-debugging": "development",
            "subagent-driven-development": "development",
            "writing-skills": "development",
            "using-superpowers": "development"
        }
        return skill_type_map.get(skill_name, "development")

    def run_validation(self, validation_cmd, skill_path):
        """执行验证命令并返回结果"""
        try:
            env = os.environ.copy()
            env["SKILL_PATH"] = str(skill_path)

            result = subprocess.run(
                validation_cmd,
                shell=True,
                capture_output=True,
                text=True,
                cwd=skill_path,
                env=env,
                timeout=30
            )

            return {
                "success": result.returncode == 0,
                "stdout": result.stdout.strip(),
                "stderr": result.stderr.strip(),
                "returncode": result.returncode
            }
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "stdout": "",
                "stderr": "验证超时（30秒）",
                "returncode": -1
            }
        except Exception as e:
            return {
                "success": False,
                "stdout": "",
                "stderr": str(e),
                "returncode": -1
            }

    def check_metric(self, metric, skill_path, skill_name):
        """检查单个指标"""
        validation_cmd = metric.get("validation", "")
        if not validation_cmd:
            return 0, "无验证命令"

        result = self.run_validation(validation_cmd, skill_path)

        # 检查成功模式
        success_pattern = metric.get("success_pattern")
        success_min = metric.get("success_min")

        if success_pattern:
            # 模式匹配验证
            if success_pattern in result["stdout"]:
                return metric["weight"], f"通过: {result['stdout'][:50]}"
            else:
                return 0, f"失败: 期望模式 '{success_pattern}'，实际: {result['stdout'][:50]}"

        elif success_min is not None:
            # 数值最小值验证
            try:
                value = int(result["stdout"])
                if value >= success_min:
                    return metric["weight"], f"通过: {value} >= {success_min}"
                else:
                    return 0, f"失败: {value} < {success_min}"
            except ValueError:
                return 0, f"失败: 无法解析数值 '{result['stdout']}'"

        else:
            # 简单成功/失败验证
            if result["success"]:
                return metric["weight"], f"通过: {result['stdout'][:50]}"
            else:
                return 0, f"失败: {result['stderr'][:50]}"

    def validate_skill(self, skill_name):
        """验证单个技能"""
        skill_path = self.skills_dir / skill_name

        if not skill_path.exists():
            self.results["issues"].append(f"技能目录不存在: {skill_name}")
            return None

        skill_type = self.get_skill_type(skill_name)
        skill_metrics = []

        # 添加通用指标
        skill_metrics.extend(self.metrics["universal_metrics"])

        # 添加类型特定指标
        if skill_type in self.metrics["skill_type_metrics"]:
            skill_metrics.extend(self.metrics["skill_type_metrics"][skill_type])

        # 执行验证
        total_score = 0
        max_score = sum(metric["weight"] for metric in skill_metrics)
        validation_details = []

        for metric in skill_metrics:
            score, message = self.check_metric(metric, skill_path, skill_name)
            total_score += score

            validation_details.append({
                "metric": metric["name"],
                "score": score,
                "max_score": metric["weight"],
                "message": message
            })

        # 计算百分比
        if max_score > 0:
            percentage = (total_score / max_score) * 100
        else:
            percentage = 0

        # 确定等级
        for level, (min_score, max_score) in {
            "excellent": (90, 100),
            "good": (80, 89),
            "fair": (70, 79),
            "poor": (60, 69),
            "fail": (0, 59)
        }.items():
            if min_score <= percentage <= max_score:
                grade = level
                break
        else:
            grade = "fail"

        return {
            "skill_name": skill_name,
            "skill_type": skill_type,
            "score": total_score,
            "max_score": max_score,
            "percentage": percentage,
            "grade": grade,
            "details": validation_details,
            "owner": self.metrics["owners"].get(skill_name, "未指定"),
            "validated_at": datetime.now().isoformat()
        }

    def validate_all_skills(self):
        """验证所有技能"""
        skill_dirs = [d for d in self.skills_dir.iterdir() if d.is_dir()]
        self.results["total_skills"] = len(skill_dirs)

        for skill_dir in skill_dirs:
            skill_name = skill_dir.name
            print(f"正在验证技能: {skill_name}")

            result = self.validate_skill(skill_name)
            if result:
                self.results["checked_skills"] += 1
                self.results["skill_scores"][skill_name] = result

                # 记录问题
                if result["grade"] in ["fail", "poor"]:
                    self.results["issues"].append(
                        f"{skill_name}: 评分{result['grade']} ({result['percentage']:.1f}%)"
                    )

        # 生成摘要
        self.generate_summary()

    def generate_summary(self):
        """生成验证摘要"""
        if not self.results["skill_scores"]:
            return

        total_percentage = sum(r["percentage"] for r in self.results["skill_scores"].values())
        avg_percentage = total_percentage / self.results["checked_skills"]

        # 等级分布
        grade_distribution = {}
        for result in self.results["skill_scores"].values():
            grade = result["grade"]
            grade_distribution[grade] = grade_distribution.get(grade, 0) + 1

        # 类型分布
        type_scores = {}
        for result in self.results["skill_scores"].values():
            skill_type = result["skill_type"]
            if skill_type not in type_scores:
                type_scores[skill_type] = []
            type_scores[skill_type].append(result["percentage"])

        type_avg = {}
        for skill_type, scores in type_scores.items():
            type_avg[skill_type] = sum(scores) / len(scores)

        self.results["summary"] = {
            "average_score": avg_percentage,
            "grade_distribution": grade_distribution,
            "type_averages": type_avg,
            "issues_count": len(self.results["issues"]),
            "validation_rate": (self.results["checked_skills"] / self.results["total_skills"]) * 100
        }

    def save_results(self, output_dir="."):
        """保存验证结果"""
        output_path = Path(output_dir)

        # 保存JSON结果
        json_file = output_path / "validation_results.json"
        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(self.results, f, ensure_ascii=False, indent=2)

        # 生成Markdown报告
        self.generate_markdown_report(output_path / "validation_report.md")

        # 生成简化的看板数据
        self.generate_dashboard_data(output_path / "dashboard.json")

        print(f"验证完成！结果已保存到: {output_path}")
        print(f"平均分: {self.results['summary']['average_score']:.1f}%")
        print(f"问题数: {self.results['summary']['issues_count']}")

    def generate_markdown_report(self, output_file):
        """生成Markdown格式的报告"""
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(f"# 技能验证报告\n")
            f.write(f"生成时间: {self.results['timestamp']}\n\n")

            f.write(f"## 验证摘要\n")
            f.write(f"- 总技能数: {self.results['total_skills']}\n")
            f.write(f"- 已验证技能: {self.results['checked_skills']}\n")
            f.write(f"- 验证率: {self.results['summary']['validation_rate']:.1f}%\n")
            f.write(f"- 平均得分: {self.results['summary']['average_score']:.1f}%\n")
            f.write(f"- 发现问题: {self.results['summary']['issues_count']}个\n\n")

            f.write(f"## 等级分布\n")
            for grade, count in self.results["summary"]["grade_distribution"].items():
                percentage = (count / self.results["checked_skills"]) * 100
                f.write(f"- {grade}: {count}个 ({percentage:.1f}%)\n")

            f.write(f"\n## 按类型平均分\n")
            for skill_type, avg_score in self.results["summary"]["type_averages"].items():
                f.write(f"- {skill_type}: {avg_score:.1f}%\n")

            f.write(f"\n## 详细结果\n")
            f.write(f"| 技能名称 | 类型 | 得分 | 等级 | 责任人 |\n")
            f.write(f"|----------|------|------|------|--------|\n")

            for skill_name, result in sorted(
                self.results["skill_scores"].items(),
                key=lambda x: x[1]["percentage"],
                reverse=True
            ):
                f.write(f"| {skill_name} | {result['skill_type']} | {result['percentage']:.1f}% | {result['grade']} | {result['owner']} |\n")

            if self.results["issues"]:
                f.write(f"\n## 发现问题\n")
                for issue in self.results["issues"]:
                    f.write(f"- {issue}\n")

            f.write(f"\n## 建议改进项\n")
            f.write(f"1. **立即修复**：评分'fail'的技能需要优先处理\n")
            f.write(f"2. **质量提升**：评分'poor'的技能需要制定改进计划\n")
            f.write(f"3. **最佳实践**：评分'excellent'的技能可以作为模板\n")
            f.write(f"4. **自动化**：增加更多自动化验证点\n")

    def generate_dashboard_data(self, output_file):
        """生成看板数据"""
        dashboard_data = {
            "timestamp": self.results["timestamp"],
            "summary": self.results["summary"],
            "top_skills": [],
            "bottom_skills": [],
            "trend_data": {
                "date": datetime.now().strftime("%Y-%m-%d"),
                "average_score": self.results["summary"]["average_score"],
                "issues_count": self.results["summary"]["issues_count"]
            }
        }

        # 前3名技能
        sorted_skills = sorted(
            self.results["skill_scores"].items(),
            key=lambda x: x[1]["percentage"],
            reverse=True
        )

        for skill_name, result in sorted_skills[:3]:
            dashboard_data["top_skills"].append({
                "name": skill_name,
                "score": result["percentage"],
                "owner": result["owner"]
            })

        # 后3名技能
        for skill_name, result in sorted_skills[-3:]:
            dashboard_data["bottom_skills"].append({
                "name": skill_name,
                "score": result["percentage"],
                "owner": result["owner"]
            })

        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(dashboard_data, f, ensure_ascii=False, indent=2)

def main():
    """主函数"""
    validator = SkillValidator()

    print("=" * 60)
    print("开始技能验证检查")
    print("=" * 60)

    # 验证所有技能
    validator.validate_all_skills()

    # 保存结果
    output_dir = Path(__file__).parent
    validator.save_results(output_dir)

    # 输出关键指标
    summary = validator.results["summary"]
    print("\n" + "=" * 60)
    print("关键指标:")
    print(f"  平均分: {summary['average_score']:.1f}%")
    print(f"  问题数: {summary['issues_count']}")
    print(f"  验证率: {summary['validation_rate']:.1f}%")

    # 列出需要改进的技能
    issues = validator.results["issues"]
    if issues:
        print(f"\n需要改进的技能:")
        for issue in issues[:5]:  # 只显示前5个
            print(f"  - {issue}")

    print("=" * 60)

if __name__ == "__main__":
    main()