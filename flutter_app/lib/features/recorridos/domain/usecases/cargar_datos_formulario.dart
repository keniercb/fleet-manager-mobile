/// Caso de uso: cargar los catálogos del formulario de recorridos (RF-02.1).
///
/// Agrupa las tres lecturas que el formulario necesita (vehículos, choferes
/// y tarjetas) para que el controlador haga una única llamada. Si algún
/// catálogo falla el resultado es `Failure` con el mensaje del primero
/// que falle (los tres vienen del mismo backend).
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../entities/flota.dart';
import '../repositories/flota_repository.dart';

class DatosFormulario {
  const DatosFormulario({
    required this.vehiculos,
    required this.choferes,
    required this.tarjetas,
  });

  final List<Vehiculo> vehiculos;
  final List<Chofer> choferes;
  final List<TarjetaCombustible> tarjetas;
}

class CargarDatosFormularioUseCase {
  CargarDatosFormularioUseCase(this._flotaRepository);

  final FlotaRepository _flotaRepository;

  Future<Result<DatosFormulario>> call() async {
    try {
      final List<Vehiculo> vehiculos = await _flotaRepository.obtenerVehiculos();
      final List<Chofer> choferes = await _flotaRepository.obtenerChoferes();
      final List<TarjetaCombustible> tarjetas =
          await _flotaRepository.obtenerTarjetas();
      return Result.success<DatosFormulario>(
        DatosFormulario(
          vehiculos: vehiculos,
          choferes: choferes,
          tarjetas: tarjetas,
        ),
      );
    } on Failure catch (failure) {
      return Result.failure<DatosFormulario>(failure);
    }
  }
}
