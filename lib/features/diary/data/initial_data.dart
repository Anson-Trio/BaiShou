List<Map<String, dynamic>> initialDiaries = [
  {
    'content':
        '今天终于把项目的架子搭起来了！虽然只是个开始，但看着空白的画布被一点点填满，心里充满了成就感。\n\n特别是设计图标的时候，想了好久，最后决定用小白狐作为我们的吉祥物。它象征着灵动和守护，就像我希望“白守”能带给每一个用户的感觉一样。\n\n加油！一定要把这个 App 做到最好！',
    'date': DateTime.now().subtract(const Duration(days: 0)).toIso8601String(),
    'tags': ['开发日志', '心情', '新开始'],
  },
  {
    'content':
        '今天调试了一个超级顽固的 Bug，明明逻辑都对，就是跑不通。最后发现居然是一个该死的拼写错误！气死我了！😤\n\n不过解决掉的那一瞬间，所有的郁闷都烟消云散了。这就是编程的魅力吧，痛并快乐着。',
    'date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    'tags': ['Bug修复', '痛苦', '快乐'],
  },
  {
    'content':
        '下雨了。🌧️\n\n喜欢雨天，听着雨声敲打窗户的声音，感觉世界都安静下来了。泡了一杯热咖啡，一边喝一边写代码，感觉效率特别高。\n\n要是能一直这样安静下去就好了。',
    'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    'tags': ['雨天', '咖啡', '平静'],
  },
  {
    'content':
        '今天去试了那家新开的拉面店。🍜\n\n汤头很浓郁，面条也很劲道，但是... 只有三片肉！三片！老板你也太抠了吧！\n\n下次不去了，哼。',
    'date': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    'tags': ['美食', '吐槽', '拉面'],
  },
  {
    'content':
        '突然想到了一个绝妙的点子！✨\n\n如果在日记列表里加入时间轴的设计，会不会更有代入感？就像是在回溯自己的人生轨迹一样。\n\n赶紧记下来，明天去试试看！',
    'date': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
    'tags': ['灵感', '功能设计', '兴奋'],
  },
  {
    'content': '今天好累啊... 感觉身体被掏空。😵\n\n连续加班了好几天，脑子都有点转不动了。今晚早点睡吧，狗命要紧。',
    'date': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
    'tags': ['加班', '疲惫', '休息'],
  },
  {
    'content':
        '在路上看到了一只流浪猫，橘色的，胖胖的。🐱\n\n它一点都不怕人，还主动蹭我的裤腿。可惜家里不能养宠物，不然真想把它带回去。\n\n给它买了一根火腿肠，希望它能吃饱一点。',
    'date': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(),
    'tags': ['猫咪', '偶遇', '温暖'],
  },
  {
    'content':
        '终于到了周末！🎉\n\n睡到了自然醒，然后把家里彻底打扫了一遍。看着整洁的房间，心情也变得明亮起来。\n\n下午打算去看场电影，听说最近上映的那部科幻片很不错。',
    'date': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
    'tags': ['周末', '大扫除', '放松'],
  },
  {
    'content': '看完电影回来了。🎬\n\n讲真，特效很棒，但是剧情稍微有点拉胯。有些逻辑根本讲不通嘛！\n\n不过爆米花很好吃，这就够了。',
    'date': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
    'tags': ['电影', '影评', '爆米花'],
  },
  {
    'content':
        '今天尝试做了一道新菜：红烧肉。🍖\n\n虽然卖相不太好，黑乎乎的，但是味道意外地还不错！肥而不腻，入口即化。\n\n看来我有当大厨的潜质啊，哈哈！',
    'date': DateTime.now().subtract(const Duration(days: 9)).toIso8601String(),
    'tags': ['厨艺', '红烧肉', '自恋'],
  },
  {
    'content':
        '心情有点低落。☁️\n\n感觉自己最近进步好慢，有点迷茫。看着别人一个个都那么厉害，心里难免会焦虑。\n\n但是路还是要一步一步走的，对吧？只要不放弃，总会变好的。',
    'date': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
    'tags': ['迷茫', '自我反省', '鼓励'],
  },
  {
    'content':
        '不仅修好了之前的 Bug，还顺手把性能优化提升了 20%！🚀\n\n我也太强了吧！今天的我，是无敌的！\n\n奖励自己一杯奶茶！🥤',
    'date': DateTime.now().subtract(const Duration(days: 11)).toIso8601String(),
    'tags': ['性能优化', '成就感', '奶茶'],
  },
  {
    'content':
        '读完了一本书，《悉达多》。📖\n\n深受震撼。关于寻找自我，关于体验生命。所有的经历，无论是好是坏，都是生命的一部分。\n\n我也在寻找我的“道”吗？',
    'date': DateTime.now().subtract(const Duration(days: 12)).toIso8601String(),
    'tags': ['阅读', '思考', '人生'],
  },
  {
    'content':
        '今天去公园散步，看到樱花开了。🌸\n\n粉白色的花瓣随风飘落，美得像一幅画。春天真的来了啊。\n\n拍了好多照片，每张都想做成壁纸！',
    'date': DateTime.now().subtract(const Duration(days: 13)).toIso8601String(),
    'tags': ['春天', '樱花', '摄影'],
  },
  {
    'content':
        '收到了一份意外的礼物！🎁\n\n居然是之前随口提到过的那个机械键盘！太惊喜了！\n\n敲击的手感简直完美，写代码都更有动力了！',
    'date': DateTime.now().subtract(const Duration(days: 14)).toIso8601String(),
    'tags': ['礼物', '惊喜', '机械键盘'],
  },
  {
    'content':
        '今天被拉去参加了一个毫无意义的会议。💤\n\n明明一封邮件就能说清楚的事情，非要讲两个小时。简直是浪费生命！\n\n以后这种会能躲就躲，太折磨人了。',
    'date': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
    'tags': ['开会', '吐槽', '效率'],
  },
  {
    'content':
        '在地铁上看到了一个很可爱的小宝宝，一直冲着我笑。👶\n\n那一瞬间，心都要化了。小孩子的笑容真的是世界上最治愈的东西。\n\n希望能一直保持这份纯真。',
    'date': DateTime.now().subtract(const Duration(days: 16)).toIso8601String(),
    'tags': ['治愈', '宝宝', '微笑'],
  },
  {
    'content':
        '今天挑战了自己，去跑了 5 公里！🏃‍♂️\n\n虽然跑到一半就快断气了，但我还是坚持下来了！\n\n出汗的感觉真爽，感觉整个人都轻盈了。以后要坚持锻炼！',
    'date': DateTime.now().subtract(const Duration(days: 17)).toIso8601String(),
    'tags': ['运动', '跑步', '坚持'],
  },
  {
    'content':
        '整理以前的老照片，发现了很多小时候的回忆。📷\n\n那时候无忧无虑，每天只想着怎么玩。现在长大了，烦恼虽然多了，但也拥有了更多。\n\n珍惜当下吧。',
    'date': DateTime.now().subtract(const Duration(days: 18)).toIso8601String(),
    'tags': ['回忆', '老照片', '感慨'],
  },
  {
    'content':
        '“白守”的初版终于快要完成了！🏁\n\n回顾这段时间的努力，真的感慨万千。从一个简单的想法，到现在初具雏形，每一步都凝聚了心血。\n\n但这只是个开始，未来还有很长的路要走。我们一起加油！',
    'date': DateTime.now().subtract(const Duration(days: 19)).toIso8601String(),
    'tags': ['里程碑', '总结', '展望'],
  },
];
