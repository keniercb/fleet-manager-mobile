"use client";

/**
 * Demo interactiva del RF-01 · Autenticación y sesión.
 *
 * Replica 1:1 la máquina de estados de `session_controller.dart` y el
 * comportamiento de `auth_interceptor.dart`, con una API simulada que
 * registra cada "request" (mismo formato que el backend real) para poder
 * evaluar el flujo paso a paso en el preview.
 */

import { useCallback, useEffect, useRef, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Switch } from "@/components/ui/switch";
import { useToast } from "@/hooks/use-toast";
import {
  AlertTriangle,
  ArrowLeft,
  CheckCircle2,
  ChevronRight,
  CloudOff,
  Eye,
  EyeOff,
  Info,
  KeyRound,
  Loader2,
  Lock,
  LockOpen,
  LogOut,
  RefreshCw,
  Route,
  Truck,
  User,
  Users,
  Zap,
} from "lucide-react";

// ---------------------------------------------------------------------------
// Modelo (espejo de las entidades Dart)
// ---------------------------------------------------------------------------

type Screen = "splash" | "login" | "home" | "profile" | "changePassword";
type Reason = "initial" | "loggedOut" | "expired";
type SessionKind =
  | "unknown"
  | "bootstrapping"
  | "authenticated"
  | "unauthenticated"
  | "bootstrapError";

interface MockUser {
  id: number;
  email: string;
  activo: boolean;
  empresa: { id: number; codigo: string; nombre: string };
  roles: { id: number; name: string; description: string }[];
}

interface Session {
  kind: SessionKind;
  reason?: Reason;
  error?: string;
  user?: MockUser;
}

interface ApiLog {
  id: number;
  method?: string;
  path?: string;
  status?: number;
  note?: string;
}

const TOKEN_KEY = "rf01_demo_token";

const USERS: Record<string, { password: string; user: MockUser }> = {
  "admin@transporte.cu": {
    password: "password123",
    user: {
      id: 1,
      email: "admin@transporte.cu",
      activo: true,
      empresa: { id: 3, codigo: "EMP-003", nombre: "Transporte Capital S.A." },
      roles: [
        { id: 1, name: "ADMIN_EMPRESA", description: "Administrador de la empresa" },
        { id: 2, name: "JEFE_TRANSPORTE", description: "Jefe de transporte" },
      ],
    },
  },
  "chofer@transporte.cu": {
    password: "password123",
    user: {
      id: 7,
      email: "chofer@transporte.cu",
      activo: true,
      empresa: { id: 3, codigo: "EMP-003", nombre: "Transporte Capital S.A." },
      roles: [{ id: 5, name: "CHOFER", description: "Conductor operativo" }],
    },
  },
};

