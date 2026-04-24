# Stage 8.5 — Web Preview Pipeline

This document explains the Web Preview pipeline for Tales of Drak: how the
Godot project gets exported to the web, how to make the preview reachable from
your phone, and what to do if any step fails.

## What this pipeline does

When a commit lands on `main`, GitHub Actions runs `.github/workflows/web-preview.yml`,
which:

1. **Validates design data**
   - runs `python tools/validate_character_framework.py`
   - confirms every `design/*.json` file parses as JSON
2. **Exports the Godot project to Web**
   - uses the `barichello/godot-ci:4.3.0` Docker image (Godot 4.3 + matching
     export templates)
   - runs `godot --headless --export-release "Web" ../build/web/index.html`
     against `godot/export_presets.cfg`
3. **Publishes to GitHub Pages**
   - uploads `build/web/` as a Pages artifact (`actions/upload-pages-artifact@v3`)
   - deploys with `actions/deploy-pages@v4`

The exported `index.html` is what you open from your iPhone.

## How to enable GitHub Pages (manual, one-time)

GitHub Pages cannot be enabled from inside a workflow file. You need to do
this once in the repository settings:

1. Push the repo to GitHub (if not already there).
2. On GitHub: **Settings → Pages**.
3. Under **Build and deployment → Source**, select **GitHub Actions**.
   - Do **not** pick "Deploy from a branch"; this pipeline uses the new Pages
     deployment API, not a `gh-pages` branch.
4. Save.

After that the next push to `main` will run the workflow end to end and
deploy the build.

## Where to find the Actions run

- GitHub repo → **Actions** tab → **Web Preview** workflow.
- Each run has three jobs: `validate`, `export-web`, `deploy-pages`.
- If `validate` fails, fix the JSON / data first; the export job will not run.
- If `export-web` fails, check the Godot output in the job log (usually a
  missing template or a bad export preset).

## Where the preview link will appear

Once the `deploy-pages` job succeeds:

- It prints the deployed URL in the job summary
  (`https://<your-github-user>.github.io/<repo-name>/`).
- The same URL is also visible under **Settings → Pages** as
  *"Your site is live at …"*.

Open that URL on your iPhone in Safari. The Godot Web export uses the
`gl_compatibility` renderer (set in `godot/project.godot`) so it will run on
mobile WebGL.

## Known iPhone / browser limitations

These are limitations of Godot's Web export, not of this pipeline:

- **iOS Safari is the only engine on iPhone.** Even Chrome on iOS uses
  WebKit underneath.
- **No mouse capture.** The third-person controller mouse-look will not work
  the same as on desktop; touch input is needed to feel right (not in v0.1).
- **WebGL only.** Vulkan / Forward+ rendering is not available on the web
  build, which is why the project is configured for the GL Compatibility
  renderer.
- **Audio / fullscreen need a user tap.** Browsers require a user gesture
  before audio plays or fullscreen activates.
- **First load is slow.** The Godot WASM runtime + your project pak need to
  download. Subsequent loads are cached.
- **Cross-Origin Isolation.** Some Godot 4 web features (threads, SharedArrayBuffer)
  require COOP/COEP headers. GitHub Pages does not set these by default. The
  preset in this repo does not require them, so the build still loads — but
  if you later enable threads in `export_presets.cfg`, you'll have to host
  the build somewhere that sets COOP/COEP headers.

## How to manually export from Godot if automation fails

If the GitHub Action can't run (for example you're working offline, or
GitHub Pages is disabled for your account), you can produce the exact same
build locally:

1. Install **Godot 4.3** from <https://godotengine.org/download>.
2. In Godot: **Editor → Manage Export Templates → Download and Install**
   (must match 4.3 stable).
3. Open the project at `godot/project.godot`.
4. **Project → Export…**
   - The `Web` preset from `godot/export_presets.cfg` should already appear.
   - Click **Export Project**, target `build/web/index.html`.
5. Serve `build/web/` over HTTP (Godot Web exports require HTTP, not
   `file://`). Quick options:
   - `python3 -m http.server 8000 --directory build/web`
   - or upload `build/web/` to any static host (Netlify, Vercel, Cloudflare
     Pages, S3, etc.).
6. Open the URL on your iPhone.

## Status of automation in this repo

- ✅ `godot/project.godot` main scene set to
  `res://scenes/test_world/test_world.tscn`
- ✅ `godot/export_presets.cfg` Web preset committed
- ✅ `.github/workflows/web-preview.yml` committed
- ⚠️ The web export job has **not** been verified to succeed inside Replit.
  Replit does not have Godot installed, so the export step is only proven to
  run on the GitHub Actions runner once the workflow executes there. Until
  the first successful Action run, treat the web preview as
  *configured but unverified*.
- ⚠️ GitHub Pages must be switched to **Source: GitHub Actions** manually
  (one-time step described above).

## Exact next manual step

In GitHub:

> **Settings → Pages → Build and deployment → Source → GitHub Actions**, then
> push to `main` (or re-run the *Web Preview* workflow from the Actions tab)
> and watch the `deploy-pages` job for the live URL.
