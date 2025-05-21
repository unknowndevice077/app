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
  bool _deleteMode = false; // Track if delete mode is active

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Notes', style: GoogleFonts.dmSerifText(fontSize: 36, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(_deleteMode ? Icons.close : Icons.edit, color: Colors.black),
            tooltip: _deleteMode ? 'Cancel' : 'Delete Notes',
            onPressed: () {
              setState(() {
                _deleteMode = !_deleteMode;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 20.0, bottom: 20.0, left: 0, right: 0),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Notes')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text('No notes yet.', style: GoogleFonts.dmSerifText(fontSize: 20, color: Colors.grey)),
                    );
                  }
                  final notes = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final doc = notes[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          title: Text(
                            data['title'] ?? '',
                            style: GoogleFonts.dmSerifText(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              (data['content'] as String?)?.isNotEmpty == true ? data['content'] : 'No content',
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.normal,
                                color: (data['content'] as String?)?.isNotEmpty == true
                                    ? Colors.black54
                                    : Colors.grey,
                                fontStyle: (data['content'] as String?)?.isNotEmpty == true
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: _deleteMode
                              ? IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('Notes')
                                        .doc(doc.id)
                                        .delete();
                                  },
                                )
                              : null,
                          onTap: _deleteMode
                              ? null
                              : () async {
                                  final updated = await Navigator.push<Map<String, String>>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddNoteScreen(
                                        initialTitle: data['title'] ?? '',
                                        initialContent: data['content'] ?? '',
                                        docId: doc.id,
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
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () async {
          final result = await Navigator.of(context).push<Map<String, String>>(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const AddNoteScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0, 1.0);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// --- Add/Edit Note Screen ---
class AddNoteScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final String? docId; // Add docId for edit mode
  const AddNoteScreen({super.key, this.initialTitle, this.initialContent, this.docId});

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
      backgroundColor: Colors.white, // <-- Set background to white
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.black),
            tooltip: 'Save',
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Top part: Title input (capitalized only)
            TextField(
              controller: _titleController,
              style: GoogleFonts.dmSerifText(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'TITLE',
                hintStyle: GoogleFonts.dmSerifText(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[400],
                  letterSpacing: 2,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                UpperCaseTextFormatter(),
              ],
            ),
            const Divider(height: 32, thickness: 1.2),
            // Bottom part: Content input (expands)
            Expanded(
              child: TextField(
                controller: _contentController,
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                  color: Colors.black87,
                  letterSpacing: 0.1,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Write your note here...',
                  hintStyle: GoogleFonts.roboto(
                    fontSize: 18,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
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



