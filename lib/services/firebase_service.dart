import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libri_audio/models/book_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }
  
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }
  
  Future<void> registerUser(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }
  
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Book sync
  Future<void> syncBook(Book book) async {
    if (!isLoggedIn) return;
    
    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('books')
        .doc(book.id)
        .set(book.toMap());
  }
  
  Future<void> syncReadingState(String bookId, int chapterIndex, int position) async {
    if (!isLoggedIn) return;
    
    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('books')
        .doc(bookId)
        .update({
      'lastChapter': chapterIndex,
      'lastPosition': position,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
  
  Stream<List<Book>> getBooksStream() {
    if (!isLoggedIn) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('books')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Book.fromMap(doc.data()))
            .toList());
  }
  
  // Notes sync
  Future<void> saveNote(String bookId, String noteText, int position) async {
    if (!isLoggedIn) return;
    
    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('books')
        .doc(bookId)
        .collection('notes')
        .add({
      'text': noteText,
      'position': position,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  Stream<List<Map<String, dynamic>>> getNotesStream(String bookId) {
    if (!isLoggedIn) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('books')
        .doc(bookId)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList());
  }
  
  Future<void> deleteNote(String bookId, String noteId) async {
    if (!isLoggedIn) return;
    
    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('books')
        .doc(bookId)
        .collection('notes')
        .doc(noteId)
        .delete();
  }
}
