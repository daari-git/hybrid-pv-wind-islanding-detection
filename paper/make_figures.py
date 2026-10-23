"""Figures of the paper, drawn at journal size from the repository's result tables.

Reads results/*.csv and paper/figdata/*.csv (written by export_figure_data.m)
and writes paper/figures/<name>.svg (used by the PDF) and .png (used by the
Word version). Run from the repository root: python paper/make_figures.py
"""
import csv
import math
import os
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import colors
from matplotlib.patches import FancyBboxPatch, Circle

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "results")
FD = os.path.join(ROOT, "paper", "figdata")
OUT = os.path.join(ROOT, "paper", "figures")
os.makedirs(OUT, exist_ok=True)

COL1, COL2 = 3.5, 7.16                     # IEEE column and page widths (in)
OK = ["#0072B2", "#D55E00", "#009E73", "#CC79A7", "#56B4E9", "#E69F00"]   # Okabe-Ito
INK, GREY, LIGHT = "#222222", "#6b6b6b", "#ececec"
plt.rcParams.update({
    "font.family": "Arial", "font.size": 7.5, "axes.titlesize": 7.5, "axes.labelsize": 7.5,
    "xtick.labelsize": 7, "ytick.labelsize": 7, "legend.fontsize": 6.8, "axes.linewidth": 0.6,
    "xtick.major.width": 0.6, "ytick.major.width": 0.6, "xtick.major.size": 2.5, "ytick.major.size": 2.5,
    "lines.linewidth": 1.1, "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.color": "#e3e3e3", "grid.linewidth": 0.5, "legend.frameon": False,
    "svg.fonttype": "path", "axes.titlepad": 3, "axes.labelpad": 2,
})


def rd(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def num(x):
    try:
        return float(x)
    except ValueError:
        return float("nan")


def save(fig, name):
    fig.savefig(os.path.join(OUT, name + ".svg"), bbox_inches="tight", pad_inches=0.02)
    fig.savefig(os.path.join(OUT, name + ".png"), dpi=300, bbox_inches="tight", pad_inches=0.02)
    plt.close(fig)


# ---------------------------------------------------------------- Fig. 1
def fig_system():
    fig = plt.figure(figsize=(COL2, 2.95))
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 100); ax.set_ylim(0, 41.2); ax.axis("off")

    def box(x, y, w, h, text, fc="white", ec=INK, fs=6.4, weight="normal", style="round,pad=0.25,rounding_size=0.6"):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle=style, fc=fc, ec=ec, lw=0.7))
        ax.text(x + w/2, y + h/2, text, ha="center", va="center", fontsize=fs, weight=weight, linespacing=1.15)

    def line(xs, ys, c=INK, lw=0.9, ls="-"):
        ax.plot(xs, ys, color=c, lw=lw, ls=ls, solid_capstyle="butt")

    def arrow(x0, y0, x1, y1, c=INK, lw=0.8, ls="-"):
        ax.annotate("", xy=(x1, y1), xytext=(x0, y0),
                    arrowprops=dict(arrowstyle="-|>", color=c, lw=lw, ls=ls, mutation_scale=6, shrinkA=0, shrinkB=0))

    def breaker(x, y, label, below=False):
        ax.add_patch(plt.Rectangle((x - 1.1, y - 1.1), 2.2, 2.2, fc="white", ec=INK, lw=0.8))
        ax.plot([x - 0.8, x + 0.8], [y - 0.8, y + 0.8], color=INK, lw=0.7)
        ax.text(x, y + (-2.4 if below else 2.0), label, ha="center", va="center", fontsize=6.2)

    # power stage (top), main bus at y = 30
    yb = 30.0
    box(0.6, 33.5, 9.6, 6.3, "PV array\n10.7 kW STC\n(5 × 10 modules)")
    box(12.4, 33.5, 10.6, 6.3, "Boost\nconverter\nP&O MPPT")
    box(0.6, 23.0, 9.6, 6.3, "Wind turbine\nPMSG, 10 kW\nat 12 m/s")
    box(12.4, 23.0, 10.6, 6.3, "Diode rectifier\n+ boost, optimal-\ntorque MPPT")
    line([10.2, 12.4], [36.65, 36.65]); line([10.2, 12.4], [26.15, 26.15])
    line([23.0, 25.6], [36.65, 36.65]); line([23.0, 25.6], [26.15, 26.15])
    line([25.6, 25.6], [26.15, 36.65], lw=1.6)
    ax.text(25.6, 38.6, "DC link\n800 V", ha="center", va="center", fontsize=6.2)
    line([25.6, 28.6], [yb, yb])
    box(28.6, 26.8, 9.4, 6.4, "Two-level\nVSI, 10 kHz\n20 kVA")
    line([38.0, 39.1], [yb, yb]); breaker(40.2, yb, "CB1"); line([41.3, 42.4], [yb, yb])
    box(42.4, 26.8, 8.6, 6.4, "LCL filter\n1.6 mH, 15 µF,\n0.8 mH")
    line([51.0, 58.6], [yb, yb])
    ax.add_patch(Circle((58.6, yb), 0.55, color=INK)); ax.text(58.6, yb + 2.1, "PCC", ha="center", fontsize=6.4, weight="bold")
    line([58.6, 66.4], [yb, yb]); breaker(67.5, yb, "CB2"); line([68.6, 71.0], [yb, yb])
    box(71.0, 26.8, 9.6, 6.4, "Grid impedance\n$Z_g = Z_b/\\mathrm{SCR}$\nX/R = 3")
    line([80.6, 83.0], [yb, yb])
    box(83.0, 25.8, 16.4, 8.4, "Programmable grid\n400 V, 50 Hz: sags, swells,\nramps, phase jumps,\n5th/7th harmonics", fc="#f6f6f6")
    # loads at the PCC
    line([58.6, 58.6], [yb, 22.0]); line([56.0, 66.0], [22.0, 22.0])
    line([56.0, 56.0], [22.0, 20.4]); line([66.0, 66.0], [22.0, 20.4])
    box(50.6, 14.2, 10.8, 6.2, "Local parallel\nRLC load\n$Q_f$ = 1 to 2.5")
    box(62.4, 14.2, 13.6, 6.2, "Second inverter, 10 kW\n(averaged), reactive\ndrift $K_q$ var/Hz")
    # switched equipment
    line([58.6, 58.6], [yb, 33.5], c=GREY, lw=0.6)
    ax.text(58.9, 34.6, "switched load\nand capacitor", fontsize=5.8, color=GREY, va="center")

    # control and detector (bottom)
    yc = 11.0
    box(26.6, 14.2, 21.0, 6.2, "Inverter control, 10 kHz:\nPLL, DC-link PI, current control\n(PI, PID, H$_\\infty$ or fuzzy PI)", fs=6.1)
    arrow(33.3, 20.4, 33.3, 26.8)
    # measurement bus with noise
    xm, ym = 46.7, 22.6
    ax.add_patch(Circle((xm, ym), 1.15, fc="white", ec=INK, lw=0.7))
    ax.text(xm, ym, "+", ha="center", va="center", fontsize=7)
    ax.text(43.6, ym, "sensor noise", fontsize=5.8, color=OK[1], ha="right", va="center")
    arrow(43.7, ym, xm - 1.2, ym, c=OK[1], lw=0.7)
    line([xm, xm], [26.8, ym + 1.15], c=OK[0], lw=0.8)
    ax.text(47.3, 24.0, "$v_{abc}$, $i_{abc}$", fontsize=5.8, color=OK[0], ha="left", va="center")
    line([xm, xm], [ym - 1.15, 20.4], c=OK[0], lw=0.8)
    # pipeline
    steps = [
        ("Buffers: $v_{abc}$, $i_{abc}$ at 10 kHz;\n$f$, $V_{dc}$, $i_d$, $i_q$ at 1 kHz", 2.0, 15.0),
        ("Every 5 ms: window $W$\n(20 ms) against the\n40 ms baseline before it", 19.4, 13.2),
        ("22 change features:\nmagnitude, frequency,\nsequence, power, distortion", 35.0, 14.6),
        ("Neural network\n22–20–10–2 (ReLU),\nscore $s_k$ = P(island)", 52.0, 13.2),
        ("Trip when $s_k > 0.8$\nfor 4 windows\nin a row", 67.6, 11.4),
        ("Open CB1,\nblock both\nboost converters", 81.4, 11.0),
    ]
    for k, (t, x, w) in enumerate(steps):
        box(x, 2.2, w, 7.2, t, fc="#eef4fa" if k < 5 else "#fbeee6", fs=6.1)
        if k:
            px, pw = steps[k - 1][1], steps[k - 1][2]
            arrow(px + pw + 0.25, 5.8, x - 0.25, 5.8)
    line([xm, xm], [14.2, 12.2], c=OK[0], lw=0.8); line([xm, 9.5], [12.2, 12.2], c=OK[0], lw=0.8)
    arrow(9.5, 12.2, 9.5, 9.6, c=OK[0])
    ax.text(26.0, 12.9, "measurements the inverter already has", fontsize=5.8, color=OK[0], ha="center")
    # trip path
    line([86.9, 86.9], [9.6, 12.2], c=OK[1], lw=0.9); line([86.9, 92.0], [12.2, 12.2], c=OK[1], lw=0.9)
    line([92.0, 92.0], [12.2, 25.3], c=OK[1], lw=0.9); line([92.0, 40.2], [25.3, 25.3], c=OK[1], lw=0.9)
    arrow(40.2, 25.3, 40.2, 28.8, c=OK[1], lw=0.9)
    ax.text(91.3, 24.8, "trip, latched with the passive protection", fontsize=5.8, color=OK[1], ha="right", va="top")
    ax.text(11.2, 10.9, "ML detector (MATLAB Function block, same code as offline)", fontsize=6.1, ha="left",
            weight="bold", color=INK)
    save(fig, "fig_system")


