// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/helpers/locale_provider.dart';
import '../../core/helpers/time_helpers.dart';
import '../../core/models/station.dart';
import '../../core/repositories/providers.dart';
import '../../l10n/app_localizations.dart';

final _stationSearchProvider = FutureProvider.family<List<Station>, String>((
  ref,
  query,
) {
  if (query.isEmpty) {
    return ref.read(stationRepositoryProvider).getMajorStations();
  }
  return ref.read(stationRepositoryProvider).searchByName(query);
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _fromFocusNode = FocusNode();
  final _toFocusNode = FocusNode();
  final _fromFieldKey = GlobalKey();
  final _toFieldKey = GlobalKey();
  String? _fromId;
  String? _toId;
  TimeOfDay _time = TimeOfDay.now();
  bool _searchingFrom = true;
  OverlayEntry? _suggestionsOverlay;

  @override
  void initState() {
    super.initState();
    _fromFocusNode.addListener(_onFromFocusChange);
    _toFocusNode.addListener(_onToFocusChange);
  }

  void _onFromFocusChange() {
    if (_fromFocusNode.hasFocus) {
      setState(() => _searchingFrom = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSuggestions());
    } else {
      _hideSuggestions();
    }
  }

  void _onToFocusChange() {
    if (_toFocusNode.hasFocus) {
      setState(() => _searchingFrom = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSuggestions());
    } else {
      _hideSuggestions();
    }
  }

  void _showSuggestions() {
    _hideSuggestions();
    final overlay = Overlay.of(context);

    final key = _searchingFrom ? _fromFieldKey : _toFieldKey;
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final fieldPosition = renderBox.localToGlobal(Offset.zero);
    final fieldSize = renderBox.size;

    _suggestionsOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideSuggestions,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: fieldPosition.dy + fieldSize.height + 4,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: _buildSuggestionsList(),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_suggestionsOverlay!);
  }

  void _hideSuggestions() {
    _suggestionsOverlay?.remove();
    _suggestionsOverlay = null;
  }

  Widget _buildSuggestionsList() {
    final locale = ref.watch(localeProvider);
    final query = _searchingFrom ? _fromController.text : _toController.text;
    final stations = ref.watch(_stationSearchProvider(query));

    return stations.when(
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          SizedBox(height: 100, child: Center(child: Text(e.toString()))),
      data: (list) => ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: list.length,
        itemBuilder: (context, i) {
          final station = list[i];
          final name = station.localizedName(locale.languageCode);
          return ListTile(
            leading: const Icon(Icons.train),
            title: Text(name),
            onTap: () {
              if (_searchingFrom) {
                setState(() {
                  _fromId = station.id;
                  _fromController.text = name;
                });
                _fromFocusNode.unfocus();
              } else {
                setState(() {
                  _toId = station.id;
                  _toController.text = name;
                });
                _toFocusNode.unfocus();
              }
              _hideSuggestions();
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _fromFocusNode.removeListener(_onFromFocusChange);
    _toFocusNode.removeListener(_onToFocusChange);
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    _hideSuggestions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.search)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  key: _fromFieldKey,
                  controller: _fromController,
                  focusNode: _fromFocusNode,
                  decoration: InputDecoration(
                    labelText: loc.from_station,
                    prefixIcon: const Icon(Icons.circle_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: _toFieldKey,
                  controller: _toController,
                  focusNode: _toFocusNode,
                  decoration: InputDecoration(
                    labelText: loc.to_station,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(
                    '${loc.departure}: ${minutesToHHMM(_time.hour * 60 + _time.minute)}',
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (picked != null) setState(() => _time = picked);
                  },
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.search),
                    label: Text(loc.search),
                    onPressed: _fromId != null && _toId != null
                        ? () {
                            FocusScope.of(context).unfocus();
                            context.goNamed(
                              'results',
                              extra: {
                                'fromStationId': _fromId!,
                                'toStationId': _toId!,
                                'afterMinutes': _time.hour * 60 + _time.minute,
                              },
                            );
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 13,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        loc.schedule_reference_note,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
