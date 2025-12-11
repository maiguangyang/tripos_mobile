import 'package:flutter_test/flutter_test.dart';
import 'package:tripos_mobile/tripos_mobile.dart';
import 'package:tripos_mobile/tripos_mobile_platform_interface.dart';
import 'package:tripos_mobile/tripos_mobile_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTriposMobilePlatform
    with MockPlatformInterfaceMixin
    implements TriposMobilePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final TriposMobilePlatform initialPlatform = TriposMobilePlatform.instance;

  test('$MethodChannelTriposMobile is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTriposMobile>());
  });

  test('getPlatformVersion', () async {
    TriposMobile triposMobilePlugin = TriposMobile();
    MockTriposMobilePlatform fakePlatform = MockTriposMobilePlatform();
    TriposMobilePlatform.instance = fakePlatform;

    expect(await triposMobilePlugin.getPlatformVersion(), '42');
  });
}
