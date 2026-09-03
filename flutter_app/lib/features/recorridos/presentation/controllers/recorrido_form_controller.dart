/// Controlador del formulario de recorridos (RF-02.1, RF-02.2, RF-02.3,
/// RF-02.6 edición).
///
/// Flujo de guardado:
///   1. Validación de cliente (RF-02.3) → errores por campo.
///   2. POST/PUT vía use cases.
///   3. Si la creación falla por RED → se encola en el outbox (Fase 2.5)
///      y el resultado [RecorridoFormOutcome.encoded] informa a la UI.
///
/// La advertencia de odómetro (R7) es live: recalculada con cada cambio
/// de vehículo o kilómetros.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/flota.dart';
import '../../domain/entities/recorrido.dart';
import '../../domain/services/odometro_regla.dart';
import '../../domain/usecases/actualizar_recorrido.dart';
import '../../domain/usecases/cargar_datos_formulario.dart';
import '../../domain/usecases/crear_recorrido.dart';
import '../../domain/usecases/obtener_recorrido.dart';
import '../../recorridos_providers.dart'
    show
        actualizarRecorridoUseCaseProvider,
        cargarDatosFormularioUseCaseProvider,
        crearRecorridoUseCaseProvider,
        obtenerRecorridoUseCaseProvider;
import 'outbox_controller.dart';

/// Resultado del guardado (la UI decide toast/banner/navegación).
sealed class RecorridoFormOutcome {
  const RecorridoFormOutcome();
}

class RecorridoGuardado extends RecorridoFormOutcome {
  const RecorridoGuardado(this.recorrido);
  final Recorrido recorrido;
}

/// Creado sin red → queda en el outbox con badge «pendiente de sync».
class RecorridoEncolado extends RecorridoFormOutcome {
  const RecorridoEncolado(this.localId);
  final String localId;
}

class RecorridoRechazado extends RecorridoFormOutcome {
  const RecorridoRechazado(this.failure);
  final Failure failure;
}

class RecorridoFormState {
  const RecorridoFormState({
    this.cargando = true,
    this.errorCarga,
    this.datos,
    this.editando = false,
    this.editId,
    this.vehiculoId,
    this.choferId,
    this.fecha,
    this.kilometros = '',
    this.conAbastecimiento = false,
    this.litros = '',
    this.numeroChip = '',
    this.lugarAbastecimiento = '',
    this.tarjetaId,
    this.importe = '',
    this.errores = const <String, String>{},
    this.enviando = false,
  });

  final bool cargando;
  final Failure? errorCarga;

  /// Catálogos cargados (vehículos/choferes/tarjetas).
  final DatosFormulario? datos;

  /// Modo edición (RF-02.6) cuando `editId != null`.
  final bool editando;
  final int? editId;

  // ----- campos -----
  final int? vehiculoId;
  final int? choferId;
  final DateTime? fecha;
  final String kilometros;

  // ----- abastecimiento opcional (RF-02.2) -----
  final bool conAbastecimiento;
  final String litros;
  final String numeroChip;
  final String lugarAbastecimiento;
  final int? tarjetaId;
  final String importe;

  /// Errores de validación por campo (RF-02.3).
  final Map<String, String> errores;
  final bool enviando;

  Vehiculo? get vehiculoSeleccionado => datos?.vehiculos
      .cast<Vehiculo?>()
      .firstWhere((Vehiculo? v) => v?.id == vehiculoId, orElse: () => null);

  TarjetaCombustible? get tarjetaSeleccionada => datos?.tarjetas
      .cast<TarjetaCombustible?>()
      .firstWhere((TarjetaCombustible? t) => t?.id == tarjetaId,
          orElse: () => null);

  RecorridoFormState copyWith({
    bool? cargando,
    Failure? errorCarga,
    bool clearErrorCarga = false,
    DatosFormulario? datos,
    bool? editando,
    int? editId,
    int? vehiculoId,
    bool clearVehiculo = false,
    int? choferId,
    bool clearChofer = false,
    DateTime? fecha,
    bool clearFecha = false,
    String? kilometros,
    bool? conAbastecimiento,
    String? litros,
    String? numeroChip,
    String? lugarAbastecimiento,
    int? tarjetaId,
    bool clearTarjeta = false,
    String? importe,
    Map<String, String>? errores,
    bool? enviando,
  }) {
    return RecorridoFormState(
      cargando: cargando ?? this.cargando,
      errorCarga: clearErrorCarga ? null : (errorCarga ?? this.errorCarga),
      datos: datos ?? this.datos,
      editando: editando ?? this.editando,
      editId: editId ?? this.editId,
      vehiculoId: clearVehiculo ? null : (vehiculoId ?? this.vehiculoId),
      choferId: clearChofer ? null : (choferId ?? this.choferId),
      fecha: clearFecha ? null : (fecha ?? this.fecha),
      kilometros: kilometros ?? this.kilometros,
      conAbastecimiento: conAbastecimiento ?? this.conAbastecimiento,
      litros: litros ?? this.litros,
      numeroChip: numeroChip ?? this.numeroChip,
      lugarAbastecimiento: lugarAbastecimiento ?? this.lugarAbastecimiento,
      tarjetaId: clearTarjeta ? null : (tarjetaId ?? this.tarjetaId),
      importe: importe ?? this.importe,
      errores: errores ?? this.errores,
      enviando: enviando ?? this.enviando,
    );
  }
}

