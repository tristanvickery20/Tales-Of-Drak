name: Web Preview

"on":
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  validate:
    name: Validate repo
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.x"

      - name: Run project validator
        run: python tools/validate_character_framework.py

      - name: Parse all design JSON
        run: |
          python - <<'PY'
          import glob
          import json

          for path in sorted(glob.glob("design/*.json")):
              with open(path, "r", encoding="utf-8") as f:
                  json.load(f)
              print(f"OK {path}")

          print("All design JSON files parsed successfully.")
          PY

  export-web:
    name: Export Godot Web build
    runs-on: ubuntu-latest
    needs: validate
    container:
      image: barichello/godot-ci:4.3.0

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Create web build folder
        run: mkdir -p build/web

      - name: Export Godot project to Web
        working-directory: godot
        run: godot --headless --verbose --export-release "Web" ../build/web/index.html

      - name: Upload GitHub Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: build/web

  deploy-pages:
    name: Deploy to GitHub Pages
    runs-on: ubuntu-latest
    needs: export-web

    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}

    steps:
      - name: Deploy Pages site
        id: deployment
        uses: actions/deploy-pages@v4
