"use client";

/**
 * RF-02 · Registro de recorridos (núcleo del negocio) — Fase 2.
 *
 * Replica el comportamiento del módulo Flutter:
 *  - Lista paginada (fecha DESC, 5/pág), filtro por vehículo (RF-02.7), búsqueda rápida.
 *  - Formulario crear/editar con abastecimiento opcional (RF-02.1..RF-02.3).
 *  - Detalle con datos calculados por el servidor + auditoría (RF-02.5).
 *  - Edición/borrado según rol (RF-02.6) con borrado lógico (R6: cuerpo vacío = éxito).
 *  - Outbox offline FIFO + SyncManager v1 (Gate F2 / 2.5): crear sin red → badge
 *    «Pendiente de sync» → auto-sync al reconectar (~1,2 s) con recalculo de
 *    odómetro/consumo por parte del "servidor".
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { useToast } from "@/hooks/use-toast";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import {
  AlertTriangle,
  ArrowLeft,
  CheckCircle2,
  ChevronRight,
  CloudOff,
  Fuel,
  Loader2,
  Pencil,
  Plus,
  RefreshCw,
  Route,
  Search,
  Trash2,
} from "lucide-react";
import {
  choferNombre,
  fmtDateTime,
  fmtDec,
  fmtFecha,
  fmtInt,
  hoyIso,
  loadDb,
  loadOutbox,
  round2,
  saveDb,
  saveOutbox,
  sortRecorridos,
  tarjetaLabel,
  type MockDb,
  type MockRecorrido,
  type OutboxEntry,
  type RecorridoId,
  type RecorridoPayload,
} from "./mock-db";

// ---------------------------------------------------------------------------
// Tipos locales (estructuralmente compatibles con phone-demo, evita imports
// circulares)
// ---------------------------------------------------------------------------

interface DemoUser {
  id: number;
  email: string;
  roles: { id: number; name: string; description: string }[];
}

type PushLog = (entry: {
  method?: string;
  path?: string;
  status?: number;
  note?: string;
}) => void;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** email del usuario demo → choferId (vehículo preseleccionado, RF-02.1). */
const DEMO_EMAIL_TO_CHOFER_ID: Record<string, number> = {
  "chofer@transporte.cu": 1,
};

function capsFor(user: DemoUser | null) {
  if (!user) return { trips: false, fleet: false, admin: false };
  const names = user.roles.map((r) => r.name.toLowerCase());
  const admin = names.some((n) => n.includes("admin") || n.includes("gerente"));
  const supervisor = names.some((n) => n.includes("jefe") || n.includes("supervisor"));
  const chofer = names.some((n) => n.includes("chofer") || n.includes("driver"));
  return {
    trips: admin || supervisor || chofer,
    fleet: admin || supervisor, // eliminar/gestionar: solo admin/jefe (RF-02.6)
    admin,
  };
}

// ---------------------------------------------------------------------------
// Provider: "BD" local + API simulada + SyncManager (outbox FIFO)
// ---------------------------------------------------------------------------

interface RecorridosContextValue {
  db: MockDb | null;
  outbox: OutboxEntry[];
  syncing: boolean;
  offline: boolean;
  canTrips: boolean;
  canDelete: boolean;
  assignedVehiculoId: number | null;
  fetchPage: (page: number, vehiculoId: number | null) => Promise<MockRecorrido[]>;
  fetchCatalogos: () => Promise<void>;
  createRecorrido: (payload: RecorridoPayload) => Promise<MockRecorrido>;
  updateRecorrido: (id: RecorridoId, payload: RecorridoPayload) => Promise<MockRecorrido>;
  deleteRecorrido: (id: RecorridoId) => Promise<void>;
  syncOutbox: () => Promise<void>;
}

const RecorridosContext = createContext<RecorridosContextValue | null>(null);

function useRecorridos(): RecorridosContextValue {
  const ctx = useContext(RecorridosContext);
  if (!ctx) throw new Error("useRecorridos fuera de RecorridosProvider");
  return ctx;
}

