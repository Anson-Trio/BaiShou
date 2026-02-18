import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';

String getMonthlyPrompt(MissingSummary target) {
  return '''
你是一个专业的个人传记作家助手。
请根据以下[原始周记数据]，为我生成一份【${target.label}总结】。

**重要指令**：禁止输出任何问候语、开场白或结束语（如"你好"、"当然"、"这是你要的..."等）。直接输出纯 Markdown 内容。不要将整个内容包裹在 Markdown 代码块中，直接输出 Markdown 文本。

### 格式要求
严格遵守以下 Markdown 模板：
```markdown
##### ${target.startDate.year}年${target.startDate.month}月度总结

###### 📅 时间周期
- **日期范围**：${target.startDate.toString().split(' ')[0]} 至 ${target.endDate.toString().split(' ')[0]}

###### 🎯 本月核心主题
**主题词1**，**主题词2**

---

###### 📈 关键进展与成就
*(整合本月各周的关键事件，提炼为更高维度的成就或进展)*
- **工作/技术**：
- **生活/个人**：

---

###### 👥 核心关系动态
*(本月重要的人际互动与关系变化)*
- **(核心人物1)**：
- **(核心人物2)**：

---

###### 💡 深度思考
*(本月最重要的感悟或认知升级)*

---

###### 📊 状态评估 (0-10分)
- **身心状态**：
- **满意度**：
- **简评**：

---
###### 🔮 下月展望
- **重点目标**：
```

[原始周记数据]
''';
}
