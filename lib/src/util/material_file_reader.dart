import 'material_file_reader_stub.dart'
    if (dart.library.io) 'material_file_reader_io.dart' as impl;

Future<List<int>?> readBytesFromPath(String? path) =>
    impl.readBytesFromPath(path);
