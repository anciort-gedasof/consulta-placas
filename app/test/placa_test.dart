import 'package:consulta_placas/dominio/placa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizarPlaca', () {
    test('quita espacios y guiones y pasa a mayúsculas', () {
      expect(normalizarPlaca(' abc-123 '), 'ABC123');
      expect(normalizarPlaca('abc 12d'), 'ABC12D');
    });
  });

  group('placaValida', () {
    test('acepta carro y moto', () {
      expect(placaValida('ABC123'), isTrue);
      expect(placaValida('ABC12D'), isTrue);
    });
    test('rechaza formatos errados', () {
      expect(placaValida('AB1234'), isFalse);
      expect(placaValida('ABC1234'), isFalse);
      expect(placaValida('abc123'), isFalse, reason: 'debe venir normalizada');
      expect(placaValida(''), isFalse);
    });
    test('identifica moto', () {
      expect(esPlacaDeMoto('ABC12D'), isTrue);
      expect(esPlacaDeMoto('ABC123'), isFalse);
    });
  });

  group('extraerPlacaDeTexto (OCR)', () {
    test('encuentra la placa entre ruido', () {
      expect(extraerPlacaDeTexto('PEREIRA\nABC-123'), 'ABC123');
    });
    test('corrige confusiones típicas del OCR', () {
      expect(extraerPlacaDeTexto('A8C 1O3'), 'ABC103');
      expect(extraerPlacaDeTexto('0RT 58D'), 'ORT58D');
    });
    test('devuelve null si no hay placa', () {
      expect(extraerPlacaDeTexto('RISARALDA'), isNull);
      expect(extraerPlacaDeTexto('PEREIRA\nRISARALDA'), isNull);
    });
    test('no corrige texto largo para no inventar placas', () {
      // Corregida, "ARALDA" daría la placa de moto ARA10A.
      expect(extraerPlacaDeTexto('ARALDA RISARALDA'), isNull);
    });
  });
}
