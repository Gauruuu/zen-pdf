class RecentFile {
  final String path;
  final String name;
  final int sizeInBytes;
  final DateTime modifiedDate;
  final int? pageCount;

  RecentFile({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.modifiedDate,
    this.pageCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'sizeInBytes': sizeInBytes,
      'modifiedDate': modifiedDate.toIso8601String(),
      'pageCount': pageCount,
    };
  }

  factory RecentFile.fromJson(Map<String, dynamic> json) {
    return RecentFile(
      path: json['path'] as String,
      name: json['name'] as String,
      sizeInBytes: json['sizeInBytes'] as int,
      modifiedDate: DateTime.parse(json['modifiedDate'] as String),
      pageCount: json['pageCount'] as int?,
    );
  }
}
