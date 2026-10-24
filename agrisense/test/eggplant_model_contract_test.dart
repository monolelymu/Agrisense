import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/model_catalog.dart';

// Read the public TFLite FlatBuffer tensor contract without a native runtime.
class _ModelBuffer {
  _ModelBuffer(Uint8List bytes) : data = ByteData.sublistView(bytes);
  final ByteData data;
  int offset(int at) => at + data.getUint32(at, Endian.little);
  int field(int table, int index) {
    final vtable = table - data.getInt32(table, Endian.little);
    final slot = vtable + 4 + index * 2;
    if (slot >= vtable + data.getUint16(vtable, Endian.little)) return 0;
    final relative = data.getUint16(slot, Endian.little);
    return relative == 0 ? 0 : table + relative;
  }

  List<int> vector(int table, int index) {
    final at = offset(field(table, index));
    return List.generate(
      data.getUint32(at, Endian.little),
      (i) => data.getInt32(at + 4 + i * 4, Endian.little),
    );
  }
}

void main() {
  test(
    'new eggplant export accepts 224 RGB float input and nine float scores',
    () {
      final model = cropModels[Crop.eggplant]!;
      final bytes = File(model.modelAsset).readAsBytesSync();
      expect(ascii.decode(bytes.sublist(4, 8)), 'TFL3');
      final buffer = _ModelBuffer(bytes);
      final root = buffer.offset(0);
      final graphs = buffer.offset(buffer.field(root, 2));
      final graph = buffer.offset(graphs + 4);
      final tensors = buffer.offset(buffer.field(graph, 0));
      for (final (field, shape) in [
        (1, [1, 224, 224, 3]),
        (2, [1, 9]),
      ]) {
        final index = buffer.vector(graph, field).single;
        final tensor = buffer.offset(tensors + 4 + index * 4);
        expect(buffer.vector(tensor, 0), shape);
        final type = buffer.field(tensor, 1);
        expect(type == 0 ? 0 : buffer.data.getUint8(type), 0); // FLOAT32
      }
      final labels =
          jsonDecode(File(model.labelsAsset).readAsStringSync()) as List;
      expect(labels.length, model.classCount);
      expect(model.version, 'eggplant-b0-f715c3c81603');
    },
  );
}
