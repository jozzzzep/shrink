import 'dart:typed_data';
import 'dart:convert';

/// A strongly-typed result containing the decoded length and payload.
class BitListPayload {
  final int length;
  final Uint8List data;

  const BitListPayload(this.length, this.data);
}

/// Utility class for encoding/decoding operations.
class ShrinkEncoder {
  /// Adds a 4-byte Uint32 (big endian) prefix to the byte array.
  static Uint8List addLengthPrefix(Uint8List data, int length) {
    final lengthBytes = ByteData(4)..setUint32(0, length, Endian.big);
    final result = Uint8List(4 + data.length);
    result.setRange(0, 4, lengthBytes.buffer.asUint8List());
    result.setRange(4, result.length, data);
    return result;
  }

  /// Extracts the Uint32 length prefix and payload from a prefixed byte array.
  static BitListPayload splitLengthPrefix(Uint8List prefixed) {
    if (prefixed.length < 4) {
      throw ArgumentError('Input is too short to contain a length prefix.');
    }
    final length = ByteData.sublistView(prefixed, 0, 4).getUint32(0, Endian.big);
    final data = Uint8List.sublistView(prefixed, 4);
    return BitListPayload(length, data);
  }

  /// Encodes a byte array to a Base64 string (Firestore-safe).
  static String encodeToBase64(Uint8List input) {
    return base64Encode(input);
  }

  /// Decodes a Base64 string into a byte array.
  static Uint8List decodeFromBase64(String encoded) {
    return base64Decode(encoded);
  }

  /// Encodes a list of integers into a bitmask representation.
  /// Returns a Uint8List with a 4-byte prefix indicating the length of the bitmask.
  static Uint8List encodeBitmask(List<int> ids) {
    // Find the maximum ID to determine bitmask size
    int maxId = 0;
    for (final id in ids) {
      if (id > maxId) {
        maxId = id;
      }
    }

    // Calculate number of bytes needed (rounded up)
    final int bitsNeeded = maxId + 1;
    final int bytesNeeded = (bitsNeeded + 7) ~/ 8; // Ceiling division

    // Create a bitmask of the appropriate size
    final bitmask = Uint8List(bytesNeeded);

    // Set bits for each ID
    for (final id in ids) {
      final int byteIndex = id ~/ 8;
      final int bitPosition = id % 8;
      bitmask[byteIndex] |= (1 << bitPosition);
    }

    // Create the result with a 4-byte length prefix for the bit length
    final result = Uint8List(4 + bitmask.length);
    ByteData.view(result.buffer).setUint32(0, bitsNeeded, Endian.big);
    result.setRange(4, result.length, bitmask);

    return result;
  }

  /// Decodes a bitmask representation into a list of integers.
  /// The input should have a 4-byte prefix indicating the length of the bitmask.
  static List<int> decodeBitmask(Uint8List bytes) {
    // Extract the bit length from the first 4 bytes
    final bitLength = ByteData.view(bytes.buffer, bytes.offsetInBytes, 4).getUint32(0, Endian.big);

    // The rest of the bytes are the bitmask
    final bitmask = Uint8List.sublistView(bytes, 4);

    // Convert bitmask back to a list of IDs
    final List<int> ids = [];

    for (int id = 0; id < bitLength; id++) {
      final int byteIndex = id ~/ 8;
      final int bitPosition = id % 8;

      // Check if this ID's bit is set
      if (byteIndex < bitmask.length && (bitmask[byteIndex] & (1 << bitPosition)) != 0) {
        ids.add(id);
      }
    }

    return ids;
  }
}
