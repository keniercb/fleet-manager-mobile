/**
 * "BD" simulada del RF-02 · Registro de recorridos.
 *
 * Espejo de las entidades Dart (Vehiculo, Chofer, TarjetaCombustible,
 * Recorrido) y de la persistencia local del APK (Drift outbox + cache).
 * Se persiste en localStorage (`rf02_db`, `rf02_outbox`) para que los datos
 * sobrevivan recargas de la demo, igual que `rf01_demo_token`.
 */

// ---------------------------------------------------------------------------
// Tipos (espejo de las entidades Dart)
// ---------------------------------------------------------------------------

/** id numérico del servidor | "local-N" para borradores del outbox. */
export type RecorridoId = number | string;

export interface MockVehiculo {
  id: number;
  matricula: string;
  modelo: string;
  marcaNombre: string;
  tipoVehiculoNombre: string;
  tipoCombustibleNombre: string;
  odometro: number; // km acumulados
  combustible: number; // litros en tanque
  indiceConsumo: number; // L/km
  choferId?: number;
  activo: boolean;
}

export interface MockChofer {
  id: number;
  nombre: string;
  apellidos: string;
  numeroLicencia: string;
  activo: boolean;
}

export interface MockTarjeta {
  id: number;
  numero: string;
  saldo: number;
  isoCode: "CUP" | "MLC";
  activo: boolean;
}

export interface MockRecorrido {
  id: RecorridoId;
  vehiculoId: number;
  choferId?: number;
  /** yyyy-MM-dd */
  fecha: string;
  kilometros: number; // ≥ 1
  /** Calculado por el "servidor" (null hasta sync en items del outbox). */
  odometroInicial: number | null;
  combustibleInicial: number | null;
  /** km / litrosAbastecidos (solo si hubo abastecimiento). */
  consumo: number | null;
  litrosAbastecidos?: number;
  numeroChip?: string;
  lugarAbastecimiento?: string;
  tarjetaId?: number;
  importeAbastecido?: number;
  /** Borrado lógico: activo=false → desaparece de las listas. */
  activo: boolean;
  creadoPor: string;
  fechaCreacion: string; // ISO
  /** true mientras el registro vive en el outbox offline (Fase 2 · 2.5). */
  pendingSync?: boolean;
}

export interface RecorridoPayload {
  vehiculoId: number;
  choferId?: number;
  fecha: string;
  kilometros: number;
  litrosAbastecidos?: number;
  numeroChip?: string;
  lugarAbastecimiento?: string;
  tarjetaId?: number;
  importeAbastecido?: number;
}

export interface MockDb {
  vehiculos: MockVehiculo[];
  choferes: MockChofer[];
  tarjetas: MockTarjeta[];
  recorridos: MockRecorrido[];
  nextRecorridoId: number;
  nextLocalId: number;
}

export interface OutboxEntry {
  localId: string;
  payload: RecorridoPayload;
  creadoEn: string;
}

// ---------------------------------------------------------------------------
// Persistencia
// ---------------------------------------------------------------------------

const DB_KEY = "rf02_db";
const OUTBOX_KEY = "rf02_outbox";

export function loadDb(): MockDb {
  try {
    const raw = localStorage.getItem(DB_KEY);
    if (raw) return JSON.parse(raw) as MockDb;
  } catch {
    /* datos corruptos → reseed */
  }
  const db = seedDb();
  saveDb(db);
  return db;
}

export function saveDb(db: MockDb) {
  localStorage.setItem(DB_KEY, JSON.stringify(db));
}

export function loadOutbox(): OutboxEntry[] {
  try {
    const raw = localStorage.getItem(OUTBOX_KEY);
    if (raw) return JSON.parse(raw) as OutboxEntry[];
  } catch {
    /* outbox corrupto → vacío */
  }
  return [];
}

export function saveOutbox(entries: OutboxEntry[]) {
  localStorage.setItem(OUTBOX_KEY, JSON.stringify(entries));
}

/** Reseed completo de la "BD" demo (botón «Reiniciar datos demo»). */
export function resetRecorridosDb() {
  localStorage.removeItem(DB_KEY);
  localStorage.removeItem(OUTBOX_KEY);
}

// ---------------------------------------------------------------------------
// Helpers de fecha / formato (es)
// ---------------------------------------------------------------------------

export const round2 = (n: number) => Math.round(n * 100) / 100;

export function isoDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function daysAgoIso(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return isoDate(d);
}

export const hoyIso = () => isoDate(new Date());

