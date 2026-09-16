#!/usr/bin/env bash
#
# Build bachelorarbeit.pdf with XeLaTeX + biber.
#
# The template needs XeLaTeX (bamberg-thesis.sty loads fontspec) and biber as the
# biblatex backend, so pdflatex/bibtex will not work here.
#
#   ./build.sh          full build (xelatex, biber, xelatex, xelatex)
#   ./build.sh --quick  single xelatex pass, for a fast look while writing
#   ./build.sh --clean  delete build artifacts (incl. the PDF) and stop
#
# Four passes are needed because each one feeds the next: the first writes the
# .bcf that biber reads, biber writes the .bbl, and the last two settle the
# citations, the table of contents and all cross-references.

set -euo pipefail

JOB="bachelorarbeit"
cd "$(dirname "${BASH_SOURCE[0]}")"

# .synctex.gz lets a PDF viewer jump back to the matching source line
ARTIFACTS=(aux bcf blg bbl log lof lot out toc run.xml synctex.gz fdb_latexmk fls xdv)

clean() {
	for ext in "${ARTIFACTS[@]}"; do
		rm -f "$JOB.$ext"
	done
}

case "${1:-}" in
--clean)
	clean
	rm -f "$JOB.pdf"
	echo "Cleaned build artifacts."
	exit 0
	;;
--quick)
	QUICK=1
	;;
"")
	QUICK=0
	;;
*)
	echo "Unknown option: $1 (expected --quick, --clean, or nothing)" >&2
	exit 2
	;;
esac

for tool in xelatex biber; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "Error: $tool not found. Install MacTeX (or TeX Live) and make sure" >&2
		echo "/Library/TeX/texbin is on your PATH." >&2
		exit 1
	fi
done

# -halt-on-error stops at the first real error instead of dropping into the
# interactive TeX prompt, which would otherwise hang a non-interactive run.
run_xelatex() {
	echo ">>> xelatex ($1)"
	xelatex -halt-on-error -interaction=nonstopmode "$JOB.tex" >/dev/null
}

if [[ $QUICK -eq 1 ]]; then
	run_xelatex "quick pass"
else
	run_xelatex "pass 1/3"
	echo ">>> biber"
	biber "$JOB" >/dev/null
	run_xelatex "pass 2/3"
	run_xelatex "pass 3/3"
fi

# Surface the warnings worth acting on. Unresolved references and citations show
# up in the PDF as "??" and are easy to miss otherwise; overfull boxes are text
# running into the margin.
echo
if grep -qE "undefined (references|citations)|Citation .* undefined" "$JOB.log"; then
	echo "Warning: undefined references or citations - these render as ?? in the PDF."
fi
overfull=$(grep -c "Overfull \\\\hbox" "$JOB.log" || true)
if [[ $overfull -gt 0 ]]; then
	echo "Note: $overfull overfull hbox warning(s) (text extending into the margin)."
fi

# xelatex reports the page count itself, so no need for pdfinfo (not part of MacTeX)
pages=$(grep -o "Output written on $JOB.pdf ([0-9]* page" "$JOB.log" | grep -o "[0-9]*" || true)
echo "Built $JOB.pdf${pages:+ ($pages pages)}"
