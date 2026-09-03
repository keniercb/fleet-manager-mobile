"use client";

/**
 * Explorador del código Dart generado en `flutter_app/`.
 * Lee el árbol y el contenido vía /api/files (whitelist de rutas).
 */

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";
import { tokenizeDart, type DartToken } from "@/lib/dart-highlight";
import { Check, Copy, FileCode2, FolderOpen, Search } from "lucide-react";

const DEFAULT_FILE = "lib/features/auth/presentation/controllers/session_controller.dart";

function languageOf(path: string): "dart" | "yaml" | "markdown" | "json" {
  if (path.endsWith(".dart")) return "dart";
  if (path.endsWith(".yaml")) return "yaml";
  if (path.endsWith(".md")) return "markdown";
  return "json";
}

export function Rf01CodeExplorer() {
  const { toast } = useToast();
  const [files, setFiles] = useState<string[]>([]);
  const [selected, setSelected] = useState<string>(DEFAULT_FILE);
  const [content, setContent] = useState<string>("");
  const [loadingTree, setLoadingTree] = useState(true);
  const [loadingFile, setLoadingFile] = useState(false);
  const [query, setQuery] = useState("");
  const [copied, setCopied] = useState(false);
  const cache = useRef<Map<string, string>>(new Map());

  useEffect(() => {
    let cancelled = false;
    fetch("/api/files")
      .then((r) => r.json())
      .then((data: { files?: string[] }) => {
        if (!cancelled) setFiles(data.files ?? []);
      })
      .catch(() => {
        if (!cancelled) setFiles([]);
      })
      .finally(() => {
        if (!cancelled) setLoadingTree(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!selected) return;
    const cached = cache.current.get(selected);
    if (cached != null) {
      setContent(cached);
      return;
    }
    let cancelled = false;
    setLoadingFile(true);
    fetch(`/api/files?path=${encodeURIComponent(selected)}`)
      .then((r) => r.json())
      .then((data: { content?: string }) => {
        const text = data.content ?? "// No disponible";
        cache.current.set(selected, text);
        if (!cancelled) setContent(text);
      })
      .catch(() => {
        if (!cancelled) setContent("// Error cargando el fichero");
      })
      .finally(() => {
        if (!cancelled) setLoadingFile(false);
      });
    return () => {
      cancelled = true;
    };
  }, [selected]);

  const filtered = useMemo(
    () => files.filter((f) => f.toLowerCase().includes(query.toLowerCase())),
    [files, query]
  );

  const grouped = useMemo(() => {
    const map = new Map<string, string[]>();
    for (const f of filtered) {
      const idx = f.lastIndexOf("/");
      const dir = idx === -1 ? "/" : f.slice(0, idx);
      if (!map.has(dir)) map.set(dir, []);
      map.get(dir)!.push(f);
    }
    return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  }, [filtered]);

  const copyCode = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(content);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      toast({ title: "No se pudo copiar al portapapeles" });
    }
  }, [content, toast]);

  const tokens: DartToken[] = useMemo(() => {
    if (languageOf(selected) !== "dart") return [];
    return tokenizeDart(content);
  }, [content, selected]);

  return (
    <div className="grid gap-4 lg:grid-cols-[300px_minmax(0,1fr)]">
      {/* Árbol de ficheros */}
      <div className="rounded-xl border bg-card">
        <div className="border-b p-3">
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Buscar fichero…"
              className="h-8 pl-8 text-xs"
            />
          </div>
        </div>
        <ScrollArea className="h-[420px] lg:h-[560px]">
          {loadingTree ? (
            <div className="space-y-2 p-3">
              {Array.from({ length: 8 }).map((_, i) => (
                <Skeleton key={i} className="h-5 w-full" />
              ))}
            </div>
          ) : grouped.length === 0 ? (
            <p className="p-4 text-center text-xs text-muted-foreground">
              Sin resultados.
            </p>
          ) : (
            <div className="p-2">
              {grouped.map(([dir, items]) => (
                <div key={dir} className="mb-2">
                  <p className="flex items-center gap-1 px-2 py-1 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
                    <FolderOpen className="h-3 w-3" />
                    {dir === "/" ? "raíz" : dir}
                  </p>
                  {items.map((f) => {
                    const name = f.slice(f.lastIndexOf("/") + 1);
                    const active = f === selected;
                    return (
                      <button
                        key={f}
                        onClick={() => setSelected(f)}
                        className={`flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left text-xs transition-colors ${
                          active
                            ? "bg-teal-600/15 font-semibold text-teal-800 dark:text-teal-300"
                            : "hover:bg-muted"
                        }`}
                      >
                        <FileCode2 className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
                        <span className="truncate font-mono">{name}</span>
                      </button>
                    );
                  })}
                </div>
              ))}
            </div>
          )}
        </ScrollArea>
      </div>

      {/* Visor de código */}
      <div className="overflow-hidden rounded-xl border bg-zinc-950">
        <div className="flex items-center justify-between gap-2 border-b border-zinc-800 px-4 py-2.5">
          <p className="truncate font-mono text-xs text-zinc-400">{selected}</p>
          <Button
            size="sm"
            variant="secondary"
            className="h-7 gap-1 px-2 text-xs"
            onClick={() => void copyCode()}
          >
            {copied ? <Check className="h-3 w-3" /> : <Copy className="h-3 w-3" />}
            {copied ? "Copiado" : "Copiar"}
          </Button>
        </div>
        <ScrollArea className="h-[420px] lg:h-[560px]">
          {loadingFile ? (
            <div className="space-y-2 p-4">
              {Array.from({ length: 12 }).map((_, i) => (
                <Skeleton key={i} className="h-4 bg-zinc-800" style={{ width: `${55 + ((i * 13) % 40)}%` }} />
              ))}
            </div>
          ) : languageOf(selected) === "dart" ? (
            <pre className="min-w-max px-4 py-4 font-mono text-[12px] leading-relaxed text-zinc-200">
              <code>
                {tokens.map((t, i) => (
                  <span key={i} className={t.cls}>
                    {t.text}
                  </span>
                ))}
              </code>
            </pre>
          ) : (
            <pre className="min-w-max px-4 py-4 font-mono text-[12px] leading-relaxed text-zinc-200">
              <code>{content}</code>
            </pre>
          )}
        </ScrollArea>
      </div>
    </div>
  );
}
