#!/bin/sh
# Optional: registers blocktopia:// for this extracted Linux build (the client also does this on first run).
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.local/share/applications
printf '[Desktop Entry]\nType=Application\nName=BlockTopia\nExec="%s/BlockTopia.x86_64" %%u\nMimeType=x-scheme-handler/blocktopia;\nTerminal=false\n' "$DIR" > ~/.local/share/applications/blocktopia.desktop
xdg-mime default blocktopia.desktop x-scheme-handler/blocktopia && echo "BlockTopia protocol registered."
