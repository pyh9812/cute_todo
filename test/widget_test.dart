import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cute_todo/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('CuteTodoApp renders smoke test', (WidgetTester tester) async {
    // 앱 빌드 및 첫 프레임 렌더링
    await tester.pumpWidget(const CuteTodoApp());
    await tester.pumpAndSettle();

    // 상단 앱바 타이틀 확인
    expect(find.text('귀여운 투두리스트'), findsOneWidget);

    // 미완료 / 완료 탭 표시 확인
    expect(find.textContaining('진행 중'), findsOneWidget);
    expect(find.textContaining('완료됨'), findsOneWidget);

    // 캐릭터 말풍선 영역 확인
    expect(find.text('토롱이의 한마디'), findsOneWidget);

    // 할 일 추가 버튼 확인
    expect(find.text('할 일 추가'), findsOneWidget);
  });
}
