#if TESTING
#if MODUL_MLX
import AppKit
import SwiftUI

/// The MLX module: protocol codecs, policies, catalog, cache layout, and the real client and
/// downloader against ai-worker/fake_worker.py and ai-worker/tests/fake_download.py (no model, no
/// network). Python: the system /usr/bin/python3 (the fakes use only the standard library).
final class MLXTests: TestSuite {
    static let python = URL(fileURLWithPath: "/usr/bin/python3")
    static var workerDir: URL { repoRoot.appendingPathComponent("ai-worker", isDirectory: true) }

    static func fakeClient(_ flags: [String] = [], log: URL? = nil) -> MLXWorkerClient {
        MLXWorkerClient {
            .init(executable: python, arguments: [workerDir.appendingPathComponent("fake_worker.py").path] + flags,
                  environment: ["PYTHONDONTWRITEBYTECODE": "1"], log: log)
        }
    }

    static func generate(_ client: MLXWorkerClient, _ prompt: String = "eins zwei drei", timeout: TimeInterval? = nil,
                         wait: TimeInterval = 10, onToken: ((String) -> Void)? = nil) -> AIWait.Outcome<MLXWorkerClient.GenerateResult> {
        AIWait.run(timeout: wait) {
            try await client.generate(prompt: prompt, system: nil, model: "/fake/model", maxTokens: 64, timeout: timeout, onToken: onToken)
        }
    }

    static func error<T>(_ outcome: AIWait.Outcome<T>) -> AIError? {
        if case .failure(let e) = outcome { return e as? AIError }
        return nil
    }

