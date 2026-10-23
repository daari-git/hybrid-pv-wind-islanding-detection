"""Figures of the README that are drawn from the result tables, not by MATLAB.

Writes to docs/:
  steps.png            the project's steps and which are done
  feeder_results.png   the detector in the loop on the real feeder, before and after retraining
  feeder_retrain.png   offline replay before and after retraining with feeder cases
  feeder_controllers.png  the four current controllers on the feeder
  confirmation.png     step 9: the ML-triggered confirmation's angle response, detection time, wrong trips
and copies the block diagrams drawn by paper/make_figures.py (system, PV and
wind models, control, feeder map, connection-bus screening) when they exist.
Run from the repository root: python scripts/readme_figures.py
"""
import csv
import os
import shutil
import textwrap

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import colors
from matplotlib.patches import FancyBboxPatch

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "results")
DOCS = os.path.join(ROOT, "docs")
PAPER_FIGS = os.path.join(ROOT, "paper", "figures")

OK = ["#0072B2", "#D55E00", "#009E73", "#CC79A7", "#56B4E9", "#E69F00"]   # Okabe-Ito
INK, GREY, LIGHT = "#222222", "#6b6b6b", "#e6e6e6"
plt.rcParams.update({
    "font.family": "Arial", "font.size": 9, "axes.titlesize": 9.5, "axes.labelsize": 9,
    "xtick.labelsize": 8.5, "ytick.labelsize": 8.5, "legend.fontsize": 8.5, "axes.linewidth": 0.7,
    "axes.spines.top": False, "axes.spines.right": False, "axes.grid": True, "grid.color": "#e3e3e3",
    "grid.linewidth": 0.6, "legend.frameon": False, "axes.titlepad": 6,
})

# Status of every step; keep in step with the table at the top of the README.
DONE, RUN, TODO = "done", "running", "to do"
STEPS = [
    ("1", "Corrected test bed", DONE),
    ("2", "PI baseline against grid strength", DONE),
    ("3", "H-infinity and four current controllers", DONE),
    ("4", "Islanding test bench, baseline relays", DONE),
    ("5", "Drift stress tests, 400-case dataset", DONE),
    ("6", "ML classifier on unseen conditions", DONE),
    ("7", "Detector in the model, sensor noise", DONE),
    ("8", "Real feeder (NEA Pidari, 400 V)", DONE),
    ("9", "ML-triggered confirmation (decision 1)", DONE),
    ("10", "Paper", RUN),
]
SUBSTEPS = [
    ("8.1", "Connection-bus screening", DONE),
    ("8.2", "Feeder model", DONE),
    ("8.3", "Original detector, PI", DONE),
    ("8.4", "Feeder training set, retraining", DONE),
    ("8.5", "Retrained detector, PI", DONE),
    ("8.6", "Retrained detector, H-infinity", DONE),
    ("8.7", "Retrained detector on the test bed", DONE),
    ("8.8", "Four controllers on the feeder", DONE),
]
FILL = {DONE: "#d9efe6", RUN: "#fde9c8", TODO: "white"}
EDGE = {DONE: "#009E73", RUN: "#E69F00", TODO: "#9a9a9a"}

EVENTS = ["Irradiance step down", "Irradiance step up", "Wind step down", "Load +6 kW at the unit",
          "Capacitor 5 kvar", "Sag to 0.7 pu", "Sag to 0.5 pu", "Swell to 1.15 pu", "Ramp -2 Hz/s",
          "Ramp +2 Hz/s", "Phase jump 20°", "Load +10 kW at B3", "Load -10 kW at B3"]
CONDS = [("f30_t1", "F1"), ("f50_t2", "F2"), ("f60a3_t3", "F3")]


