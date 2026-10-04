#!/usr/bin/env python3
"""Fits the good bot's placement weights (phase 6 step 6b,
docs/plans/rebuild-phase6-bot-tuning.md, section 2.2) from
tools/bots/placement_data.gd's CSV, in plain Python (no numpy).

The model scores a formation as weights . terms, where each term is a
feature times a context (what the fight holds: placement.gd's
CONTEXT_NAMES, so the weights move with the enemies), fitted to the heroes'
HP left at the end (a lost fight counts as -0.5, so winning matters most),
by ridge regression on standardized features. It checks itself by leaving
each encounter out in turn: fitted on the others, does the held-out
encounter's best-scored formation (of the sampled ones) win more often than
a random one? Then it prints the weights on all the data, unstandardized,
for WEIGHTS in placement.gd.

Usage: python3 tools/bots/fit_placement.py data.csv [weights.json] [--water --base=placement_weights.json]
With weights.json (tools/bots/placement_weights.json), it writes the
weights there for placement.gd to read.

With --water (phase 8 part 3): fits only the fights with water (Act 2's),
and writes them as the file's "water_weights" beside --base's "weights",
which it keeps (placement.gd scores a fight with water by them), so Act 1's
placement doesn't move.
"""

import csv
import json
import sys

LOSS_VALUE = -0.5
RIDGE = 5.0
TOP = 5  # how many best-scored formations a held-out check looks at


def read(path):
    with open(path) as handle:
        rows = list(csv.DictReader(handle))
    features = [key for key in rows[0].keys() if key not in ("encounter", "won", "hp_left") and not key.startswith("ctx_")]
    contexts = [key for key in rows[0].keys() if key.startswith("ctx_")]
    names = [f + "*" + c[4:] for c in contexts for f in features]
    data = []
    for row in rows:
        x = [float(row[f]) * float(row[c]) for c in contexts for f in features]
        won = int(row["won"])
        y = float(row["hp_left"]) if won else LOSS_VALUE
        data.append((row["encounter"], x, won, y))
    return names, data


def solve(a, b):
    """Gaussian elimination with partial pivoting: a x = b."""
    n = len(b)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(m[r][col]))
        m[col], m[pivot] = m[pivot], m[col]
        if abs(m[col][col]) < 1e-12:
            continue
        for r in range(n):
            if r != col:
                factor = m[r][col] / m[col][col]
                for c in range(col, n + 1):
                    m[r][c] -= factor * m[col][c]
    return [m[i][n] / m[i][i] if abs(m[i][i]) > 1e-12 else 0.0 for i in range(n)]


def scaling(rows):
    k = len(rows[0][1])
    means = [sum(r[1][j] for r in rows) / len(rows) for j in range(k)]
    sds = []
    for j in range(k):
        var = sum((r[1][j] - means[j]) ** 2 for r in rows) / len(rows)
        sds.append(var ** 0.5 if var > 1e-12 else 1.0)
    means[0] = 0.0
    sds[0] = 1.0
    return means, sds


def sums(rows, means, sds):
    """The normal equations' sums over `rows` (standardized)."""
    k = len(means)
    a = [[0.0] * k for _ in range(k)]
    b = [0.0] * k
    for r in rows:
        z = [(r[1][j] - means[j]) / sds[j] for j in range(k)]
        y = r[3]
        for p in range(k):
            zp = z[p]
            if zp == 0.0:
                continue
            b[p] += zp * y
            row = a[p]
            for q in range(k):
                row[q] += zp * z[q]
    return a, b


def fit(rows, means=None, sds=None, ab=None):
    """Ridge regression on standardized terms (the bias unpenalized).
    Returns weights on the raw terms."""
    if means is None:
        means, sds = scaling(rows)
    k = len(means)
    a, b = ab if ab is not None else sums(rows, means, sds)
    a = [row[:] for row in a]
    for p in range(1, k):
        a[p][p] += RIDGE
    w = solve(a, b)
    raw = [0.0] * k
    raw[0] = w[0]
    for j in range(1, k):
        raw[j] = w[j] / sds[j]
        raw[0] -= w[j] * means[j] / sds[j]
    return raw


def score(w, x):
    return sum(a * b for a, b in zip(w, x))


def main():
    options = dict((arg[2:] + "=").split("=", 1) if "=" not in arg else arg[2:].split("=", 1) for arg in sys.argv[1:] if arg.startswith("--"))
    sys.argv = [arg for arg in sys.argv if not arg.startswith("--")]
    names, data = read(sys.argv[1])
    if "water" in options:
        water = names.index("bias*water")
        data = [r for r in data if r[1][water] != 0.0]
    encounters = sorted(set(r[0] for r in data), key=lambda e: [r[0] for r in data].index(e))
    print("Held out in turn (fitted on the others): random formation's win rate, the best %d scored's, and the best scored's HP left" % TOP)
    total_base = total_top = 0.0
    means, sds = scaling(data)
    k = len(means)
    per = {e: sums([r for r in data if r[0] == e], means, sds) for e in encounters}
    total_a = [[sum(per[e][0][p][q] for e in encounters) for q in range(k)] for p in range(k)]
    total_b = [sum(per[e][1][p] for e in encounters) for p in range(k)]
    for held in encounters:
        test = [r for r in data if r[0] == held]
        a = [[total_a[p][q] - per[held][0][p][q] for q in range(k)] for p in range(k)]
        b = [total_b[p] - per[held][1][p] for p in range(k)]
        w = fit(None, means, sds, (a, b))
        ranked = sorted(test, key=lambda r: -score(w, r[1]))
        rate = sum(r[2] for r in test) / len(test)
        top = sum(r[2] for r in ranked[:TOP]) / TOP
        tenth = sum(r[2] for r in ranked[:len(ranked) // 10]) / (len(ranked) // 10)
        total_base += rate
        total_top += tenth
        print("  %-22s random %3d%%  best %d scored %3d%%  best tenth %3d%%" % (held, 100 * rate, TOP, 100 * top, 100 * tenth))
    print("  mean                   random %3d%%  best tenth %3d%%" % (100 * total_base / len(encounters), 100 * total_top / len(encounters)))
    w = fit(None, means, sds, (total_a, total_b))
    print("\nThe largest weights (all the data):")
    for name, v in sorted(zip(names, w), key=lambda pair: -abs(pair[1]))[:20]:
        print("  %-28s %8.4f" % (name, v))
    if len(sys.argv) > 2:
        with open(sys.argv[2], "w") as handle:
            out = {"_note": "The good bot's placement weights (phase 6 step 6b): one per feature times context, context-major, fitted by tools/bots/fit_placement.py on tools/bots/placement_data.gd's practice fights; water_weights (phase 8 part 3, --water) on the fights with water alone, for placement.gd to score those by. Don't edit by hand.",
                   "terms": names, "weights": [round(v, 5) for v in w]}
            if "water" in options:
                with open(options["base"]) as base_handle:
                    base = json.load(base_handle)
                assert base["terms"] == names, "the base weights' terms don't match the data's"
                out["weights"] = base["weights"]
                out["water_weights"] = [round(v, 5) for v in w]
            json.dump(out, handle, indent=1)
            handle.write("\n")


if __name__ == "__main__":
    main()
