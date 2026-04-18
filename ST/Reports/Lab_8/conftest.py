# conftest.py
import datetime
from pathlib import Path
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table,
    TableStyle, PageBreak, HRFlowable, Image
)

SCREENSHOTS_DIR = Path("screenshots")
REPORT_PATH     = Path("test_report.pdf")

_results: list[dict] = []


def pytest_configure(config):
    config.addinivalue_line("markers", "auth: authentication tests")
    config.addinivalue_line("markers", "navigation: page navigation tests")
    config.addinivalue_line("markers", "tasks: task creation and completion tests")
    config.addinivalue_line("markers", "browser: browser operation tests")
    config.addinivalue_line("markers", "i18n: internationalisation / language tests")
    config.addinivalue_line("markers", "smoke: quick sanity-check subset")
    config.addinivalue_line("markers", "flaky: known unstable")


def pytest_runtest_makereport(item, call):
    """Capture result of every test phase."""
    import pytest
    if call.when in ("call", "setup"):
        passed  = not call.excinfo
        xfailed = hasattr(call, "wasxfail") if not call.excinfo else False

        if call.excinfo is None:
            status = "PASSED"
        elif call.excinfo.typename == "XFailed":
            status = "XFAIL"
        else:
            status = "FAILED"

        markers = [m.name for m in item.iter_markers()
                   if m.name not in ("parametrize",)]

        _results.append({
            "number":   len(_results) + 1,
            "name":     item.name,
            "markers":  markers,
            "status":   status,
            "duration": call.stop - call.start,
            "error":    str(call.excinfo.value) if call.excinfo else "",
        })


def pytest_sessionfinish(session, exitstatus):
    if _results:
        _generate_pdf(_results, REPORT_PATH)