/** Espejo de UserCapabilities.fromUser (fail-open documentado). */
function capabilities(user: MockUser) {
  const names = user.roles.map((r) => r.name.toLowerCase());
  const known = names.some((n) =>
    ["admin", "jefe", "supervisor", "chofer", "driver"].some((k) => n.includes(k))
  );
  if (known === false) {
    return { trips: true, fleet: true, reports: true, admin: false };
  }
  const admin = names.some((n) => n.includes("admin") || n.includes("gerente"));
  const supervisor = names.some((n) => n.includes("jefe") || n.includes("supervisor"));
  const chofer = names.some((n) => n.includes("chofer") || n.includes("driver"));
  return {
    trips: admin || supervisor || chofer,
    fleet: admin || supervisor,
    reports: admin || supervisor,
    admin,
  };
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

const SESSION_LABEL: Record<SessionKind, string> = {
  unknown: "SessionUnknown",
  bootstrapping: "SessionBootstrapping",
  authenticated: "SessionAuthenticated",
  unauthenticated: "SessionUnauthenticated",
  bootstrapError: "SessionBootstrapError",
};

const REASON_LABEL: Record<Reason, string> = {
  initial: "initial (primer arranque)",
  loggedOut: "loggedOut (logout OK)",
  expired: "expired (401 del backend)",
};

// ---------------------------------------------------------------------------
// Componente
// ---------------------------------------------------------------------------

export function Rf01PhoneDemo() {
  const { toast } = useToast();

  const [screen, setScreen] = useState<Screen>("splash");
  const [session, setSession] = useState<Session>({ kind: "unknown" });
  const [token, setToken] = useState<string | null>(null);
  const [logs, setLogs] = useState<ApiLog[]>([]);
  const [offline, setOfflineState] = useState(false);
  const [banner, setBanner] = useState<{
    msg: string;
    kind: "warning" | "success" | "info";
  } | null>(null);

  const logIdRef = useRef(1);
  const offlineRef = useRef(false);
  const usersRef = useRef(USERS);

  /** Persiste el escenario offline para que sobreviva a recargas de la demo. */
  const setOffline = useCallback((value: boolean) => {
    setOfflineState(value);
    offlineRef.current = value;
    localStorage.setItem("rf01_offline", value ? "1" : "0");
  }, []);

  const pushLog = useCallback((entry: Omit<ApiLog, "id">) => {
    setLogs((prev) => [
      ...prev.slice(-60),
      { ...entry, id: logIdRef.current++ },
    ]);
  }, []);

  // bootstrap() — espejo de SessionController.bootstrap (RF-01.2 / RF-01.3)
  const bootstrap = useCallback(async () => {
    setBanner(null);
    setSession({ kind: "bootstrapping" });
    setScreen("splash");
    await sleep(1000);

    const stored = localStorage.getItem(TOKEN_KEY);
    if (!stored) {
      pushLog({ note: "bootstrap: secure_storage sin token → login" });
      setSession({ kind: "unauthenticated", reason: "initial" });
      setScreen("login");
      return;
    }

    if (offlineRef.current) {
      pushLog({
        method: "GET",
        path: "/api/auth/me",
        status: 0,
        note: "DioException.connectionError (simulado) → SessionBootstrapError (token NO se borra)",
      });
      setSession({
        kind: "bootstrapError",
        error:
          "No se pudo verificar la sesión.\nSin conexión con el servidor. Verifique su red e inténtelo de nuevo.",
      });
      setScreen("splash");
      return;
    }

    const email = stored.replace("demo-jwt:", "");
    const rec = usersRef.current[email];
    if (!rec) {
      localStorage.removeItem(TOKEN_KEY);
      setToken(null);
      pushLog({
        method: "GET",
        path: "/api/auth/me",
        status: 401,
        note: "token inválido → UnauthorizedFailure → limpiar token (RF-01.6)",
      });
      setSession({ kind: "unauthenticated", reason: "expired" });
      setScreen("login");
      setBanner({
        msg: "Tu sesión ha expirado. Vuelve a iniciar sesión.",
        kind: "warning",
      });
      return;
    }

    pushLog({
      method: "GET",
      path: "/api/auth/me",
      status: 200,
      note: "token válido → perfil, empresa y roles (RF-01.3)",
    });
    setToken(stored);
    setSession({ kind: "authenticated", user: rec.user });
    setScreen("home");
  }, [pushLog]);

  // Auto-bootstrap al montar (como SessionController.build → microtask).
  // Token y escenario offline se leen del "sistema externo" (localStorage).
  useEffect(() => {
    const timer = setTimeout(() => {
      const offlineStored = localStorage.getItem("rf01_offline") === "1";
      setOfflineState(offlineStored);
      offlineRef.current = offlineStored;
      setToken(localStorage.getItem(TOKEN_KEY));
      void bootstrap();
    }, 600);
    return () => clearTimeout(timer);
  }, [bootstrap]);

  // login() (RF-01.1)
  const handleLogin = useCallback(
    async (email: string, password: string): Promise<string | null> => {
      // Validaciones de cliente (Validators.dart)
      if (!email.trim()) return "El email es obligatorio.";
      if (!EMAIL_RE.test(email.trim())) return "Ingrese un email válido.";
      if (!password) return "La contraseña es obligatoria.";

      pushLog({
        method: "POST",
        path: "/api/auth/login",
        note: "skipAuth: no adjunta token ni dispara expiración",
      });
      await sleep(750);

      if (offlineRef.current) {
        pushLog({
          status: 0,
          note: "DioException.connectionError → NetworkFailure (R2)",
        });
        return "Sin conexión con el servidor. Verifique su red e inténtelo de nuevo.";
      }

      const rec = usersRef.current[email.trim().toLowerCase()];
      const credentialsOk = rec != null && rec.password === password;
      pushLog({
        method: "POST",
        path: "/api/auth/login",
        status: credentialsOk ? 200 : 401,
        note: credentialsOk
          ? "AuthResponseDto { token, type, userId, email } → token a secure_storage (RF-01.2)"
          : "UnauthorizedFailure (401) → banner en el formulario",
      });

      if (!credentialsOk) {
        return "Credenciales inválidas o sesión expirada.";
      }

      const jwt = `demo-jwt:${rec.user.email}`;
      localStorage.setItem(TOKEN_KEY, jwt);
      setToken(jwt);

      await sleep(400);
      pushLog({
        method: "GET",
        path: "/api/auth/me",
        status: 200,
        note: "sesión autenticada → perfil + capacidades por rol",
      });
      setSession({ kind: "authenticated", user: rec.user });
      setScreen("home");
      setBanner(null);
      return null;
    },
    [pushLog]
  );

  // RF-01.6 — 401 del interceptor en endpoint autenticado
  const expireSession = useCallback(() => {
    pushLog({
      method: "GET",
      path: "/api/auth/me",
      status: 401,
      note: "AuthInterceptor: 401 → SessionExpiredBus → logout local (RF-01.6)",
    });
    localStorage.removeItem(TOKEN_KEY);
    setToken(null);
    setSession({ kind: "unauthenticated", reason: "expired" });
    setScreen("login");
    setBanner({
      msg: "Tu sesión ha expirado. Vuelve a iniciar sesión.",
      kind: "warning",
    });
  }, [pushLog]);

  // RF-01.4 — logout
  const handleLogout = useCallback(async () => {
    pushLog({
      method: "POST",
      path: "/api/auth/logout",
      status: 200,
      note: "best-effort: token eliminado del secure_storage en finally",
    });
    await sleep(500);
    localStorage.removeItem(TOKEN_KEY);
    setToken(null);
    setSession({ kind: "unauthenticated", reason: "loggedOut" });
    setScreen("login");
    setBanner({ msg: "Sesión cerrada correctamente.", kind: "success" });
  }, [pushLog]);

  // RF-01.5 — cambio de contraseña
  const handleChangePassword = useCallback(
    async (
      current: string,
      next: string,
      confirm: string
    ): Promise<{ current?: string; next?: string; confirm?: string; server?: string }> => {
      const errors: {
        current?: string;
        next?: string;
        confirm?: string;
        server?: string;
      } = {};

      if (!current) errors.current = "La contraseña actual es obligatoria.";
      if (!next) errors.next = "La nueva contraseña es obligatoria.";
      else if (next.length < 6) errors.next = "Debe tener al menos 6 caracteres.";
      if (!confirm) errors.confirm = "Confirme la nueva contraseña.";
      else if (confirm !== next) errors.confirm = "No coincide con la nueva contraseña.";
      if (!errors.current && !errors.next && next === current) {
        errors.next = "Debe ser distinta de la contraseña actual.";
      }
      if (Object.keys(errors).length > 0) return errors;

      const userEmail = session.kind === "authenticated" ? session.user!.email : "";
      const rec = usersRef.current[userEmail];

      pushLog({
        method: "PUT",
        path: "/api/auth/cambiar-password",
        note: "userId del perfil autenticado (RF-01.3 → RF-01.5)",
      });
      await sleep(700);

      if (offlineRef.current) {
        pushLog({ status: 0, note: "NetworkFailure (simulado)" });
        return { server: "Sin conexión con el servidor. Verifique su red e inténtelo de nuevo." };
      }

      if (!rec || rec.password !== current) {
        pushLog({
          status: 400,
          note: "ValidationFailure del servidor (contraseña actual incorrecta)",
        });
        return { server: "La contraseña actual es incorrecta. (ValidationFailure 400)" };
      }

      pushLog({ status: 200, note: "200 OK sin cuerpo — contraseña actualizada" });
      rec.password = next;
      return {};
    },
    [pushLog, session]
  );

  const resetDemo = useCallback(() => {
    localStorage.removeItem(TOKEN_KEY);
    setToken(null);
    setLogs([]);
    setBanner(null);
    setOffline(false);
    setSession({ kind: "unknown" });
    setScreen("splash");
    setTimeout(() => void bootstrap(), 300);
  }, [bootstrap, setOffline]);

  const authenticated = session.kind === "authenticated";

  return (
    <div className="grid gap-6 lg:grid-cols-[380px_minmax(0,1fr)]">
      {/* ---------------- Teléfono ---------------- */}
      <div className="mx-auto w-full max-w-[380px]">
        <div className="rounded-[2.2rem] border-[10px] border-zinc-900 bg-zinc-950 shadow-2xl">
          <div className="flex items-center justify-between rounded-t-[1.6rem] bg-zinc-900 px-5 py-1.5 text-[11px] text-zinc-400">
            <span>09:41</span>
            <span className="flex items-center gap-2">
              <span className="font-mono">secure_storage:</span>
              {token ? (
                <span className="flex items-center gap-1 text-emerald-400">
                  <Lock className="h-3 w-3" /> token
                </span>
              ) : (
                <span className="flex items-center gap-1 text-zinc-500">
                  <LockOpen className="h-3 w-3" /> vacío
                </span>
              )}
            </span>
          </div>

          <div className="h-[640px] overflow-hidden bg-background">
            {screen === "splash" && (
              <SplashView session={session} onRetry={() => void bootstrap()} />
            )}
            {screen === "login" && (
              <LoginView
                banner={banner}
                onLogin={handleLogin}
                onDismissBanner={() => setBanner(null)}
              />
            )}
            {screen === "home" && authenticated && (
              <HomeView
                user={session.user!}
                onLogout={() => void handleLogout()}
                onProfile={() => {
                  setScreen("profile");
                  setBanner(null);
                }}
              />
            )}
            {screen === "profile" && authenticated && (
              <ProfileView
                user={session.user!}
                onChangePassword={() => {
                  setScreen("changePassword");
                  setBanner(null);
                }}
                onLogout={() => void handleLogout()}
                onBack={() => setScreen("home")}
                onRefresh={() => {
                  pushLog({
                    method: "GET",
                    path: "/api/auth/me",
                    status: 200,
                    note: "pull-to-refresh del perfil (refreshUser)",
                  });
                  toast({ title: "Perfil actualizado desde /api/auth/me" });
                }}
              />
            )}
            {screen === "changePassword" && authenticated && (
              <ChangePasswordView
                onSubmit={handleChangePassword}
                onBack={() => setScreen("profile")}
              />
            )}
          </div>
        </div>
      </div>

      {/* ---------------- Panel de evaluación ---------------- */}
      <div className="flex min-w-0 flex-col gap-4">
        {/* Máquina de estados */}
        <div className="rounded-xl border bg-card p-4">
          <h3 className="mb-3 text-sm font-semibold">
            Máquina de estados — <span className="font-mono text-xs text-muted-foreground">session_controller.dart</span>
          </h3>
          <div className="flex flex-wrap items-center gap-1.5">
            {(
              [
                "unknown",
                "bootstrapping",
                "authenticated",
                "unauthenticated",
                "bootstrapError",
              ] as SessionKind[]
            ).map((kind, i) => (
              <span key={kind} className="flex items-center gap-1.5">
                {i > 0 && <ChevronRight className="h-3.5 w-3.5 text-muted-foreground" />}
                <span
                  className={`rounded-md px-2 py-1 font-mono text-[11px] transition-colors ${
                    session.kind === kind
                      ? "bg-emerald-600 font-semibold text-white shadow-sm"
                      : "bg-muted text-muted-foreground"
                  }`}
                >
                  {SESSION_LABEL[kind]}
                </span>
              </span>
            ))}
          </div>
          {session.kind === "unauthenticated" && session.reason && (
            <p className="mt-2 text-xs text-muted-foreground">
              reason: <span className="font-mono text-amber-600 dark:text-amber-400">{REASON_LABEL[session.reason]}</span>
            </p>
          )}
        </div>

        {/* Controles del escenario */}
        <div className="rounded-xl border bg-card p-4">
          <h3 className="mb-3 text-sm font-semibold">Escenario de prueba</h3>
          <div className="flex flex-col gap-3">
            <label className="flex items-center justify-between gap-4 text-sm">
              <span className="flex items-center gap-2">
                <CloudOff className="h-4 w-4 text-muted-foreground" />
                Servidor caído / sin red
                <span className="text-xs text-muted-foreground">
                  (NetworkFailure + bootstrap con reintentar)
                </span>
              </span>
              <Switch checked={offline} onCheckedChange={setOffline} />
            </label>
            <div className="flex flex-wrap gap-2">
              <Button
                size="sm"
                variant="destructive"
                disabled={!authenticated}
                onClick={expireSession}
                title="Simula un 401 del backend en un endpoint autenticado"
              >
                <Zap className="mr-1 h-3.5 w-3.5" /> Forzar 401 (expirar sesión)
              </Button>
              <Button size="sm" variant="outline" onClick={resetDemo}>
                <RefreshCw className="mr-1 h-3.5 w-3.5" /> Reiniciar demo
              </Button>
            </div>
            <p className="text-xs text-muted-foreground">
              Credenciales de demo:{" "}
              <code className="rounded bg-muted px-1 py-0.5">admin@transporte.cu</code> ·{" "}
              <code className="rounded bg-muted px-1 py-0.5">chofer@transporte.cu</code> —
              contraseña <code className="rounded bg-muted px-1 py-0.5">password123</code>
            </p>
          </div>
        </div>

        {/* Traza de API */}
        <div className="rounded-xl border bg-card p-4">
          <h3 className="mb-3 flex items-center justify-between text-sm font-semibold">
            Traza de llamadas a la API
            <Badge variant="secondary" className="font-mono text-[10px]">
              Dio + AuthInterceptor
            </Badge>
          </h3>
          {logs.length === 0 ? (
            <p className="py-6 text-center text-sm text-muted-foreground">
              Aún no hay llamadas. Interactúa con el teléfono.
            </p>
          ) : (
            <ScrollArea className="h-[300px] pr-3">
              <ul className="space-y-2">
                {[...logs].reverse().map((l) => (
                  <li key={l.id} className="rounded-lg border bg-background/60 p-2.5 text-xs">
                    <div className="flex flex-wrap items-center gap-2">
                      {l.method && (
                        <Badge
                          variant="outline"
                          className="h-5 px-1.5 font-mono text-[10px] font-bold text-teal-700 dark:text-teal-400"
                        >
                          {l.method}
                        </Badge>
                      )}
                      {l.path && (
                        <span className="font-mono text-[11px] font-medium">{l.path}</span>
                      )}
                      {typeof l.status === "number" && (
                        <Badge
                          className={`h-5 px-1.5 font-mono text-[10px] ${
                            l.status >= 200 && l.status < 300
                              ? "bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300"
                              : l.status === 401
                                ? "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300"
                                : "bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300"
                          }`}
                        >
                          {l.status === 0 ? "ERR" : l.status}
                        </Badge>
                      )}
                    </div>
                    {l.note && (
                      <p className="mt-1 leading-relaxed text-muted-foreground">{l.note}</p>
                    )}
                  </li>
                ))}
              </ul>
            </ScrollArea>
          )}
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Pantallas (espejo de las screens Flutter)
// ---------------------------------------------------------------------------

function Banner({
  msg,
  kind,
  onDismiss,
}: {
  msg: string;
  kind: "warning" | "success" | "info";
  onDismiss?: () => void;
}) {
  const styles =
    kind === "warning"
      ? "bg-amber-100 text-amber-900 dark:bg-amber-950 dark:text-amber-200"
      : kind === "success"
        ? "bg-emerald-100 text-emerald-900 dark:bg-emerald-950 dark:text-emerald-200"
        : "bg-muted text-foreground";
  const Icon = kind === "warning" ? AlertTriangle : kind === "success" ? CheckCircle2 : Info;
  return (
    <div className={`flex items-start gap-2 rounded-xl p-3 text-xs leading-relaxed ${styles}`}>
      <Icon className="mt-0.5 h-4 w-4 shrink-0" />
      <span className="flex-1">{msg}</span>
      {onDismiss && (
        <button onClick={onDismiss} className="text-xs opacity-60 hover:opacity-100" aria-label="Cerrar aviso">
          ✕
        </button>
      )}
    </div>
  );
}

function SplashView({
  session,
  onRetry,
}: {
  session: Session;
  onRetry: () => void;
}) {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-6 p-8 text-center">
      <div className="flex h-24 w-24 items-center justify-center rounded-3xl bg-teal-700/10">
        <Truck className="h-12 w-12 text-teal-700 dark:text-teal-400" />
      </div>
      <div>
        <h2 className="text-lg font-bold">Registro de Recorridos</h2>
        <p className="text-xs text-muted-foreground">Gestión de flota y combustible</p>
      </div>
      {session.kind === "bootstrapError" ? (
        <div className="w-full space-y-3">
          <CloudOff className="mx-auto h-8 w-8 text-red-500" />
          <p className="whitespace-pre-line text-xs text-muted-foreground">{session.error}</p>
          <Button size="sm" className="w-full" onClick={onRetry}>
            Reintentar
          </Button>
        </div>
      ) : (
        <>
          <Loader2 className="h-8 w-8 animate-spin text-teal-700 dark:text-teal-400" />
          <p className="text-xs text-muted-foreground">Verificando sesión…</p>
        </>
      )}
    </div>
  );
}

function LoginView({
  banner,
  onLogin,
  onDismissBanner,
}: {
  banner: { msg: string; kind: "warning" | "success" | "info" } | null;
  onLogin: (email: string, password: string) => Promise<string | null>;
  onDismissBanner: () => void;
}) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [fieldErrors, setFieldErrors] = useState<{ email?: string; password?: string }>({});
  const [serverError, setServerError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setFieldErrors({});
    setServerError(null);
    const err = await onLogin(email, password);
    setSubmitting(false);
    if (err) setServerError(err);
  }

  return (
    <div className="flex h-full flex-col justify-center gap-4 overflow-y-auto p-6">
      <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-teal-700/10">
        <Truck className="h-8 w-8 text-teal-700 dark:text-teal-400" />
      </div>
      <div>
        <h2 className="text-xl font-bold">Iniciar sesión</h2>
        <p className="text-xs text-muted-foreground">Acceda con sus credenciales de la empresa</p>
      </div>

      {banner && <Banner msg={banner.msg} kind={banner.kind} onDismiss={onDismissBanner} />}
      {serverError && (
        <Banner msg={serverError} kind="warning" onDismiss={() => setServerError(null)} />
      )}

      <form onSubmit={submit} className="space-y-3">
        <div className="space-y-1.5">
          <Label htmlFor="demo-email">Email</Label>
          <Input
            id="demo-email"
            type="email"
            placeholder="usuario@empresa.cu"
            value={email}
            onChange={(e) => {
              setEmail(e.target.value);
              setFieldErrors((f) => ({ ...f, email: undefined }));
              setServerError(null);
            }}
            disabled={submitting}
            autoComplete="username"
          />
          {fieldErrors.email && (
            <p className="text-xs text-red-600 dark:text-red-400">{fieldErrors.email}</p>
          )}
        </div>

        <div className="space-y-1.5">
          <Label htmlFor="demo-password">Contraseña</Label>
          <div className="relative">
            <Input
              id="demo-password"
              type={showPw ? "text" : "password"}
              placeholder="••••••••"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                setFieldErrors((f) => ({ ...f, password: undefined }));
                setServerError(null);
              }}
              disabled={submitting}
              autoComplete="current-password"
              className="pr-10"
            />
            <button
              type="button"
              onClick={() => setShowPw((v) => !v)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
              aria-label={showPw ? "Ocultar contraseña" : "Mostrar contraseña"}
            >
              {showPw ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
            </button>
          </div>
          {fieldErrors.password && (
            <p className="text-xs text-red-600 dark:text-red-400">{fieldErrors.password}</p>
          )}
        </div>

        <Button type="submit" className="h-12 w-full text-base font-semibold" disabled={submitting}>
          {submitting ? <Loader2 className="h-5 w-5 animate-spin" /> : "Entrar"}
        </Button>
      </form>

      <p className="text-center font-mono text-[10px] text-muted-foreground">
        Servidor: --dart-define=API_BASE_URL=http://10.0.2.2:8081
      </p>
    </div>
  );
}

function HomeView({
  user,
  onLogout,
  onProfile,
}: {
  user: MockUser;
  onLogout: () => void;
  onProfile: () => void;
}) {
  const caps = capabilities(user);
  const modules = [
    { icon: Route, title: "Recorridos", sub: "Registrar km y abastecimientos", enabled: caps.trips },
    { icon: Truck, title: "Vehículos", sub: "Flota, odómetro y mantenimiento", enabled: caps.fleet },
    { icon: Users, title: "Choferes", sub: "Personal y licencias", enabled: caps.fleet },
    { icon: KeyRound, title: "Reportes", sub: "Consumo, abastecimiento, dashboard", enabled: caps.reports },
  ];

  return (
    <div className="flex h-full flex-col">
      <header className="flex items-center justify-between border-b px-4 py-3">
        <h2 className="text-sm font-bold">Registro de Recorridos</h2>
        <button
          onClick={onLogout}
          className="flex items-center gap-1 text-xs text-red-600 hover:underline dark:text-red-400"
        >
          <LogOut className="h-3.5 w-3.5" /> Salir
        </button>
      </header>

      <div className="flex-1 space-y-3 overflow-y-auto p-4">
        <div className="flex items-center gap-3 rounded-xl bg-teal-700/10 p-3">
          <div className="flex h-11 w-11 items-center justify-center rounded-full bg-teal-700 text-base font-bold text-white">
            {user.email[0].toUpperCase()}
          </div>
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold">{user.empresa.nombre}</p>
            <p className="truncate text-xs text-muted-foreground">{user.email}</p>
            <div className="mt-1 flex flex-wrap gap-1">
              {user.roles.map((r) => (
                <span key={r.id} className="rounded bg-teal-700/15 px-1.5 py-0.5 font-mono text-[10px] text-teal-800 dark:text-teal-300">
                  {r.name}
                </span>
              ))}
            </div>
          </div>
        </div>

        <p className="text-xs font-medium text-muted-foreground">Módulos (Fase 2+)</p>
        {modules.map((m) => (
          <div
            key={m.title}
            className={`flex items-center gap-3 rounded-xl border p-3 ${
              m.enabled ? "bg-card" : "opacity-50"
            }`}
          >
            <m.icon className={`h-5 w-5 ${m.enabled ? "text-teal-700 dark:text-teal-400" : "text-muted-foreground"}`} />
            <div className="min-w-0 flex-1">
              <p className="text-sm font-medium">{m.title}</p>
              <p className="truncate text-xs text-muted-foreground">{m.sub}</p>
            </div>
            {m.enabled ? (
              <ChevronRight className="h-4 w-4 text-muted-foreground" />
            ) : (
              <Lock className="h-3.5 w-3.5 text-muted-foreground" />
            )}
          </div>
        ))}

        <Button variant="outline" size="sm" className="w-full" onClick={onProfile}>
          <User className="mr-1 h-4 w-4" /> Ver mi perfil
        </Button>
      </div>
    </div>
  );
}

function ProfileView({
  user,
  onChangePassword,
  onLogout,
  onBack,
  onRefresh,
}: {
  user: MockUser;
  onChangePassword: () => void;
  onLogout: () => void;
  onBack: () => void;
  onRefresh: () => void;
}) {
  const caps = capabilities(user);
  const rows = [
    { label: "Empresa", value: user.empresa.nombre },
    { label: "Código de empresa", value: user.empresa.codigo },
    { label: "ID de usuario", value: String(user.id) },
  ];
  const capList = [
    { text: "Registrar recorridos", ok: caps.trips },
    { text: "Gestionar flota (vehículos, choferes, tarjetas)", ok: caps.fleet },
    { text: "Ver reportes", ok: caps.reports },
  ];

  return (
    <div className="flex h-full flex-col">
      <header className="flex items-center gap-2 border-b px-3 py-3">
        <button onClick={onBack} aria-label="Volver" className="rounded p-1 hover:bg-muted">
          <ArrowLeft className="h-4 w-4" />
        </button>
        <h2 className="flex-1 text-sm font-bold">Mi perfil</h2>
        <button onClick={onRefresh} className="text-xs text-muted-foreground hover:text-foreground">
          <RefreshCw className="h-4 w-4" />
        </button>
      </header>

      <div className="flex-1 space-y-3 overflow-y-auto p-4">
        <div className="rounded-xl border p-4 text-center">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-teal-700/10 text-xl font-bold text-teal-700 dark:text-teal-400">
            {user.email[0].toUpperCase()}
          </div>
          <p className="mt-2 text-sm font-bold">{user.email}</p>
          <span className="mt-1 inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-medium text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300">
            <CheckCircle2 className="h-3 w-3" /> Activo
          </span>
          <div className="mt-3 space-y-1.5 border-t pt-3">
            {rows.map((r) => (
              <div key={r.label} className="flex justify-between text-xs">
                <span className="text-muted-foreground">{r.label}</span>
                <span className="font-medium">{r.value}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-xl border p-4">
          <p className="mb-2 text-xs font-bold">Roles</p>
          <div className="mb-3 flex flex-wrap gap-1">
            {user.roles.map((r) => (
              <span key={r.id} className="rounded bg-teal-700/15 px-1.5 py-0.5 font-mono text-[10px] text-teal-800 dark:text-teal-300">
                {r.name}
              </span>
            ))}
          </div>
          <p className="mb-2 text-xs font-bold">Capacidades en la app (RF-01.3)</p>
          <ul className="space-y-1.5">
            {capList.map((c) => (
              <li key={c.text} className="flex items-start gap-2 text-xs">
                {c.ok ? (
                  <CheckCircle2 className="mt-0.5 h-3.5 w-3.5 shrink-0 text-emerald-600 dark:text-emerald-400" />
                ) : (
                  <Lock className="mt-0.5 h-3.5 w-3.5 shrink-0 text-muted-foreground" />
                )}
                <span className={c.ok ? "" : "text-muted-foreground line-through"}>{c.text}</span>
              </li>
            ))}
          </ul>
        </div>

        <Button className="w-full" variant="secondary" onClick={onChangePassword}>
          <KeyRound className="mr-1 h-4 w-4" /> Cambiar contraseña
        </Button>
        <Button className="w-full" variant="outline" onClick={onLogout}>
          <LogOut className="mr-1 h-4 w-4" /> Cerrar sesión
        </Button>
      </div>
    </div>
  );
}

function ChangePasswordView({
  onSubmit,
  onBack,
}: {
  onSubmit: (
    current: string,
    next: string,
    confirm: string
  ) => Promise<{ current?: string; next?: string; confirm?: string; server?: string }>;
  onBack: () => void;
}) {
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [errors, setErrors] = useState<{ current?: string; next?: string; confirm?: string; server?: string }>({});
  const [submitting, setSubmitting] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    const errs = await onSubmit(current, next, confirm);
    setSubmitting(false);
    setErrors(errs);
    if (Object.keys(errs).length === 0) {
      onBack();
    }
  }

  const field = (
    id: string,
    label: string,
    value: string,
    onChange: (v: string) => void,
    error?: string
  ) => (
    <div className="space-y-1.5">
      <Label htmlFor={id}>{label}</Label>
      <Input
        id={id}
        type="password"
        value={value}
        onChange={(e) => {
          onChange(e.target.value);
          setErrors((f) => ({ ...f, [id === "cp-current" ? "current" : id === "cp-next" ? "next" : "confirm"]: undefined, server: undefined }));
        }}
        disabled={submitting}
        autoComplete="new-password"
      />
      {error && <p className="text-xs text-red-600 dark:text-red-400">{error}</p>}
    </div>
  );

  return (
    <div className="flex h-full flex-col">
      <header className="flex items-center gap-2 border-b px-3 py-3">
        <button onClick={onBack} aria-label="Volver" className="rounded p-1 hover:bg-muted">
          <ArrowLeft className="h-4 w-4" />
        </button>
        <h2 className="text-sm font-bold">Cambiar contraseña</h2>
      </header>

      <form onSubmit={submit} className="flex-1 space-y-3 overflow-y-auto p-4">
        {errors.server && <Banner msg={errors.server} kind="warning" />}
        <p className="text-xs leading-relaxed text-muted-foreground">
          Por seguridad, elija una contraseña de al menos 6 caracteres y distinta de la anterior.
        </p>
        {field("cp-current", "Contraseña actual", current, setCurrent, errors.current)}
        {field("cp-next", "Nueva contraseña", next, setNext, errors.next)}
        {field("cp-confirm", "Confirmar nueva contraseña", confirm, setConfirm, errors.confirm)}
        <Button type="submit" className="h-12 w-full font-semibold" disabled={submitting}>
          {submitting ? <Loader2 className="h-5 w-5 animate-spin" /> : "Guardar cambios"}
        </Button>
      </form>
    </div>
  );
}
