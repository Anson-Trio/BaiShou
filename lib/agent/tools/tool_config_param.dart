// 工具可配参数模型
// 描述工具中用户可以自定义的参数（如搜索条数上限）

import 'package:flutter/material.dart';

/// 参数类型
enum ParamType { integer, string, boolean }

/// 工具可配参数定义
class ToolConfigParam {
  /// 参数键名（用于持久化和传入工具）
  final String key;

  /// 显示标签（用户可见）
  final String label;

  /// 参数描述
  final String description;

  /// 参数类型
  final ParamType type;

  /// 默认值
  final dynamic defaultValue;

  /// 数值型参数的最小值
  final num? min;

  /// 数值型参数的最大值
  final num? max;

  /// 图标
  final IconData? icon;

  const ToolConfigParam({
    required this.key,
    required this.label,
    this.description = '',
    required this.type,
    required this.defaultValue,
    this.min,
    this.max,
    this.icon,
  });
}
