import { NextRequest, NextResponse } from "next/server";
import { promises as fs } from "fs";
import path from "path";

/**
 * Sirve el módulo Flutter (`flutter_app/`) para el explorador de código:
 *  - GET /api/files            → lista de ficheros (árbol)
 *  - GET /api/files?path=x.ts  → contenido del fichero (whitelist por ruta)
 */
export const runtime = "nodejs";

const ROOT = path.join(process.cwd(), "flutter_app");
const ALLOWED_EXT = new Set([".dart", ".yaml", ".md", ".json"]);

async function walk(dir: string, base = ""): Promise<string[]> {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    if (entry.name.startsWith(".")) continue;
    const rel = base ? `${base}/${entry.name}` : entry.name;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await walk(full, rel)));
    } else if (ALLOWED_EXT.has(path.extname(entry.name))) {
      files.push(rel);
    }
  }
  return files.sort();
}

export async function GET(req: NextRequest) {
  const rel = req.nextUrl.searchParams.get("path");

  if (!rel) {
    try {
      const files = await walk(ROOT);
      return NextResponse.json({ files });
    } catch {
      return NextResponse.json(
        { files: [], error: "flutter_app no disponible" },
        { status: 500 }
      );
    }
  }

  const normalized = path.normalize(rel).replace(/^(\.\.(\/|\\|$))+/, "");
  const full = path.resolve(ROOT, normalized);
  if (!full.startsWith(ROOT)) {
    return NextResponse.json({ error: "Ruta no permitida" }, { status: 403 });
  }

  try {
    const content = await fs.readFile(full, "utf-8");
    return NextResponse.json({ path: normalized, content });
  } catch {
    return NextResponse.json(
      { error: "Fichero no encontrado" },
      { status: 404 }
    );
  }
}
