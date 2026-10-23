"""Diagrams of the ML detector for the project explainer (explainer/figures/).

    ml_network.png   the 22-20-10-2 network, its inputs, outputs and parameter count
    ml_windows.png   sliding window against baseline, and how windows are labelled
    ml_folds.png     the 16 operating conditions and the two families of held-out folds
    ml_trip.png      score -> threshold -> 4 in a row -> trip, on a synthetic score trace

Run from the repository root: python explainer/ml_diagrams.py
"""
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "figures")
os.makedirs(OUT, exist_ok=True)

OK = ["#0072B2", "#D55E00", "#009E73", "#CC79A7", "#56B4E9", "#E69F00"]   # Okabe-Ito
INK, GREY, LIGHT = "#222222", "#6b6b6b", "#ececec"
plt.rcParams.update({"font.family": "Arial", "font.size": 11, "axes.linewidth": 0.8,
                     "axes.spines.top": False, "axes.spines.right": False})


def box(ax, x, y, w, h, text, fc="#eef3fa", ec=INK, fs=11, weight="normal", color=INK, lw=1.2, ls="-"):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.08",
                                fc=fc, ec=ec, lw=lw, ls=ls))
    ax.text(x + w/2, y + h/2, text, ha="center", va="center", fontsize=fs, weight=weight, color=color,
            linespacing=1.35)


def arrow(ax, x0, y0, x1, y1, color=INK):
    ax.annotate("", xy=(x1, y1), xytext=(x0, y0),
                arrowprops=dict(arrowstyle="-|>", color=color, lw=1.3, shrinkA=0, shrinkB=0))


def save(fig, name):
    fig.savefig(os.path.join(OUT, name + ".png"), dpi=170, bbox_inches="tight", pad_inches=0.08)
    plt.close(fig)


# ------------------------------------------------------------------ network
def ml_network():
    fig, ax = plt.subplots(figsize=(13.5, 6.6))
    ax.set_xlim(0, 13.5); ax.set_ylim(-0.6, 6.6); ax.axis("off")

    groups = [("Voltage magnitude", "ΔV mean, ΔV max, ΔV max/σ", 3),
              ("Frequency", "Δf end, Δf max, Δf max/σ,\nROCOF fit, ROCOF peak", 5),
              ("Phase and sequences", "phase jump; ΔV+, ΔV−, ΔI+, ΔI−", 5),
              ("Power", "ΔP, ΔQ, P slope", 3),
              ("Distortion", "Δd_v, Δd_i, Z_h ratio", 3),
              ("Inverter internals", "ΔV_dc, ΔI_d, ΔI_q", 3)]
    y = 5.75
    for g, items, n in groups:
        box(ax, 0.05, y - 0.78, 2.75, 0.82, f"{g} ({n})\n{items}", fc="#f4f4f4", fs=9.2)
        arrow(ax, 2.8, y - 0.37, 3.25, 3.0)
        y -= 0.97
    ax.text(1.42, 6.25, "22 features of one window", ha="center", weight="bold", fontsize=11)

    box(ax, 3.3, 2.35, 1.35, 1.3, "Standardise\nz = (x − μ)/σ\n\n44 numbers", fc="#fdf1e6", fs=9.6)
    arrow(ax, 4.65, 3.0, 5.05, 3.0)

    def layer(xc, n, top, bottom, color, label, sub):
        ys = [top - i*(top - bottom)/(n - 1) for i in range(n)]
        for yy in ys:
            ax.add_patch(Circle((xc, yy), 0.11, fc=color, ec=INK, lw=0.6, zorder=3))
        ax.text(xc, top + 0.45, label, ha="center", weight="bold", fontsize=10.5)
        ax.text(xc, bottom - 0.5, sub, ha="center", va="top", fontsize=9.2, color=GREY, linespacing=1.3)
        return ys

    inp = layer(5.35, 22, 5.6, 0.45, "#dddddd", "Input\n22", "")
    h1 = layer(7.2, 20, 5.45, 0.6, "#9cc6e8", "Hidden 1\n20 ReLU", "W1: 20×22, b1: 20\n= 460")
    h2 = layer(9.05, 10, 4.55, 1.5, "#56B4E9", "Hidden 2\n10 ReLU", "W2: 10×20, b2: 10\n= 210")
    out = layer(10.75, 2, 3.45, 2.55, OK[1], "Output\n2 softmax", "W3: 2×10, b3: 2\n= 22")
    for a, b in ((inp, h1), (h1, h2), (h2, out)):
        xa = 5.35 if a is inp else (7.2 if a is h1 else 9.05)
        xb = 7.2 if b is h1 else (9.05 if b is h2 else 10.75)
        for i, ya in enumerate(a):
            for j, yb in enumerate(b):
                if (i + j) % 3 == 0 or b is out:
                    ax.plot([xa + 0.11, xb - 0.11], [ya, yb], color="#b8b8b8", lw=0.35, zorder=1)
    ax.text(10.95, 3.45, "  not island", va="center", fontsize=9.2)
    ax.text(10.95, 2.55, "  island", va="center", fontsize=9.2)

    box(ax, 11.85, 3.55, 1.6, 1.45, "Score\ns = P(island)\n= 1/(1 + e^(a1 − a2))", fc="#fdf1e6", fs=9.3)
    box(ax, 11.85, 1.75, 1.6, 1.45, "Trip if\ns > 0.8 for\n4 windows\nin a row", fc="#e7f4ee", fs=9.6)
    arrow(ax, 12.65, 3.55, 12.65, 3.2)
    ax.text(6.75, -0.45, "Parameters: 44 (standardisation) + 460 + 210 + 22 = 736 numbers, "
            "passed to the Simulink block as one vector (ml_pack.m)", ha="center", fontsize=10, color=INK)
    save(fig, "ml_network")


