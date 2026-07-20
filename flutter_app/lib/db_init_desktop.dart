/// Desktop DB init — made no-op because sqflite_common_ffi has a broken
/// Windows pub cache path on this machine. Re-enable when cache is repaired.
/// To repair: run `flutter pub cache repair` then restore the FFI init code.
void initializeDatabase() {}
