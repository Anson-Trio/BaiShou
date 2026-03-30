import 'package:flutter_test/flutter_test.dart';
import 'package:baishou/features/settings/domain/services/user_profile_service.dart';

void main() {
  group('UserProfile', () {
    group('toMarkdownBlock', () {
      test('空 identityFacts 返回空字符串', () {
        final profile = UserProfile(nickname: 'Test');
        expect(profile.toMarkdownBlock(), '');
      });

      test('单条 KV 格式化为 Markdown', () {
        final profile = UserProfile(
          nickname: 'Test',
          personas: {'默认身份': {'生日': '1998-05-20'}},
          activePersonaId: '默认身份',
        );
        final block = profile.toMarkdownBlock();
        expect(block, contains('### User Profile'));
        expect(block, contains('- **生日**: 1998-05-20'));
      });

      test('多条 KV 全部输出', () {
        final profile = UserProfile(
          nickname: '小明',
          personas: {
            '默认身份': {
              '生日': '1998-05-20',
              '性别': '男',
              '职业': '前端开发',
              '禁忌': '海鲜过敏',
            },
          },
          activePersonaId: '默认身份',
        );
        final block = profile.toMarkdownBlock();
        expect(block, contains('### User Profile'));
        expect(block, contains('- **生日**: 1998-05-20'));
        expect(block, contains('- **性别**: 男'));
        expect(block, contains('- **职业**: 前端开发'));
        expect(block, contains('- **禁忌**: 海鲜过敏'));
      });
    });

    group('copyWith', () {
      test('只改 nickname，personas 不变', () {
        final profile = UserProfile(
          nickname: 'Old',
          personas: {'默认身份': {'key': 'value'}},
          activePersonaId: '默认身份',
        );
        final updated = profile.copyWith(nickname: 'New');
        expect(updated.nickname, 'New');
        expect(updated.personas, {'默认身份': {'key': 'value'}});
      });

      test('只改 personas，nickname 不变', () {
        final profile = UserProfile(
          nickname: 'Test',
          personas: {'默认身份': {'old': 'data'}},
          activePersonaId: '默认身份',
        );
        final updated = profile.copyWith(personas: {'默认身份': {'new': 'data'}});
        expect(updated.nickname, 'Test');
        expect(updated.personas, {'默认身份': {'new': 'data'}});
      });

      test('改 avatarPath', () {
        final profile = UserProfile(nickname: 'Test');
        final updated = profile.copyWith(avatarPath: '/path/to/avatar.png');
        expect(updated.avatarPath, '/path/to/avatar.png');
        expect(updated.nickname, 'Test');
      });
    });

    group('default values', () {
      test('默认 identityFacts 为空 Map', () {
        final profile = UserProfile(nickname: 'Test');
        expect(profile.identityFacts, isEmpty);
        expect(profile.avatarPath, isNull);
      });
    });
  });
}
