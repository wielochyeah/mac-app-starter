export const meta = {
  name: "red-team",
  description:
    "Gegenprüfung eines Pakets: Renders bei Oberflächenänderungen, sechs Blickwinkel finden Fehler, Befunde werden zusammengeführt, der Widerleger prüft jeden",
  whenToUse:
    'Nach jedem Paket und vor jedem Merge. Args: { branch, base, paket, strang, umfang: "voll" | "sparsam", szenen: ["island.", "settings."] }',
  phases: [{ title: "Aufnehmen" }, { title: "Finden" }, { title: "Zusammenführen" }, { title: "Widerlegen" }],
}

// args: branch (default HEAD), base (default origin/main), paket and strang for the prompt, umfang "voll" (six lenses,
// every severity) or "sparsam" (one lens for what breaks the app, only blockierend and wichtig), szenen (optional list of
// scene id prefixes; without it every scene is rendered). Two agents run at a time.
//
// Aufnehmen comes first whenever the change touches App/Sources or App/Resources: make shots in a detached worktree
// outside the repository renders every scene in en and de, light and dark (build/shots/<lang>-<appearance>/<id>.png).
// The app is never launched normally. The visual lenses open every picture; without pictures, or when a lens did not
// open all of them, sichtpruefung.status is "nicht geprüft". Nothing replaces the pictures.

const input = args ?? {}
const branch = input.branch ?? "HEAD"
const base = input.base ?? "origin/main"
const sparse = input.umfang === "sparsam"
const prefixes = Array.isArray(input.szenen) ? input.szenen.filter((value) => typeof value === "string" && value.length > 0) : []
const scope = [input.strang ? `Strang ${input.strang}` : null, input.paket ? `Paket ${input.paket}` : null].filter(Boolean).join(", ")

const LENSES = sparse
  ? [
      {
        key: "lauf",
        agentType: "pruefer-korrektheit",
        name: "Lauffähigkeit",
        focus:
          "Nur was den Build einer Modulkombination, make check, den Selbsttest oder die Abnahme bricht: Abstürze, falsche Daten, Datenabfluss, Konflikte mit main. Keine kleinen Befunde.",
      },
    ]
  : [
      {
        key: "korrektheit",
        agentType: "pruefer-korrektheit",
        name: "Korrektheit und Randfälle",
        focus: "Logik, Randfälle, Nebenläufigkeit unter Swift 6, Tests, die nichts prüfen, Doku, die dem Code widerspricht.",
      },
      {
        key: "anforderungen",
        agentType: "pruefer-korrektheit",
        name: "Anforderungen",
        focus:
          "Abgleich mit dem Paket in docs/agents/straenge.json (Inhalt und Abnahme) und docs/agents/PLAN.md, docs/agents/VORGABEN.md, docs/DECISIONS.md und docs/PROJECT.md. Fehlt etwas, das dieses Paket liefern muss? Widerspricht etwas einer Vorgabe oder Entscheidung?",
      },
      {
        key: "laie",
        agentType: "pruefer-laie-ux",
        name: "Laie und UX",
        focus: "Verständlichkeit ohne Fachwissen, Schreibregeln in beiden Sprachen, Zustände, Barrierefreiheit.",
        visual: true,
      },
      {
        key: "design",
        agentType: "pruefer-design",
        name: "Design",
        focus: "Tokens und Muster des Kits, Stil von macOS 26, hell und dunkel, Deutsch ohne Kürzung.",
        visual: true,
      },
      {
        key: "sicherheit",
        agentType: "pruefer-sicherheit",
        name: "Sicherheit und Datenschutz",
        focus: "Berechtigungen, Entitlements, Netz, Datenschutztexte, Dateizugriff, Kindprozesse, Geheimnisse.",
      },
      {
        key: "integration",
        agentType: "pruefer-integration",
        name: "Integration und Module",
        focus: "Datei-Zuständigkeit, Modul-Flags, Build-Matrix, Registry, Entfernbarkeit der Module, Konflikte mit anderen Branches.",
      },
    ]

const SEVERITIES = sparse ? ["blockierend", "wichtig"] : ["blockierend", "wichtig", "klein"]

const UI_PATH = /^App\/(?:Sources|Resources)\//
const VIEWS = ["en-light", "en-dark", "de-light", "de-dark"]
// One visual agent opens at most this many pictures; more pictures are split over several agents of the same lens.
const VISUAL_CHUNK = 48

