/// 总结 Prompt 模板
///
/// 统一使用中文提示词（AI 模型都能理解中文 prompt）

class PromptTemplates {
  static const _persona = '你是一个专业的个人传记作家助手。';

  static const _defaultInstructions =
      '**重要指令**：禁止输出任何问候语、开场白或结束语（如"你好"、"当然"、"这是你要的..."等）。'
      '直接输出纯 Markdown 内容。不要将整个内容包裹在 Markdown 代码块中，直接输出 Markdown 文本。';

  // ─── 周总结 ────────────────────────────────────────────

  static String buildWeekly({
    required int year,
    required int month,
    required int week,
    required String startStr,
    required String endStr,
    String? customInstructions,
  }) {
    final instructions = customInstructions ?? _defaultInstructions;

    return '''
$_persona
周总结 ($year-$month-$week)
$instructions

### Markdown Template:
```markdown
##### ${year}年${month}月第${week}周总结

###### 📅 时间周期
- **日期范围**: $startStr 至 $endStr

###### 🎯 本周核心关键词
**关键词1**, **关键词2**, **关键词3**

---

###### 👥 核心人物与关系进展
- **(人物 1)**:
- **(人物 2)**:

---

###### 🎞️ 关键事件回顾 (Timeline)
- **【事件标题】**
    - **细节**:
    - **意义**:

---

###### 💡 思考与认知迭代
- **关于技术/工作**:
- **关于生活/自我**:

---

###### 📊 状态评估
- **身心能量**:
- **本周遗憾**:
- **下周展望**:

---
###### 🍵 给月度总结的"胶囊"
> (一句话概括)
```
''';
  }

  // ─── 月度总结 ──────────────────────────────────────────

  static String buildMonthly({
    required int year,
    required int month,
    required String startStr,
    required String endStr,
    String? customInstructions,
  }) {
    final instructions = customInstructions ?? _defaultInstructions;

    return '''
$_persona
月度总结 ($year-$month)
$instructions

### Markdown Template:
```markdown
##### ${year}年${month}月度总结

###### 📅 日期范围
- **范围**: $startStr 至 $endStr

###### 🎯 本月核心主题
**主题1**, **主题2**

---

###### 📈 关键进展与成就
- **工作/技术**:
- **生活/个人**:

---

###### 👥 核心关系动态
- **(人物 1)**:
- **(人物 2)**:

---

###### 💡 深度思考

---

###### 📊 状态评估 (0-10)
- **状态**:
- **满意度**:

---
###### 🔮 下月展望
- **重点方向**:
```
''';
  }

  // ─── 季度总结 ──────────────────────────────────────────

  static String buildQuarterly({
    required int year,
    required int quarter,
    required String startStr,
    required String endStr,
    String? customInstructions,
  }) {
    final instructions = customInstructions ?? _defaultInstructions;

    return '''
$_persona
季度总结 ($year Q$quarter)
$instructions

### Markdown Template:
```markdown
##### ${year}年第${quarter}季度总结

###### 📅 日期范围
- **范围**: $startStr 至 $endStr

###### 🏆 季度里程碑
1. 
2. 

---

###### 🌊 关键趋势回顾
- **上升趋势**:
- **下降趋势**:

---

###### 👥 长期关系沉淀

---

###### 💡 季度复盘与洞察

---

###### 🧭 下季度战略重点
- **核心方向**:
```
''';
  }

  // ─── 年度总结 ──────────────────────────────────────────

  static String buildYearly({
    required int year,
    required String startStr,
    required String endStr,
    String? customInstructions,
  }) {
    final instructions = customInstructions ?? _defaultInstructions;

    return '''
$_persona
年度回顾 ($year)
$instructions

### Markdown Template:
```markdown
# $year 年度回顾：(用一个词定义这一年)

###### 📅 日期范围
- **范围**: $startStr 至 $endStr

---

###### 🌟 年度高光时刻
1. 
2. 

---

###### 🗺️ 生命轨迹回顾
- **Q1**:
- **Q2**:
- **Q3**:
- **Q4**:

---

###### 👥 年度重要关系

---

###### 🧠 认知觉醒

---

###### 💌 给未来的一封信
> 
```
''';
  }
}
