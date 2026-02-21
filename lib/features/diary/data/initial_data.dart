List<Map<String, dynamic>> initialDiaries = [
  {
    'content':
        '今天终于把项目的架子搭起来了！虽然只是个开始，但看着空白的画布被一点点填满，心里充满了成就感。\n\n特别是设计图标的时候，想了好久，最后决定用小白狐作为我们的吉祥物。它象征着灵动和守护，就像我希望"白守"能带给每一个用户的感觉一样。\n\n加油！一定要把这个 App 做到最好！',
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
        '读完了一本书，《被讨厌的勇气》。📖\n\n深受震撼。关于寻找自我，关于体验生命。所有的经历，无论是好是坏，都是生命的一部分。',
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
        '"白守"的初版终于快要完成了！🏁\n\n回顾这段时间的努力，真的感慨万千。从一个简单的想法，到现在初具雏形，每一步都凝聚了心血。\n\n但这只是个开始，未来还有很长的路要走。我们一起加油！',
    'date': DateTime.now().subtract(const Duration(days: 19)).toIso8601String(),
    'tags': ['里程碑', '总结', '展望'],
  },
  // 以下是新增的 40 条
  {
    'content': '早上起来发现路边开了一片野花，黄色的，密密麻麻的。\n\n手机随手一拍，竟然特别好看。生活里的小惊喜，真的很治愈。',
    'date': DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
    'tags': ['日常', '野花', '治愈'],
  },
  {
    'content':
        '今天点了外卖，配送员迟到了四十分钟。\n\n饭都凉了。😒 不过看了看评论区，发现大家都在夸配送员辛苦，心里有点复杂。\n\n算了，下次早点下单。',
    'date': DateTime.now().subtract(const Duration(days: 21)).toIso8601String(),
    'tags': ['外卖', '吐槽', '反思'],
  },
  {
    'content': '今天和朋友打了两个小时的羽毛球。\n\n输了三局，赢了一局，但感觉还是很开心。运动真的能把所有烦恼都挥散出去。',
    'date': DateTime.now().subtract(const Duration(days: 22)).toIso8601String(),
    'tags': ['运动', '羽毛球', '朋友'],
  },
  {
    'content':
        '今天读到一句话："慢慢来，比较快。"\n\n很简单，但莫名地让我安心了很多。最近总觉得自己太着急了，什么都想立刻做好。\n\n放慢一点，也没关系。',
    'date': DateTime.now().subtract(const Duration(days: 23)).toIso8601String(),
    'tags': ['感悟', '心态', '成长'],
  },
  {
    'content':
        '今天去了一家很小的独立书店。\n\n店主养了一只猫，懒洋洋地趴在收银台上。店里只有我一个顾客，安静极了。\n\n买了两本不认识的作者写的书，期待一下。',
    'date': DateTime.now().subtract(const Duration(days: 24)).toIso8601String(),
    'tags': ['书店', '猫', '阅读'],
  },
  {
    'content':
        '发现一家新的咖啡店，装修很有意思，灯光很暗，放的都是老歌。\n\n点了一杯手冲，坐了两个小时。一行代码没写，但感觉思路清晰了很多。',
    'date': DateTime.now().subtract(const Duration(days: 25)).toIso8601String(),
    'tags': ['咖啡', '探店', '放空'],
  },
  {
    'content':
        '今天学了一个新的算法，理解起来费了一番功夫。\n\n翻了三篇文章，画了两张草图，最后终于搞明白了。\n\n感觉大脑被锻炼到了，有点累，但很充实。',
    'date': DateTime.now().subtract(const Duration(days: 26)).toIso8601String(),
    'tags': ['学习', '算法', '充实'],
  },
  {
    'content':
        '晚上突然停电了，整栋楼都黑了。\n\n翻出了一根蜡烛，点上之后，感觉房间里有一种很特别的温柔。\n\n停电的两个小时，我什么都没做，就发了会儿呆。挺好的。',
    'date': DateTime.now().subtract(const Duration(days: 27)).toIso8601String(),
    'tags': ['停电', '发呆', '安静'],
  },
  {
    'content':
        '今天做了一件一直拖着没做的事：整理了乱了半年的电脑桌面。\n\n删了几百个没用的文件，清理了三个 G 的缓存。\n\n看着干净的桌面，感觉人生都干净了。',
    'date': DateTime.now().subtract(const Duration(days: 28)).toIso8601String(),
    'tags': ['整理', '效率', '清爽'],
  },
  {
    'content': '和妈妈视频了半个小时。她说最近腰不太好，让我不要担心，我还是担心了。\n\n打算这个月回去一趟。',
    'date': DateTime.now().subtract(const Duration(days: 29)).toIso8601String(),
    'tags': ['家人', '思念', '计划'],
  },
  {
    'content':
        '今天突然下了大雨，没带伞。\n\n在便利店躲了一个小时雨，顺便买了一个饭团、一包薯片和一瓶牛奶。\n\n雨里的便利店，格外温暖。',
    'date': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
    'tags': ['雨天', '便利店', '温暖'],
  },
  {
    'content':
        '今天看到楼下有人在放风筝，风很大，风筝飞得很高很高。\n\n站在那里看了很久，心里空空的，但不是难受的那种空，是很轻盈的感觉。',
    'date': DateTime.now().subtract(const Duration(days: 31)).toIso8601String(),
    'tags': ['风筝', '轻盈', '日常'],
  },
  {
    'content':
        '今天写了一个很复杂的 SQL 查询，脑子转了很久。\n\n最后看到结果跑出来的那一刻，太爽了！数据库真的很有魅力，感觉像是在和数据对话。',
    'date': DateTime.now().subtract(const Duration(days: 32)).toIso8601String(),
    'tags': ['数据库', '成就感', '编程'],
  },
  {
    'content': '考虑了很久，今天终于下单了一双跑鞋。\n\n之前一直用的球鞋跑步，脚踝有点不舒服。给自己的健康投资嘛，值得的。',
    'date': DateTime.now().subtract(const Duration(days: 33)).toIso8601String(),
    'tags': ['购物', '运动', '健康'],
  },
  {
    'content':
        '今天骑车去了一个从来没去过的地方，随意拐弯，最后迷路了。\n\n在一条小巷子里发现了一家很小的饺子馆，吃了一碗猪肉白菜的，五块钱，好吃到哭。',
    'date': DateTime.now().subtract(const Duration(days: 34)).toIso8601String(),
    'tags': ['骑车', '探索', '美食'],
  },
  {
    'content':
        '今天失眠了，三点钟还没睡着。\n\n索性起来喝了杯热牛奶，听了一会儿轻音乐，最后四点多迷迷糊糊睡着了。\n\n明天大概率会很困，但也没办法了。',
    'date': DateTime.now().subtract(const Duration(days: 35)).toIso8601String(),
    'tags': ['失眠', '夜晚', '牛奶'],
  },
  {
    'content':
        '学了点水彩，画了一个小苹果。\n\n说实话，画得很丑，完全不像苹果。但是过程很解压，拿着笔在纸上涂涂抹抹，什么都不想。\n\n明天画一个梨试试。',
    'date': DateTime.now().subtract(const Duration(days: 36)).toIso8601String(),
    'tags': ['水彩', '手工', '解压'],
  },
  {
    'content': '今天收到了两年前买的那本书的续集终于出版的通知。\n\n立刻下单，发货了！期待度拉满！',
    'date': DateTime.now().subtract(const Duration(days: 37)).toIso8601String(),
    'tags': ['阅读', '期待', '购书'],
  },
  {
    'content': '今天帮室友搬了个柜子，腰酸了一整天。\n\n深刻认识到：家具一定要买能拆装的。\n\n以后买家当，先看能不能自己扛上楼。',
    'date': DateTime.now().subtract(const Duration(days: 38)).toIso8601String(),
    'tags': ['搬家具', '腰疼', '教训'],
  },
  {
    'content':
        '今天尝试了冥想，在 B 站跟着一个视频练了十五分钟。\n\n前五分钟脑子里乱七八糟什么都在想，后来慢慢安静了一点。\n\n明天继续试试，听说坚持下去挺有效的。',
    'date': DateTime.now().subtract(const Duration(days: 39)).toIso8601String(),
    'tags': ['冥想', '尝试', '放松'],
  },
  {
    'content':
        '今天看了一部老电影，九十年代的，画质很差，但故事很好。\n\n里面有句台词："人不能两次踏进同一条河流。" 很老生常谈，但今天看到，莫名有点感触。',
    'date': DateTime.now().subtract(const Duration(days: 40)).toIso8601String(),
    'tags': ['电影', '感悟', '老片'],
  },
  {
    'content': '今天做了个梦，梦见我会飞。\n\n那种腾空而起、飞过城市的感觉，好真实。醒来之后还有点惋惜，真希望能再飞一会儿。',
    'date': DateTime.now().subtract(const Duration(days: 41)).toIso8601String(),
    'tags': ['梦', '飞翔', '日常'],
  },
  {
    'content':
        '今天去超市，结账的时候发现手机没电，扫不了码，身上也没带现金。\n\n最后借了旁边阿姨的充电宝充了一下电，才结上账。好险！以后要养成带充电宝的习惯。',
    'date': DateTime.now().subtract(const Duration(days: 42)).toIso8601String(),
    'tags': ['超市', '尴尬', '教训'],
  },
  {
    'content':
        '申请了一个网上的读书小组，每周分享一本书。\n\n今天是第一次参加，大家聊的是一本科幻小说。感觉思维被打开了很多，认识了几个很有趣的人。',
    'date': DateTime.now().subtract(const Duration(days: 43)).toIso8601String(),
    'tags': ['读书会', '社交', '收获'],
  },
  {
    'content': '今天自己煮了一锅番茄鸡蛋汤面。\n\n材料很简单，但味道出乎意料地好。\n\n有时候最家常的东西，才是最治愈的。',
    'date': DateTime.now().subtract(const Duration(days: 44)).toIso8601String(),
    'tags': ['做饭', '面条', '治愈'],
  },
  {
    'content':
        '今天更新了系统，结果有个常用软件崩了，折腾了一个多小时才修好。\n\n以后重要的日子，千万不能随便更新系统。这是血的教训。😤',
    'date': DateTime.now().subtract(const Duration(days: 45)).toIso8601String(),
    'tags': ['系统更新', '崩溃', '教训'],
  },
  {
    'content':
        '今晚散步的时候，遇到了一对老夫妇，手牵手在路边坐着。\n\n两个人都没说话，就这么坐着，看着来来往往的人群。\n\n那画面真的很美，希望我老了也能这样。',
    'date': DateTime.now().subtract(const Duration(days: 46)).toIso8601String(),
    'tags': ['散步', '感动', '爱情'],
  },
  {
    'content':
        '今天屯了一批零食：薯片、饼干、糖、小熊软糖。\n\n囤货的时候满足感拉满，实际上买回来很可能一个月都吃不完。\n\n管不了了，快乐最重要。',
    'date': DateTime.now().subtract(const Duration(days: 47)).toIso8601String(),
    'tags': ['零食', '快乐', '购物'],
  },
  {
    'content':
        '今天帮一个不认识的人在地铁站找到了丢失的钱包。\n\n还给他的时候他非常感激，一直道谢。\n\n其实没什么大不了的，但心里还是暖暖的。',
    'date': DateTime.now().subtract(const Duration(days: 48)).toIso8601String(),
    'tags': ['好事', '暖心', '日常'],
  },
  {
    'content':
        '今天复习了一下高中数学，想看看自己还记得多少。\n\n微积分还行，线性代数已经忘得差不多了。\n\n感觉有点可惜，当初学这些的时候多费劲啊。',
    'date': DateTime.now().subtract(const Duration(days: 49)).toIso8601String(),
    'tags': ['复习', '数学', '感慨'],
  },
  {
    'content':
        '今天下午特别困，喝了两杯咖啡也没用。\n\n最后趴在桌上睡了二十分钟，醒来之后神清气爽，比咖啡管用多了。\n\n午睡是个好东西，以后要坚持。',
    'date': DateTime.now().subtract(const Duration(days: 50)).toIso8601String(),
    'tags': ['午睡', '咖啡', '精神'],
  },
  {
    'content':
        '和老朋友聊了很久的天，聊到了大学的各种事情。\n\n那个时候真的好单纯，一点小事都能开心好几天。\n\n人大了之后好像很难那么纯粹地高兴了。',
    'date': DateTime.now().subtract(const Duration(days: 51)).toIso8601String(),
    'tags': ['朋友', '回忆', '感慨'],
  },
  {
    'content':
        '今天去图书馆待了一整天，什么都没带，就带了耳机和笔记本。\n\n写了好多东西，但大多数都是随笔，不成体系。\n\n感觉很充实，下次还要来。',
    'date': DateTime.now().subtract(const Duration(days: 52)).toIso8601String(),
    'tags': ['图书馆', '写作', '充实'],
  },
  {
    'content':
        '今天给植物浇水的时候，发现墙角那盆几乎枯死的绿萝，长出了一片嫩绿的新叶。\n\n完全没想到，我都以为它死透了。生命力真的很顽强。',
    'date': DateTime.now().subtract(const Duration(days: 53)).toIso8601String(),
    'tags': ['植物', '惊喜', '生命力'],
  },
  {
    'content': '今天发现家旁边开了一家新的面包店，刚出炉的肉松小面包香气飘了整条街。\n\n买了三个，回家路上就吃完了，一个都没留住。',
    'date': DateTime.now().subtract(const Duration(days: 54)).toIso8601String(),
    'tags': ['面包', '美食', '探店'],
  },
  {
    'content':
        '今天试着做了一个小工具脚本，自动整理文件夹。\n\n写了大概五十行，跑起来之后效果出乎意料地好。以后再也不用手动整理了，太爽了！',
    'date': DateTime.now().subtract(const Duration(days: 55)).toIso8601String(),
    'tags': ['编程', '小工具', '效率'],
  },
  {
    'content': '今天风很大，树叶飘了满地，踩上去嘎吱嘎吱的。\n\n走在路上，每一步都有声音，像在演电影一样。\n\n秋天真的很好。',
    'date': DateTime.now().subtract(const Duration(days: 56)).toIso8601String(),
    'tags': ['秋天', '散步', '治愈'],
  },
  {
    'content': '今天参加了一个线下的技术分享会，听了两个小时。\n\n一半听懂了，一半没听懂。但没听懂的那部分记下来了，回去慢慢研究。',
    'date': DateTime.now().subtract(const Duration(days: 57)).toIso8601String(),
    'tags': ['学习', '分享会', '技术'],
  },
  {
    'content':
        '最近睡眠不太好，每天早上六点就自然醒了，再睡不着。\n\n索性早起，把早饭做了，在阳台坐了一会儿，看着太阳慢慢升起来。\n\n原来清晨是这样的，安静，干净，很美。',
    'date': DateTime.now().subtract(const Duration(days: 58)).toIso8601String(),
    'tags': ['早起', '清晨', '日出'],
  },
  {
    'content':
        '今天试着画了一张 UI 草图，想给 App 加一个新功能。\n\n画完之后发现实现起来比想象中复杂，但思路清晰了很多。\n\n有时候把想法画出来，比在脑子里转有用多了。',
    'date': DateTime.now().subtract(const Duration(days: 59)).toIso8601String(),
    'tags': ['设计', 'UI', '创作'],
  },
];
