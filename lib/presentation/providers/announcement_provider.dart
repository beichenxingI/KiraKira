import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/announcement.dart';

/// Pending announcement: written by the loading screen after fetching, read by the main screen
/// which shows it as a dialog and then clears it.
/// null means nothing to display (not fetched, already read, or already shown).
final pendingAnnouncementProvider =
    StateProvider<Announcement?>((ref) => null);