export function RecorridosProvider({
  offline,
  offlineRef,
  pushLog,
  user,
  resetSignal,
  children,
}: {
  offline: boolean;
  offlineRef: { current: boolean };
  pushLog: PushLog;
  user: DemoUser | null;
  resetSignal: number;
  children: React.ReactNode;
}) {
  const { toast } = useToast();

  const dbRef = useRef<MockDb | null>(null);
  const outboxRef = useRef<OutboxEntry[]>([]);
  const syncingRef = useRef(false);
  // Snapshots para render (los refs solo se leen/escriben en callbacks/effects;
  // el estado dispara el re-render tras cada mutación).
  const [db, setDb] = useState<MockDb | null>(null);
  const [outbox, setOutbox] = useState<OutboxEntry[]>([]);
  const [syncing, setSyncing] = useState(false);
  const commit = useCallback(() => {
    setDb(dbRef.current ? { ...dbRef.current } : null);
    setOutbox([...outboxRef.current]);
  }, []);

  // Carga / reseed de la "BD" (como abrir la caja Drift del APK).
  // Lectura de localStorage dentro de un callback (mismo patrón que RF-01).
  useEffect(() => {
    const timer = setTimeout(() => {
      dbRef.current = loadDb();
      outboxRef.current = loadOutbox();
      commit();
    }, 0);
    return () => clearTimeout(timer);
  }, [resetSignal, commit]);

  const caps = capsFor(user);
  const assignedVehiculoId = useMemo(() => {
    if (!user) return null;
    const choferId = DEMO_EMAIL_TO_CHOFER_ID[user.email];
    if (choferId == null) return null;
    const isChofer = user.roles.some((r) => r.name.toLowerCase().includes("chofer"));
    return isChofer ? choferId : null;
  }, [user]);

  // ---- GET /api/recorridos (paginado) o /api/recorridos/vehiculo/{id} ----
  const fetchPage = useCallback(
    async (page: number, vehiculoId: number | null): Promise<MockRecorrido[]> => {
      const base = vehiculoId == null ? "/api/recorridos" : `/api/recorridos/vehiculo/${vehiculoId}`;
      const path = `${base}?page=${page}&perPage=5&sort=fecha&sortOrder=DESC`;
      if (offlineRef.current) {
        pushLog({
          method: "GET",
          path,
          status: 0,
          note: "DioException.connectionError → NetworkFailure (R2)",
        });
        throw new Error("offline");
      }
      await sleep(550);
      const db = dbRef.current;
      if (!db) return [];
      let items = sortRecorridos(db.recorridos.filter((r) => r.activo));
      if (vehiculoId != null) items = items.filter((r) => r.vehiculoId === vehiculoId);
      pushLog({
        method: "GET",
        path,
        status: 200,
        note: `Page<RecorridoResponse> · total ${items.length} · página ${page} (5/pág, fecha DESC)`,
      });
      return items;
    },
    [offlineRef, pushLog]
  );

  // ---- Catálogos para el formulario (RF-02.1 / RF-02.2) ----
  const fetchCatalogos = useCallback(async () => {
    if (offlineRef.current) {
      pushLog({
        method: "GET",
        path: "/api/vehiculos?page=0&perPage=50",
        status: 0,
        note: "DioException.connectionError → catálogos no disponibles sin red",
      });
      throw new Error("offline");
    }
    await sleep(450);
    const db = dbRef.current;
    pushLog({
      method: "GET",
      path: "/api/vehiculos?page=0&perPage=50",
      status: 200,
      note: `catálogo → ${db?.vehiculos.length ?? 0} vehículos (cache Drift TTL 24h)`,
    });
    await sleep(250);
    pushLog({
      method: "GET",
      path: "/api/choferes?page=0&perPage=50",
      status: 200,
      note: `catálogo → ${db?.choferes.length ?? 0} choferes`,
    });
    await sleep(250);
    pushLog({
      method: "GET",
      path: "/api/tarjetas-combustible?page=0&perPage=50",
      status: 200,
      note: `catálogo → ${db?.tarjetas.length ?? 0} tarjetas (saldo visible en el selector)`,
    });
  }, [offlineRef, pushLog]);

  // ---- POST /api/recorridos (crear; offline → outbox, Gate F2) ----
  const createRecorrido = useCallback(
    async (payload: RecorridoPayload): Promise<MockRecorrido> => {
      const db = dbRef.current;
      if (!db) throw new Error("db no lista");
      const email = user?.email ?? "sistema@transporte.cu";

      if (offlineRef.current) {
        await sleep(650);
        pushLog({
          method: "POST",
          path: "/api/recorridos",
          status: 0,
          note: "DioException.connectionError → guardado en outbox local (FIFO)",
        });
        const localId = `local-${db.nextLocalId++}`;
        const rec: MockRecorrido = {
          ...payload,
          id: localId,
          odometroInicial: null, // los calcula el servidor al sincronizar
          combustibleInicial: null,
          consumo: null,
          activo: true,
          creadoPor: email,
          fechaCreacion: new Date().toISOString(),
          pendingSync: true,
        };
        db.recorridos.push(rec);
        outboxRef.current = [
          ...outboxRef.current,
          { localId, payload, creadoEn: rec.fechaCreacion },
        ];
        saveDb(db);
        saveOutbox(outboxRef.current);
        commit();
        return rec;
      }

      pushLog({
        method: "POST",
        path: "/api/recorridos",
        note: "RecorridoRequest { vehiculoId, choferId?, fecha, kilometros, abastecimiento? }",
      });
      await sleep(800);
      const veh = db.vehiculos.find((v) => v.id === payload.vehiculoId);
      if (!veh) throw new Error("vehículo inexistente");
      const rec: MockRecorrido = {
        ...payload,
        id: db.nextRecorridoId++,
        odometroInicial: veh.odometro,
        combustibleInicial: veh.combustible,
        consumo:
          (payload.litrosAbastecidos ?? 0) > 0
            ? round2(payload.kilometros / (payload.litrosAbastecidos as number))
            : null,
        activo: true,
        creadoPor: email,
        fechaCreacion: new Date().toISOString(),
        pendingSync: false,
      };
      db.recorridos.push(rec);
      // El servidor recalcula el estado del vehículo y descuenta la tarjeta.
      veh.odometro += payload.kilometros;
      veh.combustible = Math.max(
        0,
        round2(
          veh.combustible -
            payload.kilometros * veh.indiceConsumo +
            (payload.litrosAbastecidos ?? 0)
        )
      );
      if (payload.tarjetaId != null && (payload.importeAbastecido ?? 0) > 0) {
        const t = db.tarjetas.find((x) => x.id === payload.tarjetaId);
        if (t) t.saldo = round2(Math.max(0, t.saldo - (payload.importeAbastecido ?? 0)));
      }
      pushLog({
        method: "POST",
        path: "/api/recorridos",
        status: 200,
        note: `RecorridoResponse { id: ${rec.id}, odometroInicial: ${fmtInt(
          rec.odometroInicial as number
        )}, consumo: ${rec.consumo != null ? `${fmtDec(rec.consumo)} km/L` : "—"} } · continuidad de odómetro validada (R7)`,
      });
      saveDb(db);
      commit();
      return rec;
    },
    [commit, offlineRef, pushLog, user]
  );

  // ---- PUT /api/recorridos/{id} (editar; draft del outbox → solo local) ----
  const updateRecorrido = useCallback(
    async (id: RecorridoId, payload: RecorridoPayload): Promise<MockRecorrido> => {
      const db = dbRef.current;
      if (!db) throw new Error("db no lista");
      const rec = db.recorridos.find((r) => r.id === id);
      if (!rec) throw new Error("recorrido inexistente");

      if (rec.pendingSync) {
        await sleep(350);
        rec.vehiculoId = payload.vehiculoId;
        rec.choferId = payload.choferId;
        rec.fecha = payload.fecha;
        rec.kilometros = payload.kilometros;
        rec.litrosAbastecidos = payload.litrosAbastecidos;
        rec.numeroChip = payload.numeroChip;
        rec.lugarAbastecimiento = payload.lugarAbastecimiento;
        rec.tarjetaId = payload.tarjetaId;
        rec.importeAbastecido = payload.importeAbastecido;
        const entry = outboxRef.current.find((e) => e.localId === id);
        if (entry) entry.payload = payload;
        saveDb(db);
        saveOutbox(outboxRef.current);
        commit();
        pushLog({
          note: `outbox: draft actualizado localmente (${id} sigue pendiente de sync; no hay PUT)`,
        });
        return rec;
      }

      if (offlineRef.current) {
        pushLog({
          method: "PUT",
          path: `/api/recorridos/${id}`,
          status: 0,
          note: "DioException.connectionError → NetworkFailure (v1: solo la CREACIÓN se encola)",
        });
        throw new Error("offline");
      }

      pushLog({
        method: "PUT",
        path: `/api/recorridos/${id}`,
        note: "RecorridoRequest (edición)",
      });
      await sleep(750);
      const delta = payload.kilometros - rec.kilometros;
      rec.fecha = payload.fecha;
      rec.choferId = payload.choferId;
      rec.kilometros = payload.kilometros;
      rec.litrosAbastecidos = payload.litrosAbastecidos;
      rec.numeroChip = payload.numeroChip;
      rec.lugarAbastecimiento = payload.lugarAbastecimiento;
      rec.tarjetaId = payload.tarjetaId;
      rec.importeAbastecido = payload.importeAbastecido;
      rec.consumo =
        (payload.litrosAbastecidos ?? 0) > 0
          ? round2(payload.kilometros / (payload.litrosAbastecidos as number))
          : null;
      const veh = db.vehiculos.find((v) => v.id === payload.vehiculoId);
      if (veh && delta !== 0) veh.odometro = Math.max(0, veh.odometro + delta);
      pushLog({
        method: "PUT",
        path: `/api/recorridos/${id}`,
        status: 200,
        note: `200 OK — consumo recalculado${
          delta !== 0 ? ` · delta ${delta > 0 ? "+" : ""}${delta} km aplicado al odómetro` : ""
        }`,
      });
      saveDb(db);
      commit();
      return rec;
    },
    [commit, offlineRef, pushLog]
  );

  // ---- DELETE /api/recorridos/{id} (borrado lógico; R6 cuerpo vacío) ----
  const deleteRecorrido = useCallback(
    async (id: RecorridoId): Promise<void> => {
      const db = dbRef.current;
      if (!db) throw new Error("db no lista");
      const rec = db.recorridos.find((r) => r.id === id);
      if (!rec) throw new Error("recorrido inexistente");

      if (rec.pendingSync) {
        await sleep(300);
        db.recorridos = db.recorridos.filter((r) => r.id !== id);
        outboxRef.current = outboxRef.current.filter((e) => e.localId !== id);
        saveDb(db);
        saveOutbox(outboxRef.current);
        commit();
        pushLog({ note: `outbox: draft descartado (${id} eliminado de la cola FIFO)` });
        return;
      }

      if (offlineRef.current) {
        pushLog({
          method: "DELETE",
          path: `/api/recorridos/${id}`,
          status: 0,
          note: "DioException.connectionError → Reintentar (v1: solo la CREACIÓN se encola offline)",
        });
        throw new Error("offline");
      }

      await sleep(700);
      rec.activo = false; // borrado lógico → desaparece de las listas
      pushLog({
        method: "DELETE",
        path: `/api/recorridos/${id}`,
        status: 200,
        note: "200 sin cuerpo (R6: vacío = éxito) → borrado lógico activo=false",
      });
      saveDb(db);
      commit();
    },
    [commit, offlineRef, pushLog]
  );

  // ---- SyncManager v1 (2.5): vaciar el outbox FIFO contra el "servidor" ----
  const syncOutbox = useCallback(async () => {
    if (syncingRef.current || offlineRef.current) return;
    if (!dbRef.current || outboxRef.current.length === 0) return;
    syncingRef.current = true;
    setSyncing(true);
    pushLog({
      note: `SyncManager: ${outboxRef.current.length} recorrido(s) en el outbox → enviando FIFO…`,
    });
    await sleep(1200);
    let count = 0;
    while (outboxRef.current.length > 0) {
      const entry = outboxRef.current[0];
      const db = dbRef.current;
      const rec = db.recorridos.find((r) => r.id === entry.localId);
      const veh = db.vehiculos.find((v) => v.id === entry.payload.vehiculoId);
      if (rec && veh) {
        await sleep(600);
        const odometroAntes = veh.odometro;
        const nuevoId = db.nextRecorridoId++;
        rec.id = nuevoId;
        rec.pendingSync = false;
        rec.odometroInicial = veh.odometro;
        rec.combustibleInicial = veh.combustible;
        rec.consumo =
          (rec.litrosAbastecidos ?? 0) > 0
            ? round2(rec.kilometros / (rec.litrosAbastecidos as number))
            : null;
        veh.odometro += rec.kilometros;
        veh.combustible = Math.max(
          0,
          round2(
            veh.combustible - rec.kilometros * veh.indiceConsumo + (rec.litrosAbastecidos ?? 0)
          )
        );
        pushLog({
          method: "POST",
          path: "/api/recorridos",
          status: 200,
          note: `SyncManager FIFO: ${entry.localId} → id ${nuevoId} · odómetro ${fmtInt(
            odometroAntes
          )} → ${fmtInt(veh.odometro)}${
            rec.consumo != null ? ` · consumo ${fmtDec(rec.consumo)} km/L` : ""
          }`,
        });
        count++;
        saveDb(db);
        commit();
      }
      outboxRef.current = outboxRef.current.slice(1);
      saveOutbox(outboxRef.current);
      commit();
    }
    syncingRef.current = false;
    setSyncing(false);
    if (count > 0) {
      toast({
        title: `${count} recorrido(s) sincronizado(s)`,
        description: "Outbox FIFO vacío · odómetro y consumo calculados por el servidor",
      });
    }
  }, [commit, offlineRef, pushLog, toast]);

  // Auto-sync: al reconectar (offline true→false) y también al montar si hay
  // cola pendiente y hay red. El trabajo corre en un callback del timer.
  const prevOfflineRef = useRef<boolean | null>(null);
  useEffect(() => {
    const prev = prevOfflineRef.current;
    prevOfflineRef.current = offline;
    const shouldSync = prev === null ? !offline : prev && !offline;
    if (!shouldSync) return;
    const timer = setTimeout(() => void syncOutbox(), 1250);
    return () => clearTimeout(timer);
  }, [offline, syncOutbox]);

  const value: RecorridosContextValue = {
    db,
    outbox,
    syncing,
    offline,
    canTrips: caps.trips,
    canDelete: caps.fleet,
    assignedVehiculoId,
    fetchPage,
    fetchCatalogos,
    createRecorrido,
    updateRecorrido,
    deleteRecorrido,
    syncOutbox,
  };

  return <RecorridosContext.Provider value={value}>{children}</RecorridosContext.Provider>;
}

