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
import '../theme/app_colors.dart';
import '../service/language_service.dart';

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

/// --- Global listen label dynamic for FR/EN/ES ---
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
  final String source;
  final String target;
  final List<String> sourceExamples;
  final List<String> targetExamples;

  _Sense({
    required this.source,
    required this.target,
    List<String>? sourceExamples,
    List<String>? targetExamples,
  })  : sourceExamples = sourceExamples ?? [],
        targetExamples = targetExamples ?? [];

  _Sense copyWith({
    String? source,
    String? target,
    List<String>? sourceExamples,
    List<String>? targetExamples,
  }) {
    return _Sense(
      source: source ?? this.source,
      target: target ?? this.target,
      sourceExamples: sourceExamples ?? List.from(this.sourceExamples),
      targetExamples: targetExamples ?? List.from(this.targetExamples),
    );
  }
}

/// --- Audio Option Model ---
class _AudioOption {
  final String label;
  final String url;

  _AudioOption(this.label, this.url);
}

/// Extract visible text from a DOM node while removing WordReference grammar/POS tags.
///
/// Important:
/// - WordReference puts grammar info inside `<em class="POS2" data-abbr="...">`.
/// - We skip every `<em>` entirely.
/// - We also skip any element with `data-abbr`.
/// - We skip conjugation links like `⇒`.
String _visibleTextWithoutGrammar(dom.Node node) {
  if (node is dom.Text) {
    return node.text;
  }

  if (node is dom.Element) {
    final tag = node.localName?.toLowerCase() ?? '';

    if (tag == 'script' ||
        tag == 'style' ||
        tag == 'noscript' ||
        tag == 'em' ||
        node.attributes.containsKey('data-abbr')) {
      return '';
    }

    if (tag == 'a' && node.classes.contains('conjugate')) {
      return '';
    }

    if (tag == 'br') {
      return ' ';
    }
  }

  return node.nodes.map(_visibleTextWithoutGrammar).join();
}

/// Clean raw translations without using grammar regex.
///
/// Grammar is removed before this by reading DOM text while skipping `<em>`
/// and `data-abbr` elements.
String _cleanTranslation(String raw) {
  String cleaned = raw;

  /// Safety fallback: if HTML is accidentally passed here, remove em/data-abbr.
  if (cleaned.contains('<')) {
    final fragment = html_parser.parseFragment(cleaned);

    fragment
        .querySelectorAll(
            'em, [data-abbr], script, style, noscript, a.conjugate')
        .forEach((e) => e.remove());

    cleaned = fragment.text ?? '';
  }

  /// Safety fallback for conjugation arrows.
  if (cleaned.contains('⇒')) {
    cleaned = cleaned.split('⇒')[0];
  }

  cleaned =
      cleaned.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  return cleaned;
}

