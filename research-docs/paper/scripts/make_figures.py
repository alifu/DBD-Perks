"""Build every figure of the paper from measured data. Run with the dataset repo's venv:

    $DBD_DATASET_DIR/.venv/bin/python scripts/make_figures.py [--only F3 F8]

Inputs (all produced by the dataset repo, none of them images of the game):
  data/perks.json, data/addons.json     class counts (F4)
  models/v2/metrics.json                synthetic validation / hard-test accuracy (F8)
  results/ablation_<percent>.json       evaluate_real.py --json per framed share (F3, F8)
  results/scanlog/*.json                optional: scan log pulled from the phone (F5, F6)
  results/latency.json                  optional: per-stage timings from the phone (F7)
Figures whose input is missing are skipped with a message, never faked.

No game art is drawn: F2 uses a stand-in glyph (a plain star) pushed through the real synthesis code.
"""
import argparse
import json
import math
import os
import sys
from collections import Counter
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import FancyBboxPatch

DATASET_DIR = Path(os.environ.get("DBD_DATASET_DIR", Path(__file__).resolve().parents[5] / "pythonProject" / "dbd_perks_dataset"))
FIGURES_DIR = Path(__file__).resolve().parents[1] / "figures"
SEED = 7
WILSON_Z = 1.96
SHARES = (0, 25, 50, 75, 100)
SHIPPED_SHARE = 75
RARITY_ORDER = ("common", "uncommon", "rare", "veryrare", "visceral")
PALETTE = {"ink": "#1f2933", "muted": "#7b8794", "blue": "#2f6fb3", "orange": "#d9822b", "green": "#3a8f6b", "grid": "#e4e7eb"}

plt.rcParams.update({"font.size": 9, "axes.spines.top": False, "axes.spines.right": False, "axes.edgecolor": PALETTE["muted"],
                     "axes.labelcolor": PALETTE["ink"], "text.color": PALETTE["ink"], "figure.dpi": 150, "savefig.bbox": "tight",
                     "axes.grid": True, "grid.color": PALETTE["grid"], "axes.axisbelow": True})


def save(fig, name: str) -> None:
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIGURES_DIR / f"{name}.svg")
    fig.savefig(FIGURES_DIR / f"{name}.png", dpi=200)
    plt.close(fig)
    print(f"✅ {name}")


def read_json(relative: str):
    path = DATASET_DIR / relative
    return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else None


def wilson(hits: int, total: int) -> tuple[float, float]:
    p = hits / total
    d = 1 + WILSON_Z ** 2 / total
    centre = (p + WILSON_Z ** 2 / (2 * total)) / d
    half = WILSON_Z * math.sqrt(p * (1 - p) / total + WILSON_Z ** 2 / (4 * total * total)) / d
    return max(0.0, centre - half), min(1.0, centre + half)


def ablation_results() -> dict[int, dict]:
    found = {share: read_json(f"results/ablation_{share}.json") for share in SHARES}
    return {share: data for share, data in found.items() if data}


def box(ax, xy, size, text, color) -> None:
    ax.add_patch(FancyBboxPatch(xy, *size, boxstyle="round,pad=0.02,rounding_size=0.04", fc=color, ec=PALETTE["muted"], lw=0.8))
    ax.text(xy[0] + size[0] / 2, xy[1] + size[1] / 2, text, ha="center", va="center", fontsize=8)


