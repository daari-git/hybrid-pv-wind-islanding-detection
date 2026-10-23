"""Build the narrated explainer video from video_script.py.

    slides  -> video_build/slides.html -> Project_Explainer_slides.pdf (Chrome) -> one PNG per slide (PyMuPDF)
    speech  -> one WAV per sentence (Windows System.Speech, cached by text) -> narration.wav
    frames  -> slide PNG + caption of the sentence being spoken (Pillow)
    video   -> Project_Explainer.mp4 (ffmpeg from imageio-ffmpeg: H.264, AAC, one chapter per slide)

Run from the repository root: python explainer/make_video.py
Needs Google Chrome, PyMuPDF, Pillow and imageio-ffmpeg (pip install imageio-ffmpeg).
"""
import hashlib
import html
import json
import os
import re
import subprocess
import sys
import wave

import fitz
import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BUILD = os.path.join(HERE, "video_build")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
VOICE, RATE = "Microsoft Zira Desktop", -1
W, H, BAND = 1920, 1080, 150                 # frame size; bottom band reserved for captions
GAP, SLIDE_GAP, LEAD = 0.25, 0.6, 0.8        # pauses (s) after a sentence, after a slide, before the first

sys.path.insert(0, HERE)
from video_script import SLIDES  # noqa: E402


# ------------------------------------------------------------------ text for the voice
SPELL = ["PCC", "SCR", "AFD", "PLL", "LCL", "MPPT", "THD", "RMS", "RLC", "IGBT", "PWM", "SVM", "NEA", "PID",
         "PV", "DC", "ML", "PI", "DG", "NDZ", "SOGI", "VSI", "PMSG"]
WORDS = [(r"IEEE 1547-2018", "I triple E fifteen forty-seven, 2018"), (r"IEEE 1547", "I triple E fifteen forty-seven"),
         (r"\bIEEE\b", "I triple E"), (r"\bL-BFGS\b", "L B F G S"), (r"\bReLU\b", "rel-you"),
         (r"\bfitcnet\b", "fit C net"), (r"\bCB([12])\b", r"C B \1"), (r"H-infinity", "H infinity"),
         (r"(\d)\s*kVA\b", r"\1 kilovolt-amperes"), (r"(\d)\s*kV\b", r"\1 kilovolts"), (r"(\d)\s*kW\b", r"\1 kilowatts"),
         (r"(\d)\s*Hz/s\b", r"\1 hertz per second"), (r"(\d)\s*kHz\b", r"\1 kilohertz"), (r"(\d)\s*Hz\b", r"\1 hertz"),
         (r"(\d)\s*ms\b", r"\1 milliseconds"), (r"(\d)\s*µs\b", r"\1 microseconds"), (r"(\d)\s*pu\b", r"\1 per unit"),
         (r"(\d)\s*%", r"\1 percent"), (r"(\d)\s*W/m²", r"\1 watts per square metre"), (r"(\d)\s*m/s\b", r"\1 metres per second"),
         (r"(\d)\s*[–-]\s*(\d)", r"\1 to \2"), (r"→", ", then "), (r"×", " times "), (r"≈", " about "),
         (r"≤", " at most "), (r"±", " plus or minus "), (r"θ", "theta"), (r"Δ", "delta "), (r"–", ", ")]


def speech(text):
    for a, b in WORDS:
        text = re.sub(a, b, text)
    for w in SPELL:
        text = re.sub(r"\b%s\b" % w, " ".join(w), text)
    return text