let nfInt: Intl.NumberFormat;
let nfDec: Intl.NumberFormat;
try {
  nfInt = new Intl.NumberFormat("es-CU", { maximumFractionDigits: 0 });
  nfDec = new Intl.NumberFormat("es-CU", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
} catch {
  nfInt = new Intl.NumberFormat("es", { maximumFractionDigits: 0 });
  nfDec = new Intl.NumberFormat("es", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export const fmtInt = (n: number) => nfInt.format(n);
export const fmtDec = (n: number) => nfDec.format(n);

export function fmtFecha(iso: string): string {
  if (!iso) return "—";
  return new Intl.DateTimeFormat("es", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(new Date(`${iso}T00:00:00`));
}

export function fmtDateTime(iso: string): string {
  if (!iso) return "—";
  return new Intl.DateTimeFormat("es", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(iso));
}

// ---------------------------------------------------------------------------
// Semilla (3 vehículos, 3 choferes, 2 tarjetas, 8 recorridos históricos con
// odómetros acumulados coherentes)
// ---------------------------------------------------------------------------

export function seedDb(): MockDb {
  const vehiculos: MockVehiculo[] = [
    {
      id: 1,
      matricula: "P456789",
      modelo: "2107",
      marcaNombre: "Lada",
      tipoVehiculoNombre: "Automóvil ligero",
      tipoCombustibleNombre: "Gasolina",
      odometro: 184150,
      combustible: 28.5,
      indiceConsumo: 0.11,
      choferId: 1,
      activo: true,
    },
    {
      id: 2,
      matricula: "B123456",
      modelo: "ZK6122H",
      marcaNombre: "Yutong",
      tipoVehiculoNombre: "Ómnibus",
      tipoCombustibleNombre: "Diésel",
      odometro: 96750,
      combustible: 120,
      indiceConsumo: 0.28,
      choferId: 2,
      activo: true,
    },
    {
      id: 3,
      matricula: "T789012",
      modelo: "Hilux 2.4",
      marcaNombre: "Toyota",
      tipoVehiculoNombre: "Camioneta",
      tipoCombustibleNombre: "Diésel",
      odometro: 45210,
      combustible: 45,
      indiceConsumo: 0.12,
      choferId: 3,
      activo: true,
    },
  ];

  const choferes: MockChofer[] = [
    { id: 1, nombre: "Kenier", apellidos: "Rodríguez Pérez", numeroLicencia: "T-1045872", activo: true },
    { id: 2, nombre: "María", apellidos: "Fernández López", numeroLicencia: "P-0983211", activo: true },
    { id: 3, nombre: "Carlos", apellidos: "Ruiz Gómez", numeroLicencia: "T-0776543", activo: true },
  ];

  const tarjetas: MockTarjeta[] = [
    { id: 1, numero: "TJ-0001", saldo: 1250, isoCode: "CUP", activo: true },
    { id: 2, numero: "TJ-0002", saldo: 340.5, isoCode: "CUP", activo: true },
    { id: 3, numero: "TJ-MLC-01", saldo: 85, isoCode: "MLC", activo: true },
  ];

  const admin = "admin@transporte.cu";
  const chofer = "chofer@transporte.cu";
  const created = (days: number) => {
    const d = new Date();
    d.setDate(d.getDate() - days);
    d.setHours(8 + (days % 6), 24, 0, 0);
    return d.toISOString();
  };

  const recorridos: MockRecorrido[] = [
    // --- Vehículo 1 · Lada P456789 (odómetro actual 184 150) ---
    {
      id: 3,
      vehiculoId: 1,
      choferId: 1,
      fecha: daysAgoIso(9),
      kilometros: 121,
      odometroInicial: 183724,
      combustibleInicial: 28.9,
      consumo: 9.68,
      litrosAbastecidos: 12.5,
      numeroChip: "CH-8812",
      lugarAbastecimiento: "CUPET 23 y L",
      tarjetaId: 1,
      importeAbastecido: 3500,
      activo: true,
      creadoPor: admin,
      fechaCreacion: created(9),
    },
    {
      id: 5,
      vehiculoId: 1,
      choferId: 1,
      fecha: daysAgoIso(6),
      kilometros: 76,
      odometroInicial: 183845,
      combustibleInicial: 26.4,
      consumo: null,
      activo: true,
      creadoPor: chofer,
      fechaCreacion: created(6),
    },
    {
      id: 8,
      vehiculoId: 1,
      choferId: 1,
      fecha: daysAgoIso(3),
      kilometros: 142,
      odometroInicial: 183921,
      combustibleInicial: 24.2,
      consumo: 10.0,
      litrosAbastecidos: 14.2,
      numeroChip: "CH-8825",
      lugarAbastecimiento: "CUPET Calle 42",
      tarjetaId: 2,
      importeAbastecido: 3976,
      activo: true,
      creadoPor: chofer,
      fechaCreacion: created(3),
    },
    {
      id: 9,
      vehiculoId: 1,
      choferId: 1,
      fecha: daysAgoIso(1),
      kilometros: 87,
      odometroInicial: 184063,
      combustibleInicial: 25.1,
      consumo: null,
      activo: true,
      creadoPor: chofer,
      fechaCreacion: created(1),
    },
    // --- Vehículo 2 · Yutong B123456 (odómetro actual 96 750) ---
    {
      id: 4,
      vehiculoId: 2,
      choferId: 2,
      fecha: daysAgoIso(7),
      kilometros: 330,
      odometroInicial: 96150,
      combustibleInicial: 132,
      consumo: null,
      activo: true,
      creadoPor: admin,
      fechaCreacion: created(7),
    },
    {
      id: 1,
      vehiculoId: 2,
      choferId: 2,
      fecha: daysAgoIso(2),
      kilometros: 270,
      odometroInicial: 96480,
      combustibleInicial: 55,
      consumo: 3.57,
      litrosAbastecidos: 75.6,
      numeroChip: "CH-5521",
      lugarAbastecimiento: "CUPET Ómnibus Nacionales",
      tarjetaId: 3,
      importeAbastecido: 113.4,
      activo: true,
      creadoPor: admin,
      fechaCreacion: created(2),
    },
    // --- Vehículo 3 · Hilux T789012 (odómetro actual 45 210) ---
    {
      id: 7,
      vehiculoId: 3,
      choferId: 3,
      fecha: daysAgoIso(10),
      kilometros: 160,
      odometroInicial: 44850,
      combustibleInicial: 52,
      consumo: null,
      activo: true,
      creadoPor: admin,
      fechaCreacion: created(10),
    },
    {
      id: 6,
      vehiculoId: 3,
      choferId: 3,
      fecha: daysAgoIso(4),
      kilometros: 200,
      odometroInicial: 45010,
      combustibleInicial: 30,
      consumo: 8.33,
      litrosAbastecidos: 24,
      numeroChip: "CH-7734",
      lugarAbastecimiento: "Servicentro Santa Clara",
      tarjetaId: 2,
      importeAbastecido: 6720,
      activo: true,
      creadoPor: admin,
      fechaCreacion: created(4),
    },
  ];

  return {
    vehiculos,
    choferes,
    tarjetas,
    recorridos,
    nextRecorridoId: 10,
    nextLocalId: 1,
  };
}

// ---------------------------------------------------------------------------
// Consultas puras (las "queries" del repositorio Dart)
// ---------------------------------------------------------------------------

/** Orden del listado: fecha DESC; empate → pendientes primero, luego id DESC. */
export function sortRecorridos(list: MockRecorrido[]): MockRecorrido[] {
  return [...list].sort((a, b) => {
    if (a.fecha !== b.fecha) return a.fecha < b.fecha ? 1 : -1;
    if (!!a.pendingSync !== !!b.pendingSync) return a.pendingSync ? -1 : 1;
    const ai = typeof a.id === "number" ? a.id : 0;
    const bi = typeof b.id === "number" ? b.id : 0;
    return bi - ai;
  });
}

export function choferNombre(db: MockDb, choferId?: number): string {
  if (choferId == null) return "Sin chofer";
  const c = db.choferes.find((x) => x.id === choferId);
  return c ? `${c.nombre} ${c.apellidos}` : "Sin chofer";
}

export function choferLabel(db: MockDb, choferId?: number): string {
  if (choferId == null) return "Sin chofer";
  const c = db.choferes.find((x) => x.id === choferId);
  return c ? `${c.nombre} ${c.apellidos} · ${c.numeroLicencia}` : "Sin chofer";
}

export function tarjetaLabel(db: MockDb, tarjetaId?: number): string {
  if (tarjetaId == null) return "Sin tarjeta";
  const t = db.tarjetas.find((x) => x.id === tarjetaId);
  return t ? `${t.numero} · ${fmtDec(t.saldo)} ${t.isoCode}` : "Sin tarjeta";
}

export function vehiculoLabel(v: MockVehiculo): string {
  return `${v.matricula} · ${v.marcaNombre} ${v.modelo}`;
}
