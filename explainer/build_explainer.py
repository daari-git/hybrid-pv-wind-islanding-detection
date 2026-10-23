"""Build the project explainer PDF from explainer.md.

    explainer.md -> explainer.html (pandoc, template.html, explainer.css) -> Project_Explainer.pdf (Chrome)

Run from anywhere: python explainer/build_explainer.py
Needs pandoc and Google Chrome; the ML diagrams come from ml_diagrams.py.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"


def run(cmd):
    print(" ".join(cmd))
    subprocess.run(cmd, cwd=HERE, check=True)


def main():
    if not os.path.exists(os.path.join(HERE, "figures", "ml_network.png")):
        run([sys.executable, "ml_diagrams.py"])
    run(["pandoc", "explainer.md", "-f", "markdown", "-t", "html5", "--standalone", "--template", "template.html",
         "--toc", "--toc-depth=2", "-o", "explainer.html"])
    url = "file:///" + os.path.join(HERE, "explainer.html").replace("\\", "/")
    run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", "--allow-file-access-from-files",
         "--print-to-pdf=" + os.path.join(HERE, "Project_Explainer.pdf"), url])


if __name__ == "__main__":
    sys.exit(main())
