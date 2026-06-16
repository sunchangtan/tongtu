import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/core/apple_core_controller.dart';
import 'package:tongtu/core/core_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel method = MethodChannel('com.dingqi.tongtu/core');
  const EventChannel events = EventChannel('com.dingqi.tongtu/core_state');
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('AppleCoreController', () {
    final List<String> calls = <String>[];

    setUp(() {
      calls.clear();
      messenger.setMockMethodCallHandler(method, (MethodCall call) async {
        calls.add(call.method);
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(method, null);
      messenger.setMockStreamHandler(events, null);
    });

    test('初始状态为 stopped', () async {
      final AppleCoreController controller = AppleCoreController();
      expect(controller.state, CoreState.stopped);
      await controller.dispose();
    });

    test('start/stop 经 MethodChannel 调用原生', () async {
      final AppleCoreController controller = AppleCoreController();
      await controller.start(
        configYAML: 'mode: rule',
        controllerPort: 12345,
        controllerSecret: 'test-secret',
      );
      await controller.stop();
      expect(calls, <String>['start', 'stop']);
      await controller.dispose();
    });

    test('原生事件经 EventChannel 更新状态流', () async {
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink sink) {
            sink.success('connected');
          },
        ),
      );
      final AppleCoreController controller = AppleCoreController();
      final CoreState next = await controller.stateStream.first;
      expect(next, CoreState.connected);
      await controller.dispose();
    });
  });
}