def f1_architecture() -> None:
    fig, ax = plt.subplots(figsize=(7.2, 3.0))
    ax.set_xlim(0, 10.8); ax.set_ylim(0, 4.2); ax.axis("off"); ax.grid(False)
    blue, orange, green, red = "#dbe8f5", "#f8e6d2", "#dcefe6", "#f3dede"
    width, height, gap = 1.85, 0.95, 0.3
    top = [("Game data\n(datamine API)", blue), ("perks.json\naddons.json", blue), ("Synthesis:\ncompose, frame,\nphoto effects", orange),
           ("MobileNetV2\ntraining", orange), ("Core ML /\nONNX export", orange)]
    bottom = [("Camera or\nscreenshot", green), ("Locate ≤ 4\nslots, crop", green), ("Classify with\ntest-time aug.", green), ("Unique assign.,\ncards", green)]
    y_top, y_bottom = 2.9, 0.5
    xs_top = [0.1 + i * (width + gap) for i in range(len(top))]
    xs_bottom = [0.1 + i * (width + gap) for i in range(len(bottom))]
    for x, (label, color) in zip(xs_top, top):
        box(ax, (x, y_top), (width, height), label, color)
    for x, (label, color) in zip(xs_bottom, bottom):
        box(ax, (x, y_bottom), (width, height), label, color)
    arrow = dict(arrowstyle="->", color=PALETTE["muted"])
    for row_y, xs in ((y_top, xs_top), (y_bottom, xs_bottom)):
        for a_x, b_x in zip(xs, xs[1:]):
            ax.annotate("", xy=(b_x, row_y + height / 2), xytext=(a_x + width, row_y + height / 2), arrowprops=arrow)
    ax.annotate("", xy=(xs_bottom[2] + width / 2, y_bottom + height), xytext=(xs_top[4] + width / 2, y_top),
                arrowprops=dict(arrowstyle="->", color=PALETTE["muted"], ls="--", connectionstyle="angle,angleA=-90,angleB=0"))
    ax.text(xs_top[4] + width / 2 - 2.3, 2.15, "model bundled in the app", fontsize=7, color=PALETTE["muted"], style="italic")
    box(ax, (xs_top[1] + 0.1, 1.9), (2.0, 0.6), "own game export:\nicons, local only", red)
    ax.annotate("", xy=(xs_top[2] + width / 2, y_top), xytext=(xs_top[1] + 2.1, 2.2), arrowprops=dict(arrowstyle="->", color=PALETTE["muted"], connectionstyle="arc3,rad=-0.2"))
    ax.text(0.1, 4.05, "Offline pipeline (Python)", fontsize=8, weight="bold"); ax.text(0.1, 1.65, "On-device pipeline (iOS)", fontsize=8, weight="bold")
    save(fig, "F1_architecture")


def stand_in_glyph(size: int = 256) -> np.ndarray:
    """RGBA star on a transparent square. Deliberately not game art."""
    import cv2
    canvas = np.zeros((size, size, 4), np.uint8)
    centre = size / 2
    angles = np.radians(np.arange(10) * 36 - 90)
    radii = np.where(np.arange(10) % 2 == 0, size * 0.30, size * 0.13)
    points = np.stack([centre + radii * np.cos(angles), centre + radii * np.sin(angles)], axis=1).astype(np.int32)
    cv2.fillPoly(canvas, [points], (235, 235, 235, 255), cv2.LINE_AA)
    return canvas


def f2_synthesis() -> None:
    sys.path.insert(0, str(DATASET_DIR))
    from synth import compose as C
    from synth.frame import draw_framed
    from synth.photo import apply_photo_effects
    glyph, size = stand_in_glyph(), C.WORK_SIZE
    seed = [SEED, 1]
    flat = C.compose(np.random.default_rng(seed), glyph, framed_probability=0.0)
    rng = np.random.default_rng(seed)
    tint = C.make_background(rng, size)
    colour, alpha = C._place_icon(rng, glyph, size, C.FRAMED_SCALE_RANGE)
    framed = np.clip(draw_framed(rng, tint, colour, alpha), 0, 255).astype(np.uint8)
    photo = apply_photo_effects(np.random.default_rng(seed), framed, 0.9)
    stages = (("1  compose\n(rarity-coloured background)", flat), ("2  frame\n(border, backdrop, neighbour)", framed), ("3  photo effects\n(pixel grid, moiré, glare, JPEG)", photo))
    fig, axes = plt.subplots(1, 3, figsize=(6.6, 2.5))
    for ax, (title, image) in zip(axes, stages):
        ax.imshow(image); ax.set_title(title, fontsize=8); ax.axis("off")
    save(fig, "F2_synthesis_stages")


