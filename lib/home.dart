import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as path;

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String url = 'http://127.0.0.1:5000';
  List notes = [];
  bool showRecord = true;
  Duration? time = Duration.zero;
  Timer? timer;
  List contentList = [
    "Upload your audio recording or record lively",
    "Choose a wav file",
    "Recording....",
    "Processing....",
    "Play the generated instrumental!",
    "Playing...."
  ];
  String content = "";
  var filledDisabled = false;

  @override
  void initState() {
    super.initState();
    setState(() => content = contentList[0]);
    reset();
  }

  void reset() {
    setState(() => time = Duration.zero);
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) => addTime());
  }

  void addTime() {
    setState(() {
      final seconds = time!.inSeconds + 1;
      time = Duration(seconds: seconds);
    });
  }

  void stopTimer() {
    setState(() => timer?.cancel());
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      content: Container(
        color: Colors.purple.darkest,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const SizedBox(height: 3),
            Column(
              children: [
                Text(
                  "${time!.inMinutes.toString().padLeft(2, "0")}:${time!.inSeconds.toString().padLeft(2, "0")}",
                  style: TextStyle(
                    color: Colors.grey[30],
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 5,
                  ),
                ),
                Text(
                  "MINUTES     SECONDS",
                  style: TextStyle(
                    color: Colors.grey[20],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilledButton(
                  onPressed: (() async {
                    try {
                      print("upload");
                      setState(() => content = contentList[1]);
                      FilePickerResult? result =
                          await FilePicker.platform.pickFiles();
                      var filePath, fileName = '';
                      if (result != null) {
                        File file = File(result.files.single.path!);
                        filePath = file.path;
                        fileName = path.basename(filePath);
                        print(fileName);
                        setState(() => content = contentList[3]);
                        var res0 = await post(
                          Uri.parse(url),
                          headers: {
                            'Content-Type': 'application/json; charset=UTF-8',
                          },
                          body: json.encode({
                            'fileName': fileName,
                          }),
                        );
                        var data = json.decode(res0.body);
                        setState(() {
                          notes = data["notes"];
                          content = contentList[4];
                        });
                        print("${time!.inMinutes}:${time!.inSeconds}");
                      }
                    } catch (e) {
                      print(e);
                    }
                  }),
                  style: ButtonStyle(
                      padding: ButtonState.all(const EdgeInsets.all(10)),
                      backgroundColor: ButtonState.all(Colors.purple.lighter)),
                  child: Row(
                    children: [
                      Icon(FluentIcons.upload,
                          size: 40, color: Colors.grey[20]),
                      const SizedBox(width: 10),
                      const Text(
                        "Upload",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  "or",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                showRecord
                    ? FilledButton(
                        onPressed: (() async {
                          setState(() {
                            showRecord = false;
                            content = contentList[2];
                          });
                          try {
                            print("record");
                            startTimer();
                            var res1 = await get(Uri.parse(url + "/record"));
                          } catch (e) {
                            print(e);
                          }
                        }),
                        style: ButtonStyle(
                            padding: ButtonState.all(const EdgeInsets.all(10)),
                            backgroundColor:
                                ButtonState.all(Colors.purple.lighter)),
                        child: Row(
                          children: [
                            Icon(FluentIcons.microphone,
                                size: 40, color: Colors.grey[20]),
                            const SizedBox(width: 10),
                            const Text(
                              "Record",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FilledButton(
                        onPressed: (() async {
                          setState(() {
                            showRecord = true;
                            content = contentList[3];
                          });
                          try {
                            print("stop");
                            stopTimer();
                            Future.delayed(
                                (const Duration(seconds: 1)), () => reset());
                            var res2 = await get(Uri.parse(url + "/stop"));
                            var res3 = await get(Uri.parse(url));
                            var data = json.decode(res3.body);
                            setState(() {
                              notes = data["notes"];
                              content = contentList[4];
                            });
                          } catch (e) {
                            print(e);
                          }
                        }),
                        style: ButtonStyle(
                            padding: ButtonState.all(const EdgeInsets.all(10)),
                            backgroundColor:
                                ButtonState.all(Colors.purple.lighter)),
                        child: Row(
                          children: [
                            Icon(FluentIcons.stop_solid,
                                size: 40, color: Colors.grey[20]),
                            const SizedBox(width: 10),
                            const Text(
                              "Stop",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
            Column(
              children: [
                Container(
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[50],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (notes.isNotEmpty)
                        Text(
                          "    ${notes.toString()}    ",
                          style: TextStyle(
                            color: Colors.purple.darkest,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                FilledButton(
                  onPressed: notes.isEmpty
                      ? null
                      : (() async {
                          try {
                            print("play");
                            setState(() => content = contentList[5]);
                            startTimer();
                            var res4 = await get(Uri.parse(url + "/play"));
                            stopTimer();
                            Future.delayed(
                                (const Duration(seconds: 1)), () => reset());
                            setState(() => content = contentList[0]);
                          } catch (e) {
                            print(e);
                          }
                        }),
                  style: ButtonStyle(
                      padding: ButtonState.all(const EdgeInsets.all(10)),
                      backgroundColor: ButtonState.all(notes.isEmpty
                          ? Colors.grey[70]
                          : Colors.purple.lighter)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.play_solid,
                          size: 40, color: Colors.grey[20]),
                      const SizedBox(width: 10),
                      const Text(
                        "Play",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              height: 30,
              color: Colors.grey[50],
              child: Row(children: [
                const SizedBox(width: 10),
                Icon(
                  FluentIcons.music_note,
                  color: Colors.magenta.darker,
                ),
                const SizedBox(width: 10),
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.purple.darkest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            )
          ],
        ),
      ),
    );
  }
}
