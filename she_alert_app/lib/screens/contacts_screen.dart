import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
 
// TODO: replace with real auth uid once login is built
const String currentUserId = 'testuser1';
 
const List<Color> contactColors = [
  Color(0xFFFFB300),
  Color(0xFFFF5C7C),
  Color(0xFF42A5F5),
  Color(0xFFAB47BC),
  Color(0xFF26D9A6),
];
 
// ─────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────
class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final Color color;
  final int priority;
 
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.color,
    required this.priority,
  });
 
  String get initials {
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z ]'), '').trim();
    if (cleaned.isEmpty) return '?';
    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join()
        .toUpperCase();
  }
 
  /// Safe factory — returns null if the document is malformed
  static EmergencyContact? tryFromDoc(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      return EmergencyContact(
        id: doc.id,
        name: (data['name'] as String?)?.trim() ?? '',
        phone: (data['phoneNumber'] as String?)?.trim() ?? '',
        color: Color((data['colorValue'] as int?) ?? 0xFFFFB300),
        priority: (data['priority'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
 
// ─────────────────────────────────────────────
// Repository — all Firestore logic in one place
// ─────────────────────────────────────────────
class ContactsRepository {
  ContactsRepository(String userId)
      : _ref = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('contacts');
 
  final CollectionReference _ref;
 
  /// Real-time stream, ordered by priority
  Stream<List<EmergencyContact>> watchContacts() {
    return _ref.orderBy('priority').snapshots().map((snap) {
      return snap.docs
          .map(EmergencyContact.tryFromDoc)
          .whereType<EmergencyContact>() // drops nulls from malformed docs
          .toList();
    });
  }
 
  Future<void> add(String name, String phone, int priority) async {
    final color = contactColors[(priority - 1) % contactColors.length];
    await _ref.add({
      'name': name,
      'phoneNumber': phone,
      'priority': priority,
      'colorValue': color.value,
      'createdAt': FieldValue.serverTimestamp(), // useful for debugging
    });
  }
 
  Future<void> delete(String id) async {
    await _ref.doc(id).delete();
  }
 
  /// Batch-update all priorities in one round-trip
  Future<void> reorder(List<EmergencyContact> reordered) async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < reordered.length; i++) {
      batch.update(_ref.doc(reordered[i].id), {'priority': i + 1});
    }
    await batch.commit();
  }
}
 
// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
 
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}
 
class _ContactsScreenState extends State<ContactsScreen> {
  // Single repository instance — change userId here when auth is ready
  final _repo = ContactsRepository(currentUserId);
 
  // ── Helpers ──────────────────────────────────
 
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }
 
  // ── Add contact dialog ────────────────────────
 
  Future<void> _showAddDialog(int currentCount) async {
    if (currentCount >= 5) return;
 
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
 
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Add contact',
            style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name field
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 8),
              // Phone field
              TextFormField(
                controller: phoneCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone is required';
                  if (v.trim().length < 7) return 'Enter a valid phone number';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
 
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
 
              Navigator.pop(ctx); // close immediately for snappy UX
 
              try {
                await _repo.add(name, phone, currentCount + 1);
                _showSnackbar('${name} added ✓');
              } catch (e) {
                _showSnackbar('Could not save contact. Check your connection.',
                    isError: true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
 
  // ── Delete confirmation dialog ────────────────
 
  Future<void> _confirmDelete(EmergencyContact c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Remove contact?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove ${c.name} from your emergency contacts?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
 
    if (confirmed != true) return;
 
    try {
      await _repo.delete(c.id);
      _showSnackbar('${c.name} removed');
    } catch (e) {
      _showSnackbar('Could not remove contact. Try again.', isError: true);
    }
  }
 
  // ── Reorder handler ───────────────────────────
 
  Future<void> _onReorder(
      List<EmergencyContact> current, int oldIndex, int newIndex) async {
    // Flutter's ReorderableListView passes newIndex AFTER removal,
    // so we must adjust when moving downward
    if (newIndex > oldIndex) newIndex -= 1;
 
    final reordered = List<EmergencyContact>.from(current);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
 
    try {
      await _repo.reorder(reordered);
    } catch (e) {
      _showSnackbar('Could not save new order. Try again.', isError: true);
    }
  }
 
  // ── Build ─────────────────────────────────────
 
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Contacts',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Alerted in order, top to bottom · drag to reorder · swipe to remove',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
 
            // Contact list — driven by Firestore stream
            Expanded(
              child: StreamBuilder<List<EmergencyContact>>(
                stream: _repo.watchContacts(),
                builder: (context, snapshot) {
                  // ── Loading ──
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.teal),
                    );
                  }
 
                  // ── Error ──
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off,
                              color: AppColors.textSecondary, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load contacts.\nCheck your internet connection.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }
 
                  final contacts = snapshot.data ?? [];
 
                  // ── Empty state ──
                  if (contacts.isEmpty) {
                    return const Center(
                      child: Text(
                        'No contacts yet — add your first below',
                        style:
                            TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
 
                  // ── List ──
                  return ReorderableListView.builder(
                    itemCount: contacts.length,
                    onReorder: (o, n) => _onReorder(contacts, o, n),
                    itemBuilder: (context, index) {
                      final c = contacts[index];
                      return _ContactTile(
                        key: ValueKey(c.id),
                        contact: c,
                        index: index,
                        onDelete: () => _confirmDelete(c),
                      );
                    },
                  );
                },
              ),
            ),
 
            // Add button — hidden when at 5 contacts
            StreamBuilder<List<EmergencyContact>>(
              stream: _repo.watchContacts(),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                if (count >= 5) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => _showAddDialog(count),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '+ Add contact (${count}/5)',
                        style: const TextStyle(
                            color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
 
// ─────────────────────────────────────────────
// Contact tile — extracted widget for clarity
// ─────────────────────────────────────────────
class _ContactTile extends StatelessWidget {
  const _ContactTile({
    super.key,
    required this.contact,
    required this.index,
    required this.onDelete,
  });
 
  final EmergencyContact contact;
  final int index;
  final VoidCallback onDelete;
 
  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(contact.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete(); // opens confirm dialog; actual deletion is async inside
        return false; // never remove from list directly — let Firestore stream do it
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.redAccent),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.card(),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator,
                color: AppColors.textSecondary),
            const SizedBox(width: 8),
            // Avatar with initials
            CircleAvatar(
              backgroundColor: contact.color,
              child: Text(
                contact.initials,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            // Name + phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    contact.phone,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
            // Priority badge
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.teal,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}