def f3_domain_gap() -> None:
    results = ablation_results()
    if 0 not in results or SHIPPED_SHARE not in results:
        return print("⏭️  F3 skipped: needs results/ablation_0.json and ablation_75.json")
    before, after = ([r["pCorrect"] for r in sorted(results[s]["records"], key=lambda r: (r["expected"], r["file"]))] for s in (0, SHIPPED_SHARE))
    labels = [r["expected"].replace("_", " ") for r in sorted(results[0]["records"], key=lambda r: (r["expected"], r["file"]))]
    fig, ax = plt.subplots(figsize=(6.0, 0.55 * len(labels) + 1.2))
    ys = np.arange(len(labels))
    ax.hlines(ys, before, after, color=PALETTE["muted"], lw=1.2)
    ax.scatter(before, ys, color=PALETTE["orange"], zorder=3, label="0% framed samples")
    ax.scatter(after, ys, color=PALETTE["blue"], zorder=3, label=f"{SHIPPED_SHARE}% framed samples (shipped)")
    ax.set_yticks(ys, labels); ax.set_xlim(0, 1); ax.invert_yaxis()
    ax.set_xlabel("probability of the correct class on a real phone crop"); ax.legend(loc="upper right", frameon=False)
    save(fig, "F3_domain_gap")


def f4_composition() -> None:
    perks, addons = read_json("data/perks.json"), read_json("data/addons.json")
    if not perks or not addons:
        return print("⏭️  F4 skipped: perks.json / addons.json not found")
    roles = Counter(p["role"] for p in perks["perks"])
    kinds = {kind: Counter(a["rarity"] for a in addons["addons"] if a["kind"] == kind) for kind in ("power", "item")}
    fig, (left, right) = plt.subplots(1, 2, figsize=(7.0, 2.6), gridspec_kw={"width_ratios": [1, 2]})
    left.bar(list(roles), list(roles.values()), color=[PALETTE["blue"], PALETTE["orange"]])
    for i, value in enumerate(roles.values()):
        left.text(i, value + 3, str(value), ha="center")
    left.set_title(f"Perks by role (n = {sum(roles.values())})", fontsize=9)
    bottoms = np.zeros(len(RARITY_ORDER))
    for kind, color in (("power", PALETTE["blue"]), ("item", PALETTE["green"])):
        values = np.array([kinds[kind].get(r, 0) for r in RARITY_ORDER])
        right.bar(RARITY_ORDER, values, bottom=bottoms, color=color, label=f"{kind} add-ons")
        bottoms += values
    right.set_title(f"Add-ons by rarity (n = {int(bottoms.sum())})", fontsize=9); right.legend(frameon=False)
    save(fig, "F4_dataset_composition")


def scan_log() -> list[dict]:
    folder = DATASET_DIR / "results" / "scanlog"
    return [json.loads(p.read_text()) for p in sorted(folder.glob("*.json"))] if folder.is_dir() else []


def f5_confusions() -> None:
    corrections = [c for c in scan_log() if c.get("shown") and c.get("correct")]
    if not corrections:
        return print("⏭️  F5 skipped: no results/scanlog corrections (pull them from the phone, see tools/confusion_report.py)")
    pairs = Counter(tuple(sorted((c["shown"], c["correct"]))) for c in corrections).most_common(10)
    fig, ax = plt.subplots(figsize=(6.0, 0.4 * len(pairs) + 1))
    ax.barh([f"{a.replace('_', ' ')} ↔ {b.replace('_', ' ')}" for (a, b), _ in pairs][::-1], [n for _, n in pairs][::-1], color=PALETTE["blue"])
    ax.set_xlabel("corrections reported by the tester")
    save(fig, "F5_confusions")


