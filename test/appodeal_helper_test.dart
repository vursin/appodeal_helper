import 'package:appodeal_helper/src/appodeal_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test ', () async {
    expect(await checkAllowedAds(), false);
    expect(await checkAllowedAds(), false);
    expect(await checkAllowedAds(), false);
    expect(await checkAllowedAds(), false);

    // tearDown(() {
    //   hive?.deleteFromDisk();
    // });
    // hive?.deleteFromDisk();
  });
}