def rd(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def num(x):
    try:
        return float(x)
    except ValueError:
        return float("nan")


def yes(x):
    return x in ("1", "true", "True")


def save(fig, name):
    fig.savefig(os.path.join(DOCS, name + ".png"), dpi=150, bbox_inches="tight", pad_inches=0.05)
    plt.close(fig)


def fig_steps():
    fig = plt.figure(figsize=(14, 4.3))
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 110); ax.set_ylim(0, 39); ax.axis("off")
    w, h, gap = 9.8, 9.0, 1.15
    for k, (n, title, st) in enumerate(STEPS):
        x = 0.6 + k*(w + gap); y = 27.5
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0,rounding_size=0.6",
                                    fc=FILL[st], ec=EDGE[st], lw=1.4, ls="--" if st == TODO else "-"))
        ax.text(x + w/2, y + h - 1.6, f"Step {n}", ha="center", va="center", fontsize=8.5, weight="bold")
        ax.text(x + w/2, y + h/2 - 0.2, textwrap.fill(title, 15), ha="center", va="center",
                fontsize=7.6, linespacing=1.15)
        ax.text(x + w/2, y + 1.2, st.upper(), ha="center", va="center", fontsize=6.8, weight="bold", color=EDGE[st])
        if k < len(STEPS) - 1:
            ax.annotate("", xy=(x + w + gap, y + h/2), xytext=(x + w, y + h/2),
                        arrowprops=dict(arrowstyle="-|>", color=GREY, lw=0.8, mutation_scale=7))
    x8 = 0.6 + 7*(w + gap) + w/2
    ax.plot([x8, x8], [27.5, 22.5], color=GREY, lw=0.8)
    ax.text(1.0, 21.0, "Step 8 in detail", fontsize=8.5, weight="bold", va="center")
    sw, sh, sg = 12.7, 8.2, 1.05
    for k, (n, title, st) in enumerate(SUBSTEPS):
        x = 0.6 + k*(sw + sg); y = 8.5
        ax.add_patch(FancyBboxPatch((x, y), sw, sh, boxstyle="round,pad=0,rounding_size=0.6",
                                    fc=FILL[st], ec=EDGE[st], lw=1.2, ls="--" if st == TODO else "-"))
        ax.text(x + sw/2, y + sh - 1.5, n, ha="center", va="center", fontsize=8, weight="bold")
        ax.text(x + sw/2, y + sh/2 - 0.2, textwrap.fill(title, 18), ha="center", va="center",
                fontsize=7.6, linespacing=1.15)
        ax.text(x + sw/2, y + 1.1, st.upper(), ha="center", va="center", fontsize=6.5, weight="bold", color=EDGE[st])
    for st, lab, x in [(DONE, "done", 1.0), (RUN, "running or in progress", 12.5), (TODO, "still to do", 33.0)]:
        ax.add_patch(FancyBboxPatch((x, 2.0), 2.4, 2.4, boxstyle="round,pad=0,rounding_size=0.3",
                                    fc=FILL[st], ec=EDGE[st], lw=1.2, ls="--" if st == TODO else "-"))
        ax.text(x + 3.2, 3.2, lab, va="center", fontsize=8.5)
    save(fig, "steps")


