---
name: review-machine-repo
description: Review this declarative macOS machine repo and the current Mac for security advisories, installed-version exposure, upgrade recommendations, and related operational risks. Use for a broad machine audit or a package security and upgrade review; use diff-tracked-machine for a request limited to tracked drift.
---

# Review the machine repo

Run from the repository root. Produce a dated, evidence-backed review of the **installed machine** against the **declared target**. A declaration, Homebrew version, app bundle version, and running version can differ; identify which one an advisory actually covers. Start with `git status --short` and `just help`; preserve unrelated work.

## Inventory and coverage

- Read `AGENTS.md`, `modules/apps.nix`, `modules/homebrew.nix`, `flake.nix`, `flake.lock`, `homebrew/local/`, and the relevant `just` recipes. Note the owner of each update: nix-darwin, nix-homebrew/Homebrew, Mac App Store, vendor self-updater, chezmoi, or manual setup.
- Collect installed formula and cask versions with `brew list --formula --versions` and `brew list --cask --versions`; use `brew info --json=v2` where provenance, pinning, dependencies, or cask metadata matters. For self-updating apps, `version :latest` casks, and local casks, inspect the actual app or CLI version rather than treating the Homebrew receipt as the running version.
- Treat a local cask's version and checksum as the verified fresh-install baseline. When the live app is newer, check the upstream release, download digest, signing, channel, and macOS compatibility before recommending a pin change; do not copy the live version into the cask merely to remove receipt drift. For ordinary casks, the tap revision in `flake.lock` supplies the install version.
- Include Nix system packages and locked inputs, Mac App Store apps (`mas list`), macOS (`sw_vers` and available security updates), and installed VS Code/Cursor extensions (`--list-extensions --show-versions`). Check transitive packages when an advisory names one. Keep coverage counts by inventory class: identified, advisory-checked, unsupported by the chosen databases, and version unknown. Do not silently omit an unversioned component.
- Compare installed versions with available updates using [`brew outdated --json=v2 --greedy`](https://docs.brew.sh/Manpage#outdated-options-formulacask-) and current vendor/release information. `--greedy` exposes casks normally skipped because they auto-update or use `version :latest`; it is a candidate list, not proof of the effective app version. Check for deprecated, disabled, end-of-support, or unmaintained software.

## Security advisory matching

Browse current sources for each installed product. Start with vendor security notices and release notes, [Apple security releases](https://support.apple.com/100100) for macOS, [GitHub global advisories](https://docs.github.com/en/rest/security-advisories/global-advisories) and [OSV](https://google.github.io/osv.dev/post-v1-querybatch/) for supported package ecosystems, and [CISA KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog) to prioritize confirmed exploitation. Check source publication and update dates. Advisory databases have incomplete coverage of Homebrew casks and closed-source apps; an empty database result does not prove safety.

- Match the vendor/product and ecosystem, installed version/build, affected range, platform, and fixed version. Do not infer vulnerability from a similar package name or an upstream CVE without showing that the installed build is affected. Treat backports and vendor-specific versioning explicitly.
- Deduplicate CVE/GHSA/OSV aliases. Separate **confirmed affected**, **possibly affected / version uncertain**, **fixed locally**, and **no relevant advisory found in checked sources**. State why each material match applies or why it remains uncertain.
- Prioritize known exploitation, security impact and reachable exposure, then availability of a supported fix. Give an exact fixed version or mitigation when a source provides one; otherwise say the fix is unknown.

## Other review ingredients

- Check declarative drift and health where relevant: `just verify`, `just prune-diff`, `chezmoi diff`, declared startup/login services, `/run/current-system`, and managed settings. `just diff-tracked` writes ignored inventory snapshots; use it when a captured tracked-drift review is requested and note that side effect. Use `just discover-global` only when the request includes unmanaged software or a whole-machine survey; it also writes ignored inventory.
- Review upgrade provenance and blast radius: third-party tap and flake pins, narrow Homebrew trust, local cask sources/checksums, app signing, dependency changes, release-note breaking changes, rollback path, and whether an update needs app restart, logout, or reboot. Report concrete findings, not speculative warnings.
- Distinguish **security fixes** from **routine upgrades** and **manual follow-up**. For each recommendation name the repo declaration or vendor-owned surface to change, the expected version, a focused validation step, and the appropriate apply path. In this repo `just apply` installs missing Homebrew packages but does not upgrade existing ones; `just upgrade` handles outdated Homebrew-managed casks and includes a self-updating cask only when named; `just update` advances tap pins and upgrades formulae and Homebrew-managed casks. A `brew outdated --greedy` audit candidate is never by itself a reason to force an upgrade. Check the live recipe before recommending a command.

## Output and boundary

Lead with a short prioritized action list. Then show a compact evidence table: component and owner, installed version, available/fixed version, advisory or release source, applicability/confidence, proposed action, and restart impact. Include the audit date, coverage gaps, and checks that failed or were not run. Cite direct advisory and vendor links near each claim.

An audit is read-only by default. Do not run `just apply`, `just update`, `just upgrade`, `just prune`, `brew update`, `brew upgrade`, `softwareupdate --install`, or edit declarations merely to complete the review. If the user also asks for fixes, validate a concrete proposed change before applying the authorized scope. Never bypass macOS consent, and do not commit captured auth, session, inventory, cache, or SQLite data.