# ------------------------------------------------------------------ slides
CSS = """
@page { size: 1920px 1080px; margin: 0; }
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { font-family: "Segoe UI", Arial, sans-serif; color: #1f2328; }
.slide { width: 1920px; height: 1080px; position: relative; overflow: hidden; background: #ffffff; break-after: page; }
.band { position: absolute; left: 0; right: 0; bottom: 0; height: %(band)dpx; background: #16202b; }
.top { position: absolute; left: 70px; right: 70px; top: 26px; height: 40px; display: flex; justify-content: space-between;
       font-size: 21px; letter-spacing: 0.12em; text-transform: uppercase; color: #6b7480;
       border-bottom: 2px solid #d5dde6; }
.title { position: absolute; left: 70px; right: 70px; top: 80px; font-size: 46px; font-weight: 700; color: #0b5394; line-height: 1.15; }
.body { position: absolute; left: 70px; right: 70px; top: 170px; bottom: %(bodybottom)dpx; display: flex; align-items: center; justify-content: center; }
.body.fig img { max-width: 1780px; max-height: 100%%; object-fit: contain; }
.note { position: absolute; left: 70px; right: 70px; bottom: %(notebottom)dpx; text-align: center; font-size: 25px; color: #5b6470; }
.split { justify-content: space-between; gap: 50px; }
.split .im { flex: 0 0 1120px; height: 100%%; display: flex; align-items: center; justify-content: center; }
.split .im img { max-width: 1120px; max-height: 100%%; object-fit: contain; }
.split ul { flex: 1; font-size: 30px; line-height: 1.35; margin: 0; padding-left: 34px; }
.split li { margin: 0 0 20px; }
.bul ul { font-size: 36px; line-height: 1.32; margin: 0; padding-left: 44px; width: 100%%; }
.bul li { margin: 0 0 22px; }
.bul li::marker, .split li::marker { color: #0b5394; }
table { border-collapse: collapse; font-size: 27px; width: 100%%; }
th, td { border: 1px solid #d5dde6; padding: 10px 16px; text-align: left; vertical-align: top; }
tr:first-child td { background: #e8eef5; font-weight: 600; }
tr:nth-child(even) td { background: #fafbfc; }
.cover { background: linear-gradient(135deg, #0b3a66 0%%, #0b5394 60%%, #1b6fb8 100%%); color: #ffffff; }
.cover .kick { position: absolute; left: 130px; top: 250px; font-size: 26px; letter-spacing: 0.16em; text-transform: uppercase; opacity: 0.8; }
.cover h1 { position: absolute; left: 130px; right: 130px; top: 310px; font-size: 80px; line-height: 1.1; margin: 0; }
.cover .sub { position: absolute; left: 130px; right: 260px; top: 520px; font-size: 36px; line-height: 1.35; }
.cover .sub p { margin: 0 0 18px; }
.section { background: #f2f6fa; }
.section h1 { position: absolute; left: 130px; right: 130px; top: 330px; font-size: 72px; color: #0b5394; margin: 0; }
.section .sub { position: absolute; left: 130px; right: 130px; top: 470px; font-size: 32px; color: #3d4652; line-height: 1.4; }
.section .bar { position: absolute; left: 130px; top: 300px; width: 140px; height: 8px; background: #0b5394; }
"""


def esc(s):
    """HTML-escape on-screen text; ~x~ marks a subscript."""
    return re.sub(r"~([^~]+)~", r"<sub>\1</sub>", html.escape(s))


def image_src(slide, k):
    """Repository image for a slide, cropped into video_build/img when the slide asks for it."""
    path = os.path.join(ROOT, slide["image"])
    if "crop" in slide:
        im = Image.open(path)
        x0, y0, x1, y1 = slide["crop"]
        w, h = im.size
        path = os.path.join(BUILD, "img", "slide%02d.png" % k)
        im.crop((round(x0*w), round(y0*h), round(x1*w), round(y1*h))).save(path)
    return "file:///" + path.replace("\\", "/")


def slide_html(s, k, n):
    top = '<div class="top"><span>%s</span><span>%d / %d</span></div>' % (esc(s["chapter"]), k + 1, n)
    title = '<div class="title">%s</div>' % esc(s["title"])
    band = '<div class="band"></div>'
    kind = s["kind"]
    if kind == "cover":
        sub = "".join("<p>%s</p>" % esc(p) for p in s.get("points", []))
        return ('<section class="slide cover"><div class="kick">Project explainer</div><h1>%s</h1>'
                '<div class="sub">%s</div>%s</section>' % (esc(s["title"]), sub, band))
    if kind == "section":
        sub = "".join("<p>%s</p>" % esc(p) for p in s.get("points", []))
        return ('<section class="slide section"><div class="bar"></div><h1>%s</h1><div class="sub">%s</div>%s</section>'
                % (esc(s["title"]), sub, band))
    if kind == "figure":
        note = s.get("points")
        body_bottom = BAND + (70 if note else 25)
        body = ('<div class="body fig" style="bottom:%dpx"><img src="%s"></div>' % (body_bottom, image_src(s, k)))
        if note:
            body += '<div class="note" style="bottom:%dpx">%s</div>' % (BAND + 22, esc(note[0]))
        return '<section class="slide">%s%s%s%s</section>' % (top, title, body, band)
    if kind == "split":
        items = "".join("<li>%s</li>" % esc(p) for p in s["points"])
        body = ('<div class="body split"><div class="im"><img src="%s"></div><ul>%s</ul></div>' % (image_src(s, k), items))
        return '<section class="slide">%s%s%s%s</section>' % (top, title, body, band)
    if kind == "bullets":
        items = "".join("<li>%s</li>" % esc(p) for p in s["points"])
        return '<section class="slide">%s%s<div class="body bul"><ul>%s</ul></div>%s</section>' % (top, title, items, band)
    if kind == "table":
        rows = []
        for row in s["rows"]:
            cells = [c for c in row]
            if len(cells) > 1 and all(c == "" for c in cells[2:]) and cells[1] and len(row) > 3:
                rows.append('<tr><td>%s</td><td colspan="%d">%s</td></tr>' % (esc(cells[0]), len(row) - 1, esc(cells[1])))
            else:
                rows.append("<tr>%s</tr>" % "".join("<td>%s</td>" % esc(c) for c in cells))
        return ('<section class="slide">%s%s<div class="body"><table>%s</table></div>%s</section>'
                % (top, title, "".join(rows), band))
    raise ValueError(kind)


def render_slides():
    os.makedirs(os.path.join(BUILD, "img"), exist_ok=True)
    os.makedirs(os.path.join(BUILD, "slides"), exist_ok=True)
    n = len(SLIDES)
    css = CSS % dict(band=BAND, bodybottom=BAND + 25, notebottom=BAND + 22)
    doc = ('<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>Explainer slides</title><style>%s</style>'
           '</head><body>%s</body></html>' % (css, "\n".join(slide_html(s, k, n) for k, s in enumerate(SLIDES))))
    page = os.path.join(BUILD, "slides.html")
    with open(page, "w", encoding="utf-8") as f:
        f.write(doc)
    pdf = os.path.join(HERE, "Project_Explainer_slides.pdf")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", "--allow-file-access-from-files",
                    "--print-to-pdf=" + pdf, "file:///" + page.replace("\\", "/")], check=True)
    d = fitz.open(pdf)
    assert d.page_count == n, "slides PDF has %d pages for %d slides" % (d.page_count, n)
    out = []
    for k, p in enumerate(d):
        zoom = W / p.rect.width
        f = os.path.join(BUILD, "slides", "slide%02d.png" % (k + 1))
        p.get_pixmap(matrix=fitz.Matrix(zoom, zoom)).save(f)
        out.append(f)
    d.close()
    return out


# ------------------------------------------------------------------ speech
PS = r"""
param([string]$jobs)
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$s.SelectVoice('%s'); $s.Rate = %d
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
$list = Get-Content -Raw -Encoding UTF8 $jobs | ConvertFrom-Json
foreach ($j in $list) { $s.SetOutputToWaveFile($j.path, $fmt); $s.Speak($j.text); $s.SetOutputToNull() }
""" % (VOICE, RATE)


def synthesise(sentences):
    wavdir = os.path.join(BUILD, "wav")
    os.makedirs(wavdir, exist_ok=True)
    paths, jobs = [], []
    for t in sentences:
        sp = speech(t)
        key = hashlib.sha1(("%s|%d|%s" % (VOICE, RATE, sp)).encode("utf-8")).hexdigest()[:16]
        p = os.path.join(wavdir, key + ".wav")
        paths.append(p)
        if not os.path.exists(p):
            jobs.append({"text": sp, "path": p})
    if jobs:
        jf, ps = os.path.join(BUILD, "tts_jobs.json"), os.path.join(BUILD, "tts.ps1")
        with open(jf, "w", encoding="utf-8") as f:
            json.dump(jobs, f, ensure_ascii=False)
        with open(ps, "w", encoding="utf-8-sig") as f:
            f.write(PS)
        print("synthesising %d sentences" % len(jobs))
        subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps, jf], check=True)
    return paths


