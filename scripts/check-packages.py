#!/usr/bin/env python3
"""Valida listas de pacotes contra o indice Packages do Debian (somente leitura).

Para cada lista informa: pacotes inexistentes, componentes fora de --areas,
conflitos incondicionais dentro do fechamento de dependencias e o tamanho
instalado aproximado (soma de Installed-Size do fechamento, sem Essential).

Aproximacoes (por isso o resultado e uma ESTIMATIVA, nao o que o apt resolveria):
 - segue apenas Depends/Pre-Depends (sem Recommends: o build usa --apt-recommends false);
 - escolhe a primeira alternativa de "a | b" (ou a que ja esta no fechamento);
 - ignora restricoes de versao e de arquitetura alem de amd64/all;
 - Installed-Size e descompactado; a ISO (squashfs) fica menor.

Uso: check-packages.py --index main.xz --area main --index nff.xz --area non-free-firmware \
         --iso LISTA... --optional PERFIL... [--top N]
"""
import argparse
import lzma
import re
import sys

ESSENTIAL_LIKE = {"required"}  # pacotes "required" ja existem em qualquer base debootstrap


def open_text(path):
    if path.endswith(".xz"):
        return lzma.open(path, "rt", encoding="utf-8")
    return open(path, "rt", encoding="utf-8")


def load_index(paths_areas):
    pkgs = {}
    provides = {}
    for path, area in paths_areas:
        with open_text(path) as fh:
            data = fh.read()
        for block in data.split("\n\n"):
            fields = {}
            key = None
            for line in block.splitlines():
                if line[:1] in (" ", "\t") and key:
                    fields[key] += "\n" + line
                elif ":" in line:
                    key, _, val = line.partition(":")
                    fields[key] = val.strip()
            name = fields.get("Package")
            if not name or fields.get("Architecture") not in ("amd64", "all"):
                continue
            fields["_area"] = area
            pkgs[name] = fields
            for prov in fields.get("Provides", "").split(","):
                prov = re.sub(r"\(.*?\)", "", prov).strip().split(":")[0]
                if prov:
                    provides.setdefault(prov, []).append(name)
    return pkgs, provides


def parse_relations(value):
    """'a (>= 1) | b, c' -> [['a','b'], ['c']] (nomes sem versao/arquitetura)."""
    groups = []
    for part in value.split(","):
        part = part.strip()
        if not part:
            continue
        alts = []
        for alt in part.split("|"):
            alt = re.sub(r"\(.*?\)|\[.*?\]|<.*?>", "", alt).strip().split(":")[0]
            if alt:
                alts.append(alt)
        if alts:
            groups.append(alts)
    return groups


def read_list(path):
    names = []
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.split("#", 1)[0].strip()
            if line and not line.startswith("!"):
                names.extend(line.split())
    return names


def resolve(name, pkgs, provides):
    if name in pkgs:
        return name
    cands = provides.get(name, [])
    return cands[0] if cands else None


def closure(roots, pkgs, provides, skip):
    """Fechamento de Depends. Para pacotes virtuais prefere provedor ja selecionado (como o apt)."""
    wanted = set(roots)  # raizes + tudo que ja foi escolhido
    seen = set()
    unresolved = set()
    stack = list(roots)

    def pick(alts):
        for a in alts:  # 1) alternativa que ja esta escolhida (real ou via provedor)
            if a in wanted:
                return a
            for prov in provides.get(a, []):
                if prov in wanted:
                    return prov
        for a in alts:  # 2) primeira alternativa resolvivel
            r = resolve(a, pkgs, provides)
            if r:
                return r
        return None

    while stack:
        name = stack.pop()
        if name in seen:
            continue
        seen.add(name)
        deps = pkgs[name].get("Pre-Depends", "") + "," + pkgs[name].get("Depends", "")
        for alts in parse_relations(deps):
            chosen = pick(alts)
            if chosen is None:
                unresolved.add("|".join(alts))
            elif chosen not in skip and chosen not in seen:
                wanted.add(chosen)
                stack.append(chosen)
    return seen, unresolved


def conflicts_in(seen, pkgs):
    found = []
    for name in sorted(seen):
        for part in pkgs[name].get("Conflicts", "").split(","):
            part = part.strip()
            if not part or "(" in part:  # restricoes de versao sao ignoradas
                continue
            other = part.split(":")[0]
            if other in seen and other != name:
                found.append(f"{name} conflita com {other}")
    return found


def analyze(path, label, pkgs, provides, skip, allowed):
    """Retorna (erros, raizes) de uma lista."""
    names = read_list(path)
    missing = [n for n in names if resolve(n, pkgs, provides) is None]
    roots = {resolve(n, pkgs, provides) for n in names} - {None}
    out_of_area = sorted(n for n in roots if pkgs[n]["_area"] not in allowed)
    seen, unresolved = closure(roots, pkgs, provides, skip)
    size_mb = sum(int(pkgs[n].get("Installed-Size", 0)) for n in seen) / 1024
    print(f"[{label}] {path}: {len(names)} pacotes, fechamento isolado ~{len(seen)} pacotes, ~{size_mb:.0f} MB (estimativa)")
    errors = 0
    if missing:
        errors += 1
        print(f"  ERRO inexistentes em {sorted(allowed)}: {' '.join(missing)}")
    if out_of_area:
        errors += 1
        print(f"  ERRO componente nao permitido: {' '.join(out_of_area)}")
    if unresolved:
        print(f"  AVISO dependencias nao resolvidas no indice: {len(unresolved)} (ex.: {sorted(unresolved)[:3]})")
    return errors, roots


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--index", action="append", required=True, help="arquivo Packages(.xz)")
    ap.add_argument("--area", action="append", required=True, help="componente de cada --index (mesma ordem)")
    ap.add_argument("--areas", default="main,non-free-firmware", help="componentes permitidos (espelha auto/config)")
    ap.add_argument("--iso", action="append", default=[], help="lista instalada na ISO (repetivel)")
    ap.add_argument("--optional", action="append", default=[], help="lista de perfil opcional (repetivel)")
    ap.add_argument("--top", type=int, default=0, help="mostra os N maiores pacotes do fechamento da ISO")
    args = ap.parse_args()
    if len(args.index) != len(args.area):
        ap.error("--index e --area devem aparecer o mesmo numero de vezes")
    if not args.iso and not args.optional:
        ap.error("informe ao menos uma --iso ou --optional")

    allowed = set(args.areas.split(","))
    pkgs, provides = load_index(list(zip(args.index, args.area)))
    skip = {n for n, f in pkgs.items() if f.get("Essential") == "yes" or f.get("Priority") in ESSENTIAL_LIKE}

    errors = 0
    iso_roots = set()
    for path in args.iso:
        e, roots = analyze(path, "ISO", pkgs, provides, skip, allowed)
        errors += e
        iso_roots |= roots
    iso_seen, _ = closure(iso_roots, pkgs, provides, skip)
    iso_mb = sum(int(pkgs[n].get("Installed-Size", 0)) for n in iso_seen) / 1024
    print(f"TOTAL ISO (uniao): ~{len(iso_seen)} pacotes, ~{iso_mb:.0f} MB instalado (estimativa; sem Essential/required)")
    for msg in conflicts_in(iso_seen, pkgs):
        errors += 1
        print(f"  ERRO conflito na ISO: {msg}")

    for path in args.optional:
        e, roots = analyze(path, "OPCIONAL", pkgs, provides, skip, allowed)
        errors += e
        both, _ = closure(iso_roots | roots, pkgs, provides, skip)
        extra = sum(int(pkgs[n].get("Installed-Size", 0)) for n in both - iso_seen) / 1024
        print(f"  acrescenta ~{len(both - iso_seen)} pacotes e ~{extra:.0f} MB sobre a ISO")
        for msg in conflicts_in(both, pkgs):
            errors += 1
            print(f"  ERRO conflito ISO+perfil: {msg}")

    if args.top:
        print(f"Maiores pacotes do fechamento da ISO (top {args.top}):")
        for n in sorted(iso_seen, key=lambda x: -int(pkgs[x].get("Installed-Size", 0)))[: args.top]:
            print(f"  {int(pkgs[n].get('Installed-Size', 0)) / 1024:7.1f} MB  {n}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
