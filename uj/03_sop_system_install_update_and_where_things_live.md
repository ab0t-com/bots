# 03 · Install uj, keep it current, and know where everything lives

**What this is for.** Getting the `uj` binary onto every machine that runs your tests (laptops and CI), updating it or rolling it back, and knowing exactly where uj keeps settings and state. The short answer to "where is the config?": there is no global config. Everything that changes a verdict lives in your project folder, next to your tests, so Dev's laptop and Acme's CI get the same result. The one thing uj keeps outside your projects is a list of where they are, so you can find them again; it never changes what a test does.

**Before you start.** A terminal on Linux or macOS (Intel or Apple Silicon) with `curl`, or PowerShell on Windows (amd64). No account, no login, no running service. Ten minutes.

## Steps

**1. Install.** (The public `github.com/ab0t-com/uj` repository these lines download from is coming soon; if they answer `404`, it is not live yet.)
Linux / macOS:
```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/uj/main/install.sh | sh
```
Windows (PowerShell):
```powershell
irm https://raw.githubusercontent.com/ab0t-com/uj/main/install.ps1 | iex
```
Both installers are HTTPS-only, check the published sha256 before touching anything, and are safe to re-run. On Linux/macOS the binary goes to `~/.local/bin` when that works without sudo, otherwise `/usr/local/bin` (asks for sudo). On Windows it goes to `%LOCALAPPDATA%\Programs\uj\uj.exe`, and that folder is added to your user PATH; open a new terminal afterwards. Prefer to read the script first: `curl -fsSLO https://raw.githubusercontent.com/ab0t-com/uj/main/install.sh && less install.sh && sh install.sh`.

The knobs go on `sh`, not on `curl`:
```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/uj/main/install.sh | REF=v0.1.1 sh             # pin a version
curl -fsSL https://raw.githubusercontent.com/ab0t-com/uj/main/install.sh | INSTALL_DIR=$HOME/bin sh  # choose the folder
curl -fsSL https://raw.githubusercontent.com/ab0t-com/uj/main/install.sh | UJ_INSTALL_BASE=https://mirror.example.com/uj sh
```

**2. Confirm.** A `curl … | sh` pipe cannot report a failed download, so always check:
```sh
uj --version
```
It prints `uj 0.1.1-public`. "command not found" means the install did not happen, or the folder is not on your PATH (step 3).

**3. Fix PATH if the installer told you to.** If you saw `[!] <dir> is not in your $PATH. Add it:`, run the line it printed under it, for example:
```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
```
Open a new terminal and repeat step 2.

**4. Install the same way in CI.** Pin the version so every pipeline run uses the same uj, and put it in a folder you control:
```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/uj/main/install.sh | REF=v0.1.1 INSTALL_DIR="$HOME/bin" sh
export PATH="$HOME/bin:$PATH"
uj --version
```
The rest of the CI job is SOP 12.

**5. Update.** Look first, then update:
```sh
uj update --check
uj update
```
`uj update` downloads the latest published build, verifies its checksum, swaps it in atomically, and keeps the old binary beside the new one. A mirror works too: `UJ_INSTALL_BASE=https://mirror.example.com/uj uj update`. Read the CHANGELOG before you update a CI pin (SOP 14).

**6. Roll back if an update hurts.** One previous binary is kept, named `uj.previous` (Windows: `uj.exe.previous`):
```sh
mv -f "$(command -v uj).previous" "$(command -v uj)"
```
```powershell
Move-Item -Force "$env:LOCALAPPDATA\Programs\uj\uj.exe.previous" "$env:LOCALAPPDATA\Programs\uj\uj.exe"
```

**7. Know where everything lives.** uj keeps no settings in your home folder: no `~/.uj`, no `~/.config/uj`, no telemetry.

