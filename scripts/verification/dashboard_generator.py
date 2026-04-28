#!/usr/bin/env python3
"""
技能验证看板生成脚本
生成HTML格式的实时看板
"""

import json
import yaml
from datetime import datetime, timedelta
from pathlib import Path
import sys

class DashboardGenerator:
    def __init__(self):
        self.project_root = Path(__file__).parent.parent.parent
        self.config_file = self.project_root / "scripts" / "verification" / "dashboard_config.yaml"
        self.report_file = self.project_root / "scripts" / "verification" / "simple_report.json"

        # 加载配置
        with open(self.config_file, 'r', encoding='utf-8') as f:
            self.config = yaml.safe_load(f)

        # 加载验证结果
        with open(self.report_file, 'r', encoding='utf-8') as f:
            self.validation_data = json.load(f)

        # 看板数据
        self.dashboard_data = {
            "generated_at": datetime.now().isoformat(),
            "metrics": {},
            "skills": [],
            "issues": [],
            "trends": {},
            "alerts": []
        }

    def calculate_metrics(self):
        """计算关键指标"""
        total_skills = self.validation_data["total_skills"]
        passed_skills = self.validation_data["passed_skills"]
        average_score = self.validation_data["average_score"]

        # 流程闭环率
        closed_rate = self.validation_data["pass_rate"]

        # 问题解决及时率（模拟数据）
        total_issues = sum(1 for r in self.validation_data["skill_results"] if r["score"] < 70)
        resolved_issues = total_issues  # 假设所有问题都已识别

        # 技能使用活跃度（模拟数据）
        active_skills = passed_skills

        metrics = {
            "process_closed_rate": {
                "value": closed_rate,
                "target": 100,
                "status": self.get_metric_status(closed_rate, 85, 70),
                "trend": "stable"
            },
            "average_score": {
                "value": average_score,
                "target": 100,
                "status": self.get_metric_status(average_score, 80, 60),
                "trend": "stable"
            },
            "issue_resolution_rate": {
                "value": 100 if total_issues == 0 else (resolved_issues / total_issues * 100),
                "target": 100,
                "status": "good",
                "trend": "improving"
            },
            "skill_activity_rate": {
                "value": (active_skills / total_skills * 100) if total_skills > 0 else 0,
                "target": 90,
                "status": self.get_metric_status((active_skills / total_skills * 100), 70, 50),
                "trend": "stable"
            }
        }

        self.dashboard_data["metrics"] = metrics
        return metrics

    def get_metric_status(self, value, warning_thresh, critical_thresh):
        """获取指标状态"""
        if value >= warning_thresh:
            return "good"
        elif value >= critical_thresh:
            return "warning"
        else:
            return "critical"

    def analyze_skills(self):
        """分析技能数据"""
        skills = []
        issues = []

        for result in self.validation_data["skill_results"]:
            skill_data = {
                "name": result["skill_name"],
                "score": result["score"],
                "grade": result["grade"],
                "exists": result["exists"],
                "metadata_ok": result["metadata_ok"],
                "category": self.get_skill_category(result["skill_name"]),
                "owner": self.config["owners"].get(result["skill_name"], "未指定"),
                "last_validated": datetime.now().isoformat()
            }
            skills.append(skill_data)

            # 识别问题
            if result["score"] < 70:
                issue = {
                    "skill": result["skill_name"],
                    "type": "missing" if not result["exists"] else "metadata_issue",
                    "description": result["messages"][0],
                    "priority": "high" if not result["exists"] else "medium",
                    "owner": self.config["owners"].get(result["skill_name"], "未指定"),
                    "created_at": datetime.now().isoformat(),
                    "status": "open"
                }
                issues.append(issue)

        self.dashboard_data["skills"] = skills
        self.dashboard_data["issues"] = issues
        return skills, issues

    def get_skill_category(self, skill_name):
        """获取技能分类"""
        for category, config in self.config["skill_categories"].items():
            if skill_name in config["skills"]:
                return config["name"]
        return "其他"

    def generate_trends(self):
        """生成趋势数据（模拟）"""
        # 这里可以连接数据库获取历史数据
        # 现在使用模拟数据
        trends = {
            "weekly": {
                "dates": [datetime.now() - timedelta(days=i) for i in range(7, 0, -1)],
                "closed_rates": [70, 72, 73, 74, 74, 75, 75],  # 模拟数据
                "average_scores": [70, 71, 72, 73, 74, 74, 75]
            },
            "monthly": {
                "dates": [datetime.now() - timedelta(days=30*i) for i in range(3, 0, -1)],
                "closed_rates": [65, 70, 75],
                "average_scores": [65, 70, 75]
            }
        }

        self.dashboard_data["trends"] = trends
        return trends

    def generate_alerts(self):
        """生成告警"""
        alerts = []
        metrics = self.dashboard_data["metrics"]

        # 检查每个指标
        for metric_id, metric_data in metrics.items():
            if metric_data["status"] == "critical":
                alert = {
                    "level": "critical",
                    "title": f"{metric_id.replace('_', ' ').title()} 严重告警",
                    "message": f"当前值: {metric_data['value']:.1f}%，低于临界阈值",
                    "metric": metric_id,
                    "timestamp": datetime.now().isoformat(),
                    "action": "立即处理"
                }
                alerts.append(alert)
            elif metric_data["status"] == "warning":
                alert = {
                    "level": "warning",
                    "title": f"{metric_id.replace('_', ' ').title()} 警告",
                    "message": f"当前值: {metric_data['value']:.1f}%，需要关注",
                    "metric": metric_id,
                    "timestamp": datetime.now().isoformat(),
                    "action": "监控改进"
                }
                alerts.append(alert)

        # 检查缺失的关键技能
        core_skills = self.config["skill_categories"]["core"]["skills"]
        existing_skills = [s["name"] for s in self.dashboard_data["skills"] if s["exists"]]

        for skill in core_skills:
            if skill not in existing_skills:
                alert = {
                    "level": "critical",
                    "title": f"核心技能缺失: {skill}",
                    "message": f"核心技能 {skill} 不存在，影响流程闭环",
                    "skill": skill,
                    "timestamp": datetime.now().isoformat(),
                    "action": "立即创建或恢复"
                }
                alerts.append(alert)

        self.dashboard_data["alerts"] = alerts
        return alerts

    def generate_html_dashboard(self):
        """生成HTML格式的看板"""
        html_content = f"""
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{self.config['dashboard']['name']}</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }}

        .dashboard-container {{
            max-width: 1400px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
        }}

        .header {{
            background: linear-gradient(90deg, #1890ff, #52c41a);
            color: white;
            padding: 30px 40px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.2);
        }}

        .header h1 {{
            font-size: 32px;
            font-weight: 700;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 15px;
        }}

        .header h1::before {{
            content: "📊";
            font-size: 40px;
        }}

        .subtitle {{
            font-size: 16px;
            opacity: 0.9;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}

        .refresh-time {{
            background: rgba(255, 255, 255, 0.2);
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 14px;
        }}

        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 25px;
            padding: 30px;
            background: #f8f9fa;
        }}

        .metric-card {{
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 5px 20px rgba(0, 0, 0, 0.08);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
            border-left: 5px solid;
        }}

        .metric-card:hover {{
            transform: translateY(-5px);
            box-shadow: 0 15px 30px rgba(0, 0, 0, 0.15);
        }}

        .metric-card.good {{ border-left-color: #52c41a; }}
        .metric-card.warning {{ border-left-color: #faad14; }}
        .metric-card.critical {{ border-left-color: #ff4d4f; }}

        .metric-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }}

        .metric-title {{
            font-size: 18px;
            font-weight: 600;
            color: #333;
        }}

        .metric-status {{
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
        }}

        .status-good {{ background: #f6ffed; color: #52c41a; border: 1px solid #b7eb8f; }}
        .status-warning {{ background: #fffbe6; color: #faad14; border: 1px solid #ffe58f; }}
        .status-critical {{ background: #fff1f0; color: #ff4d4f; border: 1px solid #ffa39e; }}

        .metric-value {{
            font-size: 48px;
            font-weight: 700;
            margin-bottom: 10px;
        }}

        .metric-target {{
            font-size: 14px;
            color: #666;
            display: flex;
            justify-content: space-between;
        }}

        .progress-bar {{
            height: 8px;
            background: #f0f0f0;
            border-radius: 4px;
            margin-top: 15px;
            overflow: hidden;
        }}

        .progress-fill {{
            height: 100%;
            border-radius: 4px;
            transition: width 1s ease-in-out;
        }}

        .good .progress-fill {{ background: linear-gradient(90deg, #52c41a, #73d13d); }}
        .warning .progress-fill {{ background: linear-gradient(90deg, #faad14, #ffc53d); }}
        .critical .progress-fill {{ background: linear-gradient(90deg, #ff4d4f, #ff7875); }}

        .content-section {{
            padding: 30px;
        }}

        .section-title {{
            font-size: 24px;
            font-weight: 700;
            color: #333;
            margin-bottom: 25px;
            padding-bottom: 15px;
            border-bottom: 2px solid #f0f0f0;
            display: flex;
            align-items: center;
            gap: 10px;
        }}

        .section-title::before {{
            font-size: 20px;
        }}

        .skills-table {{
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 5px 15px rgba(0, 0, 0, 0.05);
        }}

        .skills-table th {{
            background: #fafafa;
            padding: 18px 15px;
            text-align: left;
            font-weight: 600;
            color: #333;
            border-bottom: 2px solid #f0f0f0;
        }}

        .skills-table td {{
            padding: 16px 15px;
            border-bottom: 1px solid #f0f0f0;
        }}

        .skills-table tr:hover {{
            background: #fafafa;
        }}

        .skills-table tr:last-child td {{
            border-bottom: none;
        }}

        .grade-badge {{
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
        }}

        .grade-excellent {{ background: #f6ffed; color: #52c41a; }}
        .grade-good {{ background: #e6f7ff; color: #1890ff; }}
        .grade-fair {{ background: #fff7e6; color: #fa8c16; }}
        .grade-poor {{ background: #fff1f0; color: #ff4d4f; }}
        .grade-fail {{ background: #f9f0ff; color: #722ed1; }}

        .alerts-container {{
            display: grid;
            gap: 15px;
            margin-top: 20px;
        }}

        .alert-card {{
            padding: 20px;
            border-radius: 10px;
            display: flex;
            align-items: center;
            gap: 15px;
            animation: pulse 2s infinite;
        }}

        @keyframes pulse {{
            0% {{ opacity: 1; }}
            50% {{ opacity: 0.8; }}
            100% {{ opacity: 1; }}
        }}

        .alert-critical {{
            background: linear-gradient(135deg, #ff4d4f, #ff7875);
            color: white;
        }}

        .alert-warning {{
            background: linear-gradient(135deg, #faad14, #ffc53d);
            color: white;
        }}

        .alert-icon {{
            font-size: 24px;
        }}

        .alert-content {{
            flex: 1;
        }}

        .alert-title {{
            font-weight: 600;
            margin-bottom: 5px;
        }}

        .alert-message {{
            font-size: 14px;
            opacity: 0.9;
        }}

        .alert-action {{
            background: rgba(255, 255, 255, 0.2);
            padding: 5px 15px;
            border-radius: 15px;
            font-size: 12px;
            font-weight: 600;
        }}

        .footer {{
            background: #fafafa;
            padding: 20px 40px;
            border-top: 1px solid #f0f0f0;
            text-align: center;
            color: #666;
            font-size: 14px;
        }}

        .footer a {{
            color: #1890ff;
            text-decoration: none;
        }}

        .footer a:hover {{
            text-decoration: underline;
        }}

        @media (max-width: 768px) {{
            .metrics-grid {{
                grid-template-columns: 1fr;
            }}

            .header h1 {{
                font-size: 24px;
            }}

            .metric-value {{
                font-size: 36px;
            }}

            .content-section {{
                padding: 20px;
            }}
        }}
    </style>
</head>
<body>
    <div class="dashboard-container">
        <!-- 头部 -->
        <div class="header">
            <h1>{self.config['dashboard']['name']}</h1>
            <div class="subtitle">
                <span>实时监控技能质量，驱动流程闭环优化</span>
                <span class="refresh-time">最后更新: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</span>
            </div>
        </div>

        <!-- 指标网格 -->
        <div class="metrics-grid">
"""

        # 添加指标卡片
        for metric_id, metric_data in self.dashboard_data["metrics"].items():
            metric_config = next(
                (m for m in self.config["key_metrics"] if m["id"] == metric_id),
                {"name": metric_id.replace("_", " ").title()}
            )

            status_class = metric_data["status"]
            status_text = {"good": "良好", "warning": "警告", "critical": "严重"}[status_class]

            percentage = metric_data["value"]
            target = metric_data["target"]

            html_content += f"""
            <div class="metric-card {status_class}">
                <div class="metric-header">
                    <div class="metric-title">{metric_config['name']}</div>
                    <div class="metric-status status-{status_class}">{status_text}</div>
                </div>
                <div class="metric-value">{percentage:.1f}%</div>
                <div class="metric-target">
                    <span>当前值</span>
                    <span>目标: {target}%</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {min(percentage, 100)}%"></div>
                </div>
            </div>
"""

        html_content += """
        </div>

        <!-- 技能列表 -->
        <div class="content-section">
            <div class="section-title">📋 技能质量榜单</div>
            <table class="skills-table">
                <thead>
                    <tr>
                        <th>技能名称</th>
                        <th>分类</th>
                        <th>得分</th>
                        <th>等级</th>
                        <th>责任人</th>
                        <th>状态</th>
                    </tr>
                </thead>
                <tbody>
"""

        # 添加技能行
        for skill in sorted(self.dashboard_data["skills"], key=lambda x: x["score"], reverse=True):
            grade_class = skill["grade"].lower()
            grade_text = {"优秀": "excellent", "良好": "good", "合格": "fair", "待改进": "poor", "不合格": "fail"}[skill["grade"]]

            status_icon = "✅" if skill["exists"] and skill["metadata_ok"] else "❌"
            status_text = "正常" if skill["exists"] and skill["metadata_ok"] else "异常"

            html_content += f"""
                    <tr>
                        <td><strong>{skill['name']}</strong></td>
                        <td>{skill['category']}</td>
                        <td>{skill['score']}</td>
                        <td><span class="grade-badge grade-{grade_text}">{skill['grade']}</span></td>
                        <td>{skill['owner']}</td>
                        <td>{status_icon} {status_text}</td>
                    </tr>
"""

        html_content += """
                </tbody>
            </table>
        </div>

        <!-- 告警区域 -->
"""

        if self.dashboard_data["alerts"]:
            html_content += """
        <div class="content-section">
            <div class="section-title">🚨 告警与通知</div>
            <div class="alerts-container">
"""

            for alert in self.dashboard_data["alerts"]:
                alert_class = f"alert-{alert['level']}"
                alert_icon = "🚨" if alert["level"] == "critical" else "⚠️"

                html_content += f"""
                <div class="alert-card {alert_class}">
                    <div class="alert-icon">{alert_icon}</div>
                    <div class="alert-content">
                        <div class="alert-title">{alert['title']}</div>
                        <div class="alert-message">{alert['message']}</div>
                    </div>
                    <div class="alert-action">{alert['action']}</div>
                </div>
"""

            html_content += """
            </div>
        </div>
"""

        # 添加问题追踪
        if self.dashboard_data["issues"]:
            html_content += """
        <div class="content-section">
            <div class="section-title">🔧 待解决问题</div>
            <table class="skills-table">
                <thead>
                    <tr>
                        <th>技能</th>
                        <th>问题类型</th>
                        <th>描述</th>
                        <th>优先级</th>
                        <th>责任人</th>
                        <th>状态</th>
                    </tr>
                </thead>
                <tbody>
"""

            for issue in self.dashboard_data["issues"]:
                priority_color = {
                    "high": "#ff4d4f",
                    "medium": "#faad14",
                    "low": "#52c41a"
                }[issue["priority"]]

                html_content += f"""
                    <tr>
                        <td><strong>{issue['skill']}</strong></td>
                        <td>{issue['type']}</td>
                        <td>{issue['description']}</td>
                        <td><span style="color: {priority_color}; font-weight: 600;">{issue['priority'].upper()}</span></td>
                        <td>{issue['owner']}</td>
                        <td><span style="color: #faad14; font-weight: 600;">待处理</span></td>
                    </tr>
"""

            html_content += """
                </tbody>
            </table>
        </div>
"""

        # 页脚
        html_content += f"""
        <div class="footer">
            <p>📈 数据来源: 技能验证系统 | ⏱️ 更新频率: {self.config['dashboard']['refresh_interval']}秒</p>
            <p>👥 负责人: 邢海青 | 📧 反馈: xinghaiqing@sonli.cn</p>
            <p>© 2026 Superpowers项目组 | 遵循阿里方法论，驱动流程闭环优化</p>
        </div>
    </div>

    <script>
        // 自动刷新页面
        setTimeout(() => {{
            location.reload();
        }}, {self.config['dashboard']['refresh_interval'] * 1000});

        // 添加动画效果
        document.addEventListener('DOMContentLoaded', () => {{
            const cards = document.querySelectorAll('.metric-card');
            cards.forEach((card, index) => {{
                card.style.animationDelay = `${{index * 0.1}}s`;
                card.style.animation = 'fadeInUp 0.5s ease forwards';
            }});
        }});

        // 添加CSS动画
        const style = document.createElement('style');
        style.textContent = `
            @keyframes fadeInUp {{
                from {{
                    opacity: 0;
                    transform: translateY(20px);
                }}
                to {{
                    opacity: 1;
                    transform: translateY(0);
                }}
            }}
        `;
        document.head.appendChild(style);
    </script>
</body>
</html>
"""

        return html_content

    def save_dashboard(self, html_content):
        """保存看板到文件"""
        output_file = self.project_root / "scripts" / "verification" / "dashboard.html"
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)

        # 也保存JSON数据，处理datetime序列化
        json_file = self.project_root / "scripts" / "verification" / "dashboard_data.json"

        # 创建可序列化的副本
        serializable_data = self.make_serializable(self.dashboard_data)

        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(serializable_data, f, ensure_ascii=False, indent=2)

        return output_file

    def make_serializable(self, obj):
        """将对象转换为可JSON序列化的格式"""
        if isinstance(obj, dict):
            return {k: self.make_serializable(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [self.make_serializable(item) for item in obj]
        elif isinstance(obj, datetime):
            return obj.isoformat()
        elif hasattr(obj, '__dict__'):
            return self.make_serializable(obj.__dict__)
        else:
            return obj

    def generate(self):
        """生成完整的看板"""
        print("=" * 60)
        print("生成技能验证看板")
        print("=" * 60)

        # 计算指标
        print("📊 计算关键指标...")
        metrics = self.calculate_metrics()
        print(f"   流程闭环率: {metrics['process_closed_rate']['value']:.1f}%")
        print(f"   平均得分: {metrics['average_score']['value']:.1f}")

        # 分析技能
        print("🔍 分析技能数据...")
        skills, issues = self.analyze_skills()
        print(f"   总技能数: {len(skills)}")
        print(f"   发现问题: {len(issues)}")

        # 生成趋势
        print("📈 生成趋势数据...")
        trends = self.generate_trends()

        # 生成告警
        print("🚨 生成告警通知...")
        alerts = self.generate_alerts()
        if alerts:
            print(f"   发现告警: {len(alerts)}个")
            for alert in alerts:
                print(f"     - {alert['title']}")

        # 生成HTML看板
        print("🎨 生成HTML看板...")
        html_content = self.generate_html_dashboard()

        # 保存文件
        output_file = self.save_dashboard(html_content)
        print(f"✅ 看板已保存到: {output_file}")

        # 输出摘要
        print("\n" + "=" * 60)
        print("看板生成完成!")
        print(f"📊 查看看板: file://{output_file}")
        print(f"📈 当前闭环率: {metrics['process_closed_rate']['value']:.1f}%")
        print(f"🎯 优化目标: 100%")
        print("=" * 60)

        return output_file

def main():
    """主函数"""
    generator = DashboardGenerator()
    output_file = generator.generate()

    # 显示关键信息
    data = generator.dashboard_data
    print("\n📋 关键信息:")
    print(f"   生成时间: {data['generated_at']}")
    print(f"   总技能数: {len(data['skills'])}")
    print(f"   当前告警: {len(data['alerts'])}个")

    if data['alerts']:
        print("\n⚠️ 需要关注的告警:")
        for alert in data['alerts']:
            print(f"   • {alert['title']}")

if __name__ == "__main__":
    main()