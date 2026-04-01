import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DefinitionPage extends StatefulWidget {
  final String word;
  final bool showAudio;
  const DefinitionPage({Key? key, required this.word, this.showAudio = true}) : super(key: key);

  @override
  State<DefinitionPage> createState() => _DefinitionPageState();
}
class _AudioDropdownValue {
  final int? accentIndex;
  final double? speed;

  const _AudioDropdownValue.accent(this.accentIndex) : speed = null;
  const _AudioDropdownValue.speed(this.speed) : accentIndex = null;

  bool get isAccent => accentIndex != null;
  bool get isSpeed => speed != null;
}
// Simple model for a word sense with examples
class _Sense {
  final String french;
  final String translation;
  final List<String> frExamples = [];
  final List<String> enExamples = [];

  _Sense({required this.french, required this.translation});
}

// Audio option (accent + url)
class _AudioOption {
  final String label;
  final String url;
  _AudioOption(this.label, this.url);
}

class _DefinitionPageState extends State<DefinitionPage> {
  bool _loading = true;
  String? _error;
  final List<_Sense> _senses = [];

  // Audio state
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
    await prefs.setString('wr_audio-fr', '$_accentIndex:${_speed.toStringAsFixed(2)}');
  }

  Future<void> _preparePlayer() async {
    if (_audio.isEmpty) return;
    final idx = _accentIndex.clamp(0, _audio.length - 1);
    _accentIndex = idx;
    await _player.setUrl(_audio[idx].url);
    await _player.setSpeed(_speed);
  }

  // Extracts window.audioFiles = ['...mp3','...mp3'];
  List<_AudioOption> _extractAudioFiles(String html) {
    final re = RegExp(r'window\.audioFiles\s*=\s*\[(.*?)\];', dotAll: true);
    final m = re.firstMatch(html);
    if (m == null) return [];
    final inner = m.group(1)!;
    final urlRe = RegExp(r"'([^']+\.mp3)'");
    final relative = urlRe.allMatches(inner).map((mm) => mm.group(1)!).toList();

    return relative.map((path) {
      final label = path.contains('/Canadian/') ? 'Canada' : 'France';
      final absolute = 'https://www.wordreference.com$path';
      return _AudioOption(label, absolute);
    }).toList();
  }

  Future<void> _fetchDefinition() async {
    setState(() {
      _loading = true;
      _error = null;
      _senses.clear();
      _audio = [];
      _ipa = null;
    });

    final wordEsc = Uri.encodeComponent(widget.word.trim());
    final url = Uri.parse('https://www.wordreference.com/fren/$wordEsc');

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final body = resp.body;
        final document = html_parser.parse(body);

        // Remove script/style elements to avoid noise
        document.querySelectorAll('script, style, noscript').forEach((e) => e.remove());

        // IPA (if present)
        _ipa = document.querySelector('#pronWR')?.text.trim();

        // Audio sources (France / Canada, etc.) - only if audio is enabled
        if (widget.showAudio) {
          _audio = _extractAudioFiles(body);
          try {
            await _preparePlayer();
          } catch (_) {
            // ignore player prepare errors
          }
        }

        // Prefer the div that contains WordReference translations/examples
        dom.Element? content = document.querySelector('#articleWRD');

        // Fallback selectors if #articleWRD isn't present
        if (content == null) {
          final selectors = ['#article', '#content', '.entry', '.WRD', '#centerCol'];
          for (final sel in selectors) {
            final el = document.querySelector(sel);
            if (el != null) {
              content = el;
              break;
            }
          }
        }

        final unescape = HtmlUnescape();

        if (content != null) {
          // Focus on tables with class WRD (translation tables)
          final tables = content.querySelectorAll('table');
          for (final table in tables) {
            final classAttr = (table.attributes['class'] ?? '').toLowerCase();
            if (!classAttr.contains('wrd')) continue; // skip non-translation tables

            for (final tr in table.querySelectorAll('tr')) {
              // skip header rows
              if (tr.querySelectorAll('th').isNotEmpty) continue;

              final frTd = tr.querySelector('td.FrWrd');
              final toTd = tr.querySelector('td.ToWrd');
              final frExTd = tr.querySelector("td.FrEx");
              final toExTd = tr.querySelector("td.ToEx");

              // If a translation row
              if (frTd != null || toTd != null) {
                final french = frTd?.text.replaceAll(RegExp(r"\s+"), ' ').trim() ?? '';
                final translation = toTd?.text.replaceAll(RegExp(r"\s+"), ' ').trim() ?? '';
                final low = (french + ' ' + translation).toLowerCase();
                // Skip rows that are not real definitions
                if (low.contains('principales traductions') || low.contains('français-anglais') || french.isEmpty) {
                  continue;
                }

                final sense = _Sense(
                  french: unescape.convert(french),
                  translation: unescape.convert(translation),
                );
                _senses.add(sense);

                // If this same row also includes examples, attach them
                if ((frExTd != null || toExTd != null) && _senses.isNotEmpty) {
                  final last = _senses.last;
                  if (frExTd != null) {
                    final fe = frExTd.text.replaceAll(RegExp(r'\s+'), ' ').trim();
                    if (fe.isNotEmpty) last.frExamples.add(unescape.convert(fe));
                  }
                  if (toExTd != null) {
                    final te = toExTd.text.replaceAll(RegExp(r'\s+'), ' ').trim();
                    if (te.isNotEmpty) last.enExamples.add(unescape.convert(te));
                  }
                }
              } else if (frExTd != null || toExTd != null) {
                // Attach examples to the last parsed sense if present
                if (_senses.isNotEmpty) {
                  final lastSense = _senses.last;
                  if (frExTd != null) {
                    final fe = frExTd.text.replaceAll(RegExp(r"\s+"), ' ').trim();
                    if (fe.isNotEmpty) lastSense.frExamples.add(unescape.convert(fe));
                  }
                  if (toExTd != null) {
                    final te = toExTd.text.replaceAll(RegExp(r"\s+"), ' ').trim();
                    if (te.isNotEmpty) lastSense.enExamples.add(unescape.convert(te));
                  }
                }
              }
            }
          }

          // Deduplicate examples within each sense
          for (final s in _senses) {
            s.frExamples.replaceRange(0, s.frExamples.length, s.frExamples.toSet().toList());
            s.enExamples.replaceRange(0, s.enExamples.length, s.enExamples.toSet().toList());
          }

          if (_senses.isEmpty) {
            _error = 'No definition found for "${widget.word}" on WordReference.';
          }
        }
      } else if (resp.statusCode == 404) {
        _error = 'Word not found on WordReference.';
      } else {
        _error = 'Server error (${resp.statusCode}). Please try again.';
      }
    } on Exception catch (e) {
      _error = 'Failed to fetch definition. ${e.toString()}';
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: const Text('', style: TextStyle(color: Colors.black)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x11000000),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _buildContentCard(),
                    ),
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Unknown error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchDefinition, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  // The stylized card content with audio bar
  Widget _buildContentCard() {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 28,
          height: 1.1,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Big word title
        Text(widget.word, style: titleStyle),
        const SizedBox(height: 10),
        // "French to English" badge
        const _Badge(label: 'French to English'),
        const SizedBox(height: 12),

        // Audio bar (if audio available and enabled)
        if (widget.showAudio && _audio.isNotEmpty) ...[
          _buildAudioBar(),
          const SizedBox(height: 12),
        ],

        if (_senses.isNotEmpty)
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _senses.length,
            separatorBuilder: (_, __) => const Divider(height: 24, thickness: 0.6),
            itemBuilder: (context, i) => _SenseTile(index: i, sense: _senses[i]),
          ),
      ],
    );
  }

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
        // Play
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
          label: const Text('ÉCOUTER:'),
        ),

        // Accent dropdown
        SizedBox(
          width: 180,
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              border: border,
              enabledBorder: border,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_AudioDropdownValue>(
                hint: Text( '${_audio[_accentIndex].label.toUpperCase()} • ${(_speed * 100).toInt()}%', ),
                value: null, // important: allows mixed selection
                items: [
                  // 🎧 Accent items
                  ...List.generate(
                    _audio.length,
                    (i) => DropdownMenuItem<_AudioDropdownValue>(
                      value: _AudioDropdownValue.accent(i),
                      child: Text(_audio[i].label.toUpperCase()),
                    ),
                  ),

                  // 🔽 Divider
                  const DropdownMenuItem<_AudioDropdownValue>(
                    enabled: false,
                    child: Divider(thickness: 1),
                  ),

                  // ⚡ Speed items
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

        // IPA, if present
        if (_ipa != null && _ipa!.isNotEmpty)
          Text(
            _ipa!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
      ],
    );
  }
}

