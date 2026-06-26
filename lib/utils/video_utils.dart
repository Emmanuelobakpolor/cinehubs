library;

/// HTTP headers for network video requests.
///
/// [isTrailer] = false → adds `Range: bytes=0-` which triggers HTTP 206 on
/// Django and Cloudinary, enabling seek-without-redownload.
/// [isTrailer] = true  → keep-alive only; range header adds a redundant
/// round-trip on looping clips that always start from byte 0.
///
/// Cloudinary migration: uncomment the block below when switching media hosts.
Map<String, String> buildVideoHeaders({
  required String url,
  bool isTrailer = false,
}) {
  // ── Future Cloudinary hook ──────────────────────────────────────────────
  // if (url.contains('res.cloudinary.com')) {
  //   return {
  //     if (!isTrailer) 'Range': 'bytes=0-',
  //     'Connection': 'keep-alive',
  //   };
  // }
  // ────────────────────────────────────────────────────────────────────────

  if (isTrailer) return const {'Connection': 'keep-alive'};
  return const {'Range': 'bytes=0-', 'Connection': 'keep-alive'};
}

/// Returns true when [url] points to an HLS manifest.
/// `video_player` handles `.m3u8` natively on Android and iOS —
/// no special controller factory is needed, just pass the URL through.
bool isHlsUrl(String url) =>
    url.toLowerCase().contains('.m3u8') ||
    url.toLowerCase().contains('/manifest/');