def fig_feeder_results():
    orig = rd(os.path.join(RES, "feeder_closed_loop_pi.csv"))
    f_re = os.path.join(RES, "feeder_closed_loop_pi_islanding_classifier_feeder.csv")
    f_hi = os.path.join(RES, "feeder_closed_loop_hinfinity_islanding_classifier_feeder.csv")
    re = rd(f_re) if os.path.exists(f_re) else []
    hi = rd(f_hi) if os.path.exists(f_hi) else []
    fig, axs = plt.subplots(1, 3, figsize=(15, 4.6), gridspec_kw={"width_ratios": [1.05, 1.0, 1.0]})

    ax = axs[0]
    def cdf(rows, label, **kw):
        isl = [r for r in rows if r["group"] in ("cases", "afd") and yes(r["island"])]
        if not isl:
            return
        t = sorted(num(r["tTrip_ms"]) for r in isl if yes(r["detected"]))
        xs, ys = [0], [0]
        for i, v in enumerate(t):
            xs += [v, v]; ys += [100*i/len(isl), 100*(i + 1)/len(isl)]
        xs.append(800); ys.append(ys[-1])
        ax.plot(xs, ys, label=f"{label}: {len(t)} of {len(isl)}", lw=1.8, **kw)
    cdf([r for r in orig if r["group"] == "cases"], "Original detector, PI", color=OK[4])
    cdf([r for r in re if r["group"] == "cases"], "Retrained detector, PI", color=OK[0])
    cdf([r for r in hi if r["group"] == "cases"], "Retrained detector, H-infinity", color=OK[3], ls="--")
    cdf([r for r in orig if r["group"] == "afd"], "Frequency drift + IEEE relay", color=OK[1], ls=":")
    ax.set_xlim(0, 800); ax.set_ylim(0, 102)
    ax.set_xlabel("Time after the island forms (ms)"); ax.set_ylabel("Islands detected (%)")
    ax.set_title("(a) Islands on F1-F3: time to detect", loc="left")
    ax.legend(loc="lower right")

    ax = axs[1]
    cols = [("Original", orig)] + ([("Retrained", re)] if re else [])
    xi = 0
    for name, rows in cols:
        for cid, lab in CONDS:
            for e in range(1, 14):
                r = next((r for r in rows if r["case"] == f"{cid}_event{e:02d}"), None)
                trip = r is not None and yes(r["falseTrip"])
                ax.add_patch(plt.Rectangle((xi - 0.42, 12 - (e - 1) - 0.42), 0.84, 0.84,
                                           fc=OK[1] if trip else LIGHT, ec="white"))
                if trip:
                    ax.text(xi, 12 - (e - 1), f"{num(r['tTrip_ms']):.0f}", ha="center", va="center",
                            fontsize=7, color="white")
            xi += 1
        xi += 0.5
    ax.set_xlim(-0.6, xi - 0.9); ax.set_ylim(-0.6, 12.6); ax.grid(False)
    ticks = [i + 3.5*g for g in range(len(cols)) for i in range(3)]
    ax.set_xticks(ticks); ax.set_xticklabels([lab for _ in cols for _, lab in CONDS])
    ax.set_yticks(range(13)); ax.set_yticklabels(EVENTS[::-1])
    for g, (name, _) in enumerate(cols):
        ax.text(1 + 3.5*g, 13.1, name, ha="center", va="bottom", fontsize=9, weight="bold")
    ax.tick_params(length=0)
    for s in ax.spines.values():
        s.set_visible(False)
    n0 = sum(yes(r["falseTrip"]) for r in orig if r["group"] == "cases")
    title = f"(b) Ordinary events: false trips (ms), {n0} of 39"
    if re:
        title += f" -> {sum(yes(r['falseTrip']) for r in re if r['group'] == 'cases')} of 39"
    ax.set_title(title, loc="left", pad=22)

    ax = axs[2]
    N = [r for r in (re or orig) if r["group"] == "ndz"]
    dPs = sorted({num(r["dP_pct"]) for r in N}); dQs = sorted({num(r["dQ_pct"]) for r in N})
    norm = colors.Normalize(20, 110); cmap = plt.get_cmap("Blues")
    for r in N:
        i, j = dPs.index(num(r["dP_pct"])), dQs.index(num(r["dQ_pct"]))
        t = num(r["tTrip_ms"]); ok = yes(r["detected"])
        ax.add_patch(plt.Rectangle((i - 0.46, j - 0.46), 0.92, 0.92,
                                   fc=cmap(0.15 + 0.8*norm(t)) if ok else LIGHT, ec="white"))
        ax.text(i, j, f"{t:.0f}" if ok else "missed", ha="center", va="center", fontsize=8,
                color="white" if ok and norm(t) > 0.5 else INK)
    ax.set_xlim(-0.5, len(dPs) - 0.5); ax.set_ylim(-0.5, len(dQs) - 0.5); ax.grid(False)
    ax.set_xticks(range(len(dPs))); ax.set_xticklabels([f"{p:+.0f}" if p else "0" for p in dPs])
    ax.set_yticks(range(len(dQs))); ax.set_yticklabels([f"{q:+g}" if q else "0" for q in dQs])
    ax.tick_params(length=0)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.set_xlabel("Active power mismatch (%)"); ax.set_ylabel("Reactive power mismatch (%)")
    ax.set_title(f"(c) Feeder islands at F1, {'retrained' if re else 'original'} detector: time (ms)", loc="left")
    fig.tight_layout(w_pad=2.5)
    save(fig, "feeder_results")


def fig_feeder_retrain():
    S = {(r["evaluation"], r["fold"]): r for r in rd(os.path.join(RES, "feeder_retrain_summary.csv"))}
    p7 = next(r for r in rd(os.path.join(RES, "detector_selection.csv"))
              if r["W_ms"] == "20" and r["model"] == "nn" and r["training"] == "noisy"
              and r["threshold"] == "0.8" and r["debounce"] == "4" and r["noise_level"] == "1")
    before = {"test bed": p7, "feeder": S[("original", "total")]}
    after = {"test bed": S[("scr", "total")], "feeder": S[("feeder", "total")]}
    groups = [("test bed", "Test bed,\ngrid strength held out"), ("feeder", "Feeder,\ncondition held out")]
    metrics = [("detected_pct", "(a) Islands detected (%)", (80, 100)),
               ("matched_pct", "(b) Matched islands detected (%)", (80, 100)),
               ("falseTrip_pct", "(c) Ordinary events tripped (%)", (0, 22))]
    fig, axs = plt.subplots(1, 3, figsize=(12, 3.6))
    for ax, (col, title, lim) in zip(axs, metrics):
        for g, (key, _) in enumerate(groups):
            for b, (src, lab, c) in enumerate([(before, "Before retraining", OK[4]), (after, "After retraining", OK[0])]):
                row = src[key]
                v = num(row.get(col, row.get("detected_matched_pct", "nan")))
                x = g + (b - 0.5)*0.36
                ax.bar(x, v - lim[0], 0.34, bottom=lim[0], color=c, label=lab if g == 0 else None)
                ax.text(x, v + (lim[1] - lim[0])*0.015, f"{v:.1f}", ha="center", va="bottom", fontsize=8.5)
        ax.set_xticks(range(len(groups))); ax.set_xticklabels([g[1] for g in groups])
        ax.set_ylim(*lim); ax.set_title(title, loc="left"); ax.grid(axis="x", visible=False)
    fig.legend(*axs[0].get_legend_handles_labels(), loc="upper center", ncol=2, bbox_to_anchor=(0.5, 1.06))
    fig.tight_layout(w_pad=2.0)
    save(fig, "feeder_retrain")


