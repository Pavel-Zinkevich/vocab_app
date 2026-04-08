import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html_unescape/html_unescape.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/dom.dart' as dom;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

/// --- Main Definition Page Widget ---
class DefinitionPage extends StatefulWidget {
  final String word;
  final bool showAudio;
  final String? wordUrl;

  const DefinitionPage({
    Key? key,
    required this.word,
    this.showAudio = true,
    this.wordUrl,
  }) : super(key: key);

  @override
  State<DefinitionPage> createState() => _DefinitionPageState();
}

/// --- Global listen label (dynamic for FR/EN) ---
String _listenLabel = 'ÉCOUTER:';

/// --- Audio Dropdown Model ---
class _AudioDropdownValue {
  final int? accentIndex;
  final double? speed;

  const _AudioDropdownValue.accent(this.accentIndex) : speed = null;
  const _AudioDropdownValue.speed(this.speed) : accentIndex = null;

  bool get isAccent => accentIndex != null;
  bool get isSpeed => speed != null;
}

/// --- Word Sense Model ---
class _Sense {
  final String french;
  final String translation;
  final List<String> frExamples = [];
  final List<String> enExamples = [];

  _Sense({required this.french, required this.translation});
}

/// --- Audio Option Model ---
class _AudioOption {
  final String label;
  final String url;

  _AudioOption(this.label, this.url);
}

/// --- Clean raw translations from grammar tags and symbols ---
String _cleanTranslation(String raw) {
  String cleaned = raw;

  // Remove everything after ⇒
  if (cleaned.contains('⇒')) cleaned = cleaned.split('⇒')[0];

  // Remove grammar tags
  final grammarPattern = RegExp(
    r'\b(vtr|vi|adj|adv|expr|loc|prep| pron| v|insep|phrasal|v pron|interj| n|nm|nf|npl|v expr|v aux|v past p|vtr \+ prep|vtr \+ refl)\b',
    caseSensitive: false,
  );
  cleaned = cleaned.replaceAll(grammarPattern, '');

  // Remove extra symbols like "+"
  cleaned = cleaned.replaceAll('+', '');

  // Normalize spaces
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

  return cleaned;
}

/// --- Definition Page State ---
class _DefinitionPageState extends State<DefinitionPage> {
  bool _loading = true;
  String? _error;
  final List<_Sense> _senses = [];

  final _player = AudioPlayer();
  List<_AudioOption> _audio = [];
  int _accentIndex = 0;
  double _speed = 1.0;
  String? _ipa;

