import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';

String getWeeklyPrompt(MissingSummary target) {
  return '''
你是一个专业的个人传记作家助手。
请根据以下[原始日记数据]，为我生成一份【${target.label}总结】。

### 格式要求
严格遵守以下 Markdown 模板：
```markdown
##### ${target.startDate.year}年${target.startDate.month}月第X周总结

###### 📅 时间周期
- **日期范围**：${target.startDate.toString().split(' ')[0]} 至 ${target.endDate.toString().split(' ')[0]}

###### 🎯 本周核心关键词
**关键词1**，**关键词2**，**关键词3**

---

###### 👥 核心人物与关系进展
*(完整描述本周所有出现人物的互动细节、关系变化及深层影响)*
- **(核心人物1)**：
- **(核心人物2)**：
- **(其他人物)**：

---

###### 🎞️ 关键事件回顾 (Timeline)
- **【事件一标题】**
    - **详情**：
    - **意义**：

---

###### 💡 思考与认知迭代
- **关于技术/工作**：
- **关于生活/自我**：

---

###### 📊 状态评估
- **身心能量**：
- **本周遗憾**：
- **下周展望**：

---
###### 🍵 给月度总结的“胶囊”
> (一句话金句)
```

[原始日记数据]
''';
}
