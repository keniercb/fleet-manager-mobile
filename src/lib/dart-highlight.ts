/**
 * Resaltador de sintaxis Dart ligero (sin dependencias).
 * Devuelve tokens con clases de Tailwind para renderizar en <pre>.
 *
 * Nota de estilo: se evitan azules/índigos por convención del proyecto;
 * se usan teal (keywords), ámbar (strings), lima (tipos) y zinc (comentarios).
 */

export interface DartToken {
  text: string;
  cls: string;
}

const KEYWORDS = new Set([
  "abstract", "as", "assert", "async", "await", "break", "case", "catch",
  "class", "const", "continue", "covariant", "default", "deferred", "do",
  "else", "enum", "export", "extends", "extension", "external", "factory",
  "false", "final", "finally", "for", "get", "hide", "if", "implements",
  "import", "in", "interface", "is", "late", "library", "mixin", "new",
  "null", "on", "operator", "part", "required", "rethrow", "return",
  "sealed", "set", "show", "static", "super", "switch", "sync", "this",
  "throw", "true", "try", "typedef", "var", "while", "with", "yield",
]);

const TYPES = new Set([
  "int", "double", "bool", "String", "num", "List", "Map", "Set", "Future",
  "Stream", "Iterable", "DateTime", "Duration", "Object", "dynamic", "void",
  "Widget", "BuildContext", "WidgetRef",
]);

const RE =
  /(\/\/[^\n]*|\/\*[\s\S]*?\*\/)|('(?:\\.|[^'\\\n])*'|"(?:\\.|[^"\\\n])*")|(@[A-Za-z_]\w*)|(\b\d+(?:\.\d+)?\b)|([A-Za-z_$][\w$]*)/g;

export function tokenizeDart(code: string): DartToken[] {
  const tokens: DartToken[] = [];
  let last = 0;

  for (const m of code.matchAll(RE)) {
    const idx = m.index ?? 0;
    if (idx > last) {
      tokens.push({ text: code.slice(last, idx), cls: "" });
    }

    if (m[1]) {
      tokens.push({ text: m[0], cls: "text-zinc-500 italic" });
    } else if (m[2]) {
      tokens.push({ text: m[0], cls: "text-amber-200" });
    } else if (m[3]) {
      tokens.push({ text: m[0], cls: "text-rose-300" });
    } else if (m[4]) {
      tokens.push({ text: m[0], cls: "text-orange-300" });
    } else if (m[5]) {
      const word = m[0];
      if (KEYWORDS.has(word)) {
        tokens.push({ text: word, cls: "text-teal-300 font-medium" });
      } else if (TYPES.has(word)) {
        tokens.push({ text: word, cls: "text-lime-200" });
      } else {
        tokens.push({ text: word, cls: "" });
      }
    }

    last = idx + m[0].length;
  }

  if (last < code.length) {
    tokens.push({ text: code.slice(last), cls: "" });
  }

  return tokens;
}