  @override
  void initState() {
    super.initState();
    if (widget.showAudio) _restoreAudioPref();
    _fetchDefinition();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// --- Add a word to user's Firebase vocabulary ---
  Future<void> _addWordToVocabulary(_Sense sense) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vocabulary')
          .add({
        'word': _cleanTranslation(sense.french),
        'translation': _cleanTranslation(sense.translation),
        'context': sense.frExamples.isNotEmpty ? sense.frExamples.first : '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Word "${sense.french}" added to vocabulary'),
            duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to add word: $e'),
            duration: Duration(seconds: 1)),
      );
    }
  }

  /// --- Audio Preferences ---
  Future<void> _restoreAudioPref() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('wr_audio-fr'); // "index:speed"
    if (raw != null) {
      final parts = raw.split(':');
      setState(() {
        _accentIndex = int.tryParse(parts[0]) ?? 0;
        _speed = parts.length > 1 ? double.tryParse(parts[1]) ?? 1.0 : 1.0;
      });
    }
  }

  Future<void> _saveAudioPref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'wr_audio-fr', '$_accentIndex:${_speed.toStringAsFixed(2)}');
  }

  /// --- Prepare audio player ---
  Future<void> _preparePlayer() async {
    if (_audio.isEmpty) return;
    _accentIndex = _accentIndex.clamp(0, _audio.length - 1);
    await _player.setUrl(_audio[_accentIndex].url);
    await _player.setSpeed(_speed);
  }

  /// --- Extract audio files from WordReference HTML ---
  List<_AudioOption> _extractAudioFiles(String html) {
    final match = RegExp(r"window\.audioFiles\s*=\s*\[(.*?)\];", dotAll: true)
        .firstMatch(html);
    if (match == null) return [];

    final urls = RegExp(r"'([^']+\.mp3)'")
        .allMatches(match.group(1)!)
        .map((m) => m.group(1)!)
        .toList();

    return urls.map((path) {
      final parts = path.split('/');
      final label = parts.length >= 4 ? parts[parts.length - 2] : 'Unknown';
      final absolute = 'https://www.wordreference.com$path';
      return _AudioOption(label, absolute);
    }).toList();
  }

  /// --- Fetch definition from WordReference ---
  Future<void> _fetchDefinition() async {
    setState(() {
      _loading = true;
      _error = null;
      _senses.clear();
      _audio.clear();
      _ipa = null;
    });

    final wordEsc = Uri.encodeComponent(widget.word.trim());
    final url = widget.wordUrl != null
        ? Uri.parse(widget.wordUrl!)
        : Uri.parse('https://www.wordreference.com/fren/$wordEsc');

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) {
        _error = resp.statusCode == 404
            ? 'Word not found on WordReference.'
            : 'Server error (${resp.statusCode}). Please try again.';
      } else {
        _parseHtml(resp.body);
      }
    } catch (e) {
      _error = 'Failed to fetch definition. ${e.toString()}';
    }

    if (mounted) setState(() => _loading = false);
  }

  /// --- Detect if listen label should be EN/FR ---
  void _detectListenLabel(dom.Document document) {
    final listenSpan = document.querySelector('#listen_txt')?.text.trim() ?? '';
    if (listenSpan.toLowerCase().startsWith('listen')) {
      _listenLabel = 'LISTEN:';
    } else {
      _listenLabel = 'ÉCOUTER:'; // default fallback
    }
  }

  /// --- Parse HTML and extract definitions, examples, IPA, and audio ---
  void _parseHtml(String body) {
    final document = html_parser.parse(body);

    // Remove scripts/styles
    document
        .querySelectorAll('script, style, noscript')
        .forEach((e) => e.remove());

    _detectListenLabel(document);
    _ipa = document.querySelector('#pronWR')?.text.trim();

    if (widget.showAudio) {
      _audio = _extractAudioFiles(body);
      _preparePlayer().catchError((_) {});
    }

    dom.Element? content =
        document.querySelector('#articleWRD') ?? _fallbackSelector(document);

    if (content == null) return;

    final unescape = HtmlUnescape();
    final tables = content.querySelectorAll('table');

    for (final table in tables) {
      if (!(table.attributes['class'] ?? '').toLowerCase().contains('wrd'))
        continue;
      _parseTableRows(table, unescape);
    }

    if (_senses.isEmpty) {
      _error = 'No definition found for "${widget.word}" on WordReference.';
    }
  }

  dom.Element? _fallbackSelector(dom.Document doc) {
    final selectors = ['#article', '#content', '.entry', '.WRD', '#centerCol'];
    for (final sel in selectors) {
      final el = doc.querySelector(sel);
      if (el != null) return el;
    }
    return null;
  }

  /// --- Show a dialog to look up a new word ---
  void _showLookupDialog() {
    final lookupController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Look up a word'),
          content: TextField(
            controller: lookupController,
            decoration: const InputDecoration(hintText: 'Enter word'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final word = lookupController.text.trim();
                if (word.isNotEmpty) {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DefinitionPage(word: word)),
                  );
                }
              },
              child: const Text('Look Up'),
            ),
          ],
        );
      },
    );
  }

  /// --- UI badge helpers ---
  String get _badgeLabel {
    final url = widget.wordUrl ?? '';
    if (url.contains('/enfr/')) return 'English → French';
    if (url.contains('/fren/')) return 'French → English';
    return 'Link to the site';
  }

  String get _badgeUrl {
    return widget.wordUrl ??
        'https://www.wordreference.com/enfr/${widget.word}';
  }

  /// --- Parse table rows for senses and examples ---
  void _parseTableRows(dom.Element table, HtmlUnescape unescape) {
    bool isHeaderRow(dom.Element tr) {
      return tr.querySelectorAll('th').isNotEmpty ||
          tr.classes.contains('langHeader') ||
          (tr.text.toLowerCase().contains('principales traductions') ||
              tr.text.toLowerCase().contains('français → anglais'));
    }

    for (final tr in table.querySelectorAll('tr')) {
      if (isHeaderRow(tr)) continue;

      final frTd = tr.querySelector('td.FrWrd');
      final toTd = tr.querySelector('td.ToWrd');
      final frExTd = tr.querySelector("td.FrEx");
      final toExTd = tr.querySelector("td.ToEx");

      if (frTd != null || toTd != null) {
        final french = frTd?.text.trim() ?? '';
        final translation = toTd?.text.trim() ?? '';
        if (french.isEmpty || translation.isEmpty) continue;

        final sense = _Sense(
          french: unescape.convert(french),
          translation: _cleanTranslation(unescape.convert(translation)),
        );

        _attachExamples(sense, frExTd, toExTd, unescape);
        _senses.add(sense);
      } else if ((frExTd != null || toExTd != null) && _senses.isNotEmpty) {
        _attachExamples(_senses.last, frExTd, toExTd, unescape);
      }
    }

    // Deduplicate examples
    for (final s in _senses) {
      s.frExamples
          .replaceRange(0, s.frExamples.length, s.frExamples.toSet().toList());
      s.enExamples
          .replaceRange(0, s.enExamples.length, s.enExamples.toSet().toList());
    }
  }

  void _attachExamples(_Sense sense, dom.Element? frExTd, dom.Element? toExTd,
      HtmlUnescape unescape) {
    if (frExTd != null) {
      final fe = frExTd.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (fe.isNotEmpty) sense.frExamples.add(unescape.convert(fe));
    }
    if (toExTd != null) {
      final te = toExTd.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (te.isNotEmpty) sense.enExamples.add(unescape.convert(te));
    }
  }

  /// --- Build UI ---
  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        // automaticallyImplyLeading: false, arrow
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: const Text('', style: TextStyle(color: Colors.black)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(surface),
      floatingActionButton: FloatingActionButton(
        heroTag: 'lookupWord',
        backgroundColor: Colors.deepPurple,
        onPressed: _showLookupDialog,
        child: const Icon(Icons.search, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Unknown error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _fetchDefinition, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Color surface) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  color: Color.fromARGB(17, 255, 0, 0),
                  blurRadius: 12,
                  offset: Offset(0, 6))
            ],
          ),
          child: _buildContentCard(),
        ),
      ),
    );
  }

  Widget _buildContentCard() {
    /// Header
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 28,
          height: 1.1,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.word, style: titleStyle),
        const SizedBox(height: 10),
        Row(
          ///badge
          children: [
            _Badge(label: _badgeLabel, url: _badgeUrl),
            const SizedBox(width: 12),
          ],
        ),

        ///audio
        const SizedBox(height: 12),
        if (widget.showAudio && _audio.isNotEmpty) ...[
          _buildAudioBar(),
          const SizedBox(height: 12),
        ],
        if (_senses.isNotEmpty)
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _senses.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 24, thickness: 0.6),
            itemBuilder: (context, i) =>
                _SenseTile(index: i, sense: _senses[i]),
          ),
      ],
    );
  }

  /// --- Audio Bar Widget ---
  Widget _buildAudioBar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.black12),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: () async {
            if (_audio.isEmpty) return;
            try {
              await _player.setUrl(_audio[_accentIndex].url);
              await _player.setSpeed(_speed);
              await _player.play();
            } catch (_) {}
          },
          icon: const Icon(Icons.volume_up_rounded),
          label: Text(_listenLabel),
        ),
        SizedBox(
          width: 180,
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              border: border,
              enabledBorder: border,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_AudioDropdownValue>(
                hint: Text(
                    '${_audio[_accentIndex].label.toUpperCase()} • ${(_speed * 100).toInt()}%'),
                value: null,
                items: [
                  ...List.generate(_audio.length, (i) {
                    return DropdownMenuItem<_AudioDropdownValue>(
                      value: _AudioDropdownValue.accent(i),
                      child: Text(_audio[i].label.toUpperCase()),
                    );
                  }),
                  const DropdownMenuItem(
                      enabled: false, child: Divider(thickness: 1)),
                  const DropdownMenuItem(
                      value: _AudioDropdownValue.speed(1.0),
                      child: Text('100%')),
                  const DropdownMenuItem(
                      value: _AudioDropdownValue.speed(0.75),
                      child: Text('75%')),
                  const DropdownMenuItem(
                      value: _AudioDropdownValue.speed(0.5),
                      child: Text('50%')),
                ],
                onChanged: (val) async {
                  if (val == null) return;
                  if (val.isAccent) {
                    setState(() => _accentIndex = val.accentIndex!);
                    await _preparePlayer();
                  } else if (val.isSpeed) {
                    setState(() => _speed = val.speed!);
                    await _player.setSpeed(_speed);
                  }
                  await _saveAudioPref();
                },
              ),
            ),
          ),
        ),
        if (_ipa != null && _ipa!.isNotEmpty)
          Text(_ipa!, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

/// --- Badge Widget ---
class _Badge extends StatelessWidget {
  final String label;
  final String? url;

  const _Badge({required this.label, this.url});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF5C7CF2);

    return GestureDetector(
      onTap: url != null
          ? () async {
              if (await canLaunchUrl(Uri.parse(url!))) {
                await launchUrl(Uri.parse(url!));
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Text(label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                )),
      ),
    );
  }
}

