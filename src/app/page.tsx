"use client";

import { useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Rf01PhoneDemo } from "@/components/rf01/phone-demo";
import { Rf01CodeExplorer } from "@/components/rf01/code-explorer";
import { Rf01SpecPanel } from "@/components/rf01/spec-panel";
import { Route, Smartphone } from "lucide-react";

export default function Home() {
  const [tab, setTab] = useState("demo");

  return (
    <div className="flex min-h-screen flex-col bg-muted/40">
      {/* ---------------- Header ---------------- */}
      <header className="border-b bg-background">
        <div className="mx-auto flex max-w-6xl flex-col gap-3 px-4 py-6 sm:px-6">
          <div className="flex flex-wrap items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-teal-700 text-white shadow-sm">
              <Smartphone className="h-6 w-6" />
            </div>
            <div className="min-w-0">
              <h1 className="text-lg font-bold leading-tight sm:text-xl">
                RF-02 · Registro de recorridos
              </h1>
              <p className="text-xs text-muted-foreground sm:text-sm">
                APK Registro de Recorridos de Vehículos — Fase 2: núcleo del negocio (RF-01
                Autenticación incluido)
              </p>
            </div>
            <Badge className="ml-auto bg-teal-700 text-white hover:bg-teal-700">
              <Route className="mr-1 h-3.5 w-3.5" /> Gate F2 listo para evaluar
            </Badge>
          </div>
          <div className="flex flex-wrap gap-1.5">
            {[
              "Flutter 3",
              "Riverpod 2",
              "Dio 5",
              "Drift (outbox)",
              "go_router",
              "Material 3",
              "Clean Architecture",
            ].map((t) => (
              <Badge key={t} variant="outline" className="font-mono text-[10px] text-muted-foreground">
                {t}
              </Badge>
            ))}
          </div>
        </div>
      </header>

      {/* ---------------- Contenido ---------------- */}
      <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6 sm:px-6">
        <Tabs value={tab} onValueChange={setTab}>
          <TabsList className="mb-4 h-10 w-full justify-start gap-1 overflow-x-auto rounded-xl bg-background p-1 shadow-sm sm:w-fit">
            <TabsTrigger value="demo" className="rounded-lg px-4 data-[state=active]:bg-teal-700 data-[state=active]:text-white">
              Demo interactiva
            </TabsTrigger>
            <TabsTrigger value="code" className="rounded-lg px-4 data-[state=active]:bg-teal-700 data-[state=active]:text-white">
              Código Dart
            </TabsTrigger>
            <TabsTrigger value="spec" className="rounded-lg px-4 data-[state=active]:bg-teal-700 data-[state=active]:text-white">
              Especificación RF-01 + RF-02
            </TabsTrigger>
          </TabsList>

          <TabsContent value="demo">
            <div className="mb-4 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-xs leading-relaxed text-amber-900 dark:border-amber-900 dark:bg-amber-950/40 dark:text-amber-200">
              <strong>Cómo evaluar RF-02:</strong> entra con{" "}
              <code className="rounded bg-amber-100 px-1 font-mono dark:bg-amber-900">admin@transporte.cu</code>{" "}
              o <code className="rounded bg-amber-100 px-1 font-mono dark:bg-amber-900">chofer@transporte.cu</code>{" "}
              (contraseña{" "}
              <code className="rounded bg-amber-100 px-1 font-mono dark:bg-amber-900">password123</code>) →
              Home → tile <strong>Recorridos</strong>. Prueba el listado paginado y sus filtros, crea
              un recorrido con abastecimiento (observa el hint de odómetro y el detalle con consumo
              calculado), edita y elimina. Después activa «Servidor caído» y crea 2 recorridos: irán
              al <strong>outbox</strong> con badge «Pendiente de sync»; al apagar el switch se
              sincronizan solos (~1,2 s) y el servidor recalcula odómetro/consumo. Como{" "}
              <strong>chofer</strong> no puedes eliminar recorridos; como{" "}
              <strong>admin</strong> sí (con confirmación).
            </div>
            <Rf01PhoneDemo />
          </TabsContent>

          <TabsContent value="code">
            <p className="mb-4 text-sm text-muted-foreground">
              Módulo completo en <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">flutter_app/</code>{" "}
              — servido dinámicamente vía{" "}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">/api/files</code>{" "}
              (ver{" "}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">flutter_app/README.md</code>{" "}
              para puesta en marcha y configuración Android).
            </p>
            <Rf01CodeExplorer />
          </TabsContent>

          <TabsContent value="spec">
            <Rf01SpecPanel />
          </TabsContent>
        </Tabs>
      </main>

      {/* ---------------- Footer (pegado al fondo) ---------------- */}
      <footer className="mt-auto border-t bg-background">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-1 px-4 py-4 text-center text-xs text-muted-foreground sm:flex-row sm:px-6 sm:text-left">
          <p>
            Plan: <span className="font-mono">plan-app-registro-recorridos-flutter.md</span> · Módulo:{" "}
            <span className="font-mono">flutter_app/</span> · RF-01.1 → RF-01.6 · RF-02.1 → RF-02.7
          </p>
          <p>Gate F2: demo end-to-end offline (outbox FIFO + SyncManager v1)</p>
        </div>
      </footer>
    </div>
  );
}