# ---------------------------------------------------------------- Fig. 2
def fig_ndz():
    R = rd(os.path.join(RES, "ndz_sweep.csv"))
    dPs = [-20, -10, -5, 0, 5, 10, 20]; dQs = [-5, -2.5, 0, 2.5, 5]
    dets = [("Fast passive", "Fast passive relay"), ("IEEE passive", "IEEE 1547 Cat. II relay"),
            ("IEEE + AFD", "IEEE relay + frequency drift")]
    fig, axs = plt.subplots(1, 3, figsize=(COL2, 2.05), sharey=True)
    norm = colors.LogNorm(5, 2000); cmap = plt.get_cmap("Blues")
    for ax, (d, title) in zip(axs, dets):
        grid = {(num(r["dP_pct"]), num(r["dQ_pct"])): r for r in R if r["detector"] == d}
        nd = 0
        for i, p in enumerate(dPs):
            for j, q in enumerate(dQs):
                r = grid[(p, q)]
                t = num(r["t_ms"])
                det = r["detected"] == "1" and t <= 2000
                fc = cmap(0.15 + 0.75*norm(t)) if det else LIGHT
                ax.add_patch(plt.Rectangle((i - 0.47, j - 0.47), 0.94, 0.94, fc=fc, ec="white", lw=0.8))
                txt = f"{t:.0f}" if det else "ND"
                ax.text(i, j, txt, ha="center", va="center", fontsize=5.6,
                        color="white" if det and norm(t) > 0.55 else INK)
                nd += not det
        ax.set_xlim(-0.5, 6.5); ax.set_ylim(-0.5, 4.5); ax.grid(False)
        ax.set_xticks(range(7)); ax.set_xticklabels([f"{p:+d}" if p else "0" for p in dPs])
        ax.set_yticks(range(5)); ax.set_yticklabels([f"{q:+g}" if q else "0" for q in dQs])
        ax.set_title(f"{title}: {35 - nd} of 35 detected")
        ax.set_xlabel("Active power mismatch ΔP (%)")
        ax.tick_params(length=0)
        for s in ax.spines.values(): s.set_visible(False)
    axs[0].set_ylabel("Reactive mismatch ΔQ (%)")
    fig.tight_layout(pad=0.3, w_pad=0.6)
    save(fig, "fig_ndz")


# ---------------------------------------------------------------- Fig. 3
def fig_rocof():
    R = rd(os.path.join(FD, "rocof.csv"))
    order = [("island", "Island, ΔQ = +2.5%"), ("Irradiance 1000 to 600 W/m2", "Irradiance 1000→600 W/m²"),
             ("Capacitor switched on (5 kvar)", "Capacitor on (5 kvar)"),
             ("Voltage sag to 0.7 pu, 0.5 s", "Sag to 0.7 pu"), ("Phase jump 20 deg", "Phase jump 20°")]
    fig, axs = plt.subplots(1, 5, figsize=(COL2, 1.65), sharey=True)
    for k, (ax, (c, title)) in enumerate(zip(axs, order)):
        t = [num(r["t_ms"]) for r in R if r["case"] == c]
        y = [max(num(r["rocof"]), 0.05) for r in R if r["case"] == c]
        peak = max(v for tt, v in zip(t, y) if 0 <= tt <= 300)
        ax.plot(t, y, color=OK[1] if k == 0 else OK[0], lw=0.9)
        ax.axhline(2.0, color=GREY, ls="--", lw=0.6)
        ax.set_yscale("log"); ax.set_ylim(0.05, 200); ax.set_xlim(-50, 300)
        ax.set_title(f"{title}\npeak {peak:.1f} Hz/s", linespacing=1.1)
        ax.set_xlabel("Time (ms)")
        ax.set_xticks([0, 100, 200, 300])
    axs[0].set_ylabel("|df/dt| at the relay (Hz/s)")
    axs[-1].text(295, 2.3, "2 Hz/s trip", ha="right", va="bottom", fontsize=6, color=GREY)
    fig.tight_layout(pad=0.3, w_pad=0.5)
    save(fig, "fig_rocof")


# ---------------------------------------------------------------- Fig. 4
def fig_afd():
    R = rd(os.path.join(FD, "afd_stress.csv"))
    trips = {r["case"]: (r["trip"] == "1", num(r["t_ms"])) for r in rd(os.path.join(FD, "afd_stress_trips.csv"))}
    S = rd(os.path.join(FD, "scr2_sag.csv"))
    st = {r["case"]: (r["trip"] in ("1", "true"), num(r["t_ms"])) for r in rd(os.path.join(FD, "scr2_sag_trips.csv"))}
    panels = [
        ("(a) Load quality factor, SCR 10", [("qf1", "$Q_f$ = 1"), ("qf2.5", "$Q_f$ = 2.5")]),
        ("(b) Grid strength, $Q_f$ = 1", [("qf1", "SCR 10"), ("scr3", "SCR 3"), ("scr2", "SCR 2")]),
        ("(c) Second inverter, SCR 10", [("der2_0", "$K_q$ = 0"), ("der2_p1000", "$K_q$ = +1 kvar/Hz"),
                                         ("der2_p2000", "$K_q$ = +2 kvar/Hz"), ("der2_m2000", "$K_q$ = −2 kvar/Hz")]),
    ]
    sty = ["-", "--", ":", "-."]
    fig, axs = plt.subplots(1, 4, figsize=(COL2, 2.15))
    for ax, (title, cases) in zip(axs[:3], panels):
        for k, (c, lbl) in enumerate(cases):
            t = [num(r["t_s"]) for r in R if r["case"] == c]
            f = [num(r["f_Hz"]) for r in R if r["case"] == c]
            ok, tt = trips[c]
            ax.plot(t, f, sty[k], color=OK[k], lw=1.0,
                    label=f"{lbl}: {tt:.0f} ms" if ok else f"{lbl}: not detected")
        ax.axhline(51.67, color=GREY, ls="--", lw=0.6)
        ax.set_xlim(-0.1, 2.0); ax.set_ylim(46, 60.5)
        ax.set_title(title); ax.set_xlabel("Time after islanding (s)")
        if len(cases) < 4:
            ax.legend(loc="lower right", handlelength=1.8, borderaxespad=0.2, labelspacing=0.25)
    # panel (c): direct labels, the legend would not fit
    ax = axs[2]; kw = dict(ha="right", fontsize=6.4, color=INK)
    ax.text(1.98, 58.6, "$K_q$ = +1, +2 kvar/Hz: 197, 188 ms", va="bottom", **kw)
    ax.text(1.98, 55.7, "$K_q$ = 0: 221 ms", va="bottom", **kw)
    ax.text(1.98, 49.8, "$K_q$ = −2 kvar/Hz (opposing):\nnot detected in 2 s", va="top", **kw)
    axs[0].set_ylabel("Frequency (Hz)")
    axs[0].text(1.98, 51.9, "OF2 51.67 Hz", ha="right", fontsize=6, color=GREY)
    ax = axs[3]
    for k, (c, lbl) in enumerate([("scr2_full_event06", "drift on"), ("scr2_full_event06_noafd", "drift off")]):
        t = [num(r["t_s"]) for r in S if r["case"] == c]
        f = [num(r["f_Hz"]) for r in S if r["case"] == c]
        ok, tt = st[c]
        ax.plot(t, f, ["-", "--"][k], color=[OK[1], OK[0]][k], lw=0.9,
                label=f"{lbl}: PLL loses lock,\nfalse trip at {tt:.0f} ms" if ok else f"{lbl}: rides through")
    ax.set_xlim(-0.1, 1.0); ax.set_ylim(40, 100)
    ax.set_title("(d) Sag to 0.7 pu, SCR 2"); ax.set_xlabel("Time after the sag (s)")
    ax.legend(loc="center right", handlelength=1.8, borderaxespad=0.2)
    fig.tight_layout(pad=0.3, w_pad=0.5)
    save(fig, "fig_afd")