class RecorridoFormController extends Notifier<RecorridoFormState> {
  late final CargarDatosFormularioUseCase _cargarDatos =
      ref.read(cargarDatosFormularioUseCaseProvider);
  late final CrearRecorridoUseCase _crear =
      ref.read(crearRecorridoUseCaseProvider);
  late final ActualizarRecorridoUseCase _actualizar =
      ref.read(actualizarRecorridoUseCaseProvider);
  late final ObtenerRecorridoUseCase _obtener =
      ref.read(obtenerRecorridoUseCaseProvider);

  @override
  RecorridoFormState build() => const RecorridoFormState();

  /// Entrada al formulario: crea (default hoy) o edita (carga el recorrido).
  Future<void> iniciar({int? editarId}) async {
    state = RecorridoFormState(
      cargando: true,
      editando: editarId != null,
      editId: editarId,
      fecha: editarId == null ? DateTime.now() : null,
    );

    final result = await _cargarDatos();
    result.when(
      success: (DatosFormulario datos) async {
        state = state.copyWith(cargando: false, datos: datos, clearErrorCarga: true);

        if (editarId != null) {
          final detalle = await _obtener(editarId);
          detalle.when(
            success: (Recorrido r) {
              state = state.copyWith(
                vehiculoId: r.vehiculo?.id,
                choferId: r.chofer?.id,
                fecha: r.fecha,
                kilometros: '${r.kilometros}',
                conAbastecimiento: r.tieneAbastecimiento,
                litros: r.litrosAbastecidos?.toString() ?? '',
                numeroChip: r.numeroChip ?? '',
                lugarAbastecimiento: r.lugarAbastecimiento ?? '',
                tarjetaId: r.tarjeta?.id,
                importe: r.importeAbastecido?.toString() ?? '',
              );
            },
            failure: (Failure failure) {
              state = state.copyWith(cargando: false, errorCarga: failure);
            },
          );
          return;
        }

        // RF-02.1 — pre-selección heurística para chofer (R9: la API no
        // expone user↔chofer): si la flota visible tiene un único vehículo
        // activo, se pre-selecciona; si no, el usuario elige.
        final List<Vehiculo> activos =
            datos.vehiculos.where((Vehiculo v) => v.activo).toList();
        if (activos.length == 1) {
          state = state.copyWith(
            vehiculoId: activos.first.id,
            choferId: activos.first.chofer?.id,
          );
        }
      },
      failure: (Failure failure) {
        state = state.copyWith(cargando: false, errorCarga: failure);
      },
    );
  }

  void setVehiculo(int? id) => state = state.copyWith(
        vehiculoId: id,
        clearVehiculo: id == null,
        errores: <String, String>{...state.errores}..remove('vehiculo'),
      );

  void setChofer(int? id) => state = state.copyWith(
        choferId: id,
        clearChofer: id == null,
      );

  void setFecha(DateTime? fecha) => state = state.copyWith(
        fecha: fecha,
        clearFecha: fecha == null,
        errores: <String, String>{...state.errores}..remove('fecha'),
      );

  void setKilometros(String value) => state = state.copyWith(
        kilometros: value,
        errores: <String, String>{...state.errores}..remove('kilometros'),
      );

  void toggleAbastecimiento(bool value) => state =
      state.copyWith(conAbastecimiento: value, errores: const <String, String>{});

  void setLitros(String value) => state = state.copyWith(
        litros: value,
        errores: <String, String>{...state.errores}..remove('litros'),
      );

  void setNumeroChip(String value) => state = state.copyWith(numeroChip: value);

  void setLugarAbastecimiento(String value) =>
      state = state.copyWith(lugarAbastecimiento: value);

  void setTarjeta(int? id) => state = state.copyWith(
        tarjetaId: id,
        clearTarjeta: id == null,
      );

  void setImporte(String value) => state = state.copyWith(importe: value);

