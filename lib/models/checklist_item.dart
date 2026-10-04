import 'package:hive_ce/hive_ce.dart';

class ChecklistItem {
  ChecklistItem({
    required this.id,
    required this.locationId,
    required this.name,
    this.isChecked = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String id;
  String locationId;
  String name;
  bool isChecked;
  DateTime createdAt;
}

class ChecklistItemAdapter extends TypeAdapter<ChecklistItem> {
  @override
  final int typeId = 11;

  @override
  ChecklistItem read(BinaryReader reader) {
    final id = reader.readString();
    final locationId = reader.readString();
    final name = reader.readString();
    final isChecked = reader.readBool();
    final createdAtMillis = reader.readInt();

    return ChecklistItem(
      id: id,
      locationId: locationId,
      name: name,
      isChecked: isChecked,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
    );
  }

  @override
  void write(BinaryWriter writer, ChecklistItem obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.locationId)
      ..writeString(obj.name)
      ..writeBool(obj.isChecked)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}