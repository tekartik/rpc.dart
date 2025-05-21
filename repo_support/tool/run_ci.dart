import 'package:dev_build/package.dart';
import 'package:path/path.dart';

Future main() async {
  for (var dir in ['rpc']) {
    await packageRunCi(join('..', 'packages', dir));
  }
}