# ---------------------------------------------------------------- Fig. 5
NAMES = {
    "dV_max": "ΔV$_{max}$  largest voltage change", "phase_jump": "Δφ  phase jump",
    "rocof_peak": "ROCOF$_{pk}$  peak ROCOF", "df_end": "Δf$_{end}$  frequency change at end",
    "dV_neg": "ΔV$^{-}$  negative-seq. voltage", "df_max": "Δf$_{max}$  largest frequency change",
    "dTHD_v": "Δd$_v$  voltage distortion", "dI_pos": "ΔI$^{+}$  positive-seq. current",
    "dV_mean": "ΔV$_{mean}$  mean voltage change", "dVdc_max": "ΔV$_{dc}$  DC-link deviation",
    "dV_pos": "ΔV$^{+}$  positive-seq. voltage", "rocof_fit": "ROCOF$_{fit}$  fitted ROCOF",
}


def fig_importance():
    R = rd(os.path.join(RES, "feature_importance.csv"))[:12]
    fig, ax = plt.subplots(figsize=(COL1, 2.45))
    y = list(range(len(R)))[::-1]
    m = [num(r["mean_drop"]) for r in R]
    lo = [min(num(r[c]) for c in ("scr20", "scr10", "scr5", "scr3")) for r in R]
    hi = [max(num(r[c]) for c in ("scr20", "scr10", "scr5", "scr3")) for r in R]
    ax.barh(y, m, color=OK[0], height=0.62, zorder=2)
    ax.errorbar(m, y, xerr=[[a - b for a, b in zip(m, lo)], [b - a for a, b in zip(m, hi)]],
                fmt="none", ecolor=INK, elinewidth=0.6, capsize=1.5, zorder=3)
    ax.set_yticks(y); ax.set_yticklabels([NAMES[r["feature"]] for r in R], fontsize=6.6)
    ax.set_xlabel("Drop in balanced accuracy when shuffled")
    ax.grid(axis="y", visible=False); ax.set_xlim(0, 0.33)
    ax.tick_params(axis="y", length=0)
    fig.tight_layout(pad=0.3)
    save(fig, "fig_importance")


# ---------------------------------------------------------------- Fig. 6
def fig_noise():
    S = rd(os.path.join(RES, "classifier_summary_noise.csv"))

    def series(model, W, thr, deb, col):
        out = []
        for lv in (0, 1, 2):
            r = [r for r in S if r["model"] == f"{model}_n{lv}" and r["W_ms"] == W and r["family"] == "scr"
                 and abs(num(r["threshold"]) - thr) < 1e-9 and r["debounce"] == str(deb)][0]
            out.append(num(r[col]))
        return out
    x = [0, 1, 2]
    fig, axs = plt.subplots(1, 2, figsize=(COL1, 1.95))
    cfg = [("nn_clean", "10", 0.5, 6, OK[0], "o", "trained without noise"),
           ("nn_noisy", "20", 0.8, 4, OK[1], "s", "trained with noise")]
    for m, W, thr, deb, c, mk, lbl in cfg:
        axs[0].plot(x, series(m, W, thr, deb, "detected_pct"), "-", color=c, marker=mk, ms=3.5, label=lbl + ", all")
        axs[0].plot(x, series(m, W, thr, deb, "detected_matched_pct"), "--", color=c, marker=mk, ms=3.5,
                    mfc="white", label=lbl + ", matched")
        axs[1].plot(x, series(m, W, thr, deb, "falseTrip_pct"), "-", color=c, marker=mk, ms=3.5)
    for ax in axs:
        ax.set_xticks(x); ax.set_xticklabels(["none", "nominal", "2×"]); ax.set_xlabel("Sensor noise in test")
    axs[0].set_ylim(0, 103); axs[0].set_ylabel("Islands detected (%)")
    axs[1].set_ylim(0, 10); axs[1].set_ylabel("Events tripped (%)")
    h, l = axs[0].get_legend_handles_labels()
    fig.legend(h, l, loc="lower center", ncol=2, fontsize=6.2, handlelength=2.2, columnspacing=1.0,
               bbox_to_anchor=(0.5, 0.0))
    fig.tight_layout(pad=0.3, w_pad=0.8, rect=(0, 0.17, 1, 1))
    save(fig, "fig_noise")


# ---------------------------------------------------------------- Fig. 7
def fig_traces():
    T = rd(os.path.join(FD, "cl_traces.csv")); Sc = rd(os.path.join(FD, "cl_score.csv"))
    I = rd(os.path.join(FD, "cl_current.csv"))
    meta = {r["case"]: r for r in rd(os.path.join(FD, "cl_meta.csv"))}
    get = lambda rows, c, k: [num(r[k]) for r in rows if r["case"] == c]
    fig, axs = plt.subplots(3, 2, figsize=(COL2, 3.9), sharex="col")
    tTrip = num(meta["island_ml"]["tTrip"]); thr = num(meta["island_ml"]["threshold"])
    cols = [("island_ml", "island_afd", "(a) Island held up by a second inverter that opposes the drift"),
            ("sag_ml", "sag_afd", "(b) Voltage sag to 0.7 pu for 0.5 s, which must be ridden through")]
    for j, (m, a, title) in enumerate(cols):
        cut = tTrip if j == 0 else math.inf
        ax = axs[0, j]
        key, lim, lab = ("f_Hz", (49.5, 50.6), "Frequency (Hz)") if j == 0 else ("V_pu", (0.45, 1.1), "PCC voltage (pu)")
        ta, ya = get(T, a, "t_s"), get(T, a, key)
        tm, ym = get(T, m, "t_s"), get(T, m, key)
        ax.plot(ta, ya, "--", color=OK[1], lw=0.9, label="frequency drift on, no ML detector" +
                (": not detected in 2 s" if j == 0 else ""))
        k = [i for i, t in enumerate(tm) if t <= cut]
        ax.plot([tm[i] for i in k], [ym[i] for i in k], "-", color=OK[0], lw=0.9,
                label="ML detector in the loop" + (": trips" if j == 0 else ": rides through"))
        ax.set_ylim(*lim); ax.set_ylabel(lab); ax.set_title(title, loc="left")
        ax.legend(loc="lower right", borderaxespad=0.2)
        ax = axs[1, j]
        ts, s = get(Sc, m, "t_s"), get(Sc, m, "score")
        k = [i for i, t in enumerate(ts) if t <= cut]
        ax.step([ts[i] for i in k], [s[i] for i in k], where="post", color=OK[0], lw=0.8)
        ax.axhline(thr, color=GREY, ls="--", lw=0.6)
        ax.text(0.79, thr + 0.04, "threshold", ha="right", fontsize=6, color=GREY)
        ax.set_ylim(-0.03, 1.05); ax.set_ylabel("Island score")
        if j == 0:
            ax.text(tTrip + 0.015, 0.45, f"trip at {1e3*tTrip:.0f} ms\n(4 windows > {thr:g})", fontsize=6.2)
        else:
            ax.text(0.02, 0.6, "no trip", fontsize=6.2)
        ax = axs[2, j]
        ti, ia = get(I, m, "t_s"), get(I, m, "ia_A")
        ax.plot(ti, ia, color=OK[0], lw=0.45)
        ax.set_ylim(-40, 40); ax.set_ylabel("Inverter current $i_a$ (A)"); ax.set_xlabel("Time after the event (s)")
        for r in range(3):
            axs[r, j].set_xlim(-0.1, 0.8)
            if j == 0:
                axs[r, j].axvspan(tTrip, 0.8, color="#f0f0f0", zorder=0, lw=0)
    axs[0, 0].text(tTrip + 0.02, 50.5, "inverter disconnected by the detector", fontsize=6.2, color=GREY, va="top")
    fig.tight_layout(pad=0.3, h_pad=0.4, w_pad=1.0)
    save(fig, "fig_traces")


