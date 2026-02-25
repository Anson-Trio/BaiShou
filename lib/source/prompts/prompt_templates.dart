import 'package:baishou/i18n/strings.g.dart';

class PromptTemplates {
  static String getSystemPersona(AppLocale locale) {
    switch (locale) {
      case AppLocale.en:
        return 'You are a professional personal biographer assistant.';
      case AppLocale.ja:
        return 'あなたはプロのパーソナルバイオグラファーの助手です。';
      case AppLocale.zhTw:
        return '你是一個專業的個人傳記作家助手。';
      case AppLocale.zh:
        return '你是一个专业的个人传记作家助手。';
    }
  }

  static String getInstructions(AppLocale locale) {
    switch (locale) {
      case AppLocale.en:
        return '**IMPORTANT INSTRUCTIONS**: DO NOT output any greetings, introductions, or conclusions (e.g., "Hello", "Sure", "Here is your..."). Output pure Markdown content directly. Do not wrap the entire output in a Markdown code block; output Markdown text directly.';
      case AppLocale.ja:
        return '**重要な指示**：挨拶、導入、結びの言葉（例：「こんにちは」、「もちろんです」、「こちらが...」など）は一切出力しないでください。純粋なMarkdown内容を直接出力してください。出力全体をMarkdownコードブロックで囲まないでください。直接Markdownテキストを出力してください。';
      case AppLocale.zhTw:
        return '**重要指令**：禁止輸出任何問候語、開場白或結束語（如"你好"、"當然"、"這是你要的..."等）。直接輸出純 Markdown 內容。不要將整個內容包裹在 Markdown 代碼塊中，直接輸出 Markdown 文本。';
      case AppLocale.zh:
        return '**重要指令**：禁止输出任何问候语、开场白或结束语（如"你好"、"当然"、"这是你要的..."等）。直接输出纯 Markdown 内容。不要将整个内容包裹在 Markdown 代码块中，直接输出 Markdown 文本。';
    }
  }

  static Map<String, String> getWeeklyLabels(AppLocale locale) {
    switch (locale) {
      case AppLocale.en:
        return {
          'summary_title': 'Weekly Summary',
          'time_period': 'Time Period',
          'date_range': 'Date Range',
          'keywords': 'Weekly Core Keywords',
          'relationships': 'Core Characters & Relationship Progress',
          'timeline': 'Key Events Review (Timeline)',
          'insights': 'Thoughts & Cognitive Iterations',
          'tech': 'About Tech/Work',
          'life': 'About Life/Self',
          'assessment': 'Status Assessment',
          'energy': 'Mental & Physical Energy',
          'regrets': 'Weekly Regrets',
          'outlook': 'Next Week Outlook',
          'capsule': '“Capsule” for Monthly Summary',
        };
      case AppLocale.ja:
        return {
          'summary_title': '週間まとめ',
          'time_period': '期間',
          'date_range': '日付範囲',
          'keywords': '今週のキーワード',
          'relationships': '主要人物と関係の進展',
          'timeline': '主要イベント回想 (タイムライン)',
          'insights': '思考と認知のアップデート',
          'tech': '技術/仕事について',
          'life': '生活/自己について',
          'assessment': '状態評価',
          'energy': '心身のエネルギー',
          'regrets': '今週の反省',
          'outlook': '来週の展望',
          'capsule': '月間まとめへの「カプセル」',
        };
      case AppLocale.zhTw:
        return {
          'summary_title': '週總結',
          'time_period': '時間週期',
          'date_range': '日期範圍',
          'keywords': '本週核心關鍵詞',
          'relationships': '核心人物與關係進展',
          'timeline': '關鍵事件回顧 (Timeline)',
          'insights': '思考與認知迭代',
          'tech': '關於技術/工作',
          'life': '關於生活/自我',
          'assessment': '狀態評估',
          'energy': '身心能量',
          'regrets': '本週遺憾',
          'outlook': '下週展望',
          'capsule': '給月度總結的“膠囊”',
        };
      case AppLocale.zh:
        return {
          'summary_title': '周总结',
          'time_period': '时间周期',
          'date_range': '日期范围',
          'keywords': '本周核心关键词',
          'relationships': '核心人物与关系进展',
          'timeline': '关键事件回顾 (Timeline)',
          'insights': '思考与认知迭代',
          'tech': '关于技术/工作',
          'life': '关于生活/自我',
          'assessment': '状态评估',
          'energy': '身心能量',
          'regrets': '本周遗憾',
          'outlook': '下週展望',
          'capsule': '给月度总结的“胶囊”',
        };
    }
  }

  static Map<String, String> getMonthlyLabels(AppLocale locale) {
    switch (locale) {
      case AppLocale.en:
        return {
          'summary_title': 'Monthly Summary',
          'theme': 'Monthly Core Theme',
          'achievements': 'Key Progress & Achievements',
          'relationships': 'Core Relationship Dynamics',
          'insights': 'Deep Insights',
          'assessment': 'Status Assessment (0-10)',
          'outlook': 'Next Month Outlook',
        };
      case AppLocale.ja:
        return {
          'summary_title': '月間まとめ',
          'theme': '今月のコアテーマ',
          'achievements': '主要な進捗と成果',
          'relationships': '主要な関係性の動態',
          'insights': '深い洞察',
          'assessment': '状態評価 (0-10)',
          'outlook': '来月の展望',
        };
      case AppLocale.zhTw:
        return {
          'summary_title': '月度總結',
          'theme': '本月核心主題',
          'achievements': '關鍵進展與成就',
          'relationships': '核心關係動態',
          'insights': '深度思考',
          'assessment': '狀態評估 (0-10)',
          'outlook': '下月展望',
        };
      case AppLocale.zh:
        return {
          'summary_title': '月度总结',
          'theme': '本月核心主题',
          'achievements': '关键进展与成就',
          'relationships': '核心关系动态',
          'insights': '深度思考',
          'assessment': '状态评估 (0-10)',
          'outlook': '下月展望',
        };
    }
  }

  static Map<String, String> getQuarterlyLabels(AppLocale locale) {
    switch (locale) {
      case AppLocale.en:
        return {
          'summary_title': 'Quarterly Summary',
          'milestones': 'Quarterly Milestones',
          'trends': 'Key Trends Review',
          'relationships': 'Long-term Relationship Accumulation',
          'insights': 'Quarterly Review & Insights',
          'strategy': 'Next Quarter Strategic Priorities',
        };
      case AppLocale.ja:
        return {
          'summary_title': '四半期まとめ',
          'milestones': '今四半期のマイルストーン',
          'trends': '主要トレンドの回想',
          'relationships': '長期的な関係の蓄積',
          'insights': '四半期の振り返りと洞察',
          'strategy': '次四半期の戦略的重点',
        };
      case AppLocale.zhTw:
        return {
          'summary_title': '季度總結',
          'milestones': '季度里程碑',
          'trends': '關鍵趨勢回顧',
          'relationships': '長期關係沉澱',
          'insights': '季度複盤與洞察',
          'strategy': '下季度戰略重點',
        };
      case AppLocale.zh:
        return {
          'summary_title': '季度总结',
          'milestones': '季度里程碑',
          'trends': '关键趋势回顾',
          'relationships': '长期关系沉淀',
          'insights': '季度复盘与洞察',
          'strategy': '下季度战略重点',
        };
    }
  }

  static Map<String, String> getYearlyLabels(AppLocale locale) {
    switch (locale) {
      case AppLocale.en:
        return {
          'summary_title': 'Yearly Review',
          'highlights': 'Yearly Highlights',
          'trajectory': 'Life Trajectory Review',
          'relationships': 'Yearly Important Relationships',
          'awakening': 'Cognitive Awakening',
          'letter': 'A Letter to the Future Self',
        };
      case AppLocale.ja:
        return {
          'summary_title': '年間回顧',
          'highlights': '今年のハイライト',
          'trajectory': '人生の軌跡の回顧',
          'relationships': '今年の重要な関係性',
          'awakening': '認知の覚醒',
          'letter': '未来の自分への手紙',
        };
      case AppLocale.zhTw:
        return {
          'summary_title': '年度回顧',
          'highlights': '年度高光時刻',
          'trajectory': '生命軌跡回顧',
          'relationships': '年度重要關係',
          'awakening': '認知覺醒',
          'letter': '給未來的一封信',
        };
      case AppLocale.zh:
        return {
          'summary_title': '年度回顾',
          'highlights': '年度高光时刻',
          'trajectory': '生命轨迹回顾',
          'relationships': '年度重要关系',
          'awakening': '认知觉醒',
          'letter': '给未来的一封信',
        };
    }
  }

