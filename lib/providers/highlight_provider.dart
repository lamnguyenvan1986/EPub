import 'package:flutter/material.dart';
import 'package:libri_audio/models/highlight_model.dart';
import 'package:libri_audio/services/storage_service.dart';

class HighlightProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  
  List<Highlight> _highlights = [];
  
  List<Highlight> get highlights => _highlights;
  List<Highlight> get bookHighlights => _highlights.where((h) => h.bookId == _currentBookId).toList();
  String? _currentBookId;
  
  void setCurrentBookId(String bookId) {
    _currentBookId = bookId;
    _loadHighlights();
  }
  
  Future<void> _loadHighlights() async {
    final bookId = _currentBookId;
    _highlights = bookId == null ? [] : _storage.getHighlights(bookId);
    notifyListeners();
  }
  
  void addHighlight(Highlight highlight) {
    _storage.saveHighlight(highlight);
    _highlights.add(highlight);
    notifyListeners();
  }
  
  void deleteHighlight(String highlightId) {
    _storage.deleteHighlight(highlightId);
    _highlights.removeWhere((h) => h.id == highlightId);
    notifyListeners();
  }
  
  void updateNote(String highlightId, String note) {
    final index = _highlights.indexWhere((h) => h.id == highlightId);
    if (index != -1) {
      _highlights[index] = _highlights[index].copyWith(note: note);
      _storage.updateHighlight(_highlights[index]);
      notifyListeners();
    }
  }
}
