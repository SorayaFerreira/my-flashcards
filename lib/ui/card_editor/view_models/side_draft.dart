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
}

/// What the editor holds for one side of the card while it is being edited.
class SideDraft {
  const SideDraft({this.text = '', this.image});

  factory SideDraft.fromCardSide(CardSide side) => SideDraft(
    text: side.text ?? '',
    image: side.image == null ? null : DraftFile(side.image!, isNew: false),
  );

  final String text;
  final DraftFile? image;

  bool get isEmpty => text.trim().isEmpty && image == null;

  /// Files created during this editing session, still in the draft folder.
  List<String> get newFileNames => [
    if (image case DraftFile(:final name, isNew: true)) name,
  ];

  SideDraft withText(String text) => SideDraft(text: text, image: image);

  SideDraft withImage(DraftFile? image) => SideDraft(text: text, image: image);

  CardSide toCardSide() => CardSide(
    text: text.trim().isEmpty ? null : text.trim(),
    image: image?.name,
  );

  @override
  bool operator ==(Object other) =>
      other is SideDraft && other.text == text && other.image == image;

  @override
  int get hashCode => Object.hash(text, image);
}