  static String buildWeekly(
    AppLocale locale, {
    required int year,
    required int month,
    required int week,
    required String startStr,
    required String endStr,
  }) {
    final labels = getWeeklyLabels(locale);
    final persona = getSystemPersona(locale);
    final instructions = getInstructions(locale);

    final header = locale == AppLocale.en
        ? '##### ${year} Summary for Week ${week} of ${month}'
        : locale == AppLocale.ja
        ? '##### ${year}年${month}月第${week}週のまとめ'
        : '##### ${year}年${month}月第${week}周总结';
    final toLabel = locale == AppLocale.en
        ? 'to'
        : locale == AppLocale.ja
        ? '～'
        : '至';

    return '''
$persona
${labels['summary_title']} (${year}-${month}-${week})
$instructions

### Markdown Template:
```markdown
$header

###### 📅 ${labels['time_period']}
- **${labels['date_range']}**: $startStr $toLabel $endStr

###### 🎯 ${labels['keywords']}
**Keyword1**, **Keyword2**, **Keyword3**

---

###### 👥 ${labels['relationships']}
- **(Character 1)**:
- **(Character 2)**:

---

###### 🎞️ ${labels['timeline']}
- **【Event Title】**
    - **Detail**:
    - **Meaning**:

---

###### 💡 ${labels['insights']}
- **${labels['tech']}**:
- **${labels['life']}**:

---

###### 📊 ${labels['assessment']}
- **${labels['energy']}**:
- **${labels['regrets']}**:
- **${labels['outlook']}**:

---
###### 🍵 ${labels['capsule']}
> (One-liner)
```
''';
  }

  static String buildMonthly(
    AppLocale locale, {
    required int year,
    required int month,
    required String startStr,
    required String endStr,
  }) {
    final labels = getMonthlyLabels(locale);
    final persona = getSystemPersona(locale);
    final instructions = getInstructions(locale);

    final header = locale == AppLocale.en
        ? '##### ${year} Monthly Summary for ${month}'
        : locale == AppLocale.ja
        ? '##### ${year}年${month}月の月間まとめ'
        : '##### ${year}年${month}月度总结';
    final toLabel = locale == AppLocale.en
        ? 'to'
        : locale == AppLocale.ja
        ? '～'
        : '至';

    return '''
$persona
${labels['summary_title']} (${year}-${month})
$instructions

### Markdown Template:
```markdown
$header

###### 📅 Date Range
- **Range**: $startStr $toLabel $endStr

###### 🎯 ${labels['theme']}
**Theme1**, **Theme2**

---

###### 📈 ${labels['achievements']}
- **Work/Tech**:
- **Life/Personal**:

---

###### 👥 ${labels['relationships']}
- **(Character 1)**:
- **(Character 2)**:

---

###### 💡 ${labels['insights']}

---

###### 📊 ${labels['assessment']}
- **Status**:
- **Satisfaction**:

---
###### 🔮 ${labels['outlook']}
- **Focus**:
```
''';
  }

  static String buildQuarterly(
    AppLocale locale, {
    required int year,
    required int quarter,
    required String startStr,
    required String endStr,
  }) {
    final labels = getQuarterlyLabels(locale);
    final persona = getSystemPersona(locale);
    final instructions = getInstructions(locale);

    final header = locale == AppLocale.en
        ? '##### ${year} Quarterly Summary for Q${quarter}'
        : locale == AppLocale.ja
        ? '##### ${year}年第${quarter}四半期まとめ'
        : '##### ${year}年第${quarter}季度总结';
    final toLabel = locale == AppLocale.en
        ? 'to'
        : locale == AppLocale.ja
        ? '～'
        : '至';

    return '''
$persona
${labels['summary_title']} (${year} Q${quarter})
$instructions

### Markdown Template:
```markdown
$header

###### 📅 Date Range
- **Range**: $startStr $toLabel $endStr

###### 🏆 ${labels['milestones']}
1. 
2. 

---

###### 🌊 ${labels['trends']}
- **Upward**:
- **Downward**:

---

###### 👥 ${labels['relationships']}

---

###### 💡 ${labels['insights']}

---

###### 🧭 ${labels['strategy']}
- **Core Direction**:
```
''';
  }

  static String buildYearly(
    AppLocale locale, {
    required int year,
    required String startStr,
    required String endStr,
  }) {
    final labels = getYearlyLabels(locale);
    final persona = getSystemPersona(locale);
    final instructions = getInstructions(locale);

    final toLabel = locale == AppLocale.en
        ? 'to'
        : locale == AppLocale.ja
        ? '～'
        : '至';

    return '''
$persona
${labels['summary_title']} (${year})
$instructions

### Markdown Template:
```markdown
# ${year} Year in Review: (Define this year in one word)

###### 📅 Date Range
- **Range**: $startStr $toLabel $endStr

---

###### 🌟 ${labels['highlights']}
1. 
2. 

---

###### 🗺️ ${labels['trajectory']}
- **Q1**:
- **Q2**:
- **Q3**:
- **Q4**:

---

###### 👥 ${labels['relationships']}

---

###### 🧠 ${labels['awakening']}

---

###### 💌 ${labels['letter']}
> 
```
''';
  }
}
