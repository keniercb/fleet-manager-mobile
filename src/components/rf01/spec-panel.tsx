"use client";

/**
 * Especificación del RF-01: requisitos implementados, mapping a ficheros,
 * riesgos de API y guía de integración en el proyecto Flutter real.
 */

import { useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { CheckCircle2, FileCode2, ShieldAlert } from "lucide-react";

interface ReqItem {
  id: string;
  title: string;
  detail: string;
  files: string[];
  endpoint?: string;
}

const REQUIREMENTS: ReqItem[] = [
  {
    id: "RF-01.1",
    title: "Login con email + contraseña",
    detail:
      "POST /api/auth/login con skipAuth (sin token). Validación de cliente espejo de Validators.dart. 401 → banner «Credenciales inválidas», error de red → NetworkFailure.",
    files: ["auth_api.dart", "usecases/login.dart", "login_screen.dart", "login_controller.dart"],
    endpoint: "POST /api/auth/login",
  },
  {
    id: "RF-01.2",
    title: "Token seguro + auto-login",
    detail:
      "El token vive en flutter_secure_storage (Keystore/Keychain) con caché en memoria. Al arrancar, bootstrap() lo lee y verifica contra /auth/me antes de entrar a Home.",
    files: ["token_storage.dart", "session_controller.dart"],
  },
  {
    id: "RF-01.3",
    title: "Perfil, empresa y roles al arrancar",
    detail:
      "GET /api/auth/me → User + UserCapabilities (único punto a ajustar cuando se confirmen los nombres reales de roles). Home deshabilita módulos según capacidades.",
    files: ["entities/user.dart", "profile_screen.dart", "home_screen.dart"],
    endpoint: "GET /api/auth/me",
  },
  {
    id: "RF-01.4",
    title: "Logout con limpieza garantizada",
    detail:
      "POST /api/auth/logout es best-effort: el repositorio elimina el token en finally aunque el backend falle. Confirmación con diálogo antes de salir.",
    files: ["auth_repository_impl.dart", "usecases/logout.dart"],
    endpoint: "POST /api/auth/logout",
  },
  {
    id: "RF-01.5",
    title: "Cambio de contraseña validado",
    detail:
      "PUT /api/auth/cambiar-password con userId del perfil autenticado. Triple validación: longitud ≥ 6, coincidencia y distinta de la anterior, en UI y en el use case.",
    files: ["change_password_controller.dart", "usecases/change_password.dart", "change_password_screen.dart"],
    endpoint: "PUT /api/auth/cambiar-password",
  },
  {
    id: "RF-01.6",
    title: "Manejo de sesión expirada (401)",
    detail:
      "El AuthInterceptor detecta 401 en endpoints autenticados → SessionExpiredBus → SessionController limpia token → GoRouter redirige a Login con banner «Tu sesión ha expirado». Excluye login y logout para evitar bucles.",
    files: ["auth_interceptor.dart", "session_expired_bus.dart", "session_controller.dart", "flow_banner.dart"],
  },
];

const RISKS = [
  {
    id: "R1",
    text: "El OpenAPI no declara securitySchemes: se asume Authorization: Bearer <token>. El interceptor es el único punto a tocar si el backend confirma otro esquema.",
  },
  {
    id: "R2",
    text: "Sin cuerpos de error definidos: failures.dart parsea RFC-7807 → Spring → errores por campo → genérico. Ningún 4xx/5xx crashea la app.",
  },
  {
    id: "R3",
    text: "No hay refresh token: al expirar la sesión se re-login con banner informativo. Propuesta al backend: añadir refresh en backlog de API.",
  },
];

const GATE_CHECKS = [
  "App arranca en Splash → sin token → Login",
  "Login incorrecto → banner «Credenciales inválidas» (401)",
  "Servidor caído → banner de red + Splash con Reintentar",
  "Login correcto → Home con empresa y roles de /auth/me",
  "Reabrir la app → auto-login directo a Home",
  "Cambio de contraseña valida longitud, coincidencia y distinta",
  "401 en endpoint autenticado → Login con «Tu sesión ha expirado»",
  "Logout → token limpio → Login con banner de éxito",
];

export function Rf01SpecPanel() {
  const [checked, setChecked] = useState<Set<number>>(new Set());

  function toggle(i: number) {
    setChecked((prev) => {
      const next = new Set(prev);
      if (next.has(i)) next.delete(i);
      else next.add(i);
      return next;
    });
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2">
        {REQUIREMENTS.map((r) => (
          <Card key={r.id} className="gap-3 py-4">
            <CardHeader className="px-4">
              <div className="flex items-center justify-between gap-2">
                <CardTitle className="text-sm">
                  <span className="font-mono text-teal-700 dark:text-teal-400">{r.id}</span>{" "}
                  · {r.title}
                </CardTitle>
                <Badge className="shrink-0 bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300">
                  <CheckCircle2 className="mr-1 h-3 w-3" /> Implementado
                </Badge>
              </div>
            </CardHeader>
            <CardContent className="space-y-3 px-4">
              <p className="text-xs leading-relaxed text-muted-foreground">{r.detail}</p>
              {r.endpoint && (
                <p className="rounded-md bg-muted px-2 py-1 font-mono text-[11px]">{r.endpoint}</p>
              )}
              <div className="flex flex-wrap gap-1.5">
                {r.files.map((f) => (
                  <span
                    key={f}
                    className="inline-flex items-center gap-1 rounded-md border px-1.5 py-0.5 font-mono text-[10px] text-muted-foreground"
                  >
                    <FileCode2 className="h-3 w-3" />
                    {f}
                  </span>
                ))}
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="py-4">
          <CardHeader className="px-4">
            <CardTitle className="flex items-center gap-2 text-sm">
              <ShieldAlert className="h-4 w-4 text-amber-600 dark:text-amber-400" />
              Riesgos de API manejados (del plan)
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 px-4">
            {RISKS.map((r) => (
              <div key={r.id} className="flex gap-2 text-xs leading-relaxed">
                <span className="mt-0.5 h-fit rounded bg-amber-100 px-1.5 py-0.5 font-mono text-[10px] font-bold text-amber-800 dark:bg-amber-950 dark:text-amber-300">
                  {r.id}
                </span>
                <p className="text-muted-foreground">{r.text}</p>
              </div>
            ))}
          </CardContent>
        </Card>

        <Card className="py-4">
          <CardHeader className="px-4">
            <CardTitle className="text-sm">Gate F1 — checklist de aceptación</CardTitle>
          </CardHeader>
          <CardContent className="px-4">
            <ul className="space-y-2.5">
              {GATE_CHECKS.map((c, i) => (
                <li key={c}>
                  <label className="flex cursor-pointer items-start gap-2 text-xs leading-relaxed">
                    <Checkbox checked={checked.has(i)} onCheckedChange={() => toggle(i)} className="mt-0.5" />
                    <span className={checked.has(i) ? "text-muted-foreground line-through" : ""}>{c}</span>
                  </label>
                </li>
              ))}
            </ul>
            <p className="mt-3 text-[11px] text-muted-foreground">
              {checked.size}/{GATE_CHECKS.length} verificados — puedes probar cada punto en la
              demo interactiva.
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