/// --- Sense row widget ---
class _SenseTile extends StatelessWidget {
  final int index;
  final _Sense sense;

  const _SenseTile({required this.index, required this.sense});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge;
    final posStyle = base?.copyWith(
        fontSize: (base?.fontSize ?? 16) - 2,
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2);

    final state = context.findAncestorStateOfType<_DefinitionPageState>();

    return GestureDetector(
      onTap: () => state?._addWordToVocabulary(sense),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: base?.copyWith(color: Colors.black87),
              children: [
                TextSpan(
                    text: '${index + 1}. ',
                    style: base?.copyWith(fontWeight: FontWeight.w600)),
                TextSpan(
                  text: _cleanTranslation(sense.french),
                  style: base?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: " - ",
                  style: base?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ' ${sense.translation}',
                  style: base?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          ..._buildExamples(sense.frExamples, context),
          ..._buildExamples(sense.enExamples, context, italic: true),
        ],
      ),
    );
  }

  List<Widget> _buildExamples(List<String> examples, BuildContext context,
      {bool italic = false}) {
    if (examples.isEmpty) return [];
    return [
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.only(left: 24.0, bottom: 2),
        child: Text(
          examples.first,
          style: italic
              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.black.withOpacity(0.7))
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ];
  }

  ///useless
  static List<InlineSpan> _formatTermSpans(String raw,
      {required bool isLemma, TextStyle? base, TextStyle? pos}) {
    final spans = <InlineSpan>[];
    final posPattern = RegExp(
        r'\b(loc v|loc adv|loc adj|vi|vt|nm|nf|n|adj|adv|expr|prep|pron|conj|interj)\b',
        caseSensitive: false);
    final match = posPattern.firstMatch(raw);

    if (match == null) {
      spans.add(TextSpan(
          text: raw,
          style: base?.copyWith(
              fontWeight: isLemma ? FontWeight.w700 : FontWeight.w600)));
      return spans;
    }

    final before = raw.substring(0, match.start).trimRight();
    final posToken = match.group(0)!;
    final after = raw.substring(match.end).trimLeft();

    if (before.isNotEmpty)
      spans.add(TextSpan(
          text: before,
          style: base?.copyWith(
              fontWeight: isLemma ? FontWeight.w700 : FontWeight.w600)));
    spans.add(TextSpan(text: ' ${posToken.toLowerCase()}', style: pos));
    if (after.isNotEmpty) spans.add(TextSpan(text: ' $after', style: base));
    return spans;
  }
}