# ------------------------------------------------------------------ windows and labels
def ml_windows():
    fig, axs = plt.subplots(2, 1, figsize=(13, 5.8), gridspec_kw={"height_ratios": [1.15, 1]})
    ax = axs[0]
    ax.set_xlim(-105, 355); ax.set_ylim(0, 3.2); ax.set_yticks([])
    ax.spines["left"].set_visible(False)
    ax.axvline(0, color=OK[1], lw=1.6)
    ax.text(2, 3.0, "event or breaker CB2 opens (t = 0)", color=OK[1], va="top", fontsize=10.5)
    ax.add_patch(Rectangle((-100, 0.3), 450, 0.5, fc=LIGHT, ec="none"))
    ax.text(125, 0.55, "one record: 0.1 s before to 0.35 s after the event, 10 kHz waveforms and 1 kHz signals",
            ha="center", va="center", fontsize=9.8, color=GREY)
    for k, (t0, a) in enumerate(((20, 1.0), (25, 0.45), (30, 0.25))):
        yb = 1.25 + 0.0*k
        ax.add_patch(Rectangle((t0 - 40, yb + 0.55*k), 40, 0.42, fc="#cfcfcf", ec=INK, lw=0.6, alpha=a))
        ax.add_patch(Rectangle((t0, yb + 0.55*k), 20, 0.42, fc=OK[0], ec=INK, lw=0.6, alpha=a))
    ax.text(-22, 1.46, "baseline B, 40 ms  ", ha="right", va="center", fontsize=10)
    ax.text(42, 1.46, "  window W, 20 ms", ha="left", va="center", fontsize=10, color=OK[0])
    ax.text(57, 2.22, "  … the pair moves on by 5 ms each time", ha="left", va="center", fontsize=10, color=GREY)
    ax.text(150, 1.75, "every feature compares W with B, for example\nΔV max = largest |V(t) − mean of V over B| inside W",
            fontsize=10, va="center")
    ax.set_xlabel("")
    ax.set_title("(a) A 20 ms window compared with the 40 ms just before it, every 5 ms (79 windows per record)",
                 loc="left", fontsize=11.5, weight="bold")

    ax = axs[1]
    ax.set_xlim(-105, 355); ax.set_ylim(0, 2.4); ax.set_yticks([])
    ax.spines["left"].set_visible(False)
    segs = [(-60, -20, OK[0], "not island (0)"), (-20, -10, "#bbbbbb", ""),
            (-10, 100, OK[1], "island (1), used\nfor training"), (100, 330, "#f3c7a6", "island (1), used only for testing")]
    for a, b, c, t in segs:
        ax.add_patch(Rectangle((a, 1.25), b - a, 0.6, fc=c, ec="white", lw=1))
        ax.text((a + b)/2, 1.55, t, ha="center", va="center", fontsize=9.5,
                color="white" if c in (OK[0], OK[1]) else INK)
    ax.annotate("left out (straddles t = 0)", xy=(-15, 1.86), xytext=(-60, 2.25), fontsize=9.5, color=GREY,
                arrowprops=dict(arrowstyle="-", color=GREY, lw=0.8))
    ax.add_patch(Rectangle((-60, 0.3), 390, 0.6, fc=OK[0], ec="white"))
    ax.text(135, 0.6, "ordinary event: every window is 'not island' (0)", ha="center", va="center", color="white", fontsize=10)
    ax.text(-104, 1.55, "island case", ha="left", va="center", fontsize=10, weight="bold")
    ax.text(-104, 0.6, "event case", ha="left", va="center", fontsize=10, weight="bold")
    ax.axvline(0, color=OK[1], lw=1.6)
    ax.set_xlabel("Start time of the window relative to the event (ms)")
    ax.set_title("(b) Labels by where the window starts. Island windows later than 100 ms are not used for training",
                 loc="left", fontsize=11.5, weight="bold")
    fig.tight_layout(h_pad=1.5)
    save(fig, "ml_windows")


