import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

// Golden comparator that tolerates sub-0.1% pixel drift. Font rasterization
// differs slightly across Flutter engine versions/machines; exact-match
// goldens fail with ~0.02% diffs that carry no visual meaning.
class _TolerantFileComparator extends LocalFileComparator {
  _TolerantFileComparator(super.testFile);

  static const _maxDiffRatio = 0.001; // 0.1%

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _maxDiffRatio) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (goldenFileComparator is LocalFileComparator) {
    // LocalFileComparator derives basedir from the dirname of the URI it is
    // given, so append a dummy file segment to preserve the original basedir.
    goldenFileComparator = _TolerantFileComparator(
      Uri.parse(
        '${(goldenFileComparator as LocalFileComparator).basedir}config.dart',
      ),
    );
  }
  await loadAppFonts();
  return GoldenToolkit.runWithConfiguration(
    () async {
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      enableRealShadows: true,
      defaultDevices: const [Device.phone],
      skipGoldenAssertion: () => false,
    ),
  );
}
