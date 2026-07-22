import 'dart:io';

class SecureFileLifecycle {
  const SecureFileLifecycle();

  Future<void> bestEffortDelete(File file) async {
    if (!await file.exists()) return;

    RandomAccessFile? handle;
    try {
      final length = await file.length();
      handle = await file.open(mode: FileMode.write);
      const blockSize = 64 * 1024;
      final zeroes = List<int>.filled(blockSize, 0, growable: false);
      var remaining = length;
      while (remaining > 0) {
        final count = remaining < blockSize ? remaining : blockSize;
        await handle.writeFrom(zeroes, 0, count);
        remaining -= count;
      }
      await handle.flush();
    } on FileSystemException {
      // Flash wear leveling and copy-on-write filesystems make guaranteed
      // erasure impossible. Unlink still runs below.
    } finally {
      await handle?.close();
      try {
        await file.delete();
      } on FileSystemException {
        // Callers persist cleanup state and can retry on the next launch.
      }
    }
  }
}
