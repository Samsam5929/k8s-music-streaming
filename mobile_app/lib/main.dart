import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';

void main() => runApp(MaterialApp(
      theme: ThemeData.dark(),
      home: MusicScreen(),
    ));

class MusicScreen extends StatefulWidget {
  @override
  _MusicScreenState createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final AudioPlayer _player = AudioPlayer();
  List tracks = [];
  String currentTitle = "Выберите трек";

  @override
  void initState() {
    super.initState();
    fetchTracks();
  }

  fetchTracks() async {
    try {
      // Запрос к твоему Go-бэкенду в K8s
      final response = await http.get(Uri.parse('http://172.24.12.22:30964/tracks'));
      if (response.statusCode == 200) {
        setState(() {
          tracks = json.decode(response.body);
        });
      }
    } catch (e) {
      print("Ошибка загрузки: $e");
    }
  }

  void playMusic(String key, String title) async {
    setState(() => currentTitle = title);
    try {
      // Стриминг из твоего Go-бэкенда
      await _player.setUrl("http://172.24.12.22:30964/stream?key=$key");
      _player.play();
    } catch (e) {
      print("Ошибка воспроизведения: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("K8s Music Streamer")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(Icons.music_note, color: Colors.blue),
                  title: Text(tracks[index]['title']),
                  subtitle: Text(tracks[index]['artist']),
                  onTap: () => playMusic(tracks[index]['minio_key'], tracks[index]['title']),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(20),
            color: Colors.black45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(currentTitle, style: TextStyle(fontSize: 16))),
                IconButton(icon: Icon(Icons.play_arrow, size: 32), onPressed: () => _player.play()),
                IconButton(icon: Icon(Icons.pause, size: 32), onPressed: () => _player.pause()),
              ],
            ),
          )
        ],
      ),
    );
  }
}