# ---------------------------------------------------------------- Fig. 8
def fig_closed_loop():
    Pi = rd(os.path.join(RES, "closed_loop_pi.csv")); H = rd(os.path.join(RES, "closed_loop_hinfinity.csv"))
    fig, axs = plt.subplots(1, 2, figsize=(COL2, 2.35), gridspec_kw={"width_ratios": [1, 1.05]})
    ax = axs[0]

    def cdf(rows, n, **kw):
        t = sorted(num(r["tTrip_ms"]) for r in rows if r["detected"] == "1")
        xs, ys = [0], [0]
        for i, v in enumerate(t):
            xs += [v, v]; ys += [100*i/n, 100*(i + 1)/n]
        xs.append(400); ys.append(ys[-1])
        ax.plot(xs, ys, **kw)
    isl = lambda R, g: [r for r in R if r["group"] == g and r["island"] == "1"]
    cdf(isl(Pi, "cases"), 30, color=OK[0], label="ML in the loop, PI: 30 of 30")
    cdf(isl(H, "cases"), 30, color=OK[1], ls="--", label="ML in the loop, H$_\\infty$: 30 of 30")
    cdf(isl(Pi, "afd"), 9, color=OK[2], ls=":", lw=1.3, label="Drift + IEEE relay: 6 of 9")
    ax.text(395, 63, "drift misses the 3 islands\nwith an opposing inverter", ha="right", va="top", fontsize=6.2, color=OK[2])
    ax.set_xlim(0, 400); ax.set_ylim(0, 102)
    ax.set_xlabel("Time after the grid breaker opens (ms)"); ax.set_ylabel("Islands detected (%)")
    ax.set_title("(a) Detection time on the three unseen conditions", loc="left")
    ax.legend(loc="center right", bbox_to_anchor=(1.0, 0.33))
    ax = axs[1]
    N = [r for r in Pi if r["group"] == "ndz"]
    dPs = sorted({num(r["dP_pct"]) for r in N}); dQs = sorted({num(r["dQ_pct"]) for r in N})
    norm = colors.Normalize(20, 100); cmap = plt.get_cmap("Blues")
    for r in N:
        i, j = dPs.index(num(r["dP_pct"])), dQs.index(num(r["dQ_pct"]))
        t = num(r["tTrip_ms"])
        ax.add_patch(plt.Rectangle((i - 0.47, j - 0.47), 0.94, 0.94, fc=cmap(0.12 + 0.8*norm(t)), ec="white", lw=0.8))
        ax.text(i, j, f"{t:.0f}", ha="center", va="center", fontsize=6, color="white" if norm(t) > 0.55 else INK)
    ax.set_xlim(-0.5, len(dPs) - 0.5); ax.set_ylim(-0.5, len(dQs) - 0.5); ax.grid(False)
    ax.set_xticks(range(len(dPs))); ax.set_xticklabels([f"{p:+.0f}" if p else "0" for p in dPs])
    ax.set_yticks(range(len(dQs))); ax.set_yticklabels([f"{q:+g}" if q else "0" for q in dQs])
    ax.tick_params(length=0)
    for s in ax.spines.values(): s.set_visible(False)
    ax.set_xlabel("Active power mismatch ΔP (%)"); ax.set_ylabel("Reactive mismatch ΔQ (%)")
    ax.set_title("(b) Mismatch grid, SCR 7 with harmonics: detection time (ms)", loc="left")
    fig.tight_layout(pad=0.3, w_pad=1.2)
    save(fig, "fig_closed_loop")


# ---------------------------------------------------------------- source models
def pv_module_iv(v, G, T=25.0):
    """Single-diode model of the 1STH-215-P module with the PV Array block's fitted parameters."""
    IL, I0, n, Rsh, Rs, Ncell = 7.8654, 2.9273e-10, 0.98119, 313.0553, 0.39381, 60
    a = n*Ncell*1.380649e-23*(T + 273.15)/1.602176634e-19
    il = IL*G/1000.0
    out = []
    for vv in v:
        i = il
        for _ in range(60):                                  # Newton on f(i) = 0
            e = math.exp((vv + i*Rs)/a)
            f = il - I0*(e - 1) - (vv + i*Rs)/Rsh - i
            df = -I0*e*Rs/a - Rs/Rsh - 1
            step = f/df
            i -= step
            if abs(step) < 1e-10:
                break
        out.append(max(i, 0.0))
    return out


def cp(lam, beta=0.0):
    """Power coefficient of the model's turbine block (its Eqn 2 and Eqn 3)."""
    inv = 1.0/(lam + 0.08*beta) - 0.035/(1 + beta**3)
    return max(0.5*(116*inv - 0.4*beta - 5)*math.exp(-21*inv), 0.0)


def fig_sources():
    fig, axs = plt.subplots(1, 4, figsize=(COL2, 1.75), gridspec_kw={"wspace": 0.55})
    Gs = [1000, 800, 600, 400, 200]
    shades = ["#08306b", "#2171b5", "#4292c6", "#6baed6", "#9ecae1"]
    vm = [k*0.25 for k in range(0, 146)]                     # module voltage (V), to 36.25
    for G, c in zip(Gs, shades):
        im = pv_module_iv(vm, G)
        V = [10*x for x in vm]; I = [5*x for x in im]; P = [a*b/1e3 for a, b in zip(V, I)]
        k = max(range(len(P)), key=lambda j: P[j])
        axs[0].plot(V, I, color=c, lw=1.0)
        axs[1].plot(V, P, color=c, lw=1.0)
        axs[1].plot(V[k], P[k], "o", ms=2.6, color=c)
        axs[0].text(8, I[0] + 0.6, f"{G}", fontsize=5.8, color=c, va="bottom")
    axs[1].axvspan(230, 330, color=LIGHT, zorder=0)
    axs[1].text(280, 11.6, "MPPT range", ha="center", fontsize=5.8, color=GREY)
    axs[0].set(xlabel="Array voltage (V)", ylabel="Array current (A)", xlim=(0, 370), ylim=(0, 44))
    axs[1].set(xlabel="Array voltage (V)", ylabel="Array power (kW)", xlim=(0, 370), ylim=(0, 12.4))
    axs[0].text(185, 41, "W/m², 25 °C", ha="center", fontsize=5.8, color=GREY)

    lam = [0.5 + 0.05*k for k in range(0, 300)]
    axs[2].plot(lam, [cp(x) for x in lam], color=OK[1])
    lo = 7.954
    axs[2].plot([lo], [cp(lo)], "o", ms=2.6, color=OK[1])
    axs[2].annotate(f"$C_{{p,max}}$ = {cp(lo):.3f}\n$\\lambda_{{opt}}$ = {lo:.2f}", (lo, cp(lo)), (10.0, 0.40),
                    fontsize=5.8, arrowprops=dict(arrowstyle="-", lw=0.5, color=GREY))
    axs[2].set(xlabel="Tip-speed ratio $\\lambda$", ylabel="Power coefficient $C_p$", xlim=(0, 15), ylim=(0, 0.46))

    R, rho = 2.7072, 1.225
    kopt = 0.5*rho*math.pi*R**5*cp(lo)/lo**3
    w = [0.5*k for k in range(0, 101)]
    for v, c in zip([12, 10, 8, 6], ["#7f2704", "#d94801", "#fd8d3c", "#fdae6b"]):
        P = [0.5*rho*math.pi*R**2*v**3*cp(max(x*R/v, 1e-3))/1e3 for x in w]
        axs[3].plot(w, P, color=c, lw=1.0)
        k = max(range(len(P)), key=lambda j: P[j])
        j = min(k + int(0.25*k), len(w) - 1)                # on the falling side, clear of the MPPT curve
        axs[3].text(w[j] + 0.8, P[j] + 0.15, f"{v} m/s", ha="left", va="bottom", fontsize=5.8, color=c)
    axs[3].plot(w, [kopt*x**3/1e3 for x in w], color=INK, lw=0.8, ls="--")
    axs[3].text(44, 9.6, "$K_{opt}\\omega^3$", fontsize=6.2)
    axs[3].set(xlabel="Rotor speed (rad/s)", ylabel="Turbine power (kW)", xlim=(0, 50), ylim=(0, 11.5))
    for ax, t in zip(axs, "abcd"):
        ax.set_title(f"({t})", loc="left", x=-0.3, fontsize=7.5, weight="bold")
    save(fig, "fig_sources")


