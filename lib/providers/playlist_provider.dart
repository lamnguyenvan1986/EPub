import 'package:flutter/material.dart';
import 'package:libri_audio/models/playlist_model.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:libri_audio/services/storage_service.dart';

class PlaylistProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  
  final List<Playlist> _playlists = [];
  
  List<Playlist> get playlists => _playlists;
  
  PlaylistProvider() {
    _loadPlaylists();
  }
  
  Future<void> _loadPlaylists() async {
    // TODO: Load playlists from storage
    notifyListeners();
  }
  
  List<Book> _books = [];

  List<Book> get books => _books;

  void setBooks(List<Book> books) {
    _books = List<Book>.from(books);
    notifyListeners();
  }
  
  void addPlaylist(String name) {
    final playlist = Playlist(
      name: name,
      bookIds: [],
    );
    _storage.savePlaylist(playlist);
    _playlists.add(playlist);
    notifyListeners();
  }
  
  void removePlaylist(String playlistId) {
    _storage.deletePlaylist(playlistId);
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
  }
  
  void addBookToPlaylist(String playlistId, String bookId) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1 && !_playlists[index].bookIds.contains(bookId)) {
      _playlists[index] = _playlists[index].copyWith(
        bookIds: [..._playlists[index].bookIds, bookId],
      );
      _storage.updatePlaylist(_playlists[index]);
      notifyListeners();
    }
  }
  
  void removeBookFromPlaylist(String playlistId, String bookId) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index] = _playlists[index].copyWith(
        bookIds: _playlists[index].bookIds.where((id) => id != bookId).toList(),
      );
      _storage.updatePlaylist(_playlists[index]);
      notifyListeners();
    }
  }
  
  Future<void> playPlaylist(String playlistId) async {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    // Play first book in playlist
    if (playlist.bookIds.isNotEmpty) {
      // TODO: Implement playlist playback
    }
  }
}