  /// Advertencia no bloqueante de odómetro (RF-02.3 / R7).
  String? advertencia() {
    final int? km = int.tryParse(state.kilometros.trim());
    if (km == null) return null;
    return OdometroRegla.advertencia(
      kilometros: km,
      odometroActual: state.vehiculoSeleccionado?.odometro,
    );
  }

  /// Odómetro esperado tras registrar (hint informativo, R7).
  int? odometroEsperado() {
    final int? km = int.tryParse(state.kilometros.trim());
    if (km == null) return null;
    return OdometroRegla.odometroEsperado(
      kilometros: km,
      odometroActual: state.vehiculoSeleccionado?.odometro,
    );
  }

  /// Validación RF-02.3 — devuelve `true` si el formulario pasa.
  bool _validar() {
    final Map<String, String> errores = <String, String>{};

    final String? errVehiculo = state.vehiculoId == null
        ? 'El vehículo es obligatorio.'
        : null;
    if (errVehiculo != null) errores['vehiculo'] = errVehiculo;

    final String? errFecha = Validators.fechaNoFutura(state.fecha);
    if (errFecha != null) errores['fecha'] = errFecha;

    final String? errKm = Validators.kilometros(state.kilometros);
    if (errKm != null) errores['kilometros'] = errKm;

    if (state.conAbastecimiento) {
      final String? errLitros = Validators.litros(state.litros);
      if (errLitros != null) errores['litros'] = errLitros;

      final String? errChip = Validators.maxLen(state.numeroChip, 50,
          label: 'El número de chip');
      if (errChip != null) errores['numeroChip'] = errChip;

      final String? errLugar = Validators.maxLen(
          state.lugarAbastecimiento, 100,
          label: 'El lugar de abastecimiento');
      if (errLugar != null) errores['lugarAbastecimiento'] = errLugar;

      final String? errImporte = Validators.importe(state.importe);
      if (errImporte != null) errores['importe'] = errImporte;

      // Coherencia mínima: si hay importe o chip debe haber litros (>0).
      final double? litros = double.tryParse(state.litros.replaceAll(',', '.'));
      final bool declaraImporte = state.importe.trim().isNotEmpty;
      if (declaraImporte && (litros == null || litros <= 0)) {
        errores['litros'] = 'Declara los litros abastecidos.';
      }
    }

    state = state.copyWith(errores: errores);
    return errores.isEmpty;
  }

  RecorridoInput _construirInput() {
    final bool abastece = state.conAbastecimiento;
    final double? litros =
        abastece ? double.tryParse(state.litros.replaceAll(',', '.')) : null;
    final double? importe =
        abastece ? double.tryParse(state.importe.replaceAll(',', '.')) : null;
    return RecorridoInput(
      vehiculoId: state.vehiculoId!,
      choferId: state.choferId,
      fecha: state.fecha!,
      kilometros: int.parse(state.kilometros.trim()),
      litrosAbastecidos: (litros != null && litros > 0) ? litros : null,
      numeroChip: abastece && state.numeroChip.trim().isNotEmpty
          ? state.numeroChip.trim()
          : null,
      lugarAbastecimiento: abastece && state.lugarAbastecimiento.trim().isNotEmpty
          ? state.lugarAbastecimiento.trim()
          : null,
      tarjetaCombustibleId: abastece ? state.tarjetaId : null,
      importeAbastecido: (importe != null && importe > 0) ? importe : null,
    );
  }

  /// Guardar (crear o editar). Nunca lanza: devuelve [RecorridoFormOutcome].
  Future<RecorridoFormOutcome> guardar() async {
    if (state.enviando) return const RecorridoRechazado(UnknownFailure());
    if (!_validar()) {
      return const RecorridoRechazado(
        ValidationFailure(userMessage: 'Revise los campos marcados.'),
      );
    }

    state = state.copyWith(enviando: true);
    final RecorridoInput input = _construirInput();
    final Result<Recorrido> result = state.editando
        ? await _actualizar(state.editId!, input)
        : await _crear(input);

    state = state.copyWith(enviando: false);

    final Failure? failure = result.failureOrNull;
    if (failure == null) {
      return RecorridoGuardado(result.valueOrNull!);
    }

    // Fase 2.5 — sólo la CREACIÓN con fallo de red se encola en el outbox.
    final bool falloDeRed =
        failure is NetworkFailure || failure is TimeoutFailure;
    if (!state.editando && falloDeRed) {
      final String localId = await ref.read(outboxProvider.notifier).enqueue(input);
      return RecorridoEncolado(localId);
    }
    return RecorridoRechazado(failure);
  }
}

final NotifierProvider<RecorridoFormController, RecorridoFormState>
    recorridoFormProvider =
    NotifierProvider<RecorridoFormController, RecorridoFormState>(
  RecorridoFormController.new,
);
