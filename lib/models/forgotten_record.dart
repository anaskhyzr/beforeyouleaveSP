import 'package:hive_ce/hive_ce.dart';

class ForgottenRecord {
  ForgottenRecord({
    required this.id,
    required this.itemName,
    required this.locationId,
    required this.locationName,
    this.count = 1,
    required this.lastForgottenAt,
  });

  String id;
  String itemName;
  String locationId;
  String locationName;
  int count;
  DateTime lastForgottenAt;
}

class ForgottenRecordAdapter extends TypeAdapter<ForgottenRecord> {
  @override
  final int typeId = 12;

  @override
  ForgottenRecord read(BinaryReader reader) {
    final id = reader.readString();
    final itemName = reader.readString();
    final locationId = reader.readString();
    final locationName = reader.readString();
    final count = reader.readInt();
    final lastForgottenMillis = reader.readInt();

    return ForgottenRecord(
      id: id,
      itemName: itemName,
      locationId: locationId,
      locationName: locationName,
      count: count,
      lastForgottenAt: DateTime.fromMillisecondsSinceEpoch(lastForgottenMillis),
    );
  }

  @override
  void write(BinaryWriter writer, ForgottenRecord obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.itemName)
      ..writeString(obj.locationId)
      ..writeString(obj.locationName)
      ..writeInt(obj.count)
      ..writeInt(obj.lastForgottenAt.millisecondsSinceEpoch);
  }
}
