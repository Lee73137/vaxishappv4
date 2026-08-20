class VaxiVideo {
  const VaxiVideo({required this.title, required this.videoUrl});

  final String title;
  final String videoUrl;

  factory VaxiVideo.fromJson(Map<String, dynamic> json) {
    return VaxiVideo(
      title: json['title']?.toString() ?? '',
      videoUrl: json['videopath']?.toString() ?? '',
    );
  }
}