const CAPTURE = {
  type: "object",
  properties: {
    changed_files: { type: "array", items: { type: "string" } },
    images: { type: "array", items: { type: "string" } },
    problem: { type: "string" },
  },
  required: ["changed_files", "images"],
}

const STRIKES = {
  type: "array",
  items: {
    type: "object",
    properties: {
      image: { type: "string" },
      kind: { type: "string", enum: ["weg", "doppelt", "box-in-box", "kante", "abgeschnitten"] },
      what: { type: "string" },
      proposal: { type: "string" },
    },
    required: ["image", "kind", "what", "proposal"],
  },
}

const FINDINGS = {
  type: "object",
  properties: {
    findings: {
      type: "array",
      items: {
        type: "object",
        properties: {
          severity: { type: "string", enum: SEVERITIES },
          file: { type: "string" },
          line: { type: "integer" },
          title: { type: "string" },
          problem: { type: "string" },
          fix: { type: "string" },
        },
        required: ["severity", "file", "line", "title", "problem", "fix"],
      },
    },
  },
  required: ["findings"],
}

const VISUAL_FINDINGS = {
  type: "object",
  properties: { ...FINDINGS.properties, seen: { type: "array", items: { type: "string" } }, strike_list: STRIKES },
  required: ["findings", "seen", "strike_list"],
}

const VERDICT = {
  type: "object",
  properties: {
    refuted: { type: "boolean" },
    reason: { type: "string" },
    severity: { type: "string", enum: ["blockierend", "wichtig", "klein"] },
    owner: { type: "string" },
    corrected_problem: { type: "string" },
    corrected_fix: { type: "string" },
  },
  required: ["refuted", "reason", "severity"],
}

// Every scene needs all four views (<lang>-<appearance> folders); a picture list with gaps counts as missing pictures.
function missingViews(images) {
  const present = new Set()
  const scenes = new Set()
  for (const image of images) {
    const parts = image.split("/")
    const scene = (parts[parts.length - 1] || "").replace(/\.png$/, "")
    const view = parts[parts.length - 2] || ""
    scenes.add(scene)
    present.add(`${view}/${scene}`)
  }
  return [...scenes].flatMap((scene) => VIEWS.filter((view) => !present.has(`${view}/${scene}`)).map((view) => `${view}/${scene}`))
}

function chunks(list, size) {
  const out = []
  for (let index = 0; index < list.length; index += size) out.push(list.slice(index, index + size))
  return out
}

const context = `Geprüft wird ${scope || "die Änderung"} auf ${branch} gegen ${base}. Arbeite nur lesend mit git gegen diese Refs (\`git diff ${base}...${branch}\`, \`git show ${branch}:<pfad>\`, \`git log ${base}..${branch}\`). Ändere nichts, committe nichts, wechsle den Checkout nicht, starte die App nie normal (kein make run, kein open). Statusdatei des Strangs: docs/agents/status/<kennung>.md. Was sie ausdrücklich als offen oder als Anfrage an andere führt, ist nur ein Befund, wenn der Ansatz falsch ist.`

const renderCommand =
  prefixes.length === 0
    ? "`make shots`"
    : prefixes.map((prefix, index) => `\`${index === 0 ? "" : "NO_BUILD=1 "}make shots ONLY=${prefix}\``).join(", dann ")

phase("Aufnehmen")
const capture = await agent(
  `${context}\n\nAufnehmen vor dem Finden. 1. \`git diff --name-only ${base}...${branch}\` ausführen und alle Pfade in changed_files zurückgeben. 2. Liegt einer davon unter App/Sources/ oder App/Resources/: den Stand ${branch} in einem eigenen Worktree außerhalb des Repositorys auschecken (\`git worktree add --detach <ordner> ${branch}\`), dort ${renderCommand} ausführen (rendert jede Szene in en und de, hell und dunkel, ohne Fenster auf dem Bildschirm) und die absoluten Pfade aller PNG-Dateien unter <ordner>/build/shots/ in images zurückgeben. Die Bilder an einen Ort außerhalb des Worktrees kopieren, der bestehen bleibt (etwa ein neuer Ordner unter dem Scratch-Verzeichnis der Session), und diese Pfade zurückgeben; danach den Worktree mit \`git worktree remove --force <ordner>\` entfernen und mit \`pgrep -fl <ordner>\` prüfen, dass kein Prozess mehr läuft. Scheitert ein Schritt, images leer lassen und in problem die entscheidende Ausgabe nennen. Ohne Änderung unter App/ images leer lassen. Keine Datei im Repository ändern.`,
  { label: "aufnehmen", phase: "Aufnehmen", schema: CAPTURE },
)
const changedFiles = capture?.changed_files ?? []
const uiChanged = capture === null || changedFiles.some((file) => UI_PATH.test(file))
const images = uiChanged ? (capture?.images ?? []) : []
const gaps = missingViews(images)
log(
  uiChanged
    ? `${images.length} Bilder aufgenommen${gaps.length > 0 ? `, es fehlen ${gaps.join(", ")}` : ""}`
    : "keine Änderung unter App/, keine Bilder nötig",
)

function visualPrompt(batch, part, parts) {
  return `Sichtprüfung (Pflicht): JEDES dieser Bilder mit dem Werkzeug Read öffnen und ansehen${parts > 1 ? ` (Teil ${part} von ${parts})` : ""}:\n${batch.join("\n")}\nDer Ordnername nennt Sprache und Erscheinungsbild (en-light, en-dark, de-light, de-dark), der Dateiname die Szene. Zusätzlich zu den Befunden eine Streichliste liefern: was weg kann (kind "weg"), was doppelt steht ("doppelt"), Kasten in Kasten ("box-in-box"), Inhalte ohne gemeinsame linke Kante ("kante") und abgeschnittene oder gekürzte Texte ("abgeschnitten"), jeweils mit Bild, was und Vorschlag. In seen den Pfad jedes wirklich geöffneten Bildes eintragen. Bei einem Befund aus einem Bild steht in file der Bildpfad und in line 0.`
}

// The sparse variant keeps one visual lens whenever the interface changed.
const lenses =
  sparse && uiChanged
    ? [...LENSES, { key: "sicht", agentType: "pruefer-laie-ux", name: "Sichtprüfung", focus: "Nur was auf den Bildern bricht oder weg kann.", visual: true }]
    : LENSES

// A visual lens with many pictures becomes several jobs of the same lens, one per batch of pictures.
const jobs = lenses.flatMap((lens) => {
  if (!lens.visual || images.length === 0) return [{ lens, batch: null, part: 1, parts: 1 }]
  const batches = chunks(images, VISUAL_CHUNK)
  return batches.map((batch, index) => ({ lens, batch, part: index + 1, parts: batches.length }))
})

phase("Finden")
// Two finders at a time; a barrier, because the merge step needs every finding to remove duplicates across lenses.
// A finder or refuter that died returns null; its lens or finding is reported as unchecked, never as "no findings".
const found = []
const unchecked = []
const visual = {}
for (let index = 0; index < jobs.length; index += 2) {
  const pair = jobs.slice(index, index + 2)
  const results = await parallel(
    pair.map(
      (job) => () =>
        agent(
          `${context}\n\nBlickwinkel: ${job.lens.name}. Schwerpunkt: ${job.lens.focus}\nMelde nur konkret belegte Probleme mit Datei und Zeile.${sparse ? " Nur blockierend und wichtig." : ""}${job.batch ? `\n\n${visualPrompt(job.batch, job.part, job.parts)}` : ""}`,
          {
            label: `finden:${job.lens.key}${job.parts > 1 ? `:${job.part}` : ""}`,
            phase: "Finden",
            agentType: job.lens.agentType,
            schema: job.batch ? VISUAL_FINDINGS : FINDINGS,
          },
        ).then((result) => ({ job, result })),
    ),
  )
  results.forEach((entry, position) => {
    const job = pair[position]
    if (!entry || !entry.result) {
      unchecked.push({ title: `Blickwinkel ${job.lens.name}${job.parts > 1 ? ` Teil ${job.part}` : ""} ohne Ergebnis`, reason: "Subagent ausgefallen oder übersprungen" })
      return
    }
    found.push(...entry.result.findings.map((finding) => ({ ...finding, lens: job.lens.key })))
    if (job.batch) {
      const record = visual[job.lens.key] ?? { seen: [], strikes: [] }
      record.seen.push(...(entry.result.seen ?? []))
      record.strikes.push(...(entry.result.strike_list ?? []))
      visual[job.lens.key] = record
    }
  })
}

log(`${found.length} Befunde aus ${jobs.length} Aufträgen in ${lenses.length} Blickwinkeln`)

// The visual check counts only when every picture of every scene in all four views was opened by every visual lens.
const visualKeys = lenses.filter((lens) => lens.visual).map((lens) => lens.key)
let sichtpruefung
if (!uiChanged)
  sichtpruefung = { status: "ohne Oberflächenänderung", grund: "keine Datei unter App/Sources oder App/Resources geändert", bilder: 0, gesehen: 0, streichliste: [] }
else if (images.length === 0)
  sichtpruefung = { status: "nicht geprüft", grund: `keine Bilder: ${capture?.problem || "Aufnehmen ohne Ergebnis"}`, bilder: 0, gesehen: 0, streichliste: [] }
else {
  const reasons = []
  if (gaps.length > 0) reasons.push(`Ansichten fehlen: ${gaps.join(", ")}`)
  let seenByAll = images.length
  for (const key of visualKeys) {
    const record = visual[key]
    if (!record) {
      reasons.push(`Blickwinkel ${key} ohne Ergebnis`)
      seenByAll = 0
      continue
    }
    const unseen = images.filter((image) => !record.seen.includes(image))
    if (unseen.length > 0) reasons.push(`${key}: nicht geöffnet ${unseen.join(", ")}`)
    seenByAll = Math.min(seenByAll, images.length - unseen.length)
  }
  const streichliste = visualKeys.flatMap((key) => visual[key]?.strikes ?? [])
  sichtpruefung =
    reasons.length > 0
      ? { status: "nicht geprüft", grund: reasons.join("; "), bilder: images.length, gesehen: seenByAll, streichliste }
      : { status: "geprüft", bilder: images.length, gesehen: images.length, streichliste }
}
if (sichtpruefung.status === "nicht geprüft") unchecked.push({ title: "Sichtprüfung nicht geprüft", reason: sichtpruefung.grund })
if (found.length === 0) return { confirmed: [], refuted: [], unchecked, sichtpruefung }

phase("Zusammenführen")
let merged = found
if (found.length > 1) {
  const result = await agent(
    `Führe diese Befunde zusammen: Befunde mit demselben Grundproblem (auch aus verschiedenen Blickwinkeln, Sprachen, Erscheinungsbildern oder an mehreren Stellen) werden zu einem Befund mit der höchsten Schwere, allen Fundstellen im Problemtext und dem Vorschlag, der das Grundproblem an allen Stellen behebt. Nichts erfinden, nichts weglassen, was kein Duplikat ist.\n${JSON.stringify(found)}`,
    { label: "zusammenfuehren", phase: "Zusammenführen", schema: FINDINGS, effort: "low" },
  )
  merged = result?.findings?.length ? result.findings : found
}

phase("Widerlegen")
const checked = []
for (let index = 0; index < merged.length; index += 2) {
  const pair = merged.slice(index, index + 2)
  const verdicts = await parallel(
    pair.map(
      (finding) => () =>
        agent(
          `${context}\n\nBefund: [${finding.severity}] ${finding.title}\nDatei: ${finding.file}:${finding.line}\nProblem: ${finding.problem}\nVorschlag: ${finding.fix}\n\nVersuche ihn zu widerlegen. Ist die Datei ein Bild, öffne es mit dem Werkzeug Read. Im Zweifel refuted=true. Ist ein anderer Strang zuständig, nenne ihn in owner.`,
          { label: `widerlegen:${finding.file}`, phase: "Widerlegen", agentType: "widerleger", schema: VERDICT, effort: "high" },
        ).then((verdict) => ({ ...finding, verdict: verdict ?? null })),
    ),
  )
  // parallel() turns a refuter that threw or failed into null; the finding stays and counts as unchecked.
  pair.forEach((finding, position) => checked.push(verdicts[position] ?? { ...finding, verdict: null, failed: true }))
}

const confirmed = checked
  .filter((finding) => finding.verdict && !finding.verdict.refuted)
  .map((finding) => ({
    severity: finding.verdict.severity,
    file: finding.file,
    line: finding.line,
    title: finding.title,
    problem: finding.verdict.corrected_problem || finding.problem,
    fix: finding.verdict.corrected_fix || finding.fix,
  }))
const refuted = checked
  .filter((finding) => finding.verdict && finding.verdict.refuted)
  .map((finding) => ({ title: finding.title, reason: finding.verdict.reason, owner: finding.verdict.owner }))
for (const finding of checked.filter((entry) => !entry.verdict))
  unchecked.push({
    title: finding.title,
    reason: `${finding.failed ? "Widerleger ausgefallen" : "ohne Urteil des Widerlegers"}, ${finding.file}:${finding.line}: ${finding.problem}`,
  })
log(`${confirmed.length} bestätigt, ${refuted.length} widerlegt, ${unchecked.length} ungeprüft`)
return { confirmed, refuted, unchecked, sichtpruefung }