// ---------------------------------------------------------------------------
// Router de pantallas RF-02 (usado dentro del teléfono de la demo RF-01)
// ---------------------------------------------------------------------------

export type Rf02Screen = "recorridos" | "recorridoForm" | "recorridoDetail";

export function RecorridosScreen({
  screen,
  selectedId,
  onBackHome,
  onOpenDetail,
  onOpenForm,
  onBackToList,
}: {
  screen: string;
  selectedId: RecorridoId | null;
  onBackHome: () => void;
  onOpenDetail: (id: RecorridoId) => void;
  onOpenForm: (id: RecorridoId | null) => void;
  onBackToList: () => void;
}) {
  if (screen === "recorridos") {
    return (
      <RecorridosListView
        onBackHome={onBackHome}
        onOpenDetail={onOpenDetail}
        onNew={() => onOpenForm(null)}
      />
    );
  }
  if (screen === "recorridoForm") {
    return <RecorridoFormView editingId={selectedId} onBackToList={onBackToList} />;
  }
  if (screen === "recorridoDetail") {
    return (
      <RecorridoDetailView
        recorridoId={selectedId}
        onBackToList={onBackToList}
        onOpenForm={onOpenForm}
      />
    );
  }
  return null;
}

// ---------------------------------------------------------------------------
// Pantalla: Lista de recorridos (RF-02.4 / RF-02.7)
// ---------------------------------------------------------------------------

