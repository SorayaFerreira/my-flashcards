enum Side { front, back }

class CardSide {
  const CardSide({this.text, this.image, this.audio});

  static const empty = CardSide();

  final String? text;

  /// File name inside the media folder, never a full path.
  final String? image;

  /// File name inside the media folder, never a full path.
  final String? audio;

  bool get hasText => text != null && text!.trim().isNotEmpty;

  bool get isEmpty => !hasText && image == null && audio == null;

  List<String> get fileNames => [?image, ?audio];

  @override
  bool operator ==(Object other) =>
      other is CardSide &&
      other.text == text &&
      other.image == image &&
      other.audio == audio;

  @override
  int get hashCode => Object.hash(text, image, audio);

  @override
  String toString() => 'CardSide(text: $text, image: $image, audio: $audio)';
}
