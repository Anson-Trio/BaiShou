import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';

String getYearlyPrompt(MissingSummary target) {
  return '''
你是一个专业的个人传记作家助手。
请根据以下[原始季度/月度数据]，为我生成一份【${target.label}年鉴】。

### 格式要求
严格遵守以下 Markdown 模板：
```markdown
# ${target.startDate.year} 年度回顾：(用一个词定义这一年)

###### 📅 时间跨度
- **日期范围**：${target.startDate.toString().split(' ')[0]} 至 ${target.endDate.toString().split(' ')[0]}

---

###### 🌟 年度高光时刻 (Highlights)
*(这一年最值得纪念的3-5个瞬间或成就)*
1. 
2. 
3. 

---

###### 🗺️ 生命轨迹回顾
*(按时间线梳理全年的主要阶段和转折点)*
- **第一季度**：
- **第二季度**：
- **第三季度**：
- **第四季度**：

---

###### 👥 年度重要关系
*(这一年谁对你影响最深？谁是你最重要的陪伴？)*

---

###### 🧠 认知觉醒
*(这一年你学到的最重要的道理，或价值观的改变)*

---

###### 💌 给未来的一封信
*(基于今年的经历，给明年的自己写一段话)*
> 

```

[原始季度/月度数据]
''';
}
