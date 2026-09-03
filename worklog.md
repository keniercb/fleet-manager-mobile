---
Task ID: 1
Agent: Z.ai Code (main)
Task: Analizar api-docs.json y elaborar plan de desarrollo Flutter (requisitos, flujos, arquitectura, roadmap por componentes) para APK de registro de recorridos de vehículos.

Work Log:
- Parseo completo de upload/api-docs.json (OpenAPI 3.1): 120+ endpoints, 80+ esquemas, tags Auth/Users/Vehicles/Drivers/Trips/FuelCards/Reportes Transporte/catálogos.
- Extracción de contratos clave: LoginRequestDto/AuthResponseDto, RecorridoRequest/Response, VehiculoRequest/Response, ChoferRequest, TarjetaCombustible, reportes (DashboardEjecutivo, ConsumoVehiculo, Abastecimiento, Mantenimiento, ReporteMovimientoMensual).
- Identificación de riesgos de contrato (sin securitySchemes, sin esquemas de error, sin refresh token, perPage vs size, sin filtros de rango en /recorridos).
- Redacción del plan completo en plan-app-registro-recorridos-flutter.md (requisitos RF/RNF, flujos mermaid, Clean Architecture + offline-first con Riverpod/Dio/Drift/freezed/go_router, roadmap en 6 fases con gates y estimaciones, mapeo API→casos de uso, riesgos, checklist de arranque).

Stage Summary:
- Artefacto entregado: /home/z/my-project/plan-app-registro-recorridos-flutter.md
- Decisión clave: núcleo de la APK = módulo Recorridos con abastecimiento; offline-first vía Drift outbox; DTOs generados desde api-docs.json; servidor = fuente de verdad del odómetro/consumo.
- 8 riesgos de API documentados con mitigación (R1-R8) para acordar con el backend.
