// Copyright 2020 Sarbagya Dhaubanjar. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math';
import 'dart:io';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:youtube_api/youtube_api.dart';
import 'package:http/http.dart' as http;

import 'widgets/meta_data_section.dart';
import 'widgets/play_pause_button_bar.dart';
import 'widgets/player_state_section.dart';

const String apiKey = "AIzaSyBFSeaJg5wolBnxH1Nxsa649cpalEBdpz4";
const int videoNameRuIndex = 2;

Future<void> main() async {
  // Set loading screen before initialization
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(YoutubeApp());
}

///
class YoutubeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatchIT App',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: YoutubeAppDemo(),
    );
  }
}

///
class YoutubeAppDemo extends StatefulWidget {
  @override
  _YoutubeAppDemoState createState() => _YoutubeAppDemoState();
}

class _YoutubeAppDemoState extends State<YoutubeAppDemo> {
  late YoutubePlayerController controller;
  String currentVideoUrl = "";
  List<String> videoNames = [];
  final List<String> videoUrls = [];
  bool isVideoReady = false;
  List<String> favorites = [];
  List<String> unfavorites = [];
  
  YoutubeAPI uApi = YoutubeAPI(apiKey);

  Future<bool> isVideoRestricted() async {
    final url =
      'https://www.googleapis.com/youtube/v3/videos?id=$currentVideoUrl&part=contentDetails&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    final jsonBody = json.decode(response.body);
    print(jsonBody);
    // CONTENT DETAILS MAYBE EMPTY
    if (jsonBody['items'].isEmpty || jsonBody['items'][0]['contentDetails'].isEmpty || jsonBody['items'][0]['contentDetails']['contentRating'].isEmpty) {
      return false;
    }

    return true;
  }

  Future<void> getNamesFromExcel() async {
    String path = '/storage/emulated/0/Download/database.xlsx';
    // file on emulator
    bool isExists = File(path).existsSync();
    print(isExists);
    if (!isExists) {
      print("Error! Path $path doesn't exists");
      throw Exception("NO VALID PATH");
    }

    while (true) {
      var res = await Permission.storage.request();

      if (res.isGranted) {
        var bytes = File(path).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        // Получаем первый лист.
        final sheet = excel.tables.keys.first;

        final rows = excel.tables[sheet]!.rows.skip(1);

        for (final row in rows) {
          if (row.any((cell) =>
              cell?.value != null && cell!.value.toString().isNotEmpty)) {
            if (row[videoNameRuIndex]?.value != null) {
              videoNames.add(row[videoNameRuIndex]!.value.toString());
            }
          }
        }
        print(videoNames);
        break;
      } else {
        print("No permission :(");
      }
    }
  }

  Future<void> initVideoIds() async {
    // Make request to database and fill videoNames list
    await getNamesFromExcel();
  }

  Future<String> getVideoUrl(String videoName) async {
    List<YouTubeVideo> videoResult = await uApi.search(videoName);
    
    if (videoResult.isNotEmpty) {
      return videoResult[0].url;
    }
    return "";
  }

  Future<void> nextVideo() async {
    // Add random number to get id from list
    while (true) {
      int randomNumber = Random().nextInt(videoNames.length);
      String currentVideoName = "${videoNames[randomNumber]} трейлер на русском";

      currentVideoUrl = await getVideoUrl(currentVideoName);

      if (currentVideoUrl.isEmpty) {
        print("currentVideoUrl is empty! Name: $currentVideoName");
        continue;
      }
      
      //check if video is ok
      if (!await isVideoRestricted()) {
        break;
      }
    }

    controller.loadVideo(currentVideoUrl);

    setState(() {
      print("Set new video");
    });
  }

  void addFavorite() {
    print("Video $currentVideoUrl favorite");
  }

  void addUnfavorite() {
    print("Video $currentVideoUrl unfavorite");
  }

  Future<void> loadData() async {
    controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
          showControls: false,
          mute: false,
          showFullscreenButton: false,
          loop: false),
    );

    // Fill video urls using names from database file
    await initVideoIds();

    // Try to load a random video from list and CHECK its restrictions
    // If there's any, choose next video
    await nextVideo();

    //Remove loading screen
    FlutterNativeSplash.remove();
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // Rebuild every time something changes
  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: controller,
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(title: const Text('Youtube Player IFrame Demo')),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (kIsWeb && constraints.maxWidth > 750) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Controls(
                          nextVideo: nextVideo,
                          addFavorite: addFavorite,
                          addUnfavorite: addUnfavorite),
                    ),
                  ],
                );
              }

              return ListView(
                children: [
                  player,
                  const VideoPositionIndicator(),
                  Controls(
                      nextVideo: nextVideo,
                      addFavorite: addFavorite,
                      addUnfavorite: addUnfavorite),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

///
class Controls extends StatelessWidget {
  ///
  const Controls(
      {required this.nextVideo,
      required this.addFavorite,
      required this.addUnfavorite});

  final VoidCallback nextVideo;
  final VoidCallback addFavorite;
  final VoidCallback addUnfavorite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetaDataSection(),
          _space,
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                      onPressed: () {
                        print("Like button pressed");
                        addFavorite();
                      },
                      child: Text("Like")),
                  SizedBox(width: 30),
                  ElevatedButton(
                      onPressed: () {
                        print("Shit button pressed");
                        addUnfavorite();
                      },
                      child: Text("Shit"))
                ],
              ),
              ElevatedButton(
                  onPressed: () {
                    print("Next button pressed");
                    // Change video
                    nextVideo();
                  },
                  child: Text("Next")),
            ],
          ),
          PlayPauseButtonBar(),
          _space,
          PlayerStateSection(nextVideo: nextVideo),
        ],
      ),
    );
  }

  Widget get _space => const SizedBox(height: 10);
}

// class VideoPlaylistIconButton extends StatelessWidget {
//   ///
//   const VideoPlaylistIconButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final controller = context.ytController;

//     return IconButton(
//       onPressed: () async {
//         controller.pauseVideo();
//         await Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => const VideoListPage(),
//           ),
//         );
//         controller.playVideo();
//       },
//       icon: const Icon(Icons.playlist_play_sharp),
//     );
//   }
// }

class VideoPositionIndicator extends StatelessWidget {
  ///
  const VideoPositionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.ytController;

    return StreamBuilder<YoutubeVideoState>(
      stream: controller.videoStateStream,
      initialData: const YoutubeVideoState(),
      builder: (context, snapshot) {
        final position = snapshot.data?.position.inMilliseconds ?? 0;
        final duration = controller.metadata.duration.inMilliseconds;

        return LinearProgressIndicator(
          value: duration == 0 ? 0 : position / duration,
          minHeight: 1,
        );
      },
    );
  }
}

class VideoPositionSeeker extends StatelessWidget {
  ///
  const VideoPositionSeeker({super.key});

  @override
  Widget build(BuildContext context) {
    var value = 0.0;

    return Row(
      children: [
        const Text(
          'Seek',
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: StreamBuilder<YoutubeVideoState>(
            stream: context.ytController.videoStateStream,
            initialData: const YoutubeVideoState(),
            builder: (context, snapshot) {
              final position = snapshot.data?.position.inSeconds ?? 0;
              final duration = context.ytController.metadata.duration.inSeconds;

              value = position == 0 || duration == 0 ? 0 : position / duration;

              return StatefulBuilder(
                builder: (context, setState) {
                  return Slider(
                    value: value,
                    onChanged: (positionFraction) {
                      value = positionFraction;
                      setState(() {});

                      context.ytController.seekTo(
                        seconds: (value * duration).toDouble(),
                        allowSeekAhead: true,
                      );
                    },
                    min: 0,
                    max: 1,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
