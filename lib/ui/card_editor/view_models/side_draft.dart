import '../../../domain/models/card_side.dart';

/// A media file used by a draft. A new file stays in the editor's draft
/// folder until the card is saved.
class DraftFile {
  const DraftFile(this.name, {required this.isNew});

  final String name;
  final bool isNew;

  @override
  bool operator ==(Object other) =>
      other is DraftFile && other.name == name && other.isNew == isNew;

  @override
  int get hashCode => Object.hash(name, isNew);

  @override
  String toString() => 'DraftFile($name, isNew: $isNew)';
}

/// What the editor holds for one side of the card while it is being edited.
class SideDraft {
  const SideDraft({this.text = '', this.image, this.audio});

  factory SideDraft.fromCardSide(CardSide side) => SideDraft(
    text: side.text ?? '',
    image: side.image == null ? null : DraftFile(side.image!, isNew: false),
    audio: side.audio == null ? null : DraftFile(side.audio!, isNew: false),
  );

  final String text;
  final DraftFile? image;
  final DraftFile? audio;

  bool get isEmpty => text.trim().isEmpty && image == null && audio == null;

  /// Files created during this editing session, still in the draft folder.
  List<String> get newFileNames => [
    if (image case DraftFile(:final name, isNew: true)) name,
    if (audio case DraftFile(:final name, isNew: true)) name,
  ];

  SideDraft withText(String text) =>
      SideDraft(text: text, image: image, audio: audio);

  SideDraft withImage(DraftFile? image) =>
      SideDraft(text: text, image: image, audio: audio);

  SideDraft withAudio(DraftFile? audio) =>
      SideDraft(text: text, image: image, audio: audio);

  CardSide toCardSide() => CardSide(
    text: text.trim().isEmpty ? null : text.trim(),
    image: image?.name,
    audio: audio?.name,
  );

  @override
  bool operator ==(Object other) =>
      other is SideDraft &&
      other.text == text &&
      other.image == image &&
      other.audio == audio;

  @override
  int get hashCode => Object.hash(text, image, audio);
}
