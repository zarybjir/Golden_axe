#!/bin/bash
# Spouštěč hry s automatickou aktualizací (Legion Go S / SteamOS / Linux).
# Při každém spuštění zkusí stáhnout nejnovější verzi z GitHubu; když je novější,
# rozbalí ji přes tuto složku. Bez internetu hru jen spustí.
# Celý skript je ve funkci, aby přepsání tohoto souboru během aktualizace nevadilo.
main() {
	cd "$(dirname "$(readlink -f "$0")")" || exit 1
	local url="https://github.com/zarybjir/Golden_axe/releases/latest/download/Kladivo-linux.zip"
	local tmp
	tmp="$(mktemp -d)"
	if curl -fsSL --max-time 25 -o "$tmp/new.zip" "$url" 2>/dev/null; then
		if ! cmp -s "$tmp/new.zip" .posledni.zip 2>/dev/null; then
			if python3 -m zipfile -e "$tmp/new.zip" "$tmp/x" 2>/dev/null && [ -f "$tmp/x/Kladivo/Kladivo.x86_64" ]; then
				cp -rf "$tmp/x/Kladivo/." .
				chmod +x Kladivo.x86_64 kladivo.sh
				cp "$tmp/new.zip" .posledni.zip
			fi
		fi
	fi
	rm -rf "$tmp"
	exec ./Kladivo.x86_64 "$@"
}
main "$@"
exit
