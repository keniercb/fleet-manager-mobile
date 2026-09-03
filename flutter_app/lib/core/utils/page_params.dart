/// Parámetros de paginación estilo Spring (Riesgo R5 del plan).
///
/// El OpenAPI usa `page` / `perPage` en los listados (los reportes usan
/// `size`). Encapsularlos aquí evita bugs sutiles y da un único punto de
/// ajuste si el backend cambia la convención.
///
///   GET /api/recorridos?page=0&perPage=20&sort=fecha&sortOrder=DESC
class PageParams {
  const PageParams({
    this.page = 0,
    this.perPage = 20,
    this.sort,
    this.sortOrder = 'DESC',
  });

  /// Página 0-indexed (convención Spring Data).
  final int page;

  /// Tamaño de página (`perPage` en los listados del api-docs.json).
  final int perPage;

  /// Campo de orden (ej. `fecha`, `id`). `null` → el default del backend.
  final String? sort;

  /// `ASC` | `DESC`.
  final String sortOrder;

  /// Página siguiente (usado por la paginación infinita de la lista).
  PageParams next() => PageParams(
        page: page + 1,
        perPage: perPage,
        sort: sort,
        sortOrder: sortOrder,
      );

  /// Primera página con la misma forma (pull-to-refresh).
  PageParams first() => PageParams(
        page: 0,
        perPage: perPage,
        sort: sort,
        sortOrder: sortOrder,
      );

  Map<String, String> toQuery() => <String, String>{
        'page': '$page',
        'perPage': '$perPage',
        if (sort != null) 'sort': sort!,
        'sortOrder': sortOrder,
      };

  @override
  String toString() => 'PageParams(page: $page, perPage: $perPage, '
      'sort: $sort, sortOrder: $sortOrder)';
}