def fig_feeder_controllers():
    M = rd(os.path.join(RES, "feeder_margins.csv"))
    T = rd(os.path.join(RES, "feeder_controllers.csv"))
    ctrls = ["PI", "PID", "H-infinity", "Fuzzy PI"]
    ccol = dict(zip(ctrls, [OK[0], OK[2], OK[3], OK[5]]))
    buses = ["A1", "A3", "A5 (PCC)"]
    conds = [("f30_t1", "F1 (A5, 30%)"), ("f50_t2", "F2 (A5, 50%,\nharmonics)"), ("f60a3_t3", "F3 (A3, 60%)")]
    panels = [(M, "bus", [(b, b.replace(" (PCC)", "")) for b in buses], "Ms", "(a) Sensitivity peak of the current loop", None),
              (T, "cond", conds, "THDi_pct", "(b) Current THD in steady state (%)", None),
              (T, "cond", conds, "VdcDev_V", "(c) DC-link dip after a 40% irradiance drop (V)", None)]
    fig, axs = plt.subplots(1, 3, figsize=(15, 3.9))
    for ax, (rows, key, groups, col, title, _) in zip(axs, panels):
        for g, (gid, glab) in enumerate(groups):
            for k, c in enumerate(ctrls):
                r = next(r for r in rows if r[key] == gid and r["controller"] == c)
                v = num(r[col]); x = g + (k - 1.5)*0.2
                ax.bar(x, v, 0.18, color=ccol[c], label=c if g == 0 else None)
                ax.text(x, v, f"{v:.2f}" if col == "Ms" else f"{v:.1f}", ha="center", va="bottom", fontsize=7.5)
        ax.set_xticks(range(len(groups))); ax.set_xticklabels([g[1] for g in groups])
        ax.set_title(title, loc="left"); ax.grid(axis="x", visible=False)
    axs[0].set_ylim(0, 2.3); axs[0].set_xlabel("Bus the unit is connected to")
    fig.legend(*axs[0].get_legend_handles_labels(), loc="upper center", ncol=4, bbox_to_anchor=(0.5, 1.07))
    fig.tight_layout(w_pad=2.5)
    save(fig, "feeder_controllers")


