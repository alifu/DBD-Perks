#!/bin/sh
# paper.md -> paper.pdf. Needs: brew install pandoc tectonic. Run from anywhere.
set -e
cd "$(dirname "$0")/.."
pandoc paper.md --citeproc --bibliography references.bib --resource-path=. \
  --pdf-engine=tectonic -V geometry:margin=2.5cm -V fontsize=11pt -V colorlinks=true \
  -o paper.pdf
echo "✅ $(pwd)/paper.pdf"
