# Idle Tapper — update feed

This branch is not source code. It is served by GitHub Pages and exists only to
host the Sparkle update feed:

- `appcast.xml` — the feed the app checks once a day
- `releases/` — the signed application archives the feed points at

Both are generated and committed by the **Generate Appcast** workflow when a
release is published. Do not edit them by hand: the appcast carries an EdDSA
signature over each archive, and a hand-edited file will fail verification in
every installed copy of the app.

The app itself lives on `main`: https://github.com/SanditZZ/idle-tapper-macos