# ---------------------------------------------------------------- workflow
def fig_workflow():
    fig = plt.figure(figsize=(COL2, 2.2))
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 100); ax.set_ylim(0, 31); ax.axis("off")
    stages = [
        ("Model", "#e8f1fa", [
            ("1", "Test bed", "Corrected PV MPPT, wind torque,\nPLL frequency, protection latch;\n18.5 kW at 800 V, THD 1.2%"),
            ("2", "Current control", "PI, PID, structured H∞,\nfuzzy PI; margins and\ndistortion at SCR 2–20")]),
        ("Baselines", "#fdf0e6", [
            ("3", "Islanding test bench", "IEEE 1547.1 RLC load; fast\nand IEEE 1547-2018 relays,\nAFD; NDZ, 11 events"),
            ("4", "AFD stress, dataset", "Q$_f$ 2.5, weak grid, opposing\nsecond inverter; 400 cases\nfrom 16 conditions")]),
        ("Detector", "#e9f6f1", [
            ("5", "Features, classifiers", "22 window features; tree,\nforest, SVM, network; held-out\nSCR and mix folds as a relay"),
            ("6", "Sensor noise", "Noise through PLL and loops\nbreaks it; training with\nmeasured noise restores it")]),
        ("Validation", "#f6ecf3", [
            ("7", "Closed loop", "Detector inside the switching\nmodel; 3 unseen conditions,\nPI and H∞; against AFD"),
            ("8", "Real feeder", "NEA Pidari 400 V feeder;\nbus screening; detector\nunchanged, then retrained")]),
        ("Selectivity", "#fbf6dc", [
            ("9", "Confirmation", "Alarm starts a 30 ms\nreactive pulse; the PCC\nangle decides the trip")]),
    ]
    w, h, gap = 18.2, 9.6, 1.65
    xs = [0.8 + k*(w + gap) for k in range(len(stages))]
    ys = [16.6, 3.0]
    for k, (name, fc, boxes) in enumerate(stages):
        x = xs[k]
        ax.add_patch(FancyBboxPatch((x - 0.6, 1.4), w + 1.2, 28.6, boxstyle="round,pad=0,rounding_size=1.0",
                                    fc=fc, ec="none"))
        ax.text(x + w/2, 28.2, name, ha="center", va="center", fontsize=7.2, weight="bold", color=INK)
        for j, (num_, title, body) in enumerate(boxes):
            y = ys[j]
            ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0,rounding_size=0.8", fc="white", ec=INK, lw=0.6))
            ax.add_patch(Circle((x + 2.3, y + h - 2.0), 1.4, fc=INK, ec="none"))
            ax.text(x + 2.3, y + h - 2.0, num_, ha="center", va="center", fontsize=6.2, color="white", weight="bold")
            ax.text(x + 4.4, y + h - 2.0, title, ha="left", va="center", fontsize=6.6, weight="bold")
            ax.text(x + 1.2, y + h - 3.9, body, ha="left", va="top", fontsize=5.7, linespacing=1.18, color="#333333")
    kw = dict(arrowstyle="-|>", color=INK, lw=0.7, mutation_scale=6, shrinkA=0, shrinkB=0)
    for k in range(len(stages)):                             # down within a stage
        if len(stages[k][2]) > 1:
            ax.annotate("", xy=(xs[k] + w/2, ys[1] + h), xytext=(xs[k] + w/2, ys[0]), arrowprops=kw)
    for k in range(len(stages) - 1):                         # bottom of one stage to the top of the next
        xm = xs[k] + w + gap/2
        ax.plot([xs[k] + w, xm, xm], [ys[1] + h/2, ys[1] + h/2, ys[0] + h/2], color=INK, lw=0.7)
        ax.annotate("", xy=(xs[k + 1], ys[0] + h/2), xytext=(xm, ys[0] + h/2), arrowprops=kw)
    save(fig, "fig_workflow")


# ---------------------------------------------------------------- converter controls
def fig_control():
    fig = plt.figure(figsize=(COL2, 2.75))
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 100); ax.set_ylim(0, 40); ax.axis("off")

    def box(x, y, w, h, text, fc="white", fs=5.9, bold=False):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0,rounding_size=0.5", fc=fc, ec=INK, lw=0.6))
        ax.text(x + w/2, y + h/2, text, ha="center", va="center", fontsize=fs, linespacing=1.15,
                weight="bold" if bold else "normal")

    def arr(pts, lw=0.65, c=INK, label=None, lpos=None, ls="-"):
        xs_, ys_ = zip(*pts)
        ax.plot(xs_[:-1] + (xs_[-1],), ys_, color=c, lw=lw, ls=ls) if len(pts) > 2 else None
        ax.annotate("", xy=pts[-1], xytext=pts[-2],
                    arrowprops=dict(arrowstyle="-|>", color=c, lw=lw, mutation_scale=5.5, shrinkA=0, shrinkB=0, ls=ls))
        if label:
            ax.text(*lpos, label, fontsize=5.7, ha="center", va="bottom", color=c)

    def power(x0, x1, y):
        ax.plot([x0, x1], [y, y], color=INK, lw=1.5, solid_capstyle="butt")

    pc, cc = "#e8f1fa", "#fdf0e6"                            # power stage, control
    # panel titles and separators
    ax.text(0.5, 39.2, "(a) PV chain", fontsize=7, weight="bold", va="top")
    ax.text(0.5, 19.6, "(b) Wind chain", fontsize=7, weight="bold", va="top")
    ax.text(55.5, 39.2, "(c) Grid inverter control", fontsize=7, weight="bold", va="top")
    ax.plot([54, 54], [1, 39], color=LIGHT, lw=0.8)

    # (a) PV: power row at y 30.5-35.5, control row at 22-26.5
    box(1, 30.5, 9.5, 5, "PV array\n10 s × 5 p\n10.7 kW STC", pc)
    box(14.5, 30.5, 12, 5, "Boost converter\n$L$ = 1.5 mH\n5 kHz", pc)
    power(10.5, 14.5, 33); power(26.5, 41.5, 33)
    box(14.5, 21.8, 12, 4.8, "P&O on duty $D$\nevery 10 ms\n$\\Delta D$ = 0.003", cc)
    arr([(5.75, 30.5), (5.75, 24.2), (14.5, 24.2)], label="$v_{pv}$, $i_{pv}$", lpos=(9.6, 24.4))
    arr([(20.5, 26.6), (20.5, 30.5)])
    ax.text(21.2, 28.2, "$D$", fontsize=5.9, va="center")
    box(30, 21.8, 9.5, 4.8, "Pulses blocked\nafter a trip", "white", fs=5.5)
    arr([(30, 24.2), (26.5, 24.2)], ls=(0, (2, 1.5)))

    # DC link shared by both chains
    box(41.5, 6.0, 10, 30, "DC link\n\n$V_{dc}$ = 800 V\n\n3.2 mF\n\n↓\nto the\ngrid\ninverter", "#dfe9f3", fs=6.1)

    # (b) wind: power row at 11-16, control row at 1.5-6.5
    box(1, 11, 7.5, 5, "Turbine\n$C_p(\\lambda)$\n$R$ = 2.71 m", pc)
    box(10.5, 11, 7, 5, "PMSG\n4 pole\npairs", pc)
    box(19.5, 11, 7, 5, "Diode\nrectifier\n2.2 mF", pc)
    box(28.5, 11, 9.5, 5, "Boost\n$L$ = 10 mH\n10 kHz", pc)
    power(8.5, 10.5, 13.5); power(17.5, 19.5, 13.5); power(26.5, 28.5, 13.5); power(38, 41.5, 13.5)
    ax.text(9.5, 14.3, "$T_m$", fontsize=5.6, ha="center")
    box(10.5, 1.5, 13.5, 5, "$i_L^* = K_{opt}\\,\\omega_m^3 / v_{rect}$\nlimited to 90 A", cc)
    box(27, 1.5, 9.5, 5, "PI, $K_p$ = 0.04,\n$K_i$ = 12; PWM", cc)
    arr([(14, 11), (14, 6.5)], label=None)
    ax.text(14.6, 8.6, "$\\omega_m$", fontsize=5.9, va="center")
    arr([(24, 4), (27, 4)])
    arr([(33.2, 11), (33.2, 6.5)])
    ax.text(33.8, 8.6, "$i_L$", fontsize=5.9, va="center")
    arr([(36.5, 4), (39.6, 4), (39.6, 10.2), (37, 10.2), (37, 11)])

    # (c) inverter control
    box(56, 30.5, 11, 5, "SRF-PLL\n30 Hz", cc)
    box(70, 30.5, 11, 5, "abc → dq", cc)
    box(84, 30.5, 14.5, 5, "Relays (fast, IEEE)\nor ML detector", "#e9f6f1")
    ax.text(61.0, 36.6, "$v_{abc}$", fontsize=5.9, ha="right", va="center")
    arr([(61.5, 37.6), (61.5, 35.5)])
    ax.text(75.0, 36.6, "$i_{abc}$", fontsize=5.9, ha="right", va="center")
    arr([(75.5, 37.6), (75.5, 35.5)])
    arr([(67, 33), (70, 33)]); ax.text(68.5, 33.5, "$\\theta$", fontsize=5.6, ha="center")
    arr([(64, 30.5), (64, 28.6), (88, 28.6), (88, 30.5)])
    ax.text(82, 27.3, "$f$, $V$, waveforms", fontsize=5.5, ha="center", color=GREY)
    box(84, 21.8, 14.5, 4.4, "Trip latch: open CB1,\nblock both boosts", "#e9f6f1", fs=5.6)
    arr([(91.25, 30.5), (91.25, 26.2)])

    box(56, 14.5, 12, 5, "DC-link PI\n$K_p$ = 0.5, $K_i$ = 10", cc)
    ax.text(57.5, 21.4, "$V_{dc}^* - V_{dc}$", fontsize=5.7, ha="left")
    arr([(62, 21.2), (62, 19.5)])
    box(56, 6.0, 12, 5, "$i_q^*$ = 0, or AFD:\n$b + K(f - 50)$", cc)
    box(71.5, 6.0, 13.5, 13.5, "Current\ncontroller\n(d and q)\n\nPI | PID |\nH∞ | fuzzy PI\nat 10 kHz,\none-sample\ndelay", "#fbe3cf", fs=5.8)
    arr([(68, 17), (71.5, 17)]); ax.text(69.75, 17.5, "$i_d^*$", fontsize=5.6, ha="center")
    arr([(68, 8.5), (71.5, 8.5)]); ax.text(69.75, 9.0, "$i_q^*$", fontsize=5.6, ha="center")
    arr([(75.5, 30.5), (75.5, 25), (78.3, 25), (78.3, 19.5)])
    ax.text(79.0, 22.5, "$i_d$, $i_q$", fontsize=5.6, va="center")
    box(88, 6.0, 10.5, 13.5, "+ $\\omega L_1$\ndecoupling\n+ $v$ feed-\nforward\n\ndq → abc,\nPWM to\nthe VSI", cc, fs=5.8)
    arr([(85, 12.75), (88, 12.75)])
    save(fig, "fig_control")