def f6_confidence() -> None:
    scans = [s for s in scan_log() if "confidence" in s]
    if len(scans) < 20:
        return print("⏭️  F6 skipped: needs ≥ 20 scan-log records with a confidence and a verdict")
    confidence = np.array([s["confidence"] for s in scans]); correct = np.array([bool(s.get("wasCorrect", True)) for s in scans])
    bins = np.linspace(0, 1, 6)
    fig, (hist, rel) = plt.subplots(1, 2, figsize=(7.0, 2.6))
    hist.hist(confidence, bins=10, range=(0, 1), color=PALETTE["blue"]); hist.set_xlabel("confidence"); hist.set_ylabel("scans")
    index = np.digitize(confidence, bins[1:-1])
    xs = [confidence[index == i].mean() for i in range(5) if (index == i).any()]
    ys = [correct[index == i].mean() for i in range(5) if (index == i).any()]
    rel.plot([0, 1], [0, 1], color=PALETTE["muted"], ls="--"); rel.plot(xs, ys, "o-", color=PALETTE["orange"])
    rel.set_xlabel("mean confidence in bin"); rel.set_ylabel("share correct")
    save(fig, "F6_confidence")


def f7_latency() -> None:
    data = read_json("results/latency.json")
    if not data:
        return print("⏭️  F7 skipped: results/latency.json (per-stage milliseconds measured on the phone) not found")
    stages = list(data["stagesMs"]); values = [data["stagesMs"][s] for s in stages]
    fig, ax = plt.subplots(figsize=(6.0, 2.4))
    ax.barh(stages[::-1], values[::-1], color=PALETTE["blue"]); ax.set_xlabel(f"milliseconds, {data.get('device', 'device')}")
    save(fig, "F7_latency")


def f8_ablation() -> None:
    results = ablation_results()
    if len(results) < 3:
        return print("⏭️  F8 skipped: needs at least 3 results/ablation_<percent>.json files")
    shares = sorted(results)
    top1 = [results[s]["summary"]["top1"] for s in shares]
    ci = [results[s]["summary"]["top1Wilson95"] for s in shares]
    mean_p = [results[s]["summary"]["meanPCorrect"] for s in shares]
    fig, ax = plt.subplots(figsize=(5.4, 2.8))
    ax.errorbar(shares, top1, yerr=[[t - c[0] for t, c in zip(top1, ci)], [c[1] - t for t, c in zip(top1, ci)]], fmt="o-",
                color=PALETTE["blue"], capsize=3, label="real top-1 (95% Wilson)")
    ax.plot(shares, mean_p, "s--", color=PALETTE["orange"], label="mean P(correct class)")
    ax.set_xlabel("share of framed training samples (%)"); ax.set_ylim(0, 1.05); ax.legend(frameon=False, loc="lower right")
    save(fig, "F8_ablation")
    rows = [{"framedPercent": s, **{k: results[s]["summary"][k] for k in ("crops", "top1", "top3", "meanPCorrect")}} for s in shares]
    (FIGURES_DIR / "F8_ablation.json").write_text(json.dumps(rows, indent=2) + "\n")


FIGURES = {"F1": f1_architecture, "F2": f2_synthesis, "F3": f3_domain_gap, "F4": f4_composition, "F5": f5_confusions,
           "F6": f6_confidence, "F7": f7_latency, "F8": f8_ablation}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", nargs="*", choices=sorted(FIGURES))
    args = parser.parse_args()
    if not DATASET_DIR.is_dir():
        print(f"❌ dataset repo not found at {DATASET_DIR}; set DBD_DATASET_DIR", file=sys.stderr)
        return 1
    np.random.seed(SEED)
    for name, build in FIGURES.items():
        if not args.only or name in args.only:
            build()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
