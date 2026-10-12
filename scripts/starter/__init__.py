"""Library behind bin/starter and scripts/check_kit.py (Python 3.9 standard library only).

Modules:
  common    errors, git helpers, file lists, JSON, checksums, block cutting
  globs     glob matching for repository paths
  manifest  starter.manifest.json (schema, path classes, modules) and starter.lock.json
  config    starter.json: reading, writing in its compact layout, three-way merge for sync
  markers   module markers: `#if MODUL_<NAME>` in Swift, `// modul:<name>` comments elsewhere
  project   init (turns a template copy into a project)
  remove    remove <module>, strip-examples
  sync      sync --ziel <tag>: three-way merge with a newer starter version
  kitcheck  check-kit (kit checksums, manifest coverage, removal safety, switched-off checks)
  cli       argument parsing and the German help texts
"""