# ---------------------------------------------------------------- controllers
def fig_controllers():
    M = rd(os.path.join(RES, "margins_all.csv"))
    C = rd(os.path.join(RES, "controller_comparison_all.csv"))
    names = ["PI", "PID", "H-infinity", "Fuzzy PI"]
    label = {"PI": "PI", "PID": "PID", "H-infinity": "H∞", "Fuzzy PI": "Fuzzy PI"}
    marks = ["o", "s", "^", "D"]
    fig, axs = plt.subplots(1, 3, figsize=(COL2, 1.75), gridspec_kw={"wspace": 0.42, "width_ratios": [1, 1, 1.35]})
    for n, c, mk in zip(names, OK, marks):
        key = n if n != "Fuzzy PI" else "Fuzzy PI (small-signal)"
        r = sorted([x for x in M if x["controller"] == key], key=lambda x: num(x["scr"]))
        s = [num(x["scr"]) for x in r]
        axs[0].plot(s, [num(x["GM_dB"]) for x in r], marker=mk, ms=3, color=c, label=label[n])
        axs[1].plot(s, [num(x["Ms"]) for x in r], marker=mk, ms=3, color=c)
    axs[0].set(xlabel="SCR", ylabel="Gain margin (dB)", xscale="log", ylim=(6, 12.5))
    axs[1].set(xlabel="SCR", ylabel="Sensitivity peak $M_s$", xscale="log", ylim=(1.3, 2.1))
    for ax in axs[:2]:
        ax.set_xticks([2, 3, 5, 10, 20]); ax.set_xticklabels(["2", "3", "5", "10", "20"]); ax.minorticks_off()
    fig.legend(*axs[0].get_legend_handles_labels(), loc="lower center", ncol=4, bbox_to_anchor=(0.5, 0.97),
               handlelength=1.6, columnspacing=1.6)
    tests = [("hard", 20, "Start\nSCR 20"), ("hard", 10, "Start\nSCR 10"), ("hard", 5, "Start\nSCR 5"),
             ("ramp", 3, "Ramp\nSCR 3"), ("ramp", 2, "Ramp\nSCR 2")]
    bw = 0.19
    for k, (n, c) in enumerate(zip(names, OK)):
        vals = []
        for t, scr, _ in tests:
            r = [x for x in C if x["controller"] == n and x["test"] == t and num(x["scr"]) == scr]
            vals.append(num(r[0]["THDi_pct"]))
        axs[2].bar([j + (k - 1.5)*bw for j in range(len(tests))], vals, bw*0.92, color=c, label=label[n])
    axs[2].set_xticks(range(len(tests))); axs[2].set_xticklabels([t[2] for t in tests], fontsize=6.2)
    axs[2].set(ylabel="Current THD (%)", ylim=(0, 2.0)); axs[2].grid(axis="x", visible=False)
    for ax, t in zip(axs, "abc"):
        ax.set_title(f"({t})", loc="left", x=-0.28 if t != "c" else -0.26, fontsize=7.5, weight="bold")
    save(fig, "fig_controllers")


# ---------------------------------------------------------------- real feeder
def fig_feeder():
    F11 = rd(os.path.join(FD, "feeder11.csv"))
    LV = rd(os.path.join(FD, "feeder_lv.csv"))
    SC = {r["Bus"]: r for r in rd(os.path.join(RES, "feeder_screening.csv"))}
    fig = plt.figure(figsize=(COL2, 2.5))
    a = fig.add_axes([0.0, 0.0, 0.37, 1.0]); b = fig.add_axes([0.39, 0.0, 0.61, 1.0])
    for ax in (a, b):
        ax.axis("off")

    # (a) the 11 kV feeder, schematic, nodes coloured by voltage at the recorded peak
    cmap = matplotlib.colormaps["viridis"]
    norm = colors.Normalize(0.80, 1.0)
    pos = {2: (0.0, 0.0)}
    trunk = [2, 3, 4, 5, 6, 7]
    x = 0.0
    for c in trunk[1:]:
        x += num(F11[c - 1]["km"]); pos[c] = (x, 0.0)
    kids = {3: [(8, 0)], 4: [(9, 0)], 5: [(10, 0)], 6: [(11, 0)], 7: [(12, -1.3), (13, 1.3)]}
    spur = {8: 14, 9: 15, 10: 16, 11: 17, 12: 18, 13: 19}
    for p_, ks in kids.items():
        for k, dx in ks:
            pos[k] = (pos[p_][0] + dx, -1.5)
            pos[spur[k]] = (pos[p_][0] + dx, -3.0)
    pos[1] = (-2.4, 0.0)
    wid = {"ACSR Dog 100mm2": 1.8, "ACSR Rabbit 50mm2": 1.1, "ACSR Weasel 30mm2": 0.7}
    for r in F11[1:]:
        k, p_ = int(r["bus"]), int(r["parent"])
        a.plot([pos[p_][0], pos[k][0]], [pos[p_][1], pos[k][1]], color="#8a8a8a", lw=wid.get(r["conductor"], 0.9),
               zorder=1, solid_capstyle="round")
    for r in F11[1:]:
        k = int(r["bus"])
        a.scatter(*pos[k], s=26 if k == 2 else 15, c=[cmap(norm(num(r["V_peak"])))], ec=INK, lw=0.4, zorder=3,
                  marker="s" if k == 2 else "o")
    a.scatter(*pos[1], s=70, c="white", ec=INK, lw=0.6, zorder=3)
    a.text(pos[1][0], pos[1][1], "~", ha="center", va="center", fontsize=7, zorder=4)
    a.text(pos[1][0] + 0.4, 0.45, "Mujeliya\n33/11 kV", ha="center", va="bottom", fontsize=5.7)
    a.text(pos[3][0], 0.35, "Pidari\nChowk", ha="center", va="bottom", fontsize=5.6)
    a.text(pos[7][0], 0.35, "Bindhi", ha="center", va="bottom", fontsize=5.6)
    for name, d in (("Dog", 1.8), ("Rabbit", 1.1), ("Weasel", 0.7)):
        pass
    kc = pos[18]
    a.scatter(*kc, s=95, facecolors="none", ec=OK[1], lw=1.0, zorder=4)
    a.annotate("Khajuri Chanha: 100 kVA\ntransformer, 0.81 pu at peak", kc, (kc[0] - 6.2, kc[1] - 1.05), fontsize=5.7,
               color=OK[1], ha="center", va="center", arrowprops=dict(arrowstyle="-", lw=0.5, color=OK[1]))
    a.set_xlim(-3.6, 17.4); a.set_ylim(-4.6, 4.6)
    a.text(-3.5, 4.5, "(a) Pidari 11 kV feeder", fontsize=7, weight="bold", va="top")
    a.text(-3.5, 3.55, "69.9 km of ACSR Dog, Rabbit and Weasel;\n293 A at the recorded peak", fontsize=5.6,
           color=GREY, va="top")
    cax = fig.add_axes([0.245, 0.80, 0.11, 0.022])
    cb = fig.colorbar(matplotlib.cm.ScalarMappable(norm=norm, cmap=cmap), cax=cax, orientation="horizontal")
    cb.set_ticks([0.8, 0.9, 1.0]); cb.ax.tick_params(labelsize=5.6, length=1.5, pad=1); cb.outline.set_linewidth(0.4)
    cax.set_title("$V$ at peak (pu)", fontsize=5.6, pad=2)

    # (b) the 400 V feeder
    b.set_xlim(0, 100); b.set_ylim(0, 54)
    b.text(0.5, 53.5, "(b) 400 V feeder of the Khajuri Chanha transformer", fontsize=7, weight="bold", va="top")

    def brk(x, y, c=INK):
        b.add_patch(plt.Rectangle((x - 1.4, y - 1.4), 2.8, 2.8, fc="white", ec=c, lw=0.8, zorder=3))
        b.plot([x - 1.0, x + 1.0], [y - 1.0, y + 1.0], color=c, lw=0.7, zorder=4)

    def load(x, y):
        b.plot([x, x], [y, y - 3.0], color=INK, lw=0.6)
        b.annotate("", (x, y - 5.4), (x, y - 3.0), arrowprops=dict(arrowstyle="-|>", lw=0.6, color=INK, mutation_scale=5))

    yA, yB = 30, 11
    b.scatter(4, yA, s=150, c="white", ec=INK, lw=0.7, zorder=3)
    b.text(4, yA, "~", ha="center", va="center", fontsize=9, zorder=4)
    b.text(4, yA + 3.2, "11 kV\nequivalent", ha="center", va="bottom", fontsize=5.6)
    b.plot([6.4, 14.0], [yA, yA], color=INK, lw=1.0)
    brk(10.0, yA, OK[1])
    b.text(10.0, yA - 2.6, "island\npoint 1", ha="center", va="top", fontsize=5.6, color=OK[1])
    b.scatter([15.2, 17.4], [yA, yA], s=90, facecolors="none", ec=INK, lw=0.7, zorder=3)
    b.text(16.3, yA + 2.6, "100 kVA\n11/0.433 kV", ha="center", va="bottom", fontsize=5.6)
    x0 = 22.0
    xs = {k: x0 + 13.4*(k - 1) for k in range(1, 7)}
    xb = {7: xs[2], 8: xs[3], 9: xs[4]}
    b.plot([18.6, x0], [yA, yA], color=INK, lw=1.0)
    b.plot([x0, x0], [yB, yA], color=INK, lw=2.4, solid_capstyle="butt")
    b.text(x0 - 1.4, (yA + yB)/2, "DT LV\nbus", ha="right", va="center", fontsize=5.6)
    b.plot([x0, xs[6]], [yA, yA], color=INK, lw=1.2)
    b.plot([x0, xb[9] + 8.5], [yB, yB], color=INK, lw=1.0)
    for k in range(2, 7):
        load(xs[k], yA)
        off, ha = ((-0.8, "right") if k in (4, 6) else (0, "center"))     # clear of the unit's lead
        b.text(xs[k] + off, yA + 1.0, LV[k - 1]["name"].replace(" (PCC)", ""), ha=ha, va="bottom", fontsize=6, weight="bold")
    for k in (7, 8, 9):
        load(xb[k], yB)
        b.text(xb[k], yB + 1.0, LV[k - 1]["name"], ha="center", va="bottom", fontsize=6, weight="bold")
    b.text((xs[1] + xs[2])/2, yA - 1.4, "ABC\n95 mm²", fontsize=5.3, color=GREY, ha="center", va="top")
    b.text((xs[4] + xs[5])/2, yA - 1.4, "ABC\n50 mm²", fontsize=5.3, color=GREY, ha="center", va="top")
    b.text((xs[1] + xs[2])/2, yB - 1.4, "ABC\n50 mm²", fontsize=5.3, color=GREY, ha="center", va="top")
    b.text(xs[2] - 6.0, yA - 7.2, "2.0 kW per pole at 30 %\nof peak; 100 m spans", fontsize=5.3, color=GREY, va="top")
    # the unit at A5 (and the alternative at A3)
    x5, x3 = xs[6], xs[4]
    b.plot([x5, x5], [yA, yA + 9.4], color=INK, lw=0.9)
    brk(x5, yA + 5.2, OK[1])
    b.text(x5 - 2.2, yA + 5.2, "island\npoint 2", fontsize=5.6, color=OK[1], va="center", ha="right")
    b.add_patch(FancyBboxPatch((x5 - 9.5, yA + 9.4), 19, 6.4, boxstyle="round,pad=0,rounding_size=0.6", fc="#e8f1fa", ec=INK, lw=0.6))
    b.text(x5, yA + 12.6, "PV–wind unit,\n20 kVA, local load", ha="center", va="center", fontsize=5.7)
    b.plot([x3, x3], [yA, yA + 9.4], color=INK, lw=0.7, ls=(0, (2, 1.5)))
    b.add_patch(FancyBboxPatch((x3 - 7.5, yA + 9.4), 15, 6.4, boxstyle="round,pad=0,rounding_size=0.6", fc="white", ec=INK,
                               lw=0.6, ls=(0, (2, 1.5))))
    b.text(x3, yA + 12.6, "or the unit\nat A3", ha="center", va="center", fontsize=5.6)
    s5, s3 = SC["A5 (PCC)"], SC["A3"]
    for xx, ss in ((x5, s5), (x3, s3)):
        b.text(xx + 1.0, yA - 6.4, f"SCR {num(ss['SCR']):.1f}\nX/R {num(ss['XR']):.2f}", ha="left", va="top",
               fontsize=5.6, color=OK[0])
    # B3: other generation and the switched load
    xe = xb[9] + 8.5
    b.plot([xe, xe], [yB - 4.4, yB + 4.4], color=INK, lw=0.8)
    for yy, txt, fc in ((yB + 4.4, "other DG, lumped\n(10–28 kW)", "#f6ecf3"), (yB - 4.4, "switched load,\n10 kW (event)", "white")):
        b.plot([xe, xe + 3], [yy, yy], color=INK, lw=0.8)
        b.add_patch(FancyBboxPatch((xe + 3, yy - 3.0), 18, 6.0, boxstyle="round,pad=0,rounding_size=0.6", fc=fc, ec=INK, lw=0.6))
        b.text(xe + 12, yy, txt, ha="center", va="center", fontsize=5.6)
    save(fig, "fig_feeder")


