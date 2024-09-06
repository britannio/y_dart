import 'dart:io';

import 'package:native_toolchain_rust/native_toolchain_rust.dart';
import 'package:native_assets_cli/native_assets_cli.dart';

void main(List<String> args) async {
  try {
    await build(args, (BuildConfig buildConfig, BuildOutput output) async {
      final builder = RustBuilder(
        package: 'y_dart',
        cratePath: 'rust',
        buildConfig: buildConfig,
      );
      await builder.run(output: output);
    });
  } catch (e) {
    stdout.writeln(e);
    exit(1);
  }
}