function RecorridosListView({
  onBackHome,
  onOpenDetail,
  onNew,
}: {
  onBackHome: () => void;
  onOpenDetail: (id: RecorridoId) => void;
  onNew: () => void;
}) {
  const ctx = useRecorridos();
  const db = ctx.db;
  const [status, setStatus] = useState<"loading" | "ready" | "error">("loading");
  const [visible, setVisible] = useState(5);
  const [loadingMore, setLoadingMore] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [vehiculoFilter, setVehiculoFilter] = useState("all");
  const [search, setSearch] = useState("");

  const filterNum = vehiculoFilter === "all" ? null : Number(vehiculoFilter);

  // Carga inicial (traza GET page=0) — en callback del timer.
  useEffect(() => {
    const timer = setTimeout(() => {
      void (async () => {
        try {
          await ctx.fetchPage(0, null);
          setStatus("ready");
        } catch {
          setStatus("error");
        }
      })();
    }, 60);
    return () => clearTimeout(timer);
  }, []);

  // Auto-recuperación (RF-02.4): si la lista quedó en error por red caída,
  // al reconectar se reintenta sola (una vez), sin esperar el click humano.
  const prevOfflineRef = useRef<boolean | null>(null);
  useEffect(() => {
    const prev = prevOfflineRef.current;
    prevOfflineRef.current = ctx.offline;
    if (prev !== true || ctx.offline) return;
    const timer = setTimeout(() => {
      void (async () => {
        try {
          await ctx.fetchPage(0, null);
          setStatus("ready");
        } catch {
          setStatus("error");
        }
      })();
    }, 1500);
    return () => clearTimeout(timer);
  }, [ctx.offline, ctx.fetchPage]);

  async function refresh() {
    setRefreshing(true);
    try {
      await ctx.fetchPage(0, filterNum);
      setStatus("ready");
      setVisible(5);
    } catch {
      setStatus("error");
    }
    setRefreshing(false);
  }

  function onFilterChange(v: string) {
    setVehiculoFilter(v);
    setVisible(5);
    setStatus("loading");
    void (async () => {
      try {
        await ctx.fetchPage(0, v === "all" ? null : Number(v));
        setStatus("ready");
      } catch {
        setStatus("error");
      }
    })();
  }

  async function loadMore() {
    setLoadingMore(true);
    try {
      await ctx.fetchPage(Math.floor(visible / 5), filterNum);
      setVisible((v) => v + 5);
    } catch {
      setStatus("error");
    }
    setLoadingMore(false);
  }

  // "Respuesta del servidor" (se reevalúa al sync/borrado para reflejar cambios)
  const serverItems = useMemo(() => {
    if (!db) return [];
    let items = sortRecorridos(db.recorridos.filter((r) => r.activo));
    if (filterNum != null) items = items.filter((r) => r.vehiculoId === filterNum);
    return items;
    // ctx.db cambia de identidad tras cada mutación (snapshot de estado)
  }, [ctx, filterNum, db]);

  const shown = serverItems.slice(0, visible);
  const q = search.trim().toLowerCase();
  const filtered = q
    ? shown.filter((r) => {
        const v = db?.vehiculos.find((x) => x.id === r.vehiculoId);
        return (
          (v?.matricula.toLowerCase().includes(q) ?? false) ||
          choferNombre(db as MockDb, r.choferId).toLowerCase().includes(q)
        );
      })
    : shown;

  return (
    <div className="relative flex h-full flex-col">
      <header className="flex items-center gap-2 border-b px-3 py-3">
        <button onClick={onBackHome} aria-label="Volver" className="rounded p-1 hover:bg-muted">
          <ArrowLeft className="h-4 w-4" />
        </button>
        <div className="flex-1">
          <h2 className="text-sm font-bold">Recorridos</h2>
          <p className="text-[10px] text-muted-foreground">
            {serverItems.length} registro(s) · fecha DESC
          </p>
        </div>
        <button
          onClick={() => void refresh()}
          aria-label="Actualizar (pull-to-refresh)"
          className="rounded p-2 text-muted-foreground hover:bg-muted hover:text-foreground"
        >
          <RefreshCw className={`h-4 w-4 ${refreshing ? "animate-spin" : ""}`} />
        </button>
      </header>

      {/* Banner de outbox pendiente (Gate F2) */}
      {ctx.outbox.length > 0 && (
        <div className="mx-3 mt-3 rounded-xl bg-amber-100 p-3 text-xs text-amber-900 dark:bg-amber-950/60 dark:text-amber-200">
          <div className="flex items-center gap-2">
            <AlertTriangle className="h-4 w-4 shrink-0" />
            <span className="flex-1 font-medium">
              {ctx.outbox.length} recorrido(s) pendiente(s) de sincronizar
              {ctx.syncing && (
                <span className="ml-1 inline-flex items-center gap-1 font-normal">
                  <Loader2 className="inline h-3 w-3 animate-spin" /> sincronizando…
                </span>
              )}
            </span>
            <Button
              size="sm"
              variant="outline"
              className="h-7 border-amber-300 px-2 text-[11px] dark:border-amber-800"
              disabled={ctx.syncing}
              onClick={() => void ctx.syncOutbox()}
            >
              Reintentar sincronización
            </Button>
          </div>
          <p className="mt-1 text-[10px] leading-relaxed opacity-70">
            v1 offline: solo la CREACIÓN se encola (FIFO). Editar/eliminar recorridos ya
            sincronizados requiere conexión.
          </p>
        </div>
      )}

      {/* Filtros (RF-02.7) */}
      <div className="space-y-2 px-3 pt-3">
        <Select value={vehiculoFilter} onValueChange={onFilterChange}>
          <SelectTrigger aria-label="Filtrar por vehículo" className="w-full">
            <SelectValue placeholder="Todos los vehículos" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Todos los vehículos</SelectItem>
            {(db?.vehiculos ?? [])
              .filter((v) => v.activo)
              .map((v) => (
                <SelectItem key={v.id} value={String(v.id)}>
                  {v.matricula} · {v.marcaNombre} {v.modelo}
                </SelectItem>
              ))}
          </SelectContent>
        </Select>
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
          <Input
            id="rf02-search"
            aria-label="Búsqueda rápida por matrícula o chofer"
            placeholder="Buscar por matrícula o chofer…"
            className="h-9 pl-8 text-xs"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>

      <ScrollArea className="flex-1 px-3 pb-24 pt-3">
        <div className="space-y-2">
          {status === "loading" && (
            <>
              <Skeleton className="h-[74px] w-full rounded-xl" />
              <Skeleton className="h-[74px] w-full rounded-xl" />
              <Skeleton className="h-[74px] w-full rounded-xl" />
            </>
          )}

          {status === "error" && (
            <div className="flex flex-col items-center gap-3 rounded-xl border border-red-200 bg-red-50 p-6 text-center dark:border-red-900 dark:bg-red-950/40">
              <CloudOff className="h-8 w-8 text-red-500" />
              <p className="text-xs text-muted-foreground">
                Sin conexión con el servidor. No se pudo cargar el historial.
              </p>
              <Button size="sm" onClick={() => void refresh()}>
                Reintentar
              </Button>
            </div>
          )}

          {status === "ready" && filtered.length === 0 && (
            <div className="flex flex-col items-center gap-2 rounded-xl border border-dashed p-8 text-center">
              <Route className="h-8 w-8 text-muted-foreground" />
              <p className="text-sm font-medium">
                {q ? "Sin resultados para la búsqueda" : "Aún no hay recorridos registrados"}
              </p>
              <p className="text-xs text-muted-foreground">
                {q
                  ? "Prueba con otra matrícula o nombre de chofer."
                  : "Pulsa «+ Nuevo» para registrar el primero."}
              </p>
            </div>
          )}

          {status === "ready" &&
            filtered.map((r) => {
              const v = db?.vehiculos.find((x) => x.id === r.vehiculoId);
              return (
                <button
                  key={String(r.id)}
                  onClick={() => onOpenDetail(r.id)}
                  className="block w-full rounded-xl border bg-card p-3 text-left transition-colors hover:bg-muted/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-600"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="flex items-center gap-1.5 text-sm font-semibold">
                      {fmtFecha(r.fecha)}
                      {(r.litrosAbastecidos ?? 0) > 0 && (
                        <Fuel className="h-3.5 w-3.5 text-teal-700 dark:text-teal-400" aria-label="Con abastecimiento" />
                      )}
                    </span>
                    <ChevronRight className="h-4 w-4 text-muted-foreground" />
                  </div>
                  <div className="mt-1 flex items-center justify-between gap-2 text-xs">
                    <span className="min-w-0 truncate">
                      <span className="font-mono font-semibold">{v?.matricula ?? "—"}</span>
                      <span className="text-muted-foreground">
                        {" "}
                        · {choferNombre(db as MockDb, r.choferId)}
                      </span>
                    </span>
                    <span className="shrink-0 font-medium">{fmtInt(r.kilometros)} km</span>
                  </div>
                  {r.pendingSync && (
                    <div className="mt-1.5 flex items-center gap-1.5">
                      <Badge className="h-5 bg-amber-100 px-1.5 text-[10px] text-amber-800 dark:bg-amber-950 dark:text-amber-300">
                        Pendiente de sync
                      </Badge>
                      <span className="font-mono text-[10px] text-muted-foreground">{r.id}</span>
                    </div>
                  )}
                </button>
              );
            })}

          {status === "ready" && visible < serverItems.length && (
            <Button variant="outline" className="w-full" onClick={() => void loadMore()} disabled={loadingMore}>
              {loadingMore ? <Loader2 className="mr-1 h-4 w-4 animate-spin" /> : null}
              Cargar más ({serverItems.length - visible} restante(s))
            </Button>
          )}
        </div>
      </ScrollArea>

      {/* FAB «+ Nuevo» (solo con capabilities.trips) */}
      {ctx.canTrips && (
        <button
          onClick={onNew}
          aria-label="Nuevo recorrido"
          title="Nuevo recorrido"
          className="absolute bottom-4 right-4 flex h-14 w-14 items-center justify-center rounded-full bg-teal-700 text-white shadow-lg transition-transform hover:scale-105 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-600 focus-visible:ring-offset-2"
        >
          <Plus className="h-6 w-6" />
        </button>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Pantalla: Formulario (RF-02.1 / RF-02.2 / RF-02.3)
// ---------------------------------------------------------------------------

function RecorridoFormView({
  editingId,
  onBackToList,
}: {
  editingId: RecorridoId | null;
  onBackToList: () => void;
}) {
  const ctx = useRecorridos();
  const db = ctx.db;
  const { toast } = useToast();
  const editing =
    editingId != null && db ? db.recorridos.find((r) => r.id === editingId) ?? null : null;
  const isEdit = editing != null;

  const [catStatus, setCatStatus] = useState<"loading" | "ready">("loading");
  // Sin red los catálogos se sirven desde la caché local (Drift TTL 24h) — igual
  // que el APK real, para que la creación offline (Gate F2) sea posible.
  const [catDesdeCache, setCatDesdeCache] = useState(false);
  const [vehiculoId, setVehiculoId] = useState(() => {
    if (editing) return String(editing.vehiculoId);
    return ctx.assignedVehiculoId != null ? String(ctx.assignedVehiculoId) : "";
  });
  const [choferId, setChoferId] = useState(() => {
    if (editing) return String(editing.choferId ?? "none");
    const veh = db?.vehiculos.find((v) => v.id === ctx.assignedVehiculoId);
    return veh?.choferId != null ? String(veh.choferId) : "none";
  });
  const [fecha, setFecha] = useState(() => (editing ? editing.fecha : hoyIso()));
  const [km, setKm] = useState(() => (editing ? String(editing.kilometros) : ""));
  const [fuelOn, setFuelOn] = useState(() =>
    editing ? editing.litrosAbastecidos != null || editing.importeAbastecido != null : false
  );
  const [litros, setLitros] = useState(() =>
    editing?.litrosAbastecidos != null ? String(editing.litrosAbastecidos) : ""
  );
  const [chip, setChip] = useState(() => editing?.numeroChip ?? "");
  const [lugar, setLugar] = useState(() => editing?.lugarAbastecimiento ?? "");
  const [tarjetaId, setTarjetaId] = useState(() => String(editing?.tarjetaId ?? "none"));
  const [importe, setImporte] = useState(() =>
    editing?.importeAbastecido != null ? String(editing.importeAbastecido) : ""
  );
  const [errors, setErrors] = useState<Record<string, string | undefined>>({});
  const [submitting, setSubmitting] = useState(false);

  // Catálogos al abrir el formulario (traza GET ×3) — callback del timer.
  useEffect(() => {
    const timer = setTimeout(() => {
      void (async () => {
        try {
          await ctx.fetchCatalogos();
          setCatDesdeCache(false);
        } catch {
          setCatDesdeCache(true);
        }
        setCatStatus("ready");
      })();
    }, 60);
    return () => clearTimeout(timer);
  }, []);

  const veh = db?.vehiculos.find((v) => v.id === Number(vehiculoId));
  const kmNum = Number(km);
  const kmValido = km.trim() !== "" && Number.isInteger(kmNum) && kmNum >= 1;
  const odometroPrevisto = veh && kmValido ? veh.odometro + kmNum : null;
  // RF-02.3 / R7: advertencia si los km difieren fuertemente del uso esperado.
  const kmWarning =
    veh && kmValido && (kmNum >= 1000 || kmNum >= veh.odometro);
  const tarjeta = db?.tarjetas.find((t) => t.id === Number(tarjetaId));
  const importeNum = Number(importe || 0);
  const saldoWarning =
    fuelOn && tarjeta != null && importe.trim() !== "" && !Number.isNaN(importeNum) && importeNum > tarjeta.saldo;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    // Validación inline (RF-02.3, espejo de Validators.dart / use case)
    const errs: Record<string, string> = {};
    if (!vehiculoId) errs.vehiculo = "Seleccione un vehículo.";
    if (!fecha) errs.fecha = "La fecha es obligatoria.";
    else if (fecha > hoyIso()) errs.fecha = "La fecha no puede ser posterior a hoy.";
    if (!kmValido) errs.km = "Los kilómetros deben ser un entero ≥ 1.";
    if (fuelOn) {
      const litNum = Number(litros);
      if (litros.trim() === "" || Number.isNaN(litNum) || litNum < 0)
        errs.litros = "Los litros deben ser ≥ 0.";
      if (chip.length > 50) errs.chip = "Máximo 50 caracteres.";
      if (lugar.length > 100) errs.lugar = "Máximo 100 caracteres.";
      if (importe.trim() !== "" && (Number.isNaN(importeNum) || importeNum < 0))
        errs.importe = "El importe debe ser ≥ 0.";
    }
    setErrors(errs);
    if (Object.keys(errs).length > 0) return;

    const payload: RecorridoPayload = {
      vehiculoId: Number(vehiculoId),
      choferId: choferId === "none" ? undefined : Number(choferId),
      fecha,
      kilometros: kmNum,
      ...(fuelOn && litros.trim() !== "" && Number(litros) > 0
        ? { litrosAbastecidos: Number(litros) }
        : {}),
      ...(fuelOn && chip.trim() !== "" ? { numeroChip: chip.trim() } : {}),
      ...(fuelOn && lugar.trim() !== "" ? { lugarAbastecimiento: lugar.trim() } : {}),
      ...(fuelOn && tarjetaId !== "none" ? { tarjetaId: Number(tarjetaId) } : {}),
      ...(fuelOn && importe.trim() !== "" && Number(importe) > 0
        ? { importeAbastecido: Number(importe) }
        : {}),
    };

    setSubmitting(true);
    try {
      if (isEdit && editing) {
        const rec = await ctx.updateRecorrido(editing.id, payload);
        if (rec.pendingSync) {
          toast({ title: "Borrador offline actualizado", description: "El draft vive en el outbox local" });
        } else {
          toast({ title: "Recorrido actualizado", description: `PUT /api/recorridos/${rec.id} → 200` });
        }
      } else {
        const rec = await ctx.createRecorrido(payload);
        if (rec.pendingSync) {
          toast({
            title: "Guardado en el outbox",
            description: `${rec.id} se sincronizará al reconectar (badge pendiente)`,
          });
        } else {
          toast({
            title: "Recorrido registrado",
            description: `id ${rec.id} · odómetro del vehículo actualizado`,
          });
        }
      }
      onBackToList();
    } catch {
      // status 0 ya quedó en la traza; el flujo offline de creación nunca lanza.
      setErrors({ km: "Error de red al guardar. Revise la traza de API." });
    }
    setSubmitting(false);
  }

  const inputErr = (k: string) => (errors[k] ? "border-red-500 focus-visible:ring-red-300" : "");

  return (
    <div className="flex h-full flex-col">
      <header className="flex items-center gap-2 border-b px-3 py-3">
        <button onClick={onBackToList} aria-label="Volver" className="rounded p-1 hover:bg-muted">
          <ArrowLeft className="h-4 w-4" />
        </button>
        <h2 className="flex-1 text-sm font-bold">{isEdit ? "Editar recorrido" : "Nuevo recorrido"}</h2>
        {isEdit && (
          <Badge variant="outline" className="font-mono text-[10px]">
            {String(editing.id)}
          </Badge>
        )}
      </header>

      {catStatus === "loading" && (
        <div className="space-y-3 p-4">
          <Skeleton className="h-14 w-full rounded-xl" />
          <Skeleton className="h-14 w-full rounded-xl" />
          <Skeleton className="h-14 w-full rounded-xl" />
          <p className="text-center text-xs text-muted-foreground">Cargando catálogos…</p>
        </div>
      )}

      {catStatus === "ready" && catDesdeCache && (
        <div className="mx-4 mt-2 flex items-start gap-2 rounded-xl bg-amber-100 p-2.5 text-[11px] leading-relaxed text-amber-900 dark:bg-amber-950/60 dark:text-amber-200">
          <CloudOff className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          Sin conexión: catálogos servidos desde la caché local (Drift TTL 24h). El registro se
          guardará en el outbox.
        </div>
      )}

      {catStatus === "ready" && (
        <form onSubmit={submit} className="flex-1 space-y-3 overflow-y-auto px-4 py-3">
          {/* Vehículo */}
          <div className="space-y-1.5">
            <Label htmlFor="rf02-vehiculo">Vehículo</Label>
            <Select
              value={vehiculoId || undefined}
              onValueChange={(v) => {
                setVehiculoId(v);
                setErrors((f) => ({ ...f, vehiculo: undefined }));
                // selectores dependientes (vehículo → chofer asignado)
                const nv = db?.vehiculos.find((x) => x.id === Number(v));
                setChoferId(nv?.choferId != null ? String(nv.choferId) : "none");
              }}
            >
              <SelectTrigger
                id="rf02-vehiculo"
                aria-invalid={!!errors.vehiculo}
                className={`w-full ${inputErr("vehiculo")}`}
              >
                <SelectValue placeholder="Seleccione un vehículo" />
              </SelectTrigger>
              <SelectContent>
                {(db?.vehiculos ?? [])
                  .filter((v) => v.activo)
                  .map((v) => (
                    <SelectItem key={v.id} value={String(v.id)}>
                      {v.matricula} · {v.marcaNombre} {v.modelo}
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
            {veh && (
              <p className="text-[11px] text-muted-foreground">
                Odómetro: {fmtInt(veh.odometro)} km · {veh.tipoCombustibleNombre} · tanque{" "}
                {fmtDec(veh.combustible)} L
              </p>
            )}
            {errors.vehiculo && <p className="text-xs text-red-600 dark:text-red-400">{errors.vehiculo}</p>}
          </div>

          {/* Chofer */}
          <div className="space-y-1.5">
            <Label htmlFor="rf02-chofer">Chofer</Label>
            <Select value={choferId} onValueChange={setChoferId}>
              <SelectTrigger id="rf02-chofer" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">Sin chofer</SelectItem>
                {(db?.choferes ?? [])
                  .filter((c) => c.activo)
                  .map((c) => (
                    <SelectItem key={c.id} value={String(c.id)}>
                      {c.nombre} {c.apellidos} · {c.numeroLicencia}
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
          </div>

          {/* Fecha */}
          <div className="space-y-1.5">
            <Label htmlFor="rf02-fecha">Fecha (máx. hoy)</Label>
            <Input
              id="rf02-fecha"
              type="date"
              value={fecha}
              max={hoyIso()}
              aria-invalid={!!errors.fecha}
              className={inputErr("fecha")}
              onChange={(e) => {
                setFecha(e.target.value);
                setErrors((f) => ({ ...f, fecha: undefined }));
              }}
            />
            {errors.fecha && <p className="text-xs text-red-600 dark:text-red-400">{errors.fecha}</p>}
          </div>

          {/* Kilómetros + hint vivo + advertencia R7 */}
          <div className="space-y-1.5">
            <Label htmlFor="rf02-km">Kilómetros recorridos</Label>
            <Input
              id="rf02-km"
              type="number"
              min={1}
              step={1}
              placeholder="Ej: 120"
              value={km}
              aria-invalid={!!errors.km}
              className={inputErr("km")}
              onChange={(e) => {
                setKm(e.target.value);
                setErrors((f) => ({ ...f, km: undefined }));
              }}
            />
            {odometroPrevisto != null && veh && (
              <p className="text-[11px] text-teal-700 dark:text-teal-400">
                Odómetro tras registrar: {fmtInt(odometroPrevisto)} km
              </p>
            )}
            {kmWarning && (
              <div className="flex items-start gap-2 rounded-lg bg-amber-100 p-2 text-[11px] leading-relaxed text-amber-900 dark:bg-amber-950/60 dark:text-amber-200">
                <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
                Los km difieren fuertemente del uso esperado. El servidor valida la continuidad
                del odómetro.
              </div>
            )}
            {errors.km && <p className="text-xs text-red-600 dark:text-red-400">{errors.km}</p>}
          </div>

          {/* Abastecimiento opcional (RF-02.2) */}
          <div className="rounded-xl border p-3">
            <label className="flex items-center justify-between gap-3 text-sm">
              <span>
                <span className="font-medium">Abastecimiento</span>
                <span className="block text-[11px] text-muted-foreground">
                  Opcional: combustible, chip, lugar, tarjeta e importe
                </span>
              </span>
              <Switch checked={fuelOn} onCheckedChange={setFuelOn} aria-label="Registrar abastecimiento" />
            </label>

            {fuelOn && (
              <div className="mt-3 space-y-3 border-t pt-3">
                <div className="space-y-1.5">
                  <Label htmlFor="rf02-litros">Litros abastecidos (≥ 0)</Label>
                  <Input
                    id="rf02-litros"
                    type="number"
                    min={0}
                    step="0.1"
                    placeholder="Ej: 12.5"
                    value={litros}
                    aria-invalid={!!errors.litros}
                    className={inputErr("litros")}
                    onChange={(e) => {
                      setLitros(e.target.value);
                      setErrors((f) => ({ ...f, litros: undefined }));
                    }}
                  />
                  {errors.litros && <p className="text-xs text-red-600 dark:text-red-400">{errors.litros}</p>}
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="rf02-chip">Nº de chip (máx. 50)</Label>
                  <Input
                    id="rf02-chip"
                    maxLength={50}
                    placeholder="Ej: CH-8841"
                    value={chip}
                    aria-invalid={!!errors.chip}
                    className={inputErr("chip")}
                    onChange={(e) => {
                      setChip(e.target.value);
                      setErrors((f) => ({ ...f, chip: undefined }));
                    }}
                  />
                  {errors.chip && <p className="text-xs text-red-600 dark:text-red-400">{errors.chip}</p>}
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="rf02-lugar">Lugar de abastecimiento (máx. 100)</Label>
                  <Input
                    id="rf02-lugar"
                    maxLength={100}
                    placeholder="Ej: CUPET 23 y L"
                    value={lugar}
                    aria-invalid={!!errors.lugar}
                    className={inputErr("lugar")}
                    onChange={(e) => {
                      setLugar(e.target.value);
                      setErrors((f) => ({ ...f, lugar: undefined }));
                    }}
                  />
                  {errors.lugar && <p className="text-xs text-red-600 dark:text-red-400">{errors.lugar}</p>}
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="rf02-tarjeta">Tarjeta de combustible</Label>
                  <Select value={tarjetaId} onValueChange={setTarjetaId}>
                    <SelectTrigger id="rf02-tarjeta" className="w-full">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="none">Sin tarjeta</SelectItem>
                      {(db?.tarjetas ?? [])
                        .filter((t) => t.activo)
                        .map((t) => (
                          <SelectItem key={t.id} value={String(t.id)}>
                            {t.numero} · {fmtDec(t.saldo)} {t.isoCode}
                          </SelectItem>
                        ))}
                    </SelectContent>
                  </Select>
                  {saldoWarning && tarjeta && (
                    <p className="text-[11px] leading-relaxed text-amber-600 dark:text-amber-400">
                      El importe supera el saldo de la tarjeta ({fmtDec(tarjeta.saldo)}{" "}
                      {tarjeta.isoCode}). Advertencia suave: no bloquea el envío.
                    </p>
                  )}
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="rf02-importe">Importe (≥ 0)</Label>
                  <Input
                    id="rf02-importe"
                    type="number"
                    min={0}
                    step="0.01"
                    placeholder="Ej: 3500"
                    value={importe}
                    aria-invalid={!!errors.importe}
                    className={inputErr("importe")}
                    onChange={(e) => {
                      setImporte(e.target.value);
                      setErrors((f) => ({ ...f, importe: undefined }));
                    }}
                  />
                  {errors.importe && (
                    <p className="text-xs text-red-600 dark:text-red-400">{errors.importe}</p>
                  )}
                </div>
              </div>
            )}
          </div>

          {ctx.offline && !isEdit && (
            <p className="rounded-lg bg-muted p-2 text-[11px] leading-relaxed text-muted-foreground">
              Sin conexión: el recorrido se guardará en el outbox local (FIFO) con badge
              «Pendiente de sync» y se sincronizará al reconectar.
            </p>
          )}
          {ctx.offline && isEdit && editing?.pendingSync && (
            <p className="rounded-lg bg-muted p-2 text-[11px] leading-relaxed text-muted-foreground">
              Sin conexión: solo se actualizará el draft local del outbox (sin llamada PUT).
            </p>
          )}

          <Button type="submit" className="h-12 w-full font-semibold" disabled={submitting}>
            {submitting ? (
              <Loader2 className="h-5 w-5 animate-spin" />
            ) : isEdit ? (
              "Guardar cambios"
            ) : (
              "Registrar recorrido"
            )}
          </Button>
        </form>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Pantalla: Detalle (RF-02.5 / RF-02.6) — datos calculados por el servidor
// ---------------------------------------------------------------------------

function RecorridoDetailView({
  recorridoId,
  onBackToList,
  onOpenForm,
}: {
  recorridoId: RecorridoId | null;
  onBackToList: () => void;
  onOpenForm: (id: RecorridoId | null) => void;
}) {
  const ctx = useRecorridos();
  const db = ctx.db;
  const { toast } = useToast();
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState(false);
  const rec = db?.recorridos.find((r) => r.id === recorridoId) ?? null;

  async function confirmDelete() {
    if (!rec) return;
    setDeleting(true);
    setDeleteError(false);
    try {
      await ctx.deleteRecorrido(rec.id);
      toast({
        title: "Recorrido eliminado",
        description: "Borrado lógico (activo=false) · desaparece de las listas",
      });
      onBackToList();
    } catch {
      setDeleteError(true);
    }
    setDeleting(false);
  }

  if (!db || !rec) {
    return (
      <div className="flex h-full flex-col">
        <header className="flex items-center gap-2 border-b px-3 py-3">
          <button onClick={onBackToList} aria-label="Volver" className="rounded p-1 hover:bg-muted">
            <ArrowLeft className="h-4 w-4" />
          </button>
          <h2 className="flex-1 text-sm font-bold">Detalle del recorrido</h2>
        </header>
        <div className="flex flex-1 flex-col items-center justify-center gap-2 p-6 text-center">
          <Route className="h-8 w-8 text-muted-foreground" />
          <p className="text-xs text-muted-foreground">Recorrido no encontrado (¿eliminado?).</p>
        </div>
      </div>
    );
  }

  const veh = db.vehiculos.find((v) => v.id === rec.vehiculoId);
  const tarjeta = db.tarjetas.find((t) => t.id === rec.tarjetaId);

  const row = (label: string, value: React.ReactNode) => (
    <div className="flex items-start justify-between gap-3 text-xs">
      <span className="shrink-0 text-muted-foreground">{label}</span>
      <span className="text-right font-medium">{value}</span>
    </div>
  );

  return (
    <div className="flex h-full flex-col">
      <header className="flex items-center gap-2 border-b px-3 py-3">
        <button onClick={onBackToList} aria-label="Volver" className="rounded p-1 hover:bg-muted">
          <ArrowLeft className="h-4 w-4" />
        </button>
        <h2 className="flex-1 text-sm font-bold">Detalle del recorrido</h2>
        <Badge variant="outline" className="font-mono text-[10px]">
          {String(rec.id)}
        </Badge>
      </header>

      <div className="flex-1 space-y-3 overflow-y-auto px-4 py-3">
        {rec.pendingSync && (
          <div className="rounded-xl bg-amber-100 p-3 text-xs text-amber-900 dark:bg-amber-950/60 dark:text-amber-200">
            <p className="flex items-center gap-2 font-medium">
              <AlertTriangle className="h-4 w-4 shrink-0" /> Pendiente de sync — está en el outbox
              local ({String(rec.id)}).
            </p>
            <p className="mt-1 leading-relaxed opacity-80">
              Los datos calculados (odómetro inicial, combustible, consumo) los completará el
              servidor al sincronizar.
            </p>
          </div>
        )}

        <div className="space-y-2 rounded-xl border p-3">
          {row("Fecha", fmtFecha(rec.fecha))}
          {row(
            "Vehículo",
            veh ? (
              <span>
                <span className="font-mono">{veh.matricula}</span> · {veh.marcaNombre} {veh.modelo}
                <span className="block text-[10px] text-muted-foreground">
                  {veh.tipoVehiculoNombre} · {veh.tipoCombustibleNombre} · odómetro{" "}
                  {fmtInt(veh.odometro)} km
                </span>
              </span>
            ) : (
              "—"
            )
          )}
          {row("Chofer", choferNombre(db, rec.choferId))}
          {row("Kilómetros", <span className="text-sm font-bold">{fmtInt(rec.kilometros)} km</span>)}
        </div>

        {/* Datos calculados por el servidor (RF-02.5) */}
        <div className="space-y-2 rounded-xl border border-teal-700/40 bg-teal-700/5 p-3 dark:border-teal-400/40 dark:bg-teal-400/5">
          <p className="flex items-center gap-1.5 text-xs font-bold text-teal-800 dark:text-teal-300">
            <CheckCircle2 className="h-3.5 w-3.5" /> Datos calculados por el servidor
          </p>
          {row(
            "Odómetro inicial",
            rec.odometroInicial != null ? `${fmtInt(rec.odometroInicial)} km` : "— (pendiente de sync)"
          )}
          {row(
            "Combustible inicial",
            rec.combustibleInicial != null ? `${fmtDec(rec.combustibleInicial)} L` : "— (pendiente de sync)"
          )}
          {row(
            "Consumo",
            rec.consumo != null ? `${fmtDec(rec.consumo)} km/L` : "— (solo con abastecimiento)"
          )}
        </div>

        {(rec.litrosAbastecidos != null || rec.importeAbastecido != null) && (
          <div className="space-y-2 rounded-xl border p-3">
            <p className="flex items-center gap-1.5 text-xs font-bold">
              <Fuel className="h-3.5 w-3.5 text-teal-700 dark:text-teal-400" /> Abastecimiento
            </p>
            {rec.litrosAbastecidos != null && row("Litros", `${fmtDec(rec.litrosAbastecidos)} L`)}
            {rec.numeroChip && row("Nº de chip", <span className="font-mono">{rec.numeroChip}</span>)}
            {rec.lugarAbastecimiento && row("Lugar", rec.lugarAbastecimiento)}
            {row(
              "Tarjeta",
              tarjeta
                ? `${tarjeta.numero} · saldo ${fmtDec(tarjeta.saldo)} ${tarjeta.isoCode}`
                : "Sin tarjeta"
            )}
            {rec.importeAbastecido != null && row("Importe", `${fmtDec(rec.importeAbastecido)}`)}
          </div>
        )}

        <div className="space-y-2 rounded-xl border p-3">
          <p className="text-xs font-bold">Auditoría</p>
          {row("Creado por", <span className="font-mono text-[11px]">{rec.creadoPor}</span>)}
          {row("Fecha de creación", fmtDateTime(rec.fechaCreacion))}
        </div>

        {deleteError && (
          <div className="flex items-start gap-2 rounded-xl bg-red-100 p-3 text-xs text-red-900 dark:bg-red-950/60 dark:text-red-200">
            <CloudOff className="mt-0.5 h-4 w-4 shrink-0" />
            <span className="flex-1">
              Sin conexión: no se pudo eliminar. En v1 solo la CREACIÓN se encola offline.
            </span>
            <Button size="sm" variant="outline" className="h-7 px-2 text-[11px]" onClick={() => void confirmDelete()}>
              Reintentar
            </Button>
          </div>
        )}

        <div className="flex gap-2 pt-1">
          <Button
            variant="outline"
            className="h-11 flex-1"
            onClick={() => onOpenForm(rec.id)}
            disabled={deleting}
          >
            <Pencil className="mr-1 h-4 w-4" /> Editar
          </Button>
          {ctx.canDelete ? (
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <Button variant="destructive" className="h-11 flex-1" disabled={deleting}>
                  {deleting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="mr-1 h-4 w-4" />}
                  Eliminar
                </Button>
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>¿Eliminar este recorrido?</AlertDialogTitle>
                  <AlertDialogDescription>
                    El backend realiza un borrado lógico (activo=false): el registro desaparece de
                    las listas pero se conserva para auditoría. La traza mostrará{" "}
                    <span className="font-mono">DELETE /api/recorridos/{String(rec.id)}</span>.
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Cancelar</AlertDialogCancel>
                  <AlertDialogAction onClick={() => void confirmDelete()}>Eliminar</AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          ) : (
            <p className="flex flex-1 items-center text-[11px] leading-relaxed text-muted-foreground">
              Como CHOFER puedes crear y editar recorridos, pero no eliminarlos (RF-02.6).
            </p>
          )}
        </div>
        <p className="pb-2 text-[10px] leading-relaxed text-muted-foreground">
          v1 offline: solo la creación se encola en el outbox; eliminar sin conexión muestra error
          con Reintentar.
        </p>
      </div>
    </div>
  );
}
