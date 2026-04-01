import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class DefinitionPage extends StatefulWidget {
  final String word;

  const DefinitionPage({Key? key, required this.word}) : super(key: key);

  @override
  State<DefinitionPage> createState() => _DefinitionPageState();
}

// Simple model for a word sense with examples
class _Sense {
  final String french;
  final String translation;
  final List<String> frExamples = [];
  final List<String> enExamples = [];

  _Sense({required this.french, required this.translation});
}

class _DefinitionPageState extends State<DefinitionPage> {
  bool _loading = true;
  String? _error;
  final List<_Sense> _senses = [];

  @override
  void initState() {
    super.initState();
    _fetchDefinition();
  }

  Future<void> _fetchDefinition() async {
    setState(() {
      _loading = true;
      _error = null;
      _senses.clear();
    });

  final wordEsc = Uri.encodeComponent(widget.word.trim());
    final url = Uri.parse('https://www.wordreference.com/fren/$wordEsc');

    try {
      final resp = await http.get(url).timeout(Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = resp.body;
        final document = html_parser.parse(body);

        // Remove script/style elements to avoid noise
        document.querySelectorAll('script, style, noscript').forEach((e) => e.remove());

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

                final sense = _Sense(french: unescape.convert(french), translation: unescape.convert(translation));
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.word)),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
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
            SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchDefinition, child: Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.word, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          if (_senses.isNotEmpty) ...[
            Text('Definitions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            for (int i = 0; i < _senses.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ${_senses[i].french} — ${_senses[i].translation}', style: Theme.of(context).textTheme.bodyLarge),
                    if (_senses[i].frExamples.isNotEmpty) ...[
                      SizedBox(height: 6),
                      for (final fe in _senses[i].frExamples)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                          child: Text(fe, style: Theme.of(context).textTheme.bodyMedium),
                        ),
                    ],
                    if (_senses[i].enExamples.isNotEmpty) ...[
                      SizedBox(height: 4),
                      for (final ee in _senses[i].enExamples)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                          child: Text(ee, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // (HTML cleaning is handled inline using HtmlUnescape and the parser.)
}
