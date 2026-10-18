import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/ui/card_editor/view_models/side_draft.dart';

void main() {
  test('um lado só com áudio não está vazio', () {
    const draft = SideDraft(audio: DraftFile('aud_1.m4a', isNew: true));

    expect(draft.isEmpty, isFalse);
  });

  test('newFileNames lista imagem e áudio novos, nunca os já salvos', () {
    const draft = SideDraft(
      image: DraftFile('img_salva.jpg', isNew: false),
      audio: DraftFile('aud_novo.m4a', isNew: true),
    );

    expect(draft.newFileNames, ['aud_novo.m4a']);
  });

  test('vai e volta de CardSide mantendo os três conteúdos', () {
    const side = CardSide(text: 'oi', image: 'img_1.jpg', audio: 'aud_1.m4a');

    final draft = SideDraft.fromCardSide(side);

    expect(draft.audio, const DraftFile('aud_1.m4a', isNew: false));
    expect(draft.toCardSide(), side);
  });

  test('withText e withImage não perdem o áudio', () {
    const draft = SideDraft(audio: DraftFile('aud_1.m4a', isNew: true));

    expect(draft.withText('x').audio, draft.audio);
    expect(draft.withImage(null).audio, draft.audio);
    expect(draft.withAudio(null).isEmpty, isTrue);
  });
}