def fig_screening():
    T = rd(os.path.join(RES, "feeder_screening.csv"))
    W = rd(os.path.join(RES, "feeder_operating_window.csv"))
    names = [r["Bus"].replace(" (PCC)", "").replace("DT LV bus", "DT") for r in T]
    fig, axs = plt.subplots(1, 3, figsize=(COL2, 1.8), gridspec_kw={"wspace": 0.42, "width_ratios": [1.15, 1.15, 1]})
    hc = [num(r["Hosting_kW"]) for r in T]
    cols = [OK[0] if h >= 20 else "#9ecae1" for h in hc]
    axs[0].bar(range(len(T)), hc, 0.7, color=cols)
    axs[0].axhline(20, color=OK[1], lw=0.9)
    axs[0].text(8.4, 21.5, "20 kVA unit", ha="right", fontsize=5.8, color=OK[1])
    axs[0].set(ylabel="Hosting capacity (kW)", ylim=(0, 64))
    dl = [num(r["dLoss_peak_kW"]) for r in T]
    axs[1].bar(range(len(T)), dl, 0.7, color=[OK[0] if h >= 20 else "#9ecae1" for h in hc])
    axs[1].set(ylabel="Loss change at peak (kW)", ylim=(-1.6, 0.1))
    for ax in axs[:2]:
        ax.set_xticks(range(len(T))); ax.set_xticklabels(names, fontsize=6.2, rotation=0); ax.grid(axis="x", visible=False)
    k3 = names.index("A3"); k5 = names.index("A5")
    axs[1].annotate("best within limits", (k3, dl[k3]), (k3 - 1.0, -1.52), fontsize=5.8, ha="center",
                    arrowprops=dict(arrowstyle="-", lw=0.5, color=GREY))
    axs[0].text(8.5, 61, "light: a 20 kW unit lifts\nthe feeder above 1.05 pu\nat 30 % load", ha="right",
                va="top", fontsize=5.6, color=GREY)
    ls = [100*num(r["loadScale"]) for r in W]
    axs[2].axhspan(0.917, 1.05, color=LIGHT, zorder=0)
    axs[2].text(96, 1.035, "enter-service range", ha="right", fontsize=5.6, color=GREY, va="top")
    axs[2].plot(ls, [num(r["Vpcc_noDG"]) for r in W], color=GREY, marker="o", ms=2.4, label="no unit")
    axs[2].plot(ls, [num(r["Vpcc_DG"]) for r in W], color=OK[0], marker="o", ms=2.4, label="unit, 20 kW")
    axs[2].set(xlabel="Feeder loading (% of peak)", ylabel="Voltage at A5 (pu)", ylim=(0.76, 1.1), xlim=(15, 105))
    axs[2].legend(loc="lower left", handlelength=1.4)
    for ax, t in zip(axs, "abc"):
        ax.set_title(f"({t})", loc="left", x=-0.3 if t != "c" else -0.4, fontsize=7.5, weight="bold")
    save(fig, "fig_screening")


