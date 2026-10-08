import 'package:flutter/foundation.dart' show immutable;

import 'package:flowcraft/core/utils/id_generator.dart';
import 'package:flowcraft/models/sketch_element.dart';

/// Metadata for one saved whiteboard, cheap enough to list a whole library
/// of them without touching a single element.
///
/// This is deliberately separate from [FlowProjectScene]: the sidebar needs
/// names and timestamps for every project, and paying a full element-list
/// deserialization per row would make opening the drawer scale with the
/// user's total drawing history rather than their project count.
@immutable
class FlowProject {
  const FlowProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.elementCount,
    this.isBroken = false,
    this.linkedPath,
  });

  /// A brand-new, empty project stamped with the current time.
  factory FlowProject.create({required String name, DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return FlowProject(
      id: IdGenerator.generate('proj'),
      name: name,
      createdAt: timestamp,
      updatedAt: timestamp,
      elementCount: 0,
    );
  }

  /// Stand-in for a project file that exists but can't be parsed. Listing
  /// keeps returning these so a single corrupt file shows up as one broken
  /// row instead of blanking the whole sidebar.
  factory FlowProject.broken({required String id, DateTime? updatedAt}) {
    final timestamp = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return FlowProject(
      id: id,
      name: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      elementCount: 0,
      isBroken: true,
    );
  }

  /// Whether [id] may be turned into a file name.
  ///
  /// Ids do not only come from [IdGenerator] — a project file carries its
  /// own id in its JSON header, and one-file-per-project is a format people
  /// hand to each other, so any file dropped into the projects directory
  /// gets a say in a path the repository composes. The alphabet here is
  /// exactly what [IdGenerator] emits (`prefix_micros_hex`): no separator,
  /// no dot, therefore no `..` and no way out of that directory.
  static bool isValidId(String id) => _idPattern.hasMatch(id);

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_]{1,64}$');

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Number of elements in the saved scene — shown in the sidebar so the
  /// user can tell an empty draft from real work without opening it.
  final int elementCount;

  /// Whether the backing file failed to parse. Broken projects can be
  /// deleted but not opened.
  final bool isBroken;

  /// Absolute path of a file the repository mirrors every save to (and
  /// prefers over its own copy when that file is newer), or `null` when the
  /// project is not linked. Additive in the header and the index: files
  /// written before linking existed simply lack the key and load unlinked.
  final String? linkedPath;

  FlowProject copyWith({
    String? name,
    DateTime? updatedAt,
    int? elementCount,
    bool? isBroken,
    String? linkedPath,
    bool clearLinkedPath = false,
  }) {
    return FlowProject(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      elementCount: elementCount ?? this.elementCount,
      isBroken: isBroken ?? this.isBroken,
      linkedPath: clearLinkedPath ? null : (linkedPath ?? this.linkedPath),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'elementCount': elementCount,
      if (linkedPath != null) 'linkedPath': linkedPath,
    };
  }

  factory FlowProject.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    // Rejected here rather than at each call site: this is the one door
    // every id takes into the app from a file, and the callers that turn it
    // into a path are several layers away from the parse.
    if (!isValidId(id)) {
      throw FormatException('Not a usable project id: "$id"');
    }
    final created = _parseTime(json['createdAt']);
    return FlowProject(
      id: id,
      name: json['name'] as String? ?? 'Untitled',
      createdAt: created,
      updatedAt: json['updatedAt'] == null
          ? created
          : _parseTime(json['updatedAt']),
      elementCount: (json['elementCount'] as num?)?.toInt() ?? 0,
      linkedPath: json['linkedPath'] as String?,
    );
  }

  static DateTime _parseTime(Object? raw) {
    final parsed = DateTime.tryParse(raw as String? ?? '');
    return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowProject &&
        other.id == id &&
        other.name == name &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.elementCount == elementCount &&
        other.isBroken == isBroken &&
        other.linkedPath == linkedPath;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdAt,
    updatedAt,
    elementCount,
    isBroken,
    linkedPath,
  );

  @override
  String toString() => 'FlowProject($id, "$name", $elementCount elements)';
}

/// A project's metadata together with its fully-loaded scene — what the
/// repository hands back on `load` and takes on `save`.
@immutable
class FlowProjectScene {
  const FlowProjectScene({
    required this.project,
    required this.elements,
    this.droppedCount = 0,
  });

  final FlowProject project;
  final List<SketchElement> elements;

  /// How many elements the file held that this build could not decode.
  ///
  /// Non-zero means [elements] is *less* than what is on disk, so whoever
  /// loaded it owes the user a warning before anything writes back over
  /// that file — see `SketchController.sceneIsPartial`. Always `0` on a
  /// scene built in memory for a save.
  final int droppedCount;
}