// Small pill badge
class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF5C7CF2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
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
    );
  }
}

// One sense row (number + lemma + arrow + translation + examples)
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
      letterSpacing: 0.2,
    );

    final arrowStyle = base?.copyWith(
      color: Colors.grey.shade700,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header line: "1. savon nm → soap n"
        RichText(
          text: TextSpan(
            style: base?.copyWith(color: Colors.black87),
            children: [
              TextSpan(
                text: '${index + 1}. ',
                style: base?.copyWith(fontWeight: FontWeight.w600),
              ),
              ..._formatTermSpans(sense.french, isLemma: true, base: base, pos: posStyle),
              TextSpan(text: '  →  ', style: arrowStyle),
              ..._formatTermSpans(sense.translation, isLemma: false, base: base, pos: posStyle),
            ],
          ),
        ),
        // French examples (regular)
        if (sense.frExamples.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...sense.frExamples.take(1).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(left: 24.0, bottom: 2),
                  child: Text(e, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
        ],
        // English examples (italic, lighter)
        if (sense.enExamples.isNotEmpty) ...[
          const SizedBox(height: 2),
          ...sense.enExamples.take(1).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(left: 24.0, bottom: 2),
                  child: Text(
                    e,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.black.withOpacity(0.7),
                        ),
                  ),
                ),
              ),
        ],
      ],
    );
  }

  // Splits a term like "savon nm" or "haul [sb] over the coals v expr"
  // into styled spans: lemma (bold), POS (small), rest (regular).
  static List<InlineSpan> _formatTermSpans(
    String raw, {
    required bool isLemma,
    TextStyle? base,
    TextStyle? pos,
  }) {
    final spans = <InlineSpan>[];

    final posPattern = RegExp(
      r'\b(loc v|loc adv|loc adj|vi|vt|nm|nf|n|adj|adv|expr|prep|pron|conj|interj)\b',
      caseSensitive: false,
    );

    final match = posPattern.firstMatch(raw);
    if (match == null) {
      spans.add(TextSpan(
        text: raw,
        style: base?.copyWith(fontWeight: isLemma ? FontWeight.w700 : FontWeight.w600),
      ));
      return spans;
    }

    final before = raw.substring(0, match.start).trimRight();
    final posToken = match.group(0)!;
    final after = raw.substring(match.end).trimLeft();

    if (before.isNotEmpty) {
      spans.add(TextSpan(
        text: before,
        style: base?.copyWith(fontWeight: isLemma ? FontWeight.w700 : FontWeight.w600),
      ));
    }
    spans.add(TextSpan(text: ' ${posToken.toLowerCase()}', style: pos));
    if (after.isNotEmpty) {
      spans.add(TextSpan(text: ' $after', style: base));
    }
    return spans;
  }
}