def fig_feeder_results():
    # the feeder-retrained detector (step 8.4) in the loop; drift + IEEE from the original campaign
    f_pi = os.path.join(RES, "feeder_closed_loop_pi_islanding_classifier_feeder.csv")
    f_h = os.path.join(RES, "feeder_closed_loop_hinfinity_islanding_classifier_feeder.csv")
    f_afd = os.path.join(RES, "feeder_closed_loop_pi.csv")
    if not os.path.exists(f_pi):
        return
    Pi = rd(f_pi); H = rd(f_h) if os.path.exists(f_h) else []
    A = rd(f_afd) if os.path.exists(f_afd) else []
    fig, axs = plt.subplots(1, 2, figsize=(COL2, 2.35), gridspec_kw={"width_ratios": [1, 1.05]})
    ax = axs[0]

    def cdf(rows, label, **kw):
        n = len(rows)
        if not n:
            return
        t = sorted(num(r["tTrip_ms"]) for r in rows if r["detected"] == "1")
        xs, ys = [0], [0]
        for i, v in enumerate(t):
            xs += [v, v]; ys += [100*i/n, 100*(i + 1)/n]
        xs.append(800); ys.append(ys[-1])
        ax.plot(xs, ys, label=f"{label}: {len(t)} of {n}", **kw)
    isl = lambda R, g, k: [r for r in R if r["group"] == g and r["island"] == "1" and (k is None or r["kind"] == k)]
    cdf(isl(Pi, "cases", "svc"), "ML, PI, unit's islands", color=OK[0])
    cdf(isl(Pi, "cases", "dt"), "ML, PI, feeder islands", color=OK[0], ls="--")
    cdf(isl(H, "cases", None), "ML, H$_\\infty$, all islands", color=OK[1], ls="-.")
    cdf(isl(A, "afd", None), "Drift + IEEE relay", color=OK[2], ls=":", lw=1.3)
    ax.set_xlim(0, 800); ax.set_ylim(0, 102)
    ax.set_xlabel("Time after the island forms (ms)"); ax.set_ylabel("Islands detected (%)")
    ax.set_title("(a) Detection time on the feeder", loc="left")
    ax.legend(loc="lower right", fontsize=6.2)
    ax = axs[1]
    N = [r for r in Pi if r["group"] == "ndz"]
    if N:
        dPs = sorted({num(r["dP_pct"]) for r in N}); dQs = sorted({num(r["dQ_pct"]) for r in N})
        norm = colors.Normalize(20, 100); cmap = plt.get_cmap("Blues")
        for r in N:
            i, j = dPs.index(num(r["dP_pct"])), dQs.index(num(r["dQ_pct"]))
            t = num(r["tTrip_ms"]); ok = r["detected"] == "1"
            fc = cmap(0.12 + 0.8*norm(t)) if ok else LIGHT
            ax.add_patch(plt.Rectangle((i - 0.47, j - 0.47), 0.94, 0.94, fc=fc, ec="white", lw=0.8))
            ax.text(i, j, f"{t:.0f}" if ok else "ND", ha="center", va="center", fontsize=6,
                    color="white" if ok and norm(t) > 0.55 else INK)
        ax.set_xlim(-0.5, len(dPs) - 0.5); ax.set_ylim(-0.5, len(dQs) - 0.5); ax.grid(False)
        ax.set_xticks(range(len(dPs))); ax.set_xticklabels([f"{p:+.0f}" if p else "0" for p in dPs])
        ax.set_yticks(range(len(dQs))); ax.set_yticklabels([f"{q:+g}" if q else "0" for q in dQs])
        ax.tick_params(length=0)
        for s in ax.spines.values(): s.set_visible(False)
        ax.set_xlabel("Active power mismatch ΔP (%)"); ax.set_ylabel("Reactive mismatch ΔQ (%)")
        ax.set_title("(b) Feeder island, F1: detection time (ms)", loc="left")
    else:
        ax.axis("off")
    fig.tight_layout(pad=0.3, w_pad=1.2)
    save(fig, "fig_feeder_results")


# ---------------------------------------------------------------- Fig. 16
def fig_confirmation():
    # the feeder-retrained detector without (step 8) and with (step 9) the alarm-triggered confirmation
    det = "islanding_classifier_feeder"
    runs = {}
    for where, pre in (("feeder", "feeder_closed_loop"), ("test bed", "closed_loop")):
        for ctrl in ("pi", "hinfinity"):
            for step, suf in ((8, ""), (9, "_confirm")):
                f = os.path.join(RES, f"{pre}_{ctrl}_{det}{suf}.csv")
                if not os.path.exists(f):
                    return
                runs[(where, ctrl, step)] = rd(f)
    fig, axs = plt.subplots(1, 3, figsize=(COL2, 2.25), gridspec_kw={"width_ratios": [1.35, 1.0, 0.95]})

    ax = axs[0]
    rows = [("Feeder, grid\nconnected", "feeder", False, lambda r: True),
            ("Test bed, grid\nconnected", "test bed", False, lambda r: True),
            ("Feeder, unit's\nislands", "feeder", True, lambda r: r["kind"] == "svc"),
            ("Feeder, whole-\nfeeder islands", "feeder", True, lambda r: r["kind"] == "dt"),
            ("Test bed,\nislands", "test bed", True, lambda r: True)]
    for y, (lab, where, island, pick) in enumerate(rows[::-1]):
        for ctrl, mk, col, dy in (("pi", "o", OK[0], 0.13), ("hinfinity", "D", OK[3], -0.13)):
            v = [abs(num(r["resp_rad"])) for r in runs[(where, ctrl, 9)]
                 if num(r["nConfirm"]) > 0 and (r["island"] == "1") == island and pick(r)]
            ax.scatter(v, [y + dy]*len(v), s=7, marker=mk, facecolor="none" if island else col, edgecolor=col,
                       lw=0.6, label=("PI" if ctrl == "pi" else "H$_\\infty$") if y == 0 else None, zorder=3)
    ax.axvline(0.05, color=OK[1], lw=1.0)
    ax.text(0.056, len(rows) - 0.55, "threshold\n0.05 rad", color=OK[1], fontsize=6.2, va="center", linespacing=1.0)
    ax.text(0.0028, -0.8, "alarm reset", fontsize=6.2, color=GREY)
    ax.text(0.55, -0.8, "trip", fontsize=6.2, color=GREY)
    ax.set_xscale("log"); ax.set_xlim(0.0025, 4); ax.set_ylim(-1.05, len(rows) - 0.2)
    ax.set_yticks(range(len(rows))); ax.set_yticklabels([r[0] for r in rows[::-1]], fontsize=6.2, linespacing=1.0)
    ax.set_xlabel("PCC angle response |Δφ| (rad)")
    ax.set_title("(a) Every confirmation", loc="left")
    ax.legend(loc="upper right", fontsize=6.2, handletextpad=0.2, borderaxespad=0.1)

    ax = axs[1]
    def cdf(rows, label, **kw):
        isl = [r for r in rows if r["group"] == "cases" and r["island"] == "1"]
        t = sorted(num(r["tTrip_ms"]) for r in isl if r["detected"] == "1")
        xs, ys = [0], [0]
        for i, v in enumerate(t):
            xs += [v, v]; ys += [100*i/len(isl), 100*(i + 1)/len(isl)]
        xs.append(300); ys.append(ys[-1])
        ax.plot(xs, ys, label=label, **kw)
    cdf(runs[("feeder", "pi", 8)], "Without, PI", color=OK[4])
    cdf(runs[("feeder", "pi", 9)], "With, PI", color=OK[0])
    cdf(runs[("feeder", "hinfinity", 9)], "With, H$_\\infty$", color=OK[3], ls="--")
    ax.set_xlim(0, 300); ax.set_ylim(0, 102)
    ax.set_xlabel("Time after the island forms (ms)"); ax.set_ylabel("Feeder islands detected (%)")
    ax.set_title("(b) Detection time, F1–F3 (30)", loc="left")
    ax.legend(loc="lower right", fontsize=6.2)

    ax = axs[2]
    groups = [("Feeder\nPI", "feeder", "pi"), ("Feeder\nH$_\\infty$", "feeder", "hinfinity"),
              ("Test bed\nPI", "test bed", "pi"), ("Test bed\nH$_\\infty$", "test bed", "hinfinity")]
    for g, (lab, where, ctrl) in enumerate(groups):
        for k, step in enumerate((8, 9)):
            calm = [r for r in runs[(where, ctrl, step)] if r["group"] in ("cases", "steady") and r["island"] == "0"]
            n = sum(num(r["tTrip_ms"]) < 1e9 for r in calm)       # any trip, before or after the event
            x = g + (k - 0.5)*0.38
            ax.bar(x, n, 0.34, color=OK[4] if step == 8 else OK[0],
                   label=("Without" if step == 8 else "With confirmation") if g == 0 else None)
            ax.text(x, n + 0.12, f"{n}", ha="center", va="bottom", fontsize=6.2)
    ax.set_xticks(range(len(groups))); ax.set_xticklabels([g[0] for g in groups], fontsize=6.2, linespacing=1.0)
    ax.set_ylim(0, 10); ax.grid(axis="x", visible=False)
    ax.set_ylabel("Grid-connected runs tripped")
    ax.set_title("(c) False trips", loc="left")
    ax.legend(loc="upper right", fontsize=6.2)
    fig.tight_layout(pad=0.3, w_pad=0.9)
    save(fig, "fig_confirmation")


if __name__ == "__main__":
    fig_system(); fig_ndz(); fig_rocof(); fig_afd(); fig_importance(); fig_noise(); fig_traces(); fig_closed_loop()
    fig_sources(); fig_workflow(); fig_control(); fig_controllers(); fig_feeder(); fig_screening(); fig_feeder_results()
    fig_confirmation()
    print("figures written to", OUT)
