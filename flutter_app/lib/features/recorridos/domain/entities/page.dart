/// Página genérica estilo Spring Data (RF-02.4).
///
/// Contrato de `PageRecorridoResponse` / `PageVehiculoResponse` /
/// `PageChoferResponse` / `PageTarjetaCombustibleResponse` del
/// `api-docs.json`:
///
///   { content, totalElements, totalPages, number, size, first, last, empty }
class PageResult<T> {
  const PageResult({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
    required this.first,
    required this.last,
  });

  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final int size;
  final bool first;
  final bool last;

  bool get empty => content.isEmpty;

  bool get hasNext => !last && content.isNotEmpty;

  /// Página inicial vacía — usada como estado de arranque de la lista.
  factory PageResult.empty() => PageResult<T>(
        content: <T>[],
        totalElements: 0,
        totalPages: 0,
        number: 0,
        size: 0,
        first: true,
        last: true,
      );
}
