import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:atomic_sdk_flutter/atomic_sdk_flutter.dart';

void main() {
  const channel = MethodChannel('atomic_sdk_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMethodCallHandler((call) => Future.value('42'));
  });

  tearDown(() {
    channel.setMethodCallHandler((call) => Future.value());
  });

  // test('getPlatformVersion', () async {
  //   expect(await AtomicSdkFlutter.platformVersion, '42');
  // });
}
