/// Pantalla: formulario de recorrido (RF-02.1 + RF-02.2 + RF-02.3, y
/// RF-02.6 en modo edición).
///
///  - Paso único con bloque «Abastecimiento» opcional colapsable (switch).
///  - Selectores: vehículo (con odómetro), chofer, tarjeta con saldo.
///  - Validación RF-02.3 en submit + advertencia live de odómetro (R7).
///  - Al guardar: éxito → toast y pop; sin red → outbox + toast informativo;
///    error → banner con el mensaje del backend.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/widgets/app_text_field.dart';
import '../../../auth/presentation/widgets/flow_banner.dart';
import '../controllers/recorrido_form_controller.dart';

final DateFormat _fechaFmt = DateFormat('dd/MM/yyyy');
final NumberFormat _saldoFmt = NumberFormat('#,##0.00');

class RecorridoFormScreen extends ConsumerStatefulWidget {
  const RecorridoFormScreen({super.key, this.editarId});

  final int? editarId;

  @override
  ConsumerState<RecorridoFormScreen> createState() =>
      _RecorridoFormScreenState();
}

class _RecorridoFormScreenState extends ConsumerState<RecorridoFormScreen> {
  String? _banner;

  @override
  void initState() {
    super.initState();
    // El estado del formulario se reinicia al entrar (nuevo o editar).
    Future<void>.microtask(
      () => ref.read(recorridoFormProvider.notifier).iniciar(
            editarId: widget.editarId,
          ),
    );
  }