| what | where |
|---|---|
| the binary | the install folder from step 1, plus `uj.previous` after an update |
| your project | the folder holding `harness.toml` (by default the root of your git repo, SOP 04); uj finds it by walking up from the journey path, then from where you stand |
| which service to test | `harness.toml`: `[target.NAME]` `base = "…"`, and `default_target = "NAME"` in `[project]` |
| what runs before every journey | `<project>/environment.json`, or another file with `--env FILE` (SOP 05) |
| local secrets for `{env:NAME}` (this machine only, never committed) | `<project>/.env`, next to `harness.toml` |
| the tests | `<project>/journeys/**` (`.yaml`, `.yml`, `.json`); files and folders starting with `_` or `.` are not run |
| the project's memory (committed) | `<project>/.uj/`: what the product is, the risk register, team conventions, a decisions log and a findings log (SOPs 04, 06) |
| run history (flake detection, `uj history`) | `<project>/runs/history.jsonl` |
| resume checkpoints | `<project>/runs/<journey>/<run-id>/checkpoint.json` (secrets masked) and `secrets.json` (mode 600, deleted when the run finishes cleanly) |
| your list of projects (this machine) | `projects.json` in uj's state folder (below); `uj projects` reads it |
| notes about a project (this machine only, for you or Quinn) | `projects/<project id>/` in the same state folder; `uj where` prints the path |
| load-test output | `./results/` (SOP 16) |

`uj init` adds `runs/` and `.env` to `.gitignore`: history is per machine, and `.env` holds your local secrets. Everything else in the project, `.uj/` included, is meant to be committed.

The state folder is the first that applies: `$UJ_STATE_DIR`, then `$XDG_STATE_HOME/uj`, then the OS default: `~/.local/state/uj` (Linux), `~/Library/Application Support/uj` (macOS), `%LocalAppData%\uj` (Windows). `uj init`, `uj run`, `uj doctor` and `uj where` record the project they ran in: its name, folder, target names and how the last run went. No URLs, no secrets, no test content. Deleting the folder loses nothing that matters; `uj projects --scan <dir>` rebuilds the list. `UJ_NO_INDEX=1` turns it off.

To see all of this for the project you stand in, offline and without touching the service:
```sh
uj where
```

**8. Know the configuration layers.** First match wins:

| layer | what it holds | examples |
|---|---|---|
| 1. flags | this one run | `--base URL`, `--target NAME`, `--env FILE`, `--runs-dir DIR`, `--timeout 90s` |
| 2. environment variables | the machine or CI job, and secrets | `UJ_BASE` (the target), `UJ_TIMEOUT` (per-request timeout, default `30s`), `UJ_INSTALL_BASE` (update source), `UJ_BROWSER_DRIVER` / `UJ_BROWSER_CMD` / `UJ_BROWSER_URL` (browser steps, SOP 10), `UJ_INSECURE_TLS=1` (accept a self-signed certificate on a dev target only, SOP 12), and any `{env:NAME}` your files reference |
| 3. `<project>/.env` | local values you would otherwise export by hand | `ACME_QA_PASSWORD=<your-password>`; read by `uj run` and `uj doctor`, and it sets only variables that are not already set, so the shell and CI always win |
| 4. project files | everything a verdict depends on | `harness.toml`, `environment.json`, `journeys/` |

For the target the full order is `--base` › `--target NAME` › `$UJ_BASE` › `harness.toml` (`default_target`, else the only target, else `local`). There is no built-in URL: with no target, uj stops and tells you how to set one. `UJ_STATE_DIR` and `UJ_NO_INDEX` only move or switch off the project list; they never change a verdict.

