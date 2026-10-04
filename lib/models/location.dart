import 'package:hive_ce/hive_ce.dart';

class Location {
  Location({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.createdAt,
    this.lastLeftAt,
    this.latitude,
    this.longitude,
    this.radiusMeters = 100.0,
    this.reminderMinutes,
    this.colorValue = 0xFFFFFFFF,
    this.isPinned = false,
    this.isArchived = false,
    this.colorKey,
  });

  String id;
  String name;
  String iconKey;
  DateTime createdAt;
  DateTime? lastLeftAt;
  double? latitude;
  double? longitude;
  double radiusMeters;
  int? reminderMinutes; // minutes from midnight, e.g. 14:00 = 840
  int colorValue; // ARGB color integer for Keep-style card
  bool isPinned;
  bool isArchived;
  String? colorKey;

  bool get hasGps => latitude != null && longitude != null;
  bool get hasReminder => reminderMinutes != null;
}

class LocationAdapter extends TypeAdapter<Location> {
  @override
  final int typeId = 10;

  @override
  Location read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final iconKey = reader.readString();
    final createdAtMillis = reader.readInt();
    final lastLeftMillis = reader.readInt();

    double? latitude;
    double? longitude;
    double radiusMeters = 100.0;
    int? reminderMinutes;
    int colorValue = 0xFFFFFFFF;

    if (reader.availableBytes > 0) {
      final hasLat = reader.readBool();
      if (hasLat) {
        latitude = reader.readDouble();
      }
      final hasLng = reader.readBool();
      if (hasLng) {
        longitude = reader.readDouble();
      }
      radiusMeters = reader.readDouble();
      final rem = reader.readInt();
      reminderMinutes = rem >= 0 ? rem : null;
      colorValue = reader.readInt();
    }

    var isPinned = false;
    var isArchived = false;
    String? colorKey;
    if (reader.availableBytes > 0) {
      isPinned = reader.readBool();
    }
    if (reader.availableBytes > 0) {
      isArchived = reader.readBool();
    }
    if (reader.availableBytes > 0) {
      final hasColorKey = reader.readBool();
      if (hasColorKey && reader.availableBytes > 0) {
        colorKey = reader.readString();
      }
    }

    return Location(
      id: id,
      name: name,
      iconKey: iconKey,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
      lastLeftAt: lastLeftMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastLeftMillis)
          : null,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      reminderMinutes: reminderMinutes,
      colorValue: colorValue,
      isPinned: isPinned,
      isArchived: isArchived,
      colorKey: colorKey,
    );
  }

  @override
  void write(BinaryWriter writer, Location obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeString(obj.iconKey)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeInt(obj.lastLeftAt?.millisecondsSinceEpoch ?? 0)
      ..writeBool(obj.latitude != null);

    if (obj.latitude != null) {
      writer.writeDouble(obj.latitude!);
    }

    writer.writeBool(obj.longitude != null);
    if (obj.longitude != null) {
      writer.writeDouble(obj.longitude!);
    }

    writer
      ..writeDouble(obj.radiusMeters)
      ..writeInt(obj.reminderMinutes ?? -1)
      ..writeInt(obj.colorValue)
      ..writeBool(obj.isPinned)
      ..writeBool(obj.isArchived)
      ..writeBool(obj.colorKey != null);

    if (obj.colorKey != null) {
      writer.writeString(obj.colorKey!);
    }
  }
}
