import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class Notes extends StatefulWidget {
  const Notes({super.key});

  @override
  State<Notes> createState() => _NotesState();
}

class _NotesState extends State<Notes> {
  void _deleteNote(String docId) async {
    await FirebaseFirestore.instance.collection('Notes').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notes', style: GoogleFonts.dmSerifText(fontSize: 40)),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Notes')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No notes yet.', style: GoogleFonts.dmSerifText(fontSize: 20)),
                  );
                }
                final notes = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final doc = notes[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text(
                          data['title'] ?? '',
                          style: GoogleFonts.dmSerifText(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          (data['content'] as String?)?.isNotEmpty == true ? data['content'] : 'No content',
                          style: GoogleFonts.roboto(
                            fontWeight: FontWeight.normal,
                            color: (data['content'] as String?)?.isNotEmpty == true
                                ? Colors.black
                                : Colors.grey, // Grey for hint
                            fontStyle: (data['content'] as String?)?.isNotEmpty == true
                                ? FontStyle.normal
                                : FontStyle.italic, // Italic for hint
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          // Open the note in the AddNoteScreen for viewing/editing
                          final updated = await Navigator.push<Map<String, String>>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddNoteScreen(
                                initialTitle: data['title'] ?? '',
                                initialContent: data['content'] ?? '',
                              ),
                            ),
                          );
                          if (updated != null) {
                            FirebaseFirestore.instance
                                .collection('Notes')
                                .doc(doc.id)
                                .update({
                              'title': updated['title'],
                              'content': updated['content'],
                            });
                          }
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteNote(doc.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        onPressed: () async {
          // Use a custom PageRouteBuilder for slide animation
          final result = await Navigator.of(context).push<Map<String, String>>(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const AddNoteScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0); // Slide from right
                const end = Offset.zero;
                const curve = Curves.ease;
                final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            ),
          );
          if (result != null &&
              ((result['title']?.isNotEmpty ?? false) || (result['content']?.isNotEmpty ?? false))) {
            await FirebaseFirestore.instance.collection('Notes').add({
              'title': result['title'],
              'content': result['content'],
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// New screen for adding or editing a note
class AddNoteScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  const AddNoteScreen({super.key, this.initialTitle, this.initialContent});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    Navigator.pop(context, {
      'title': title,
      'content': content,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Note', style: GoogleFonts.dmSerifText()),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top part: Title input (capitalized only)
            TextField(
              controller: _titleController,
              style: GoogleFonts.dmSerifText(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                UpperCaseTextFormatter(),
              ],
            ),
            const Divider(),
            // Bottom part: Content input (expands)
            Expanded(
              child: TextField(
                controller: _contentController,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                  fontFamily: 'Roboto', // Use a clean, non-bold font
                  letterSpacing: 0.1,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                maxLines: null,
                expands: true,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Formatter to force uppercase in the title field
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}



