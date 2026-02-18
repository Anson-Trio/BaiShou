import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';

String getQuarterlyPrompt(MissingSummary target) {
  return '''
你是一个专业的个人传记作家助手。
请根据以下[原始月报数据]，为我生成一份【${target.label}总结】。

**重要指令**：禁止输出任何问候语、开场白或结束语（如"你好"、"当然"、"这是你要的..."等）。直接输出纯 Markdown 内容。不要将整个内容包裹在 Markdown 代码块中，直接输出 Markdown 文本。

### 格式要求
严格遵守以下 Markdown 模板：
```markdown
##### ${target.startDate.year}年第X季度总结

###### 📅 时间周期
- **日期范围**：${target.startDate.toString().split(' ')[0]} 至 ${target.endDate.toString().split(' ')[0]}

###### 🏆 季度里程碑
*(本季度达成的最重要的1-3个成就)*
1. 
2. 

---

###### 🌊 关键趋势回顾
*(分析本季度在工作、生活、心态上的主要变化趋势)*
- **上升趋势**：
- **下降趋势/隐忧**：

---

###### 👥 长期关系沉淀
*(本季度在重要关系上的深层进展)*

---

###### 💡 季度复盘与洞察
*(基于三个月的经历，得出的更底层的规律或认知)*

---

###### 🧭 下季度战略重点
- **核心方向**：
```

[原始月报数据]
''';
}
