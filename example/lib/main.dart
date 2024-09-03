import 'package:flutter/material.dart';
import 'package:y_dart/y_dart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // late int randomResult;

  late final _controller = TextEditingController();
  late YDoc yDoc = YDoc();
  YText get yText => yDoc.getText('name');

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    const spacerSmall = SizedBox(height: 10);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native Packages'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const Text(
                  'This calls a native function through FFI that is shipped as source in the package. '
                  'The native code is built as part of the Flutter Runner build.',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                ElevatedButton(
                  child: const Text('New Document'),
                  onPressed: () {
                    setState(() {
                      yDoc = YDoc();
                    });
                  },
                ),
                // Button to add copious amounts of text under the 'spam' key
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      var text = yDoc.getText('spam');
                      yDoc.transaction(() {
                        for (var i = 0; i < 1000; i++) {
                          text.append(kLipsum);
                        }
                      });
                    });
                  },
                  child: const Text("Append"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      yText.append(" ${DateTime.now().toIso8601String()}");
                    });
                  },
                  child: const Text("Append"),
                ),
                Text('Text length: ${yText.length}'),
                const Center(child: CircularProgressIndicator()),
                Text(yText.toString()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const kLipsum =
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