# ------------------------------------------------------------------ captions and frames
FONT = r"C:\Windows\Fonts\segoeui.ttf"


def wrap(draw, text, font, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=font) <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def caption(slide_png, text, out):
    im = Image.open(slide_png).convert("RGB")
    d = ImageDraw.Draw(im)
    d.rectangle([0, H - BAND, W, H], fill="#16202b")
    for size in (36, 33, 30, 27):
        font = ImageFont.truetype(FONT, size)
        lines = wrap(d, text, font, W - 200)
        lh = int(size * 1.3)
        if len(lines) * lh <= BAND - 20:
            break
    y = H - BAND + (BAND - len(lines) * lh) // 2
    for line in lines:
        d.text((W // 2, y), line, font=font, fill="#ffffff", anchor="ma")
        y += lh
    im.save(out)


def wav_seconds(p):
    with wave.open(p) as w:
        return w.getnframes() / w.getframerate()


def main():
    os.makedirs(os.path.join(BUILD, "frames"), exist_ok=True)
    pngs = render_slides()
    sentences = [t for s in SLIDES for t in s["say"]]
    wavs = synthesise(sentences)

    with wave.open(wavs[0]) as w0:
        params = w0.getparams()
    rate = params.framerate
    silence = lambda sec: b"\x00\x00" * int(round(sec * rate))
    audio = [silence(LEAD)]
    concat = []                       # (frame png, duration)
    chapters = []                     # (start, end, title)
    t, i = LEAD, 0
    first = True
    for k, s in enumerate(SLIDES):
        start = 0.0 if first else t
        for j, text in enumerate(s["say"]):
            frame = os.path.join(BUILD, "frames", "f%03d_%02d.png" % (k + 1, j + 1))
            caption(pngs[k], text, frame)
            with wave.open(wavs[i]) as w:
                data = w.readframes(w.getnframes())
            dur = len(data) / 2 / rate
            pause = GAP + (SLIDE_GAP if j == len(s["say"]) - 1 else 0.0)
            audio += [data, silence(pause)]
            show = dur + pause + (LEAD if first else 0.0)
            concat.append((frame, show))
            t += dur + pause
            i += 1
            first = False
        chapters.append((start, t, "%d. %s" % (k + 1, s["title"])))

    nar = os.path.join(BUILD, "narration.wav")
    with wave.open(nar, "wb") as w:
        w.setparams(params)
        w.writeframes(b"".join(audio))

    lst = os.path.join(BUILD, "frames.txt")
    with open(lst, "w", encoding="utf-8") as f:
        for p, dur in concat:
            f.write("file '%s'\nduration %.4f\n" % (p.replace("\\", "/"), dur))
        f.write("file '%s'\n" % concat[-1][0].replace("\\", "/"))
    meta = os.path.join(BUILD, "chapters.txt")
    with open(meta, "w", encoding="utf-8") as f:
        f.write(";FFMETADATA1\ntitle=Islanding detection for a hybrid PV-wind inverter: project explainer\n")
        for a, b, name in chapters:
            f.write("[CHAPTER]\nTIMEBASE=1/1000\nSTART=%d\nEND=%d\ntitle=%s\n" % (round(a*1000), round(b*1000),
                                                                                 name.replace("=", "-")))

    out = os.path.join(HERE, "Project_Explainer.mp4")
    part = os.path.join(BUILD, "Project_Explainer.part.mp4")    # renamed only when encoding finished
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    cmd = [ff, "-y", "-hide_banner", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-i", nar,
           "-i", meta, "-map", "0:v", "-map", "1:a", "-map_metadata", "2", "-map_chapters", "2",
           "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-tune", "stillimage", "-pix_fmt", "yuv420p", "-r", "15",
           "-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-shortest", "-movflags", "+faststart", part]
    subprocess.run(cmd, check=True)
    os.replace(part, out)
    print("%s: %d slides, %d sentences, %.1f min" % (out, len(SLIDES), len(sentences), t / 60))


if __name__ == "__main__":
    main()
