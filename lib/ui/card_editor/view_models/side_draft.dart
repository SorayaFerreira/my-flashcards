import '../../../domain/models/card_side.dart';

/// What the editor holds for one side of the card while it is being edited.
class SideDraft {
  const SideDraft({this.text = ''});

  factory SideDraft.fromCardSide(CardSide side) =>
      SideDraft(text: side.text ?? '');

  final String text;

  bool get isEmpty => text.trim().isEmpty;

  SideDraft withText(String text) => SideDraft(text: text);

  CardSide toCardSide() => CardSide(text: isEmpty ? null : text.trim());

  @override
  bool operator ==(Object other) => other is SideDraft && other.text == text;

  @override
  int get hashCode => text.hashCode;
}
