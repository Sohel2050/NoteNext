import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/note_model.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';

enum _NotesTab { notes, archive, trash }

final _notesViewModeProvider = StateProvider<bool>((ref) => true); // true = grid

class NotesHomeScreen extends ConsumerStatefulWidget {
  const NotesHomeScreen({super.key});

  @override
  ConsumerState<NotesHomeScreen> createState() => _NotesHomeScreenState();
}

class _NotesHomeScreenState extends ConsumerState<NotesHomeScreen> {
  _NotesTab _tab = _NotesTab.notes;
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEditor([NoteModel? note]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(existingNote: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGrid = ref.watch(_notesViewModeProvider);
    final controller = ref.read(notesControllerProvider);

    List<NoteModel> notes;
    switch (_tab) {
      case _NotesTab.notes:
        notes = ref.watch(filteredNotesProvider);
        break;
      case _NotesTab.archive:
        notes = ref.watch(archivedNotesProvider);
        break;
      case _NotesTab.trash:
        final trashedAsync = ref.watch(trashedNotesStreamProvider);
        notes = trashedAsync.when(
          data: (d) => d,
          loading: () => [],
          error: (_, __) => [],
        );
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'নোট খুঁজুন...',
            border: InputBorder.none,
          ),
          onChanged: (v) =>
          ref.read(searchQueryProvider.notifier).state = v,
        )
            : Text(_titleForTab(_tab)),
        actions: [
          if (_tab == _NotesTab.notes)
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                  }
                });
              },
            ),
          IconButton(
            icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
            onPressed: () =>
            ref.read(_notesViewModeProvider.notifier).state = !isGrid,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          if (_tab == _NotesTab.notes) _buildTagFilterBar(),
          Expanded(
            child: notes.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: () async {},
              child: isGrid
                  ? MasonryLikeGrid(
                notes: notes,
                onTap: (n) =>
                _tab == _NotesTab.trash ? null : _openEditor(n),
                onLongPress: (n) =>
                    _showActionsSheet(n, controller),
              )
                  : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: notes.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final n = notes[i];
                  return NoteCard(
                    note: n,
                    onTap: () => _tab == _NotesTab.trash
                        ? null
                        : _openEditor(n),
                    onLongPress: () =>
                        _showActionsSheet(n, controller),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _tab == _NotesTab.notes
          ? FloatingActionButton.extended(
        heroTag: 'notes_home_fab',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('নতুন নোট'),
      )
          : null,
    );
  }

  Widget _buildTagFilterBar() {
    final tags = ref.watch(allNoteTagsProvider);
    if (tags.isEmpty) return const SizedBox.shrink();
    final selected = ref.watch(tagFilterProvider);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final tag in tags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tag),
                selected: selected == tag,
                onSelected: (isSelected) {
                  ref.read(tagFilterProvider.notifier).state =
                  isSelected ? tag : null;
                },
              ),
            ),
        ],
      ),
    );
  }

  String _titleForTab(_NotesTab tab) {
    switch (tab) {
      case _NotesTab.notes:
        return 'Mi Notes';
      case _NotesTab.archive:
        return 'আর্কাইভ';
      case _NotesTab.trash:
        return 'ট্র্যাশ';
    }
  }

  Widget _buildEmptyState() {
    IconData icon;
    String msg;
    switch (_tab) {
      case _NotesTab.notes:
        icon = Icons.note_alt_outlined;
        msg = 'এখনো কোনো নোট নেই\n+ বাটনে চেপে শুরু করুন';
        break;
      case _NotesTab.archive:
        icon = Icons.archive_outlined;
        msg = 'আর্কাইভে কোনো নোট নেই';
        break;
      case _NotesTab.trash:
        icon = Icons.delete_outline;
        msg = 'ট্র্যাশ খালি আছে';
        break;
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Mi Notes',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('নোট'),
              selected: _tab == _NotesTab.notes,
              onTap: () {
                setState(() => _tab = _NotesTab.notes);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('আর্কাইভ'),
              selected: _tab == _NotesTab.archive,
              onTap: () {
                setState(() => _tab = _NotesTab.archive);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('ট্র্যাশ'),
              selected: _tab == _NotesTab.trash,
              onTap: () {
                setState(() => _tab = _NotesTab.trash);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('সেটিংস'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showActionsSheet(NoteModel note, NotesController controller) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        if (_tab == _NotesTab.trash) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('রিস্টোর করুন'),
                  onTap: () {
                    controller.restoreFromTrash(note);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('স্থায়ীভাবে মুছুন',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    controller.deleteForever(note);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        }
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(note.isPinned
                    ? Icons.push_pin
                    : Icons.push_pin_outlined),
                title: Text(note.isPinned ? 'আনপিন করুন' : 'পিন করুন'),
                onTap: () {
                  controller.togglePin(note);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(note.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined),
                title: Text(note.isArchived ? 'আনআর্কাইভ' : 'আর্কাইভ করুন'),
                onTap: () {
                  controller.toggleArchive(note);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('ট্র্যাশে সরান',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  controller.moveToTrash(note);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Masonry-স্টাইল গ্রিড (নোটের উচ্চতা ভিন্ন ভিন্ন হয় বলে flutter's
/// staggered_grid_view প্যাকেজ ছাড়াই একটি সহজ ২-কলাম Wrap-ভিত্তিক সমাধান)
class MasonryLikeGrid extends StatelessWidget {
  final List<NoteModel> notes;
  final void Function(NoteModel) onTap;
  final void Function(NoteModel) onLongPress;

  const MasonryLikeGrid({
    super.key,
    required this.notes,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // দুই কলামে ভাগ করা (index % 2 অনুযায়ী)
    final left = <NoteModel>[];
    final right = <NoteModel>[];
    for (var i = 0; i < notes.length; i++) {
      (i.isEven ? left : right).add(notes[i]);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildColumn(left)),
          const SizedBox(width: 8),
          Expanded(child: _buildColumn(right)),
        ],
      ),
    );
  }

  Widget _buildColumn(List<NoteModel> items) {
    return Column(
      children: items
          .map(
            (n) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NoteCard(
            note: n,
            onTap: () => onTap(n),
            onLongPress: () => onLongPress(n),
          ),
        ),
      )
          .toList(),
    );
  }
}