Why no per-user settings file? Test runners such as Playwright, pytest, Jest and Cypress keep test settings in the project too; a per-user layer exists only for logins and caches, and uj has neither. Passwords come from environment variables, which is how CI secret stores deliver them; `.env` is only a local shortcut for the same variables (SOP 05). The project list is a remembered list (like an editor's recent folders), not settings.

**9. Uninstall.** Delete the binary and its `.previous` (`rm "$(command -v uj)" "$(command -v uj).previous"`); on Windows delete `%LOCALAPPDATA%\Programs\uj` and remove it from your user PATH. Delete the state folder from step 7 (on Linux `~/.local/state/uj`). In each project, `runs/` is the only thing uj wrote that you did not ask for; delete it if you no longer want the history. `.uj/` and the rest of the project are your tests: keep them.

## What you'll see

The installer prints `[ok] Checksum verified` and `[ok] Installed: uj 0.1.1-public`, then where it put the binary, the rollback command, and a start hint: `Start  uj init --base <your-service-url>   (in your repo), then:` / `uj doctor  ·  uj new journey "A customer signs up"  ·  uj run`. A re-run at the same version prints `[ok] uj 0.1.1-public already installed at <path> — nothing to do.` and exits `0`.

`uj update --check` prints `current:` and `published:` lines, then `uj is up to date.`, `no newer release.`, or `` a different release is available (<version>) — run `uj update` to install it. `` A real update prints `checksum verified.`, `updated: uj <old> → <new>`, and a `(previous binary kept at … — roll back with: mv -f …)` line.

`uj where` in Acme's project (offline; abridged):
```
project   invoicer  (.)
target    http://localhost:8080  (from target "dev" (<path>/harness.toml))
          all targets: dev, staging
setup     environment.json (2 step(s) before every journey)
journeys  4 in journeys
last run  never (here)
risks     5 registered · 1 with no journey
          gap: delete-means-gone        P1 a deleted invoice still shows up
memory
          .uj/conventions.context  (updated 0 days ago)
notes     <state folder>/projects/uj_<id> (this machine only)
```
`uj projects` ends with `(list kept at <path> — safe to delete; UJ_NO_INDEX=1 turns it off)`.

## If it goes wrong

| you see | it means | do |
|---|---|---|
| your shell says command not found for `uj` | not installed, or its folder is not on PATH | step 3; on Windows open a new terminal |
| `[x] could not fetch checksums.txt — refusing to install without verification` | network, proxy, or mirror problem | fix the network or `UJ_INSTALL_BASE`; never bypass the check |
| `[x] checksum mismatch — expected …, got …. Aborting (no install performed).` | the download was altered or truncated | retry; if it repeats, stop and report it |
| `[x] no checksum entry for <asset> in checksums.txt (is this platform published?)` | no build for this OS/CPU | use a supported platform (Coming) |
| `[x] <dir> is not writable and sudo is unavailable` | the chosen folder is locked | `INSTALL_DIR=$HOME/bin` (step 1) |
| `uj update: refusing a non-HTTPS source "<url>" (TLS is mandatory)` | a mirror on plain HTTP | serve the mirror over HTTPS |
| `uj update: could not read published version: …` then `you are still on <version> — nothing was changed …` | update source unreachable; with `HTTP 404` also `no release is published at <url> yet (or the address is wrong).` | check the network or `UJ_INSTALL_BASE`, or re-run the installer; your current uj keeps working |
| `uj update: install failed, restored previous binary: …` | it could not replace the file (permissions) | re-run the installer (asks for sudo if needed) |
| `uj update: unknown flag "<x>" (only --check)` | typo | `uj update` or `uj update --check` |
| the wrong service gets tested | an exported `UJ_BASE` beat `harness.toml` | read the `(target: … — from …)` line or `uj where`; `unset UJ_BASE` |
| a value in `.env` seems ignored | the same variable is already set in your shell or CI, and that wins | `unset NAME`, or change it where it is set |
| `uj projects: the project list is off (UJ_NO_INDEX is set)` | you (or CI) turned the list off | `unset UJ_NO_INDEX`, or ignore it: nothing else depends on it |
| you cannot remember where your tests are | the repo or folder slipped your mind | `uj projects`; `uj projects --scan ~/code` finds ones never used on this machine (SOP 13) |

## Coming

- **`uj uninstall`.** *Today:* step 9 (two files and the state folder).
- **Update to a chosen version (`uj update` with a version).** *Today:* re-run the installer with `REF=v<version>`.
- **Package-manager installs (Homebrew, winget, apt).** *Today:* the installers, or a prebuilt binary from the repo's `release/` folder checked against `release/checksums.txt`.
- **Windows on ARM and other platforms.** *Today:* linux amd64/arm64, macOS amd64/arm64, windows amd64.

## Next

SOP 04, start a project and set its targets.
