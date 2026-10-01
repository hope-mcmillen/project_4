import 'dart:math';

/// Letters and digits that can't be misread aloud or on screen (no 0/O, 1/I/L).
const roomCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const roomCodeLength = 5;

String generateRoomCode([Random? random]) {
  final source = random ?? Random.secure();
  return String.fromCharCodes(
    List.generate(
      roomCodeLength,
      (_) =>
          roomCodeAlphabet.codeUnitAt(source.nextInt(roomCodeAlphabet.length)),
    ),
  );
}

/// Uppercases and strips spaces/dashes so "abc-de" matches "ABCDE".
String normalizeRoomCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

bool isValidRoomCode(String code) =>
    code.length == roomCodeLength &&
    code.split('').every(roomCodeAlphabet.contains);