  Future<void> _guardar() async {
    final RecorridoFormOutcome outcome =
        await ref.read(recorridoFormProvider.notifier).guardar();
    if (!mounted) return;
    switch (outcome) {
      case RecorridoGuardado():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recorrido guardado correctamente')),
        );
        context.pop();
      case RecorridoEncolado():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin conexión: el recorrido quedó guardado en el dispositivo '
              'y se sincronizará automáticamente.',
            ),
          ),
        );
        context.pop();
      case RecorridoRechazado(:final failure):
        setState(() => _banner = failure.userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RecorridoFormState form = ref.watch(recorridoFormProvider);
    final RecorridoFormController controller =
        ref.read(recorridoFormProvider.notifier);

    if (form.cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recorrido')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (form.errorCarga != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recorrido')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(form.errorCarga!.userMessage, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => controller.iniciar(editarId: widget.editarId),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final String? advertencia = controller.advertencia();
    final int? esperado = controller.odometroEsperado();

    return Scaffold(
      appBar: AppBar(
        title: Text(form.editando ? 'Editar recorrido' : 'Nuevo recorrido'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (_banner != null)
              FlowBanner(
                message: _banner!,
                kind: FlowBannerKind.warning,
                onDismiss: () => setState(() => _banner = null),
              ),

            // ---------------- Datos del recorrido ----------------
            _DropdownField<int>(
              label: 'Vehículo *',
              value: form.vehiculoId,
              errorText: form.errores['vehiculo'],
              icon: Icons.directions_car_rounded,
              items: <DropdownMenuItem<int>>[
                ...?form.datos?.vehiculos
                    .where((v) => v.activo)
                    .map(
                      (v) => DropdownMenuItem<int>(
                        value: v.id,
                        child: Text(
                          '${v.etiqueta}'
                          '  ·  odómetro ${_saldoFmt.format(v.odometro.toDouble())} km',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
              ],
              onChanged: controller.setVehiculo,
            ),
            const SizedBox(height: 12),
            _DropdownField<int>(
              label: 'Chofer',
              value: form.choferId,
              icon: Icons.badge_rounded,
              items: <DropdownMenuItem<int>>[
                const DropdownMenuItem<int>(value: null, child: Text('Sin chofer')),
                ...?form.datos?.choferes
                    .where((c) => c.activo)
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(
                          '${c.nombreCompleto}'
                          '${c.numeroLicencia != null ? ' · ${c.numeroLicencia}' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
              ],
              onChanged: controller.setChofer,
            ),
            const SizedBox(height: 12),

            // Fecha (default hoy, ≤ hoy — RF-02.3).
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _seleccionarFecha(context, form),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fecha *',
                  errorText: form.errores['fecha'],
                  prefixIcon: const Icon(Icons.calendar_month_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  form.fecha == null
                      ? 'Seleccione la fecha'
                      : _fechaFmt.format(form.fecha!),
                ),
              ),
            ),
            const SizedBox(height: 12),

            AppTextField(
              label: 'Kilómetros recorridos *',
              hint: 'Solo enteros, mínimo 1',
              keyboardType: TextInputType.number,
              errorText: form.errores['kilometros'],
              prefixIcon: const Icon(Icons.speed_rounded),
              onChanged: controller.setKilometros,
            ),

            // Hint odómetro esperado + advertencia R7 (live).
            if (!form.editando && form.vehiculoSeleccionado != null) ...<Widget>[
              const SizedBox(height: 6),
              if (esperado != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Odómetro tras registrar: '
                    '${_saldoFmt.format(esperado.toDouble())} km (el servidor valida la continuidad)',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
            if (advertencia != null) ...<Widget>[
              const SizedBox(height: 10),
              FlowBanner(message: advertencia, kind: FlowBannerKind.warning),
            ],

            const Divider(height: 32),

            // ---------------- Abastecimiento opcional (RF-02.2) ----------------
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Abastecimiento de combustible'),
              subtitle: const Text(
                'Opcional: litros, chip, lugar, tarjeta e importe',
              ),
              value: form.conAbastecimiento,
              onChanged: controller.toggleAbastecimiento,
            ),
            if (form.conAbastecimiento) ...<Widget>[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      label: 'Litros abastecidos',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      errorText: form.errores['litros'],
                      prefixIcon: const Icon(Icons.local_gas_station_rounded),
                      onChanged: controller.setLitros,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: 'Importe',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      errorText: form.errores['importe'],
                      prefixIcon:
                          const Icon(Icons.attach_money_rounded),
                      onChanged: controller.setImporte,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Número de chip',
                hint: 'Máximo 50 caracteres',
                errorText: form.errores['numeroChip'],
                prefixIcon: const Icon(Icons.badge_outlined),
                onChanged: controller.setNumeroChip,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Lugar de abastecimiento',
                hint: 'Máximo 100 caracteres',
                errorText: form.errores['lugarAbastecimiento'],
                prefixIcon: const Icon(Icons.place_rounded),
                onChanged: controller.setLugarAbastecimiento,
              ),
              const SizedBox(height: 12),
              _DropdownField<int>(
                label: 'Tarjeta de combustible',
                value: form.tarjetaId,
                icon: Icons.credit_card_rounded,
                items: <DropdownMenuItem<int>>[
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Sin tarjeta'),
                  ),
                  ...?form.datos?.tarjetas
                      .where((t) => t.activo)
                      .map(
                        (t) => DropdownMenuItem<int>(
                          value: t.id,
                          child: Text(
                            '${t.etiqueta} · saldo ${_saldoFmt.format(t.saldo)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                ],
                onChanged: controller.setTarjeta,
              ),
            ],

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: form.enviando ? null : _guardar,
              icon: form.enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                form.editando ? 'Guardar cambios' : 'Registrar recorrido',
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '* obligatorios · el servidor calcula odómetro inicial, '
                'combustible y consumo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarFecha(
    BuildContext context,
    RecorridoFormState form,
  ) async {
    final DateTime hoy = DateTime.now();
    final DateTime inicial = form.fecha ?? hoy;
    final DateTime? elegida = await showDatePicker(
      context: context,
      initialDate: inicial.isAfter(hoy) ? hoy : inicial,
      firstDate: DateTime(hoy.year - 2),
      lastDate: hoy, // RF-02.3: fecha ≤ hoy
      helpText: 'Fecha del recorrido',
    );
    if (elegida != null) {
      ref.read(recorridoFormProvider.notifier).setFecha(elegida);
    }
  }
}

/// Dropdown con estilo del design system (etiqueta, icono, error).
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.errorText,
    this.icon,
  });

  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final T? value;
  final String? errorText;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixIcon: icon == null ? null : Icon(icon),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items,
      onChanged: (T? v) => onChanged(v),
    );
  }
}
