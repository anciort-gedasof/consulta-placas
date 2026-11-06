/// Reglas de la placa colombiana.
///
/// Carro: ABC123. Moto: ABC12D. Se guarda en mayúsculas sin espacios ni
/// guiones. Debe coincidir con `normalizar_placa` y `placa_valida` del
/// backend (backend/migrations/002_funciones.sql).
library;

final RegExp _carro = RegExp(r'^[A-Z]{3}[0-9]{3}$');
final RegExp _moto = RegExp(r'^[A-Z]{3}[0-9]{2}[A-Z]$');
final RegExp _noAlfanumerico = RegExp(r'[^A-Za-z0-9]');

/// Quita espacios, guiones y otros signos, y pasa a mayúsculas.
String normalizarPlaca(String texto) =>
    texto.replaceAll(_noAlfanumerico, '').toUpperCase();

/// true si la placa (ya normalizada) es de carro o de moto.
bool placaValida(String placa) => _carro.hasMatch(placa) || _moto.hasMatch(placa);

/// true si la placa normalizada corresponde a una moto.
bool esPlacaDeMoto(String placa) => _moto.hasMatch(placa);

/// Busca una placa válida dentro de un texto leído por la cámara (OCR).
///
/// El OCR suele traer ruido (nombre de la ciudad, guiones, saltos de línea)
/// y confunde letras con números (O/0, I/1, B/8, S/5).
///
/// 1. Una línea que tenga exactamente 6 caracteres se corrige según la
///    posición (letras al inicio, números al final) y se valida.
/// 2. Si no aparece, se busca una placa exacta, sin corregir, en todo el
///    texto. No se corrige aquí para no "inventar" placas a partir de
///    palabras como RISARALDA.
String? extraerPlacaDeTexto(String textoOcr) {
  for (final linea in textoOcr.split(RegExp(r'[\r\n]+'))) {
    final n = normalizarPlaca(linea);
    if (n.length == 6) {
      final candidato = _corregirConfusiones(n);
      if (placaValida(candidato)) return candidato;
    }
  }
  final limpio = normalizarPlaca(textoOcr);
  for (var i = 0; i + 6 <= limpio.length; i++) {
    final candidato = limpio.substring(i, i + 6);
    if (placaValida(candidato)) return candidato;
  }
  return null;
}

const Map<String, String> _aLetra = {'0': 'O', '1': 'I', '8': 'B', '5': 'S', '2': 'Z'};
const Map<String, String> _aNumero = {'O': '0', 'Q': '0', 'D': '0', 'I': '1', 'L': '1', 'B': '8', 'S': '5', 'Z': '2'};

String _corregirConfusiones(String s) {
  final c = s.split('');
  // Posiciones 0-2: letras. 3-4: números. 5: número (carro) o letra (moto).
  for (var i = 0; i < 3; i++) {
    c[i] = _aLetra[c[i]] ?? c[i];
  }
  for (var i = 3; i < 5; i++) {
    c[i] = _aNumero[c[i]] ?? c[i];
  }
  return c.join();
}
