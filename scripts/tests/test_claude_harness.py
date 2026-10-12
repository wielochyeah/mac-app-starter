"""Tests for the agent harness in .claude/ (permissions, hooks, subagents, skills, red-team workflow) and the CI file.

Run: python3 -m unittest discover -s scripts/tests -t . (part of make test).
"""
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLAUDE = ROOT / ".claude"


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


session_start = load("session_start", CLAUDE / "hooks" / "session-start.py")
announce = load("announce_directives", CLAUDE / "hooks" / "announce-directives.py")


# Permission matching as Claude Code does it for Bash rules: "*" is any text, a trailing " *" or ":*" also matches the
# bare command; deny wins over ask, ask over allow.
def rule_matches(rule, command):
    match = re.fullmatch(r"Bash\((.*)\)", rule, re.S)
    if not match:
        return False
    pattern = match.group(1)
    if pattern.endswith(":*"):
        pattern = pattern[:-2] + " *"
    regex = "".join(".*" if char == "*" else re.escape(char) for char in pattern)
    if pattern.endswith(" *"):
        regex = regex[: -len(re.escape(" ") + ".*")] + "(?: .*)?"
    return re.fullmatch(regex, command, re.S) is not None


def decision(settings, command):
    permissions = settings["permissions"]
    for kind in ("deny", "ask", "allow"):
        if any(rule_matches(rule, command) for rule in permissions.get(kind, [])):
            return kind
    return "none"


class SettingsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.settings = json.loads((CLAUDE / "settings.json").read_text(encoding="utf-8"))

    def test_bypasses_and_destructive_commands_are_denied(self):
        for command in [
            "git commit --no-verify -m x",
            "git commit -m x --no-verify",
            "git commit -m x --no-ver",
            "git commit -n -m x",
            "git push --no-verify",
            "git push origin feature --no-veri",
            "git -c core.hooksPath=/dev/null commit -m x",
            "git config core.hooksPath /tmp/none",
            "git config --unset core.hooksPath",
            "git push --force origin feature",
            "git push origin +main",
            "git push origin feature -f",
            "git reset --hard HEAD~1",
            "git clean -fd",
            "git checkout .",
            "sudo rm -rf /",
            "make build && sudo make install",
            "printenv",
            "env",
            "tccutil reset All",
            "security find-generic-password -s x -w",
            "rm -f scripts/hooks/commit-msg",
        ]:
            self.assertEqual(decision(self.settings, command), "deny", command)

    def test_everyday_commands_are_not_denied(self):
        for command, expected in [
            ("make check", "allow"),
            ("make build MODULES=window,menubar", "allow"),
            ("make test ONLY=Settings", "allow"),
            ("make shots ONLY=island.", "allow"),
            ("git status", "allow"),
            ("git diff origin/main...HEAD", "allow"),
            ("STARTER_HEADLESS=1 build/Starter.app/Contents/MacOS/Starter --selftest", "allow"),
            ("grep -rn hooksPath scripts", "none"),
            ("git commit -m 'fix(island): keep the capsule below the menu bar'", "none"),
        ]:
            self.assertEqual(decision(self.settings, command), expected, command)

    def test_actions_with_side_effects_ask(self):
        for command in [
            "make run",
            "open build/Starter.app",
            "git push origin main",
            "bin/starter remove island",
            "bin/starter init --name Notes",
            "tccutil reset All com.example.starter",
            "xcrun notarytool submit build/dmg/Starter-1.0.0.dmg --wait",
            "rm -rf build",
        ]:
            self.assertEqual(decision(self.settings, command), "ask", command)

    def test_every_hook_command_names_an_existing_file(self):
        commands = [
            hook["command"]
            for entries in self.settings["hooks"].values()
            for entry in entries
            for hook in entry["hooks"]
        ]
        self.assertGreaterEqual(len(commands), 2)
        for command in commands:
            path = re.search(r'"\$CLAUDE_PROJECT_DIR/([^"]+)"', command).group(1)
            self.assertTrue((ROOT / path).is_file(), path)
            self.assertTrue(command.startswith("python3 "), command)


def fake_git(config):
    calls = []

    def git(args, cwd, timeout=10):
        calls.append(args)
        if args[:3] == ["git", "config", "--get"]:
            key = args[3]
            return (0, config[key] + "\n") if key in config else (1, "")
        if args[:2] == ["git", "config"] and len(args) == 4:
            config[args[2]] = args[3]
            return 0, ""
        return 1, "unexpected"

    return git, calls


class SessionStartTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write_config(self, commit):
        (self.tmp / "starter.json").write_text(json.dumps({"app": {}, "commit": commit}), encoding="utf-8")

    def test_identity_is_set_from_starter_json(self):
        self.write_config({"name": "Ada", "email": "ada@example.org"})
        config = {}
        git, _ = fake_git(config)
        line = session_start.identity_line(str(self.tmp), git)
        self.assertIn("gesetzt", line)
        self.assertEqual(config, {"user.name": "Ada", "user.email": "ada@example.org"})
        self.assertIn("passt", session_start.identity_line(str(self.tmp), git))

    def test_empty_identity_sets_nothing_and_says_so(self):
        self.write_config({"name": "", "email": ""})
        config = {"user.name": "Someone"}
        git, _ = fake_git(config)
        line = session_start.identity_line(str(self.tmp), git)
        self.assertIn("FEHLT", line)
        self.assertIn("nie erfinden", line)
        self.assertEqual(config, {"user.name": "Someone"})

    def test_broken_config_is_reported(self):
        (self.tmp / "starter.json").write_text("{", encoding="utf-8")
        self.assertIsNone(session_start.read_identity(str(self.tmp)))
        git, calls = fake_git({})
        self.assertIn("nichts gesetzt", session_start.identity_line(str(self.tmp), git))
        self.assertEqual(calls, [])

    def test_hooks_path_is_set_once(self):
        (self.tmp / "scripts" / "hooks").mkdir(parents=True)
        config = {}
        git, _ = fake_git(config)
        self.assertIn("eingerichtet", session_start.hooks_line(str(self.tmp), git))
        self.assertEqual(config["core.hooksPath"], "scripts/hooks")
        self.assertIn("aktiv", session_start.hooks_line(str(self.tmp), git))

    def test_missing_hooks_folder_changes_nothing(self):
        git, calls = fake_git({})
        self.assertIn("fehlt", session_start.hooks_line(str(self.tmp), git))
        self.assertEqual(calls, [])

    def test_doctor_summary(self):
        ready = "Required\n  ok    developer dir: /x\n  ok    SDK: /Library/SDKs/MacOSX26.5.sdk\n\ndoctor: ready to build\n"
        self.assertEqual(session_start.summarize_doctor(0, ready), "Werkzeuge: bereit für make build (SDK MacOSX26.5.sdk).")
        broken = "Required\n  FAIL  no usable macOS SDK\n  FAIL  python3 missing\ndoctor: 2 problem(s)\n"
        line = session_start.summarize_doctor(1, broken)
        self.assertIn("NICHT bereit", line)
        self.assertIn("no usable macOS SDK; python3 missing", line)
        self.assertIn("lief nicht", session_start.summarize_doctor(None, "timed out"))

    def test_doctor_is_skipped_off_macos(self):
        line = session_start.doctor_line(str(self.tmp), platform="linux", runner=lambda *a, **k: self.fail("ran doctor"))
        self.assertIn("kein Mac", line)

    def test_context_names_rules_and_headless_checks(self):
        self.write_config({"name": "Ada", "email": "ada@example.org"})
        git, _ = fake_git({})
        text = session_start.context(str(self.tmp), platform="linux", git=git)
        self.assertIn("docs/agents/VORGABEN.md", text)
        self.assertIn("STARTER_HEADLESS=1", text)


VORGABEN = """# Vorgaben

```
## V1 (TT.MM.JJJJ): <kurzer Titel>

Stand: offen
```

## V1 (01.11.2026): Insel nur mit Notch

Die Kapsel soll entfallen.

Stand: offen

## V2 (02.11.2026): Erledigt

Alt.

Stand: eingearbeitet in P-01, Commit abc123
"""


class AnnounceDirectivesTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        subprocess.run(["git", "init", "-q", str(self.tmp)], check=True)
        (self.tmp / "docs" / "agents").mkdir(parents=True)
        self.write(VORGABEN)
        self.payload = {"tool_name": "Edit", "session_id": "s1", "agent_id": "a1", "transcript_path": "/t"}

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write(self, text):
        (self.tmp / "docs" / "agents" / "VORGABEN.md").write_text(text, encoding="utf-8")

    def test_parse_skips_template_and_done_sections(self):
        sections = announce.parse(VORGABEN)
        self.assertEqual(list(sections), ["V1"])
        self.assertIn("Insel nur mit Notch", sections["V1"][0])
        self.assertIn("Kapsel soll entfallen", sections["V1"][1])

    def test_fingerprint_ignores_the_stand_line(self):
        self.assertEqual(announce.fingerprint("Text\n\nStand: offen"), announce.fingerprint("Text\n\nStand: in Arbeit"))
        self.assertNotEqual(announce.fingerprint("Text"), announce.fingerprint("Text, neu"))

    def test_writing_tools_only(self):
        self.assertTrue(announce.is_writing({"tool_name": "Write"}))
        self.assertTrue(announce.is_writing({"tool_name": "Bash", "tool_input": {"command": "git -C x commit -m y"}}))
        self.assertFalse(announce.is_writing({"tool_name": "Bash", "tool_input": {"command": "git log"}}))
        self.assertFalse(announce.is_writing({"tool_name": "Read"}))
        self.assertIsNone(announce.announce(str(self.tmp), {**self.payload, "tool_name": "Read"}))

    def test_each_directive_once_per_agent_and_again_after_a_change(self):
        first = announce.announce(str(self.tmp), self.payload)
        self.assertIn("NEUE VORGABEN", first)
        self.assertIn("V1", first)
        self.assertNotIn("V2", first)
        self.assertIsNone(announce.announce(str(self.tmp), self.payload))
        other = announce.announce(str(self.tmp), {**self.payload, "agent_id": "a2"})
        self.assertIn("V1", other)
        self.write(VORGABEN.replace("Die Kapsel soll entfallen.", "Die Kapsel bleibt, aber kleiner."))
        changed = announce.announce(str(self.tmp), self.payload)
        self.assertIn("(geändert)", changed)
        self.assertIn("kleiner", changed)

    def test_long_directives_point_to_the_file(self):
        self.write("# Vorgaben\n\n## V3 (03.11.2026): Lang\n\n" + "Wort " * 3000 + "\n\nStand: offen\n")
        text = announce.announce(str(self.tmp), self.payload)
        self.assertLessEqual(len(text.encode("utf-8")), announce.MAX_CONTEXT_BYTES)
        self.assertIn("VOLLSTÄNDIG LESEN", text)


def frontmatter(path):
    text = path.read_text(encoding="utf-8")
    match = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not match:
        return {}
    return dict(line.split(": ", 1) for line in match.group(1).splitlines() if ": " in line)


class AgentsAndSkillsTests(unittest.TestCase):
    def test_agents_are_read_only_and_named_like_their_file(self):
        agents = sorted((CLAUDE / "agents").glob("*.md"))
        names = {path.stem for path in agents}
        self.assertTrue({"pruefer-korrektheit", "pruefer-laie-ux", "pruefer-sicherheit", "pruefer-integration", "pruefer-design", "widerleger"} <= names)
        for path in agents:
            meta = frontmatter(path)
            self.assertEqual(meta.get("name"), path.stem, path)
            self.assertEqual(meta.get("tools"), "Read, Grep, Glob, Bash", path)
            self.assertIn("Ändert nichts", meta.get("description", ""), path)

    def test_skills_have_front_matter_and_steps(self):
        expected = {
            "neues-feature", "neue-ansicht", "neue-einstellung", "neuer-onboarding-schritt", "neue-berechtigung", "insel-zustand",
            "menueleisten-app", "hintergrund-job", "kurzbefehl", "ki-funktion", "screenshots", "red-team", "starter-rueckfluss", "release-dmg",
        }
        found = {path.parent.name for path in (CLAUDE / "skills").glob("*/SKILL.md")}
        self.assertTrue(expected <= found, expected - found)
        for name in found:
            path = CLAUDE / "skills" / name / "SKILL.md"
            meta = frontmatter(path)
            self.assertEqual(meta.get("name"), name, path)
            self.assertIn("Nutzen", meta.get("description", ""), path)
            self.assertIn("## Verträge und Dateien", path.read_text(encoding="utf-8"), path)

    def test_workflow_uses_existing_agents(self):
        script = (CLAUDE / "workflows" / "red-team.js").read_text(encoding="utf-8")
        for agent_type in set(re.findall(r'agentType: "([a-z-]+)"', script)):
            self.assertTrue((CLAUDE / "agents" / (agent_type + ".md")).is_file(), agent_type)
        self.assertNotRegex(script, r"Date\.now|Math\.random|new Date\(\)")


