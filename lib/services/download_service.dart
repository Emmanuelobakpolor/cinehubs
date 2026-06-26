import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when a download is intentionally paused by the user — not an error.
class DownloadPausedException implements Exception {
  const DownloadPausedException();
}

class DownloadService {
  static const _prefsKey = 'ch_downloaded_movies';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(minutes: 5),
    receiveTimeout: const Duration(minutes: 30),
  ));

  /// Active CancelTokens, keyed by movieId — used to pause downloads.
  static final Map<int, CancelToken> _activeTokens = {};

  /// Live progress for each active download (0.0–1.0), keyed by movieId.
  static final Map<int, double> _progressMap = {};

  /// Broadcasts a void event whenever any download's progress changes.
  /// Listeners should call [currentProgress] / [isDownloaded] / [isPaused]
  /// to query current state — the event itself carries no payload.
  static final StreamController<void> _progressController =
      StreamController.broadcast();

  static Stream<void> get progressUpdates => _progressController.stream;

  /// Returns the current download progress (0.0–1.0) for [movieId],
  /// or null if no active download exists for that movie.
  static double? currentProgress(int movieId) => _progressMap[movieId];

  // ── Internal helpers ────────────────────────────────────────────────────

  static Future<Map<String, String>> _loadMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  static Future<void> _saveMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  static Future<Directory> _moviesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/cinehubs_movies');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Returns true if the complete movie file exists locally.
  static Future<bool> isDownloaded(int movieId) async {
    final path = await getLocalPath(movieId);
    if (path == null) return false;
    return File(path).existsSync();
  }

  /// Returns true if a paused (partial) download exists for [movieId].
  static Future<bool> isPaused(int movieId) async {
    final dir = await _moviesDir();
    return File('${dir.path}/$movieId.mp4.part').existsSync();
  }

  /// Returns true if [movieId] is actively downloading right now.
  static bool isActivelyDownloading(int movieId) =>
      _activeTokens.containsKey(movieId);

  /// Returns the local file path for [movieId], or null if not downloaded.
  static Future<String?> getLocalPath(int movieId) async {
    final map = await _loadMap();
    final path = map[movieId.toString()];
    if (path == null) return null;
    return File(path).existsSync() ? path : null;
  }

  /// Pauses an active download by cancelling its HTTP request.
  ///
  /// The partial `.part` file is kept on disk so [downloadMovie] can resume
  /// from where it left off via an HTTP Range request.
  static void pauseDownload(int movieId) {
    _activeTokens[movieId]?.cancel('paused');
  }

  /// Downloads [url] to device storage, calling [onProgress] with 0.0–1.0.
  ///
  /// **Resume support**: if a `.part` file exists from a previous paused
  /// download, the transfer resumes using `Range: bytes=<offset>-`.
  ///
  /// Throws [DownloadPausedException] when paused — treat it as a non-error
  /// state and call [downloadMovie] again when the user wants to resume.
  static Future<void> downloadMovie(
    int movieId,
    String url,
    void Function(double progress) onProgress,
  ) async {
    final dir = await _moviesDir();
    final savePath = '${dir.path}/$movieId.mp4';
    final partPath = '${dir.path}/$movieId.mp4.part';
    final partFile = File(partPath);

    // Resume from an existing partial download if present
    int startByte = 0;
    if (await partFile.exists()) {
      startByte = await partFile.length();
    }

    final token = CancelToken();
    _activeTokens[movieId] = token;

    IOSink? sink;
    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
        ),
        cancelToken: token,
      );

      // Determine total file size for accurate progress reporting.
      // A Range response gives Content-Length = remaining bytes, so we add
      // startByte to get the true total.
      int totalBytes = 0;
      final contentLen =
          response.headers.value(Headers.contentLengthHeader);
      if (contentLen != null) {
        totalBytes = (int.tryParse(contentLen) ?? 0) + startByte;
      }
      // Fallback: parse Content-Range: bytes X-Y/Z
      if (totalBytes == 0) {
        final cr = response.headers.value('content-range');
        if (cr != null) {
          final m = RegExp(r'/(\d+)$').firstMatch(cr);
          if (m != null) totalBytes = int.tryParse(m.group(1)!) ?? 0;
        }
      }

      // Append to partial file if resuming, otherwise write fresh
      sink = partFile.openWrite(
        mode: startByte > 0 ? FileMode.append : FileMode.write,
      );
      int received = startByte;

      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          final progress = (received / totalBytes).clamp(0.0, 1.0);
          _progressMap[movieId] = progress;
          _progressController.add(null);
          onProgress(progress);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Rename .part → final path now that the download is complete
      await partFile.rename(savePath);

      final map = await _loadMap();
      map[movieId.toString()] = savePath;
      await _saveMap(map);
    } on DioException catch (e) {
      await sink?.flush();
      await sink?.close();
      if (CancelToken.isCancel(e)) {
        // Partial file is preserved for resume — surface as a non-error pause
        throw const DownloadPausedException();
      }
      rethrow;
    } catch (_) {
      await sink?.flush();
      await sink?.close();
      rethrow;
    } finally {
      _activeTokens.remove(movieId);
      _progressMap.remove(movieId);
      _progressController.add(null); // notify listeners that state changed
    }
  }

  /// Deletes the local file (and any partial download) and removes the entry.
  static Future<void> deleteDownload(int movieId) async {
    final map = await _loadMap();
    final path = map.remove(movieId.toString());
    await _saveMap(map);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    // Clean up any leftover .part file
    final dir = await _moviesDir();
    final partFile = File('${dir.path}/$movieId.mp4.part');
    if (await partFile.exists()) await partFile.delete();
  }
}