# ------------------------------------------------------------------ folds
def ml_folds():
    fig, axs = plt.subplots(1, 3, figsize=(14, 4.6), gridspec_kw={"width_ratios": [1, 1, 1.05]})
    scr = ["SCR 20", "SCR 10", "SCR 5", "SCR 3"]
    mix = ["18.6 kW\n1000 W/m², 12 m/s", "10.6 kW\n1000, 6 m/s", "11.2 kW\n300, 12 m/s", "6.8 kW\n500, 8 m/s"]

    def grid(ax, test, title):
        for i in range(4):
            for j in range(4):
                t = test(i, j)
                ax.add_patch(Rectangle((j, 3 - i), 0.94, 0.94, fc=OK[1] if t else "#cfe2f3", ec="white"))
                ax.text(j + 0.47, 3 - i + 0.47, "test" if t else "train", ha="center", va="center", fontsize=9.5,
                        color="white" if t else INK)
        ax.set_xlim(-0.05, 4); ax.set_ylim(-0.05, 4)
        ax.set_xticks([k + 0.47 for k in range(4)]); ax.set_xticklabels(mix, fontsize=7.6)
        ax.set_yticks([3 - k + 0.47 for k in range(4)]); ax.set_yticklabels(scr, fontsize=9.5)
        ax.tick_params(length=0)
        for s in ax.spines.values(): s.set_visible(False)
        ax.set_title(title, loc="left", fontsize=10.8, weight="bold")

    grid(axs[0], lambda i, j: i == 3, "(a) Grid-strength fold (one of 4):\nSCR 3 held out → results reported")
    grid(axs[1], lambda i, j: j == 1, "(b) Mix fold (one of 4): one PV/wind\nmix held out → setting chosen")
    ax = axs[2]; ax.axis("off"); ax.set_xlim(0, 10); ax.set_ylim(0, 10)
    txt = ("• 16 conditions × 25 cases = 400 cases\n   (224 islands, 176 ordinary events)\n\n"
           "• A case is never split: all its windows\n   are either in training or in testing\n\n"
           "• The threshold θ and the run length D\n   are chosen on the mix folds only,\n"
           "   by a rule fixed in advance\n\n"
           "• The reported numbers come from the\n   grid-strength folds, which played no\n   part in the choice\n\n"
           "• Feeder retraining (step 8.4): each of\n   the 4 feeder training conditions is\n   also held out in turn")
    ax.text(0.2, 9.8, txt, va="top", fontsize=10.3, linespacing=1.3)
    fig.tight_layout(w_pad=2)
    save(fig, "ml_folds")


# ------------------------------------------------------------------ trip logic
def ml_trip():
    import random
    random.seed(4)
    t = list(range(0, 160, 5))
    s = []
    for k in t:
        if k < 40:
            s.append(random.uniform(0.0, 0.12))
        elif k in (45, 50):
            s.append([0.86, 0.35][(k - 45)//5])
        elif k < 70:
            s.append(random.uniform(0.82, 0.97) if k != 60 else 0.62)
        else:
            s.append(random.uniform(0.86, 0.99))
    fig, ax = plt.subplots(figsize=(12.5, 3.9))
    ax.step(t, s, where="post", color=OK[0], lw=1.6)
    ax.axhline(0.8, color=GREY, ls="--", lw=1)
    ax.text(158, 0.81, "threshold θ = 0.8", ha="right", va="bottom", color=GREY, fontsize=10)
    run, trip = 0, None
    for k, v in zip(t, s):
        run = run + 1 if v > 0.8 else 0
        ax.text(k + 2.5, -0.13, str(run), ha="center", fontsize=8.5, color=OK[1] if run else GREY)
        if run >= 4 and trip is None:
            trip = k
    ax.axvline(trip + 5, color=OK[1], lw=1.6)
    ax.text(trip + 6, 0.45, f"4 windows in a row above θ:\ntrip, CB1 opens", color=OK[1], fontsize=10.5, va="center")
    ax.text(-2, -0.13, "run:", ha="right", fontsize=8.5, color=GREY)
    ax.set_ylim(-0.2, 1.05); ax.set_xlim(-12, 160)
    ax.set_xlabel("Time after the event (ms); a new window is scored every 5 ms")
    ax.set_ylabel("Island score s")
    ax.set_title("Illustration (synthetic score): single high windows do not trip; four in a row do",
                 loc="left", fontsize=11.5, weight="bold")
    save(fig, "ml_trip")


if __name__ == "__main__":
    ml_network(); ml_windows(); ml_folds(); ml_trip()
    print("diagrams written to", OUT)