def fig_confirmation():
    det = "islanding_classifier_feeder"
    runs = {(where, ctrl, step): rd(os.path.join(RES, f"{pre}_{ctrl}_{det}{suf}.csv"))
            for where, pre in (("feeder", "feeder_closed_loop"), ("test bed", "closed_loop"))
            for ctrl in ("pi", "hinfinity") for step, suf in ((8, ""), (9, "_confirm"))}
    fig, axs = plt.subplots(1, 3, figsize=(15, 4.4), gridspec_kw={"width_ratios": [1.25, 1.0, 0.9]})

    ax = axs[0]
    rows = [("Feeder, grid connected\n(load switching alarms)", "feeder", False, lambda r: True),
            ("Test bed, grid connected\n(no-load steady alarm)", "test bed", False, lambda r: True),
            ("Feeder islands,\nunit's breaker", "feeder", True, lambda r: r["kind"] == "svc"),
            ("Feeder islands,\nwhole feeder", "feeder", True, lambda r: r["kind"] == "dt"),
            ("Test-bed islands", "test bed", True, lambda r: True)]
    for y, (lab, where, island, pick) in enumerate(rows[::-1]):
        for ctrl, mk, col, dy in (("pi", "o", OK[0], 0.12), ("hinfinity", "D", OK[3], -0.12)):
            v = [abs(num(r["resp_rad"])) for r in runs[(where, ctrl, 9)]
                 if num(r["nConfirm"]) > 0 and yes(r["island"]) == island and pick(r)]
            ax.scatter(v, [y + dy]*len(v), s=16, marker=mk, facecolor="none" if island else col, edgecolor=col,
                       lw=0.9, label=("PI" if ctrl == "pi" else "H-infinity") if y == 0 else None, zorder=3)
    ax.axvline(0.05, color=OK[1], lw=1.5)
    ax.text(0.052, len(rows) - 0.45, "threshold 0.05 rad", color=OK[1], fontsize=8.5, va="center")
    ax.text(0.0028, -0.75, "no trip: alarm reset", fontsize=8.5, color=GREY)
    ax.text(0.6, -0.75, "trip", fontsize=8.5, color=GREY)
    ax.set_xscale("log"); ax.set_xlim(0.0025, 4); ax.set_ylim(-1.0, len(rows) - 0.2)
    ax.set_yticks(range(len(rows))); ax.set_yticklabels([r[0] for r in rows[::-1]])
    ax.set_xlabel("PCC voltage angle response to the nudge, |Δφ| (rad)")
    ax.set_title("(a) Every confirmation: feeder and test bed, PI and H-infinity", loc="left")
    ax.legend(loc="upper right", fontsize=8)

    ax = axs[1]
    def cdf(rows, label, **kw):
        isl = [r for r in rows if r["group"] == "cases" and yes(r["island"])]
        t = sorted(num(r["tTrip_ms"]) for r in isl if yes(r["detected"]))
        xs, ys = [0], [0]
        for i, v in enumerate(t):
            xs += [v, v]; ys += [100*i/len(isl), 100*(i + 1)/len(isl)]
        xs.append(300); ys.append(ys[-1])
        ax.plot(xs, ys, label=f"{label}: {len(t)} of {len(isl)}", lw=1.8, **kw)
    cdf(runs[("feeder", "pi", 8)], "Step 8 (retrained), PI", color=OK[4])
    cdf(runs[("feeder", "pi", 9)], "Step 9 (confirmed), PI", color=OK[0])
    cdf(runs[("feeder", "hinfinity", 9)], "Step 9 (confirmed), H-infinity", color=OK[3], ls="--")
    ax.set_xlim(0, 300); ax.set_ylim(0, 102)
    ax.set_xlabel("Time after the island forms (ms)"); ax.set_ylabel("Islands detected (%)")
    ax.set_title("(b) Feeder islands F1-F3: every one 30 ms later", loc="left")
    ax.legend(loc="lower right")

    ax = axs[2]
    groups = [("Feeder\nPI", "feeder", "pi"), ("Feeder\nH-infinity", "feeder", "hinfinity"),
              ("Test bed\nPI", "test bed", "pi"), ("Test bed\nH-infinity", "test bed", "hinfinity")]
    for g, (lab, where, ctrl) in enumerate(groups):
        for k, step in enumerate((8, 9)):
            calm = [r for r in runs[(where, ctrl, step)] if r["group"] in ("cases", "steady") and not yes(r["island"])]
            n = sum(num(r["tTrip_ms"]) < 1e9 for r in calm)       # any trip, before or after the event
            tot = len(calm)
            x = g + (k - 0.5)*0.36
            ax.bar(x, n, 0.32, color=OK[4] if step == 8 else OK[0], label=f"Step {step}" if g == 0 else None)
            ax.text(x, n + 0.1, f"{n}/{tot}", ha="center", va="bottom", fontsize=8)
    ax.set_xticks(range(len(groups))); ax.set_xticklabels([g[0] for g in groups])
    ax.set_ylim(0, 10); ax.grid(axis="x", visible=False)
    ax.set_ylabel("Ordinary events and steady runs tripped")
    ax.set_title("(c) Wrong trips", loc="left")
    ax.legend(loc="upper right")
    fig.tight_layout(w_pad=2.5)
    save(fig, "confirmation")


def copy_paper_figures():
    names = {"fig_system": "system_diagram", "fig_sources": "pv_wind_models", "fig_control": "control_diagram",
             "fig_feeder": "feeder_map", "fig_screening": "feeder_screening"}
    for src, dst in names.items():
        f = os.path.join(PAPER_FIGS, src + ".png")
        if os.path.exists(f):
            shutil.copyfile(f, os.path.join(DOCS, dst + ".png"))


if __name__ == "__main__":
    fig_steps()
    fig_feeder_results()
    fig_feeder_retrain()
    fig_feeder_controllers()
    fig_confirmation()
    copy_paper_figures()
    print("README figures written to", DOCS)