/// Clean text from a specific DOM element, excluding grammar/POS tags.
String _cleanElementText(dom.Element element, HtmlUnescape unescape) {
  final raw = _visibleTextWithoutGrammar(element);
  return _cleanTranslation(unescape.convert(raw));
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
        'word': _cleanTranslation(sense.source),
        'translation': _cleanTranslation(sense.target),
        'context':
            sense.sourceExamples.isNotEmpty ? sense.sourceExamples.first : '',
        'language': LanguageService.instance.currentLang,
        'status': 'learning',
        'step': 0,
        'nextReview': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Word "${sense.source}" added to vocabulary'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add word: $e'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// --- Audio Preferences ---
  Future<void> _restoreAudioPref() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = LanguageService.instance.currentLang;
    final raw = prefs.getString('wr_audio-$lang');

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
    final lang = LanguageService.instance.currentLang;

    await prefs.setString(
      'wr_audio-$lang',
      '$_accentIndex:${_speed.toStringAsFixed(2)}',
    );
  }

  /// --- Prepare audio player ---
  Future<void> _preparePlayer() async {
    if (_audio.isEmpty) return;

    _accentIndex = _accentIndex.clamp(0, _audio.length - 1).toInt();

    await _player.setUrl(_audio[_accentIndex].url);
    await _player.setSpeed(_speed);
  }

  /// --- Extract audio files from WordReference HTML ---
  List<_AudioOption> _extractAudioFiles(String html) {
    final match = RegExp(
      r"window\.audioFiles\s*=\s*\[(.*?)\];",
      dotAll: true,
    ).firstMatch(html);

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
    final langCode =
        LanguageService.instance.currentLang == 'fr' ? 'fren' : 'esen';

    final url = widget.wordUrl != null
        ? Uri.parse(widget.wordUrl!)
        : Uri.parse('https://www.wordreference.com/$langCode/$wordEsc');

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

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  /// --- Detect if listen label should be EN/FR/ES ---
  void _detectListenLabel(dom.Document document) {
    if (LanguageService.instance.currentLang == 'es') {
      _listenLabel = 'ESCUCHAR:';
      return;
    }

    final listenSpan = document.querySelector('#listen_txt')?.text.trim() ?? '';

    if (listenSpan.toLowerCase().startsWith('listen')) {
      _listenLabel = 'LISTEN:';
    } else {
      _listenLabel = 'ÉCOUTER:';
    }
  }

  /// Choose an extra translation segment that fits within [maxLen] characters.
  String? _chooseExtraSegment(String raw, {int maxLen = 50}) {
    final candidate = raw.trim();

    if (candidate.length <= maxLen) return candidate;

    if (candidate.contains(',')) {
      for (final part in candidate.split(',')) {
        final p = part.trim();
        if (p.isNotEmpty && p.length <= maxLen) return p;
      }
    }

    if (candidate.contains('/')) {
      for (final part in candidate.split('/')) {
        final p = part.trim();
        if (p.isNotEmpty && p.length <= maxLen) return p;
      }
    }

    return null;
  }

  /// --- Parse HTML and extract definitions, examples, IPA, and audio ---
  void _parseHtml(String body) {
    final document = html_parser.parse(body);

    document
        .querySelectorAll('script, style, noscript')
        .forEach((e) => e.remove());

    _detectListenLabel(document);

    _ipa = document.querySelector('#pronWR')?.text.trim();

    if (widget.showAudio) {
      _audio = _extractAudioFiles(body);
      _preparePlayer().catchError((_) {});
    }

    final dom.Element? content =
        document.querySelector('#articleWRD') ?? _fallbackSelector(document);

    if (content == null) return;

    final unescape = HtmlUnescape();
    final tables = content.querySelectorAll('table');

    for (final table in tables) {
      final className = (table.attributes['class'] ?? '').toLowerCase();

      if (!className.contains('wrd')) continue;

      _parseTableRows(table, unescape);
    }

    if (_senses.isEmpty) {
      _error = 'No definition found for "${widget.word}" on WordReference.';
    }
  }

  dom.Element? _fallbackSelector(dom.Document doc) {
    final selectors = [
      '#article',
      '#content',
      '.entry',
      '.WRD',
      '#centerCol',
    ];

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
                      builder: (_) => DefinitionPage(word: word),
                    ),
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

  String get _badgeLabel {
    return 'Link to the site';
  }

  String get _badgeUrl {
    final langCode =
        LanguageService.instance.currentLang == 'fr' ? 'fren' : 'esen';

    return widget.wordUrl ??
        'https://www.wordreference.com/$langCode/${Uri.encodeComponent(widget.word)}';
  }

  /// --- Parse table rows for senses and examples ---
  void _parseTableRows(dom.Element table, HtmlUnescape unescape) {
    bool isHeaderRow(dom.Element tr) {
      final text = tr.text.toLowerCase();

      return tr.querySelectorAll('th').isNotEmpty ||
          tr.classes.contains('langHeader') ||
          text.contains('principal translations') ||
          text.contains('principales traductions') ||
          text.contains('français') ||
          text.contains('anglais') ||
          text.contains('spanish') ||
          text.contains('english');
    }

    for (final tr in table.querySelectorAll('tr')) {
      if (isHeaderRow(tr)) continue;

      final frTd = tr.querySelector('td.FrWrd');
      final toTd = tr.querySelector('td.ToWrd');
      final frExTd = tr.querySelector('td.FrEx');
      final toExTd = tr.querySelector('td.ToEx');

      if (frTd != null && toTd != null) {
        final sourceWord = _cleanElementText(frTd, unescape);
        final targetWord = _cleanElementText(toTd, unescape);

        if (sourceWord.isEmpty || targetWord.isEmpty) continue;

        final sense = _Sense(
          source: sourceWord,
          target: targetWord,
        );

        _attachExamples(sense, frExTd, toExTd, unescape);
        _senses.add(sense);
      } else if (frTd == null && toTd != null && _senses.isNotEmpty) {
        final extraTranslation = _cleanElementText(toTd, unescape);

        if (extraTranslation.isNotEmpty) {
          final chosen = _chooseExtraSegment(extraTranslation, maxLen: 20);

          if (chosen != null && chosen.isNotEmpty) {
            final lastIndex = _senses.length - 1;
            final last = _senses.last;

            _senses[lastIndex] = last.copyWith(
              target: '${last.target} / $chosen',
            );
          }
        }

        _attachExamples(_senses.last, frExTd, toExTd, unescape);
      } else if ((frExTd != null || toExTd != null) && _senses.isNotEmpty) {
        _attachExamples(_senses.last, frExTd, toExTd, unescape);
      }
    }

    for (final s in _senses) {
      s.sourceExamples.replaceRange(
        0,
        s.sourceExamples.length,
        s.sourceExamples.toSet().toList(),
      );

      s.targetExamples.replaceRange(
        0,
        s.targetExamples.length,
        s.targetExamples.toSet().toList(),
      );
    }
  }

  void _attachExamples(
    _Sense sense,
    dom.Element? frExTd,
    dom.Element? toExTd,
    HtmlUnescape unescape,
  ) {
    if (frExTd != null) {
      final fe = _cleanElementText(frExTd, unescape);

      if (fe.isNotEmpty) {
        sense.sourceExamples.add(fe);
      }
    }

    if (toExTd != null) {
      final te = _cleanElementText(toExTd, unescape);

      if (te.isNotEmpty) {
        sense.targetExamples.add(te);
      }
    }
  }

  /// --- Build UI ---
  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor:
          Theme.of(context).extension<AppSemanticColors>()?.pageBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor:
            Theme.of(context).extension<AppSemanticColors>()?.appBarText,
        title: const Text('', style: TextStyle(color: Colors.black)),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).extension<AppSemanticColors>()?.loader,
              ),
            )
          : _error != null
              ? _buildError()
              : _buildContent(surface),
      floatingActionButton: FloatingActionButton(
        heroTag: 'lookupWord',
        backgroundColor:
            Theme.of(context).floatingActionButtonTheme.backgroundColor ??
                Theme.of(context).colorScheme.primary,
        onPressed: _showLookupDialog,
        child: Icon(
          Icons.search,
          color: Theme.of(context).floatingActionButtonTheme.foregroundColor ??
              Theme.of(context).colorScheme.onPrimary,
        ),
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
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchDefinition,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context)
                        .floatingActionButtonTheme
                        .backgroundColor ??
                    Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context)
                        .floatingActionButtonTheme
                        .foregroundColor ??
                    Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Retry'),
            ),
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
            boxShadow: [
              BoxShadow(
                color: Theme.of(context)
                        .extension<AppSemanticColors>()
                        ?.cardShadow ??
                    Colors.black12,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _buildContentCard(),
        ),
      ),
    );
  }

  Widget _buildContentCard() {
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
          children: [
            _Badge(label: _badgeLabel, url: _badgeUrl),
            const SizedBox(width: 12),
          ],
        ),
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
            itemBuilder: (context, i) {
              return _SenseTile(
                index: i,
                sense: _senses[i],
              );
            },
          ),
      ],
    );
  }

  /// --- Audio Bar Widget ---
  Widget _buildAudioBar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color:
            Theme.of(context).extension<AppSemanticColors>()?.controlBorder ??
                Colors.black12,
      ),
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
                isExpanded: true,
                hint: Text(
                  '${_audio[_accentIndex].label.toUpperCase()} • ${(_speed * 100).toInt()}%',
                  overflow: TextOverflow.ellipsis,
                ),
                value: null,
                items: [
                  ...List.generate(_audio.length, (i) {
                    return DropdownMenuItem<_AudioDropdownValue>(
                      value: _AudioDropdownValue.accent(i),
                      child: Text(_audio[i].label.toUpperCase()),
                    );
                  }),
                  const DropdownMenuItem(
                    enabled: false,
                    child: Divider(thickness: 1),
                  ),
                  const DropdownMenuItem(
                    value: _AudioDropdownValue.speed(1.0),
                    child: Text('100%'),
                  ),
                  const DropdownMenuItem(
                    value: _AudioDropdownValue.speed(0.75),
                    child: Text('75%'),
                  ),
                  const DropdownMenuItem(
                    value: _AudioDropdownValue.speed(0.5),
                    child: Text('50%'),
                  ),
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
          Text(
            _ipa!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
      ],
    );
  }
}

/// --- Badge Widget ---
class _Badge extends StatelessWidget {
  final String label;
  final String? url;

  const _Badge({
    required this.label,
    this.url,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).extension<AppSemanticColors>()?.badge ??
        AppSemanticColors.light().badge;

    return GestureDetector(
      onTap: url != null
          ? () async {
              final uri = Uri.parse(url!);

              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).extension<AppSemanticColors>()?.badgeBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
        ),
      ),
    );
  }
}

/// --- Sense row widget ---
class _SenseTile extends StatelessWidget {
  final int index;
  final _Sense sense;

  const _SenseTile({
    required this.index,
    required this.sense,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge;
    final state = context.findAncestorStateOfType<_DefinitionPageState>();

    return GestureDetector(
      onTap: () => state?._addWordToVocabulary(sense),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: base?.copyWith(
                color: Theme.of(context)
                    .extension<AppSemanticColors>()
                    ?.textPrimaryStrong,
              ),
              children: [
                TextSpan(
                  text: '${index + 1}. ',
                  style: base?.copyWith(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: _cleanTranslation(sense.source),
                  style: base?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ' - ',
                  style: base?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: sense.target,
                  style: base?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          ..._buildExamples(sense.sourceExamples, context),
          ..._buildExamples(sense.targetExamples, context, italic: true),
        ],
      ),
    );
  }

  List<Widget> _buildExamples(
    List<String> examples,
    BuildContext context, {
    bool italic = false,
  }) {
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
                    color: Theme.of(context)
                        .extension<AppSemanticColors>()
                        ?.textPrimaryStrong
                        .withOpacity(0.7),
                  )
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ];
  }
}
