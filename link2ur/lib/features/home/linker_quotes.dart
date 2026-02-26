import 'dart:math';

import 'package:flutter/material.dart';

/// 首页 Linker 思考云朵语录（按中英文区分）
class LinkerQuotes {
  LinkerQuotes._();

  static final _random = Random();

  static const List<String> zh = [
    '今天也要加油呀～',
    '你比想象中更棒。',
    '小步前进也是进步。',
    '做自己的光 ✨',
    '休息一下再出发～',
    '每一天都是新的开始。',
    '慢慢来，比较快。',
    '你值得被温柔以待。',
    '你永远可以重写你的故事。',
    '今天也要开心呀～',
    '小小的鼓励，大大的力量。',
    'Linker 随时在你身边 💙',
  ];

  static const List<String> en = [
    'The only way to do great work is to love what you do. — Steve Jobs',
    'Stay hungry, stay foolish. — Steve Jobs',
    'Think different. — Apple',
    'Every day is a new beginning.',
    'Small steps still move you forward.',
    'Be your own light ✨',
    'You deserve to be treated gently.',
    'It\'s never too late to start.',
    'Linker is here for you 💙',
  ];

  static String randomQuote(Locale locale) {
    final isZh = locale.languageCode.toLowerCase().startsWith('zh');
    final list = isZh ? zh : en;
    return list[_random.nextInt(list.length)];
  }
}
