import 'package:cloud_functions/cloud_functions.dart';

class AiListing {
  final String id;
  final String title;
  final String author;
  const AiListing(this.id, this.title, this.author);
}

class AiReply {
  final String text;
  final List<AiListing> listings;
  const AiReply(this.text, this.listings);
}

/// Talks to the `aiAssistant` Cloud Function. The AI provider key never touches the app.
class AiRepository {
  final FirebaseFunctions _functions;
  AiRepository(this._functions);

  Future<AiReply> ask(List<Map<String, String>> messages) async {
    final res = await _functions
        .httpsCallable('aiAssistant', options: HttpsCallableOptions(timeout: const Duration(seconds: 50)))
        .call<Map<String, dynamic>>({'messages': messages});
    final d = res.data;
    final listings = (d['listings'] as List? ?? [])
        .map((e) => AiListing(e['id'].toString(), e['title'].toString(), e['author'].toString()))
        .toList();
    return AiReply(d['reply'].toString(), listings);
  }
}