    override class func register() {
        // MARK: Pure parts

        test("worker events parse") {
            expectEqual(WorkerEvent.parse(#"{"event":"ready","protocol":1,"pid":42}"#), .ready(pid: 42))
            expectEqual(WorkerEvent.parse(#"{"event":"pong","id":3,"loaded":"/m","busy":true}"#), .pong(id: 3, loaded: "/m", busy: true))
            expectEqual(WorkerEvent.parse(#"{"event":"started","id":7}"#), .started(id: 7))
            expectEqual(WorkerEvent.parse(#"{"event":"token","id":7,"text":" Grüße"}"#), .token(id: 7, text: " Grüße"))
            expectEqual(WorkerEvent.parse(#"{"event":"done","id":7,"text":"Hallo","stats":{"tokens":3,"tps":120.5,"eval_s":0.1,"load_s":2}}"#),
                        .done(id: 7, text: "Hallo", model: nil, cancelled: false,
                              stats: WorkerStats(tokens: 3, tokensPerSecond: 120.5, loadSeconds: 2, evalSeconds: 0.1)))
            expectEqual(WorkerEvent.parse(#"{"event":"done","id":2,"model":"/m","load_s":1.5}"#),
                        .done(id: 2, text: nil, model: "/m", cancelled: false, stats: WorkerStats(loadSeconds: 1.5)))
            expectEqual(WorkerEvent.parse(#"{"event":"done","id":9,"cancelled":true}"#),
                        .done(id: 9, text: nil, model: nil, cancelled: true, stats: WorkerStats()))
            expectEqual(WorkerEvent.parse(#"{"event":"error","id":4,"kind":"load-failed","error":"nope"}"#),
                        .error(id: 4, kind: "load-failed", message: "nope"))
            expectEqual(WorkerEvent.parse(#"{"event":"error","id":null,"kind":"bad-request","error":"x"}"#),
                        .error(id: nil, kind: "bad-request", message: "x"))
            expectEqual(WorkerEvent.parse(#"{"event":"exit","reason":"idle"}"#), .exit(reason: "idle"))
            expectEqual(WorkerEvent.parse("library chatter"), .unknown("library chatter"))
            expectEqual(WorkerEvent.parse(#"{"event":"started"}"#), .unknown(#"{"event":"started"}"#))
        }

        test("requests are one sorted JSON line") {
            let line = WorkerRequest.generate(id: 5, prompt: "Hallo \"Welt\"\n", system: "", model: "/a/b", maxTokens: 100,
                                              temperature: 0, stream: true)
            expect(line.hasSuffix("\n") && line.dropLast().contains("\n") == false, line)
            let o = JSONLine.object(String(line.dropLast()))
            expectEqual(o?["op"], .string("generate"))
            expectEqual(o?["prompt"], .string("Hallo \"Welt\"\n"))
            expectEqual(o?["model"], .string("/a/b"))
            expectEqual(o?["stream"], .bool(true))
            expect(o?["system"] == nil, "empty system is left out")
            expect(line.hasPrefix(#"{"id":5,"loop_guard":true,"max_tokens":100"#), line)
            expectEqual(WorkerRequest.cancel(id: 5), "{\"id\":5,\"op\":\"cancel\"}\n")
            expectEqual(WorkerRequest.shutdown, "{\"op\":\"shutdown\"}\n")
        }

        test("download events parse") {
            expectEqual(DownloadEvent.parse(#"{"event":"start","repo":"a/b","total":100}"#), .start(total: 100))
            expectEqual(DownloadEvent.parse(#"{"event":"progress","done":40,"total":100}"#), .progress(done: 40, total: 100))
            expectEqual(DownloadEvent.parse(#"{"event":"done","path":"/p","total":100}"#), .done(path: "/p", total: 100))
            expectEqual(DownloadEvent.parse(#"{"event":"error","kind":"offline","error":"x","done":40,"total":100}"#),
                        .error(kind: "offline", message: "x", done: 40, total: 100))
            if case .unknown = DownloadEvent.parse("{") {} else { fail("broken line is unknown") }
        }

        test("restart backoff is 0, 5, 30, 300 s") {
            let p = RestartPolicy()
            expectEqual([0, 1, 2, 3, 4, 9].map { p.delay(afterCrashes: $0) }, [0, 0, 5, 30, 300, 300])
            let crash = Date(timeIntervalSince1970: 1000)
            expectEqual(p.wait(crashes: 2, lastCrash: crash, now: crash.addingTimeInterval(2)), 3)
            expectEqual(p.wait(crashes: 2, lastCrash: crash, now: crash.addingTimeInterval(9)), 0)
            expectEqual(p.wait(crashes: 1, lastCrash: crash, now: crash), 0)
            expectEqual(p.wait(crashes: 3, lastCrash: nil, now: crash), 0)
        }

        test("budgets grow with the input and stop at a ceiling") {
            expectEqual(WorkerBudget.maxTokens(promptCharacters: 0), 256)
            expectEqual(WorkerBudget.maxTokens(promptCharacters: 1000), 756)
            expectEqual(WorkerBudget.maxTokens(promptCharacters: 100_000), 2048)
            expectEqual(WorkerBudget.timeout(maxTokens: 200), 30)
            expectEqual(WorkerBudget.timeout(maxTokens: 100_000), 300)
        }

        test("line buffer joins chunks and keeps split characters") {
            let b = LineBuffer()
            let bytes = Array("{\"a\":\"Grüße\"}\n{\"b\":1}\npartial".utf8)
            let cut = 7   // inside "ü"
            expectEqual(b.append(Data(bytes[..<cut])), [])
            expectEqual(b.append(Data(bytes[cut...])), ["{\"a\":\"Grüße\"}", "{\"b\":1}"])
            expectEqual(b.append(Data(" end\n\n".utf8)), ["partial end"])
        }

        test("built-in catalog matches ai-worker/models.json") {
            do {
                let file = try ModelCatalog.load(workerDir.appendingPathComponent("models.json"))
                expectEqual(file, ModelCatalog.builtIn)
            } catch {
                fail("models.json: \(error)")
            }
            expect(ModelCatalog.builtIn.defaultModel.map { $0.bytes <= 1_000_000_000 } ?? false, "default model at most 1 GB")
        }

        test("catalog validation") {
            let m = ModelSpec(id: "a", role: "fast", name: "A", repo: "o/a", bytes: 1)
            expectThrows { try ModelCatalog(version: 1, defaultID: "a", models: []).validate() }
            expectThrows { try ModelCatalog(version: 1, defaultID: "a", models: [m, m]).validate() }
            expectThrows { try ModelCatalog(version: 1, defaultID: "b", models: [m]).validate() }
            expectThrows { try ModelCatalog(version: 1, defaultID: "a", models: [ModelSpec(id: "a", role: "fast", name: "A", repo: "noslash", bytes: 1)]).validate() }
            do { try ModelCatalog(version: 1, defaultID: "a", models: [m]).validate() } catch { fail("valid catalog: \(error)") }
        }

        test("the models folder is created on a download and kept out of backups") {
            let hfHome = tempDir().appendingPathComponent("Models/huggingface", isDirectory: true)
            let folder = MLXPaths.prepareModelsFolder(hfHome)
            expectEqual(folder.lastPathComponent, "Models")
            let values = try folder.resourceValues(forKeys: [.isExcludedFromBackupKey])
            expectEqual(values.isExcludedFromBackup, true)
        }

        test("hub cache: complete snapshots only, blob bytes include partial files") {
            let hub = tempDir()
            let fm = FileManager.default
            let repo = HubCache.repoDir(hub: hub, repo: "org/model")
            expect(repo.lastPathComponent == "models--org--model")
            let blobs = repo.appendingPathComponent("blobs")
            try fm.createDirectory(at: blobs, withIntermediateDirectories: true)
            fm.createFile(atPath: blobs.appendingPathComponent("cfg").path, contents: Data("{}".utf8))
            fm.createFile(atPath: blobs.appendingPathComponent("w.incomplete").path, contents: Data(count: 100))
            try fm.createSymbolicLink(at: blobs.appendingPathComponent("link"), withDestinationURL: blobs.appendingPathComponent("cfg"))
            expectEqual(HubCache.blobBytes(hub: hub, repo: "org/model"), 102)
            let snap = repo.appendingPathComponent("snapshots/rev1")
            try fm.createDirectory(at: snap, withIntermediateDirectories: true)
            try fm.createSymbolicLink(at: snap.appendingPathComponent("config.json"), withDestinationURL: blobs.appendingPathComponent("cfg"))
            try fm.createSymbolicLink(at: snap.appendingPathComponent("model.safetensors"), withDestinationURL: blobs.appendingPathComponent("w"))
            expect(HubCache.snapshot(hub: hub, repo: "org/model", revision: "rev1") == nil, "weights blob still incomplete")
            try fm.moveItem(at: blobs.appendingPathComponent("w.incomplete"), to: blobs.appendingPathComponent("w"))
            expectEqual(HubCache.snapshot(hub: hub, repo: "org/model", revision: "rev1")?.lastPathComponent, "rev1")
            expectEqual(HubCache.snapshot(hub: hub, repo: "org/model", revision: nil)?.lastPathComponent, "rev1")
            expect(HubCache.snapshot(hub: hub, repo: "org/model", revision: "other") == nil)
            try HubCache.remove(hub: hub, repo: "org/model")
            expect(!fm.fileExists(atPath: repo.path))
        }

        test("hub cache: a sharded model is complete only with every shard") {
            let hub = tempDir()
            let fm = FileManager.default
            let repo = HubCache.repoDir(hub: hub, repo: "org/big")
            let blobs = repo.appendingPathComponent("blobs"), snap = repo.appendingPathComponent("snapshots/r")
            try fm.createDirectory(at: blobs, withIntermediateDirectories: true)
            try fm.createDirectory(at: snap, withIntermediateDirectories: true)
            let index = #"{"weight_map": {"a": "model-00001-of-00002.safetensors", "b": "model-00002-of-00002.safetensors"}}"#
            for (name, body) in [("cfg", "{}"), ("idx", index), ("s1", "1"), ("s2", "2")] {
                fm.createFile(atPath: blobs.appendingPathComponent(name).path, contents: Data(body.utf8))
            }
            func link(_ name: String, _ blob: String) throws {
                try fm.createSymbolicLink(atPath: snap.appendingPathComponent(name).path, withDestinationPath: "../../blobs/" + blob)
            }
            try link("config.json", "cfg")
            try link(HubCache.weightsIndex, "idx")
            try link("model-00001-of-00002.safetensors", "s1")
            expect(HubCache.snapshot(hub: hub, repo: "org/big", revision: "r") == nil, "one shard of two")
            try link("model-00002-of-00002.safetensors", "s2")
            expectEqual(HubCache.snapshot(hub: hub, repo: "org/big", revision: "r")?.lastPathComponent, "r")
        }

        test("MLX availability: fix the first missing piece first") {
            expectEqual(MLXProvider.availability(appleSilicon: false, systemOK: false, installed: false, modelPresent: false),
                        .unavailable(.unsupportedHardware))
            expectEqual(MLXProvider.availability(appleSilicon: true, systemOK: false, installed: true, modelPresent: true),
                        .unavailable(.systemTooOld))
            expectEqual(MLXProvider.availability(appleSilicon: true, systemOK: true, installed: false, modelPresent: true),
                        .unavailable(.notInstalled))
            expectEqual(MLXProvider.availability(appleSilicon: true, systemOK: true, installed: true, modelPresent: false),
                        .unavailable(.modelMissing))
            expectEqual(MLXProvider.availability(appleSilicon: true, systemOK: true, installed: true, modelPresent: true), .available)
        }

        test("download footnote follows VoiceBud's states") {
            Localizer.shared.forced = .en
            defer { Localizer.shared.forced = nil }
            let f: ([String: ModelDownloads.State], String) -> String = { MLXSectionModel.footnote($0, selected: $1) }
            expectEqual(f(["a": .paused(done: 1, total: 2, problem: "offline"), "b": .running(done: 1, total: 2)], "a"), MLXText.noteOffline)
            expectEqual(f(["a": .paused(done: 1, total: 2, problem: "failed")], "a"), MLXText.noteFailed)
            expectEqual(f(["a": .paused(done: 1, total: 2, problem: "cancelled"), "b": .queued], "a"), MLXText.noteRunning)
            expectEqual(f(["a": .done, "b": .notStarted], "a"), MLXText.noteReady)
            expectEqual(f(["a": .notStarted, "b": .done], "a"), MLXText.noteNothing)
            expectEqual(MLXSectionModel.footnote(["a": .done], selected: "a", installed: false),
                        MLXText.noteNotInstalled(developer: AIBuild.canSetUpMLX))
            expectEqual(f(["a": .paused(done: 0, total: 2, problem: "setup")], "a"), MLXText.noteNothing,
                        "a download that never ran is no failure")
        }

        test("without MLX set up: no Download chip, no retry, no onboarding row; release copy names no script") {
            Localizer.shared.forced = .en
            defer { Localizer.shared.forced = nil }
            let spec = ModelCatalog.builtIn.model("small")!
            expectEqual(MLXSectionModel.row(spec, .paused(done: 0, total: 1, problem: "setup")).phase, .notStarted(total: spec.bytes))
            let scene = MLXScenes.sectionModel(.notInstalled)
            expect(!scene.installed)
            let step = MLXScenes.sections(.notInstalled)
            expect(step.first?.onboarding != nil)
            let user = MLXText.noteNotInstalled(developer: false) + AIText.notInstalledHint(developer: false)
            expect(!user.contains("setup.sh") && !user.contains("ai-worker"), user)
            expect(MLXText.noteNotInstalled(developer: true).contains("setup.sh"))
        }

        // MARK: Client against fake_worker.py

        test("client streams pieces and returns the answer") {
            let client = fakeClient()
            defer { client.shutdown() }
            var pieces: [String] = []
            let out = generate(client, "eins zwei drei") { pieces.append($0) }
            guard case .value(let r) = out else { return fail("\(out)") }
            expectEqual(r.text, "echo: eins zwei drei")
            expectEqual(pieces.joined(), r.text)
            expectEqual(r.stats.tokens, 4)
            expectEqual(client.loadedModel, "/fake/model")
            expectEqual(client.phase, .running)
            expectEqual(client.starts, 1)
        }

        test("ping answers while a generation runs") {
            let client = fakeClient(["--gen", "0.2"])
            defer { client.shutdown() }
            let out = AIWait.run(timeout: 10) { () async throws -> Bool in
                let task = Task { @MainActor in
                    try await client.generate(prompt: "a b c d", system: nil, model: "/m", maxTokens: 10)
                }
                try await Task.sleep(for: .milliseconds(300))
                let pong = try await client.ping()
                _ = try await task.value
                return pong.busy
            }
            guard case .value(let busy) = out else { return fail("\(out)") }
            expect(busy, "pong says busy")
        }

        test("cancelling the Task stops the generation, the worker stays") {
            let client = fakeClient(["--gen", "0.1"])
            defer { client.shutdown() }
            var first = false
            let out = AIWait.run(timeout: 10) { () async throws -> AIError? in
                let task = Task { @MainActor in
                    try await client.generate(prompt: String(repeating: "w ", count: 100), system: nil, model: "/m",
                                              maxTokens: 10) { _ in first = true }
                }
                while !first { try await Task.sleep(for: .milliseconds(10)) }
                let t = Date()
                task.cancel()
                do { _ = try await task.value } catch {
                    return Date().timeIntervalSince(t) < 1 ? AIError.from(error) : .failed("slow cancel")
                }
                return nil
            }
            guard case .value(let e) = out else { return fail("\(out)") }
            expectEqual(e, .cancelled)
            expect(client.isRunning, "a cancel does not stop the worker")
            expect(client.openRequests.isEmpty)
            guard case .value = generate(client, "danach") else { return fail("next request after cancel") }
            expectEqual(client.starts, 1)
        }

        test("a cancel the worker never confirms: the stuck worker is stopped, the next request starts fresh") {
            let client = fakeClient(["--hang"])
            client.cancelGrace = 1
            defer { client.shutdown() }
            let out = AIWait.run(timeout: 10) { () async throws -> AIError? in
                let task = Task { @MainActor in
                    try await client.generate(prompt: "x", system: nil, model: "/m", maxTokens: 10, timeout: 30)
                }
                try await Task.sleep(for: .milliseconds(800))
                task.cancel()
                do { _ = try await task.value } catch { return AIError.from(error) }
                return nil
            }
            guard case .value(let e) = out else { return fail("\(out)") }
            expectEqual(e, .cancelled)
            expect(AIWait.until(timeout: 4) { !client.isRunning }, "the stuck worker was stopped")
            expectEqual(client.crashes, 0, "our own kill is not a crash")
            expectEqual(client.phase, .stopped, "no back-off before the next start")
            let t = Date()
            expectEqual(error(generate(client, timeout: 0.5, wait: 10)), .timeout)
            expect(Date().timeIntervalSince(t) < 4, "the next request did not queue behind the stuck one")
            expectEqual(client.starts, 2)
        }

        test("timeout counts from started: a slow load is fine, a hang is killed") {
            let slowLoad = fakeClient(["--load", "1.0"])
            defer { slowLoad.shutdown() }
            guard case .value = generate(slowLoad, timeout: 0.5) else { return fail("load time counted against the timeout") }

            let hang = fakeClient(["--hang"])
            defer { hang.shutdown() }
            let t = Date()
            let out = generate(hang, timeout: 0.5)
            expectEqual(error(out), .timeout)
            expect(Date().timeIntervalSince(t) < 3, "timed out in time")
            expect(AIWait.until(timeout: 3) { !hang.isRunning }, "hung worker was stopped")
            expectEqual(hang.crashes, 0, "our own kill is not a crash")
            _ = generate(hang, timeout: 0.3)
            expectEqual(hang.starts, 2, "next request starts a fresh worker")
        }

        test("crash: one retry, then back off 5 s") {
            var crashy = true
            let client = MLXWorkerClient {
                .init(executable: python, arguments: [workerDir.appendingPathComponent("fake_worker.py").path] + (crashy ? ["--crash"] : []),
                      environment: [:], log: nil)
            }
            defer { client.shutdown() }
            var clock = Date()
            client.now = { clock }
            expectEqual(error(generate(client)), .workerCrashed)
            expectEqual(client.starts, 2, "sent once more on a fresh worker")
            expectEqual(client.crashes, 2)
            if case .restarting(let wait) = error(generate(client)) { expectEqual(wait, 5) } else { fail("expected a backoff") }
            expectEqual(client.starts, 2, "no start during the backoff")
            crashy = false
            clock = clock.addingTimeInterval(6)
            guard case .value(let r) = generate(client) else { return fail("no answer after the backoff") }
            expectEqual(r.text, "echo: eins zwei drei")
            expectEqual(client.crashes, 0, "an answer resets the count")
        }

        test("a crash mid-answer: the stream starts over, never two answers glued together") {
            let tmp = tempDir()
            let client = fakeClient(["--crash-after", "2", "--marker", tmp.appendingPathComponent("crashed").path])
            defer { client.shutdown() }
            let hub = tmp.appendingPathComponent("hub")
            fakeModel(hub)
            let provider = MLXProvider(client: client, downloads: ModelDownloads(catalog: .builtIn, hub: hub) { _ in nil },
                                       settings: Settings(fileURL: tmp.appendingPathComponent("s.json")), isInstalled: { true })
            var snaps: [String] = []
            let out = AIWait.run(timeout: 10) { () async throws -> String in
                for try await s in provider.stream(AIRequest(prompt: "eins zwei drei", instructions: nil, maxTokens: 20)) { snaps.append(s) }
                return snaps.last ?? ""
            }
            guard case .value(let text) = out else { return fail("no answer: \(out)") }
            expectEqual(text, "echo: eins zwei drei")
            expectEqual(client.starts, 2, "sent once more after the crash")
            expect(snaps.contains(""), "the restart was signalled: \(snaps)")
            for (a, b) in zip(snaps, snaps.dropFirst()) where !(b.hasPrefix(a) || b.isEmpty) {
                fail("snapshot \(b.debugDescription) does not continue \(a.debugDescription)")
            }
            expect(!snaps.contains { $0.components(separatedBy: "echo:").count > 2 }, "\(snaps)")
        }

        test("a worker that dies before ready is a crash") {
            let client = fakeClient(["--crash-at-start"])
            defer { client.shutdown() }
            expectEqual(error(generate(client)), .workerCrashed)
            expectEqual(client.crashes, 2)
        }

        test("idle exit is not a crash; the next request starts it again") {
            let client = fakeClient(["--idle", "1"])
            defer { client.shutdown() }
            guard case .value = generate(client) else { return fail("first answer") }
            expect(AIWait.until(timeout: 5) { !client.isRunning }, "worker exits when idle")
            expectEqual(client.phase, .stopped)
            expectEqual(client.crashes, 0)
            expect(client.loadedModel == nil)
            guard case .value = generate(client) else { return fail("answer after idle exit") }
            expectEqual(client.starts, 2)
        }

        test("worker errors and a missing install map to AIError") {
            let client = fakeClient()
            defer { client.shutdown() }
            let out = AIWait.run(timeout: 5) { try await client.load(model: "/models/missing") }
            if case .failed(let why) = error(out) { expect(why.contains("load-failed"), why) } else { fail("\(out)") }
            let none = MLXWorkerClient { nil }
            expectEqual(error(generate(none)), .unavailable(.notInstalled))
        }

        test("shutdown ends the process and open requests") {
            let client = fakeClient(["--gen", "0.5"])
            var result: AIError?
            let task = Task { @MainActor in
                do { _ = try await client.generate(prompt: "a b c d e f", system: nil, model: "/m", maxTokens: 10) }
                catch { result = AIError.from(error) }
            }
            expect(AIWait.until(timeout: 5) { client.phase == .running && !client.openRequests.isEmpty })
            client.shutdown()
            expect(!client.isRunning)
            expect(AIWait.until(timeout: 2) { result != nil })
            expectEqual(result, .cancelled)
            _ = task
        }

        test("worker stderr goes to the log, never into the protocol") {
            let log = tempDir().appendingPathComponent("worker.log")
            let client = fakeClient(["--noise"], log: log)
            defer { client.shutdown() }
            guard case .value(let r) = generate(client) else { return fail("answer with noise") }
            expectEqual(r.text, "echo: eins zwei drei")
            let text = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
            expect(text.contains("chatter"), "library output in the log")
        }

        // MARK: Downloads against fake_download.py

        test("download: progress, done, provider notified") {
            let (downloads, hub) = makeDownloads("ok")
            var finished: [String] = []
            downloads.onFinished = { finished.append($0) }
            expectEqual(downloads.state("small"), .notStarted)
            var sawProgress = false
            downloads.start("small")
            expectEqual(downloads.isBusy, true)
            expect(AIWait.until(timeout: 10) {
                if case .running(let d, _) = downloads.state("small"), d > 0 { sawProgress = true }
                return downloads.state("small") == .done
            }, "download finished: \(downloads.state("small"))")
            expect(sawProgress, "progress was reported")
            expect(AIWait.until(timeout: 5) { !downloads.isBusy }, "the process ended")
            expectEqual(finished, ["small"])
            expect(downloads.path(ModelCatalog.builtIn.model("small")!) != nil, "snapshot on disk under \(hub.path)")
            downloads.remove("small")
            expectEqual(downloads.state("small"), .notStarted)
        }

        test("download: offline pauses with the bytes so far, retry resumes") {
            let (downloads, _) = makeDownloads("offline")
            downloads.start("small")
            expect(AIWait.until(timeout: 10) { if case .paused = downloads.state("small") { return true }; return false })
            guard case .paused(let done, let total, let problem) = downloads.state("small") else { return fail("not paused") }
            expectEqual(problem, "offline")
            expect(done > 0 && done < total, "\(done) of \(total)")
            expectEqual(MLXSectionModel.footnote(downloads.states, selected: "small"), MLXText.noteOffline)
        }

        test("download: pause stops it, one at a time") {
            let (downloads, _) = makeDownloads("slow")
            downloads.start("small")
            downloads.start("quality")
            expectEqual(downloads.state("quality"), .queued)
            expect(AIWait.until(timeout: 5) { if case .running(let d, _) = downloads.state("small") { return d > 0 }; return false })
            downloads.pause("small")
            expect(AIWait.until(timeout: 5) { if case .paused = downloads.state("small") { return true }; return false },
                   "\(downloads.state("small"))")
            if case .paused(_, _, let problem) = downloads.state("small") { expectEqual(problem, "cancelled") }
            expect(AIWait.until(timeout: 5) { if case .running = downloads.state("quality") { return true }; return false },
                   "the queued one starts")
            downloads.stopAll()
            expect(AIWait.until(timeout: 5) { !downloads.isBusy })
        }

        test("download: deleting the model while it downloads leaves nothing and no paused row") {
            let (downloads, hub) = makeDownloads("slow")
            let repo = ModelCatalog.builtIn.model("small")!.repo
            var finished: [String] = []
            downloads.onFinished = { finished.append($0) }
            downloads.start("small")
            downloads.start("quality")
            expect(AIWait.until(timeout: 5) { if case .running(let d, _) = downloads.state("small") { return d > 0 }; return false })
            downloads.remove("quality")
            expectEqual(downloads.state("quality"), .notStarted, "a queued one just leaves the queue")
            downloads.remove("small")
            expectEqual(downloads.state("small"), .notStarted)
            expect(AIWait.until(timeout: 5) { !downloads.isBusy }, "the process ended")
            _ = AIWait.until(timeout: 0.3) { false }
            expectEqual(downloads.state("small"), .notStarted, "the late cancelled line was ignored")
            expectEqual(downloads.state("quality"), .notStarted, "the queued one did not start")
            expectEqual(HubCache.blobBytes(hub: hub, repo: repo), 0)
            expect(!FileManager.default.fileExists(atPath: HubCache.repoDir(hub: hub, repo: repo).path), "folder gone")
            expect(finished.contains("small"))
        }

        test("scene states follow ProviderChoice: a missing model is what the step explains") {
            expectEqual(MLXScenes.model(.missing).problem, .modelMissing)
            expectEqual(MLXScenes.model(.download).problem, .appleIntelligenceOff)
            expectEqual(MLXScenes.model(.tooOld).problem, .systemTooOld)
            expect(!MLXScenes.model(.missing).hasAlternative, "Apple cannot run here, so MLX is the only way")
            var applePicked = MLXScenes.model(.missing)
            applePicked.activeID = AppleOnDeviceProvider.providerID
            applePicked.availability = .unavailable(.deviceNotEligible)
            expect(applePicked.hasAlternative, "Apple picked by hand: MLX can still be set up")
        }

        test("Delete Models is off while a download runs") {
            let catalog = ModelCatalog.builtIn
            @MainActor func model(_ s: ModelDownloads.State) -> MLXSectionModel {
                MLXSectionModel(rows: catalog.models.map { MLXSectionModel.row($0, $0.id == "quality" ? s : .done) }, selected: "small",
                                options: [], memoryGB: nil, footnote: "", bytesOnDisk: 1, installed: true)
            }
            expect(model(.running(done: 1, total: 2)).isDownloading)
            expect(model(.queued).isDownloading)
            expect(!model(.paused(done: 1, total: 2, problem: "failed")).isDownloading)
            expect(!model(.done).isDownloading)
        }

        test("mlx scenes render and the module registered its provider and section") {
            expect(LocalAI.shared.provider(MLXProvider.providerID) != nil)
            expect(LocalAI.shared.sections.contains { $0.id == "mlx" })
            for id in ["ai.pane-mlx", "ai.pane-mlx-setup", "ai.pane-mlx-offline", "ai.pane-mlx-too-old", "ai.onboarding-mlx",
                       "ai.onboarding-mlx-missing", "ai.onboarding-mlx-setup"] {
                guard let scene = Registry.renderScenes.first(where: { $0.id == id }) else { fail("\(id) missing"); continue }
                let png = RenderRunner.png(scene.content(), size: scene.size, appearance: .dark, lang: .de)
                expect((png?.count ?? 0) > 5_000, id)
            }
        }
    }

    /// A complete snapshot of the built-in "small" model (tiny files) under `hub`.
    static func fakeModel(_ hub: URL, model id: String = "small") {
        let fm = FileManager.default
        let spec = ModelCatalog.builtIn.model(id)!
        let repo = HubCache.repoDir(hub: hub, repo: spec.repo)
        let blobs = repo.appendingPathComponent("blobs")
        let snap = repo.appendingPathComponent("snapshots/\(spec.revision!)")
        try? fm.createDirectory(at: blobs, withIntermediateDirectories: true)
        try? fm.createDirectory(at: snap, withIntermediateDirectories: true)
        fm.createFile(atPath: blobs.appendingPathComponent("cfg").path, contents: Data("{}".utf8))
        fm.createFile(atPath: blobs.appendingPathComponent("w").path, contents: Data(count: 10))
        try? fm.createSymbolicLink(atPath: snap.appendingPathComponent("config.json").path, withDestinationPath: "../../blobs/cfg")
        try? fm.createSymbolicLink(atPath: snap.appendingPathComponent("model.safetensors").path, withDestinationPath: "../../blobs/w")
    }

    static func makeDownloads(_ mode: String) -> (ModelDownloads, URL) {
        let home = tempDir()
        let hub = home.appendingPathComponent("hub")
        let fake = workerDir.appendingPathComponent("tests/fake_download.py").path
        let downloads = ModelDownloads(catalog: .builtIn, hub: hub) { model in
            .init(executable: python, arguments: [fake, "--repo", model.repo, "--revision", model.revision ?? "rev",
                                                  "--total", "1000", "--hf-home", home.path, "--mode", mode, "--watch-stdin"],
                  environment: ["PYTHONDONTWRITEBYTECODE": "1"], log: nil)
        }
        return (downloads, hub)
    }
}
#endif
#endif
