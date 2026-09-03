/// Regla de negocio pura: advertencia de continuidad del odómetro
/// (RF-02.3 + Riesgo R7 del plan).
///
/// El servidor es la **fuente de verdad**: calcula `odometroInicial`,
/// `combustibleInicial` y `consumo`, y actualiza el odómetro del vehículo.
/// El cliente no puede validar la continuidad exacta (no conoce los
/// recorridos concurrentes), pero sí avisar cuando los km declarados
/// «difieren fuertemente» del uso esperado del vehículo.
///
/// Regla (documentada, conservadora — nunca bloquea, sólo sugiere):
///   1. `kilometros >= umbralAlto` (1000 km en un día es atípico).
///   2. `kilometros >= odómetro actual` — los km del recorrido no deberían
///      superar el odómetro total acumulado del vehículo.
///   3. `kilometros <= 0` no llega aquí: lo bloquea `Validators.kilometros`.
class OdometroRegla {
  const OdometroRegla._();

  /// Umbral a partir del cual un registro diario se considera atípico.
  static const int umbralKmAlto = 1000;

  /// Devuelve el mensaje de advertencia o `null` si todo es razonable.
  static String? advertencia({
    required int kilometros,
    int? odometroActual,
  }) {
    if (odometroActual != null && odometroActual > 0) {
      if (kilometros >= odometroActual) {
        return 'Los km declarados ($kilometros) superan el odómetro del '
            'vehículo ($odometroActual km). Verifique el dato: el servidor '
            'valida la continuidad del odómetro.';
      }
    }
    if (kilometros >= umbralKmAlto) {
      return 'Kilometraje atípico para un recorrido diario '
          '($kilometros km ≥ $umbralKmAlto). Verifique antes de guardar.';
    }
    return null;
  }

  /// Odómetro esperado tras registrar (sólo informativo, R7).
  static int? odometroEsperado({
    required int kilometros,
    int? odometroActual,
  }) {
    if (odometroActual == null) return null;
    return odometroActual + kilometros;
  }
}