# The red-team workflow runs with stand-ins for agent(), parallel(), phase() and log() in JavaScriptCore
# (osascript -l JavaScript); promises settle after the top-level script, before run() returns the result.
JXA_HARNESS = r"""
var scenario = __SCENARIO__;
var calls = [];
var active = 0, maxActive = 0;
function tick() { return new Promise(function (resolve) { resolve(); }); }
async function agent(prompt, opts) {
  opts = opts || {};
  active += 1; maxActive = Math.max(maxActive, active);
  await tick(); await tick();
  active -= 1;
  calls.push({ label: opts.label, agentType: opts.agentType || null, prompt: prompt });
  var label = opts.label || "";
  if (label === "aufnehmen") return scenario.capture;
  if (label.indexOf("finden:") === 0) {
    var key = label.split(":")[1];
    if ((scenario.dead || []).indexOf(key) >= 0) return null;
    var images = prompt.split("\n").filter(function (line) { return /\.png$/.test(line); });
    var skip = scenario.skipSeen || "";
    var result = { findings: (scenario.findings && scenario.findings[key]) || [] };
    if (opts.schema && opts.schema.required.indexOf("seen") >= 0) {
      result.seen = images.filter(function (image) { return image !== skip; });
      result.strike_list = [];
    }
    return result;
  }
  if (label === "zusammenfuehren") return null;
  if (label.indexOf("widerlegen:") === 0) return { refuted: false, reason: "belegt", severity: "wichtig" };
  return null;
}
async function parallel(thunks) { return Promise.all(thunks.map(function (thunk) { return thunk().catch(function () { return null; }); })); }
function phase() {}
function log() {}
var output = "pending";
(async function (args, agent, parallel, phase, log) {
__BODY__
})(scenario.args, agent, parallel, phase, log).then(
  function (value) { output = JSON.stringify({ result: value, calls: calls, maxActive: maxActive }); },
  function (error) { output = JSON.stringify({ error: String(error) }); }
);
function run() { return output; }
"""


def images_for(scenes, views=("en-light", "en-dark", "de-light", "de-dark")):
    return ["/tmp/shots/{}/{}.png".format(view, scene) for scene in scenes for view in views]


@unittest.skipUnless(sys.platform == "darwin" and shutil.which("osascript"), "needs JavaScriptCore through osascript (macOS)")
class RedTeamWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (CLAUDE / "workflows" / "red-team.js").read_text(encoding="utf-8")
        cls.body = re.sub(r"\Aexport const meta = \{.*?^\}\n", "", source, count=1, flags=re.S | re.M)
        assert not cls.body.startswith("export"), "meta block not stripped"

    def run_workflow(self, scenario):
        script = JXA_HARNESS.replace("__SCENARIO__", json.dumps(scenario)).replace("__BODY__", self.body)
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as handle:
            handle.write(script)
            path = handle.name
        try:
            result = subprocess.run(["osascript", "-l", "JavaScript", path], capture_output=True, text=True, timeout=60)
        finally:
            os.unlink(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertNotIn("error", data, data.get("error"))
        return data

    def finders(self, data):
        return [call for call in data["calls"] if (call["label"] or "").startswith("finden:")]

    def test_ui_change_renders_first_and_checks_every_picture(self):
        images = images_for(["island.done-card", "settings.general"])
        finding = {"severity": "wichtig", "file": "App/Sources/Modules/Island/IslandView.swift", "line": 3, "title": "t", "problem": "p", "fix": "f"}
        data = self.run_workflow({
            "args": {"strang": "C"},
            "capture": {"changed_files": ["App/Sources/Modules/Island/IslandView.swift"], "images": images},
            "findings": {"korrektheit": [finding]},
        })
        self.assertEqual(data["calls"][0]["label"], "aufnehmen")
        self.assertIn("make shots", data["calls"][0]["prompt"])
        self.assertLessEqual(data["maxActive"], 2)
        self.assertEqual(sorted(call["label"].split(":")[1] for call in self.finders(data)),
                         ["anforderungen", "design", "integration", "korrektheit", "laie", "sicherheit"])
        visual = [call for call in self.finders(data) if call["agentType"] in ("pruefer-laie-ux", "pruefer-design")]
        for call in visual:
            for image in images:
                self.assertIn(image, call["prompt"])
        result = data["result"]
        self.assertEqual(result["sichtpruefung"]["status"], "geprüft")
        self.assertEqual(result["sichtpruefung"]["bilder"], 8)
        self.assertEqual(len(result["confirmed"]), 1)
        self.assertEqual(result["unchecked"], [])

    def test_without_ui_change_no_pictures_are_needed(self):
        data = self.run_workflow({"args": {}, "capture": {"changed_files": ["docs/KI.md"], "images": []}})
        self.assertEqual(data["result"]["sichtpruefung"]["status"], "ohne Oberflächenänderung")
        for call in self.finders(data):
            self.assertNotIn("Sichtprüfung (Pflicht)", call["prompt"])

    def test_missing_view_means_not_checked(self):
        images = images_for(["window.main"])[:-1]
        data = self.run_workflow({"args": {}, "capture": {"changed_files": ["App/Sources/Modules/Window/W.swift"], "images": images}})
        status = data["result"]["sichtpruefung"]
        self.assertEqual(status["status"], "nicht geprüft")
        self.assertIn("de-dark/window.main", status["grund"])
        self.assertTrue(any(entry["title"] == "Sichtprüfung nicht geprüft" for entry in data["result"]["unchecked"]))

    def test_no_pictures_for_a_ui_change_means_not_checked(self):
        data = self.run_workflow({"args": {}, "capture": {"changed_files": ["App/Resources/InfoPlist.json"], "images": [], "problem": "make shots: swiftc failed"}})
        self.assertEqual(data["result"]["sichtpruefung"]["status"], "nicht geprüft")
        self.assertIn("swiftc failed", data["result"]["sichtpruefung"]["grund"])

    def test_dead_lens_is_unchecked_not_clean(self):
        data = self.run_workflow({"args": {}, "capture": {"changed_files": ["scripts/x.py"], "images": []}, "dead": ["sicherheit"]})
        titles = [entry["title"] for entry in data["result"]["unchecked"]]
        self.assertIn("Blickwinkel Sicherheit und Datenschutz ohne Ergebnis", titles)

    def test_unopened_picture_means_not_checked(self):
        images = images_for(["menubar.panel"])
        data = self.run_workflow({
            "args": {},
            "capture": {"changed_files": ["App/Sources/Modules/MenuBar/P.swift"], "images": images},
            "skipSeen": images[2],
        })
        status = data["result"]["sichtpruefung"]
        self.assertEqual(status["status"], "nicht geprüft")
        self.assertIn(images[2], status["grund"])

    def test_many_pictures_are_split_over_several_agents(self):
        images = images_for(["window.scene-{}".format(index) for index in range(25)])
        data = self.run_workflow({"args": {}, "capture": {"changed_files": ["App/Sources/Kit/Design/Theme.swift"], "images": images}})
        laie = [call for call in self.finders(data) if call["label"].startswith("finden:laie")]
        self.assertEqual(len(laie), 3)
        self.assertLessEqual(data["maxActive"], 2)
        self.assertEqual(data["result"]["sichtpruefung"]["status"], "geprüft")
        self.assertEqual(data["result"]["sichtpruefung"]["gesehen"], 100)

    def test_sparse_mode_keeps_one_lens_and_the_visual_check(self):
        images = images_for(["hotkeys.pane"])
        data = self.run_workflow({"args": {"umfang": "sparsam", "szenen": ["hotkeys."]},
                                  "capture": {"changed_files": ["App/Sources/Modules/Hotkeys/H.swift"], "images": images}})
        self.assertEqual(sorted(call["label"] for call in self.finders(data)), ["finden:lauf", "finden:sicht"])
        self.assertIn("make shots ONLY=hotkeys.", data["calls"][0]["prompt"])


class CiTests(unittest.TestCase):
    def test_ci_runs_every_gate(self):
        ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        for needle in ["make check-rules", "make check-texts", "make check-design", "make check-kit", "make build", "make test",
                       "make shots", "--selftest", "check_commit_msg.py", "bin/starter init", "bin/starter remove", "persist-credentials: false"]:
            self.assertIn(needle, ci)
        self.assertNotIn("continue-on-error: true", ci)
        self.assertNotRegex(ci, r"if:\s*false")


if __name__ == "__main__":
    unittest.main()