def _generate_pdf(results: list[dict], output_path: Path):
    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=A4,
        leftMargin=2 * cm, rightMargin=2 * cm,
        topMargin=2 * cm,  bottomMargin=2 * cm,
    )

    styles = getSampleStyleSheet()
    W = A4[0] - 4 * cm

    title_style = ParagraphStyle(
        "ReportTitle", parent=styles["Title"],
        fontSize=22, textColor=colors.HexColor("#db4035"), spaceAfter=6,
    )
    subtitle_style = ParagraphStyle(
        "Subtitle", parent=styles["Normal"],
        fontSize=10, textColor=colors.grey, spaceAfter=4,
    )
    section_style = ParagraphStyle(
        "Section", parent=styles["Heading2"],
        fontSize=13, textColor=colors.HexColor("#202020"),
        spaceBefore=14, spaceAfter=6,
    )
    normal = styles["Normal"]
    small  = ParagraphStyle("Small", parent=normal, fontSize=8,
                             textColor=colors.grey)

    passed  = [r for r in results if r["status"] == "PASSED"]
    failed  = [r for r in results if r["status"] == "FAILED"]
    xfailed = [r for r in results if r["status"] == "XFAIL"]
    run_at  = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    story = []

    # ── Cover ──────────────────────────────────────────────────────────────────
    story.append(Spacer(1, 1.5 * cm))
    story.append(Paragraph("Todoist Selenium", title_style))
    story.append(Paragraph("Automated Test Report", title_style))
    story.append(Spacer(1, 0.4 * cm))
    story.append(HRFlowable(width=W, color=colors.HexColor("#db4035"), thickness=2))
    story.append(Spacer(1, 0.3 * cm))
    story.append(Paragraph(f"Generated: {run_at}", subtitle_style))
    story.append(Paragraph("Target: https://todoist.com", subtitle_style))
    story.append(Spacer(1, 1 * cm))

    # ── Summary box ────────────────────────────────────────────────────────────
    summary_data = [
        ["Total", "Passed", "Failed", "XFail (expected)"],
        [str(len(results)), str(len(passed)),
         str(len(failed)), str(len(xfailed))],
    ]
    summary_table = Table(summary_data, colWidths=[W / 4] * 4)
    summary_table.setStyle(TableStyle([
        ("BACKGROUND",  (0, 0), (-1, 0), colors.HexColor("#db4035")),
        ("TEXTCOLOR",   (0, 0), (-1, 0), colors.white),
        ("FONTNAME",    (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE",    (0, 0), (-1, 0), 11),
        ("ALIGN",       (0, 0), (-1, -1), "CENTER"),
        ("VALIGN",      (0, 0), (-1, -1), "MIDDLE"),
        ("ROWHEIGHT",   (0, 0), (-1, -1), 22),
        ("BACKGROUND",  (0, 1), (-1, 1), colors.HexColor("#f9f9f9")),
        ("FONTNAME",    (0, 1), (-1, 1), "Helvetica-Bold"),
        ("FONTSIZE",    (0, 1), (-1, 1), 16),
        ("GRID",        (0, 0), (-1, -1), 0.5, colors.HexColor("#dddddd")),
    ]))
    story.append(summary_table)
    story.append(Spacer(1, 1 * cm))

    # ── Results table ──────────────────────────────────────────────────────────
    story.append(Paragraph("Test Results", section_style))

    STATUS_COLORS = {
        "PASSED": "#2ecc71",
        "FAILED": "#e74c3c",
        "XFAIL":  "#f39c12",
    }

    table_data = [["#", "Test Name", "Markers", "Status", "Duration"]]
    for r in results:
        hex_col = STATUS_COLORS.get(r["status"], "#888888")
        table_data.append([
            str(r["number"]),
            Paragraph(r["name"],
                      ParagraphStyle("tc", parent=normal, fontSize=8)),
            Paragraph(", ".join(r["markers"]), small),
            Paragraph(f'<font color="{hex_col}"><b>{r["status"]}</b></font>',
                      ParagraphStyle("sc", parent=normal, fontSize=9)),
            f'{r["duration"]:.2f}s',
        ])

    rt = Table(table_data,
               colWidths=[1*cm, 7*cm, 3.5*cm, 2*cm, 2*cm])
    rt.setStyle(TableStyle([
        ("BACKGROUND",     (0, 0), (-1, 0), colors.HexColor("#2c2c2c")),
        ("TEXTCOLOR",      (0, 0), (-1, 0), colors.white),
        ("FONTNAME",       (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE",       (0, 0), (-1, 0), 9),
        ("ALIGN",          (0, 0), (-1, 0), "CENTER"),
        ("ALIGN",          (3, 1), (4, -1), "CENTER"),
        ("VALIGN",         (0, 0), (-1, -1), "MIDDLE"),
        ("ROWHEIGHT",      (0, 1), (-1, -1), 28),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1),
         [colors.white, colors.HexColor("#f5f5f5")]),
        ("GRID",           (0, 0), (-1, -1), 0.4, colors.HexColor("#dddddd")),
        ("LEFTPADDING",    (0, 0), (-1, -1), 6),
        ("RIGHTPADDING",   (0, 0), (-1, -1), 6),
    ]))
    story.append(rt)

    # ── Failure details ────────────────────────────────────────────────────────
    hard_failures = [r for r in results if r["status"] == "FAILED"]
    if hard_failures:
        story.append(PageBreak())
        story.append(Paragraph("Failure Details", section_style))
        for r in hard_failures:
            story.append(Spacer(1, 0.3 * cm))
            story.append(Paragraph(
                f'<b>{r["number"]}. {r["name"]}</b>',
                ParagraphStyle("fh", parent=normal, fontSize=10,
                               textColor=colors.HexColor("#e74c3c")),
            ))
            if r.get("error"):
                story.append(Paragraph(
                    r["error"].replace("\n", "<br/>"),
                    ParagraphStyle("err", parent=normal, fontSize=8,
                                   backColor=colors.HexColor("#fff0f0"),
                                   leftIndent=10, rightIndent=10,
                                   fontName="Courier"),
                ))
            story.append(HRFlowable(width=W, color=colors.HexColor("#eeeeee")))

    # ── Screenshots ────────────────────────────────────────────────────────────
    screenshots = sorted(SCREENSHOTS_DIR.glob("*.png"))
    if screenshots:
        story.append(PageBreak())
        story.append(Paragraph("Screenshots", section_style))
        story.append(Spacer(1, 0.3 * cm))
        img_w = (W - 0.5 * cm) / 2
        pairs = [screenshots[i:i+2] for i in range(0, len(screenshots), 2)]
        for pair in pairs:
            cells_img, cells_cap = [], []
            for shot in pair:
                try:
                    cells_img.append(Image(str(shot), width=img_w,
                                           height=img_w * 0.6))
                    cells_cap.append(Paragraph(shot.stem, small))
                except Exception:
                    cells_img.append(Paragraph("(error)", small))
                    cells_cap.append(Paragraph(shot.name, small))
            while len(cells_img) < 2:
                cells_img.append("")
                cells_cap.append("")
            img_tbl = Table(
                [cells_img, cells_cap],
                colWidths=[img_w + 0.2*cm, img_w + 0.2*cm],
            )
            img_tbl.setStyle(TableStyle([
                ("ALIGN",  (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("PADDING",(0, 0), (-1, -1), 4),
            ]))
            story.append(img_tbl)
            story.append(Spacer(1, 0.4 * cm))

    # ── Footer ─────────────────────────────────────────────────────────────────
    story.append(Spacer(1, 1 * cm))
    story.append(HRFlowable(width=W, color=colors.HexColor("#dddddd")))
    story.append(Spacer(1, 0.2 * cm))
    story.append(Paragraph(
        f"Auto-generated by pytest + reportlab  |  {run_at}",
        ParagraphStyle("footer", parent=normal, fontSize=7,
                       textColor=colors.grey, alignment=1),
    ))

    doc.build(story)
    print(f"\n📄  PDF report → {output_path.resolve()}")