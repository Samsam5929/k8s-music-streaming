import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart'; // НОВЫЙ ИМПОРТ ДЛЯ ЗАГРУЗКИ ФАЙЛОВ
import 'dart:convert';
import 'dart:typed_data';

void main() {
  runApp(const SpotifyK8sApp());
}

// --- МОДЕЛЬ ДАННЫХ ---
class Track {
  final int id;
  final String title;
  final String artist;
  final String minioKey;
  final String coverUrl;

  Track({required this.id, required this.title, required this.artist, 
         required this.minioKey, required this.coverUrl});

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'],
      title: json['title'],
      artist: json['artist'] ?? "Unknown Artist",
      minioKey: json['minio_key'],
      coverUrl: json['cover_url'] ?? "",
    );
  }
}

// --- ГЛАВНОЕ ПРИЛОЖЕНИЕ ---
class SpotifyK8sApp extends StatelessWidget {
  const SpotifyK8sApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'K8s Spotify Clone',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const MobileFrame(child: MusicPlayerScreen()),
    );
  }
}

class MobileFrame extends StatelessWidget {
  final Widget child;
  const MobileFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ClipRRect(child: child),
        ),
      ),
    );
  }
}

// --- ОСНОВНОЙ ЭКРАН ---
class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Track> _tracks = [];
  List<Track> _filteredTracks = [];
  Track? _currentTrack;
  bool _isLoading = true;
  String _searchQuery = "";

  final String baseUrl = "http://172.24.12.22:30964";

  @override
  void initState() {
    super.initState();
    _fetchTracks();
  }

  Future<void> _fetchTracks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tracks'));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        setState(() {
          _tracks = jsonResponse.map((data) => Track.fromJson(data)).toList();
          _filteredTracks = _tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching tracks: $e");
    }
  }

  void _filterTracks(String query) {
    setState(() {
      _searchQuery = query;
      _filteredTracks = _tracks
          .where((t) => t.title.toLowerCase().contains(query.toLowerCase()) || 
                        t.artist.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _playTrack(Track track) async {
    // 1. Если это та же самая песня, просто перематываем в начало
    if (_currentTrack?.id == track.id) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      return;
    }

    // 2. Если песня другая:
    setState(() => _currentTrack = track);
    
    try {
      // Останавливаем плеер перед загрузкой нового URL
      await _audioPlayer.stop(); 
      
      final streamUrl = "$baseUrl/stream?key=${track.minioKey}";
      
      // Загружаем новый URL
      await _audioPlayer.setUrl(streamUrl);
      
      // Запускаем
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Error streaming: $e");
    }
  }

  void _openFullPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullPlayerPage(
        track: _currentTrack!,
        player: _audioPlayer,
        baseUrl: baseUrl,
      ),
    );
  }

  // --- НОВЫЙ МЕТОД ДЛЯ ОТКРЫТИЯ ФОРМЫ ЗАГРУЗКИ ---
  void _showUploadBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: UploadTrackForm(baseUrl: baseUrl),
      ),
    ).then((_) {
      // Обновляем список треков после закрытия окна загрузки
      _fetchTracks(); 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              _isLoading 
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.green)))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildTrackCard(_filteredTracks[index]),
                        childCount: _filteredTracks.length,
                      ),
                    ),
                  ),
            ],
          ),
          if (_currentTrack != null)
            Positioned(
              left: 12, right: 12, bottom: 20,
              child: _buildMiniPlayer(),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar.large(
      backgroundColor: const Color(0xFF121212),
      title: const Text("Моя музыка", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
      // НОВАЯ КНОПКА ЗАГРУЗКИ ТРЕКА
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
          onPressed: _showUploadBottomSheet,
        ),
        const SizedBox(width: 10),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: TextField(
            onChanged: _filterTracks,
            decoration: InputDecoration(
              hintText: "Поиск песен...",
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackCard(Track track) {
    bool isPlaying = _currentTrack?.id == track.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isPlaying ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        onTap: () => _playTrack(track),
        leading: Hero(
          tag: 'cover-${track.id}',
          child: _CORSImage(url: track.coverUrl, size: 55),
        ),
        title: Text(track.title, style: TextStyle(
          color: isPlaying ? Colors.green : Colors.white,
          fontWeight: FontWeight.bold,
        )),
        subtitle: Text(track.artist, style: const TextStyle(color: Colors.white60)),
        trailing: const Icon(Icons.play_circle_outline, color: Colors.white38),
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return GestureDetector(
      onTap: _openFullPlayer,
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 15)],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _CORSImage(url: _currentTrack!.coverUrl, size: 50),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentTrack!.title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text(_currentTrack!.artist, style: const TextStyle(fontSize: 13, color: Colors.white60)),
                ],
              ),
            ),
            StreamBuilder<PlayerState>(
              stream: _audioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return IconButton(
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 35),
                  onPressed: playing ? _audioPlayer.pause : _audioPlayer.play,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      backgroundColor: Colors.black,
      height: 70,
      indicatorColor: Colors.green.withOpacity(0.2),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_filled), label: "Главная"),
        NavigationDestination(icon: Icon(Icons.explore), label: "Обзор"),
        NavigationDestination(icon: Icon(Icons.library_music), label: "Медиатека"),
      ],
    );
  }
}

// --- ПОЛНОЭКРАННЫЙ ПЛЕЕР ---
class FullPlayerPage extends StatelessWidget {
  final Track track;
  final AudioPlayer player;
  final String baseUrl;

  const FullPlayerPage({super.key, required this.track, required this.player, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.withOpacity(0.4), Colors.black],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          children: [
            const SizedBox(height: 20),
            IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 35), onPressed: () => Navigator.pop(context)),
            const Spacer(),
            Hero(
              tag: 'cover-${track.id}',
              child: Center(child: _CORSImage(url: track.coverUrl, size: 320, radius: 20)),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    Text(track.artist, style: const TextStyle(fontSize: 18, color: Colors.white70)),
                  ],
                ),
                const Icon(Icons.favorite_border, color: Colors.green, size: 32),
              ],
            ),
            const SizedBox(height: 30),
            _buildProgressBar(),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(Icons.shuffle, color: Colors.white54, size: 28),
                const Icon(Icons.skip_previous, size: 45),
                StreamBuilder<PlayerState>(
                  stream: player.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton(
                      icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                      iconSize: 85,
                      onPressed: playing ? player.pause : player.play,
                    );
                  },
                ),
                const Icon(Icons.skip_next, size: 45),
                const Icon(Icons.repeat, color: Colors.white54, size: 28),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = player.duration ?? Duration.zero;
        return Column(
          children: [
            Slider(
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              max: duration.inMilliseconds.toDouble(),
              value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
              onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position)),
                  Text(_formatDuration(duration)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}

// --- ВИДЖЕТ ЗАГРУЗКИ ОБЛОЖКИ (Обход CORS) ---
class _CORSImage extends StatelessWidget {
  final String url;
  final double size;
  final double radius;

  const _CORSImage({required this.url, required this.size, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();

    return FutureBuilder<Uint8List>(
      future: http.get(Uri.parse(url)).then((res) => res.bodyBytes),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.memory(snapshot.data!, width: size, height: size, fit: BoxFit.cover),
          );
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(radius)),
      child: const Icon(Icons.music_note, color: Colors.white38),
    );
  }
}

// --- НОВАЯ ФОРМА ЗАГРУЗКИ ТРЕКОВ ---
class UploadTrackForm extends StatefulWidget {
  final String baseUrl;
  const UploadTrackForm({super.key, required this.baseUrl});

  @override
  State<UploadTrackForm> createState() => _UploadTrackFormState();
}

class _UploadTrackFormState extends State<UploadTrackForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  
  PlatformFile? _audioFile;
  PlatformFile? _coverFile;
  bool _isUploading = false;

  Future<void> _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true, 
    );
    if (result != null) setState(() => _audioFile = result.files.first);
  }

  Future<void> _pickCover() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) setState(() => _coverFile = result.files.first);
  }

  Future<void> _uploadTrack() async {
    if (_titleController.text.isEmpty || _artistController.text.isEmpty || _audioFile == null || _coverFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Заполните все поля и выберите файлы!")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('${widget.baseUrl}/upload-track'));
      
      request.fields['title'] = _titleController.text;
      request.fields['artist'] = _artistController.text;

      // Аудиофайл (байты для Web)
      request.files.add(http.MultipartFile.fromBytes(
        'audio', 
        _audioFile!.bytes!,
        filename: _audioFile!.name,
      ));

      // Обложка (байты для Web)
      request.files.add(http.MultipartFile.fromBytes(
        'cover', 
        _coverFile!.bytes!,
        filename: _coverFile!.name,
      ));

      var response = await request.send();

      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context); // Закрываем модальное окно
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Трек успешно загружен!", style: TextStyle(color: Colors.green))));
        }
      } else {
        throw Exception("Ошибка загрузки: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Загрузить новый трек", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 20),
        
        TextField(
          controller: _titleController,
          decoration: InputDecoration(labelText: "Название песни", filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 15),
        
        TextField(
          controller: _artistController,
          decoration: InputDecoration(labelText: "Исполнитель", filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickAudio,
                icon: const Icon(Icons.audiotrack),
                label: Text(_audioFile != null ? "MP3 выбран" : "Выбрать MP3"),
                style: ElevatedButton.styleFrom(backgroundColor: _audioFile != null ? Colors.green.withOpacity(0.2) : Colors.grey[800], foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickCover,
                icon: const Icon(Icons.image),
                label: Text(_coverFile != null ? "Фото выбрано" : "Выбрать фото"),
                style: ElevatedButton.styleFrom(backgroundColor: _coverFile != null ? Colors.green.withOpacity(0.2) : Colors.grey[800], foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 30),
        
        _isUploading
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : ElevatedButton(
                onPressed: _uploadTrack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Загрузить", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
        const SizedBox(height: 20),
      ],
    );
  }
}