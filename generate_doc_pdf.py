import os
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super(NumberedCanvas, self).__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 9)
        self.setFillColor(colors.HexColor("#64748B"))
        
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(54, 11.2 * inch, "Zen PDF Studio & GDRM Ecosystem — Official Documentation")
            self.setStrokeColor(colors.HexColor("#E2E8F0"))
            self.setLineWidth(0.75)
            self.line(54, 11.1 * inch, 8.27 * inch - 54, 11.1 * inch)
            
        # Footer
        footer_text = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(8.27 * inch - 54, 36, footer_text)
        self.drawString(54, 36, "Zen PDF Studio • 100% Offline • Zero-Trust Security • Zero Ads")
        self.setStrokeColor(colors.HexColor("#E2E8F0"))
        self.setLineWidth(0.75)
        self.line(54, 48, 8.27 * inch - 54, 48)
        self.restoreState()

def create_documentation_pdf(output_filename):
    doc = SimpleDocTemplate(
        output_filename,
        pagesize=A4,
        leftMargin=50,
        rightMargin=50,
        topMargin=50,
        bottomMargin=50
    )
    
    styles = getSampleStyleSheet()
    
    # Custom Sobar & Clean Typography Styles
    title_style = ParagraphStyle(
        'DocTitle',
        fontName='Helvetica-Bold',
        fontSize=22,
        leading=26,
        textColor=colors.HexColor("#0F172A"),
        spaceAfter=4
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        fontName='Helvetica',
        fontSize=12,
        leading=16,
        textColor=colors.HexColor("#475569"),
        spaceAfter=12
    )
    
    h1_style = ParagraphStyle(
        'Heading1_Custom',
        fontName='Helvetica-Bold',
        fontSize=13.5,
        leading=17,
        textColor=colors.HexColor("#0F172A"),
        spaceBefore=12,
        spaceAfter=6,
        keepWithNext=True
    )
    
    h2_style = ParagraphStyle(
        'Heading2_Custom',
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=15,
        textColor=colors.HexColor("#1E3A8A"),
        spaceBefore=8,
        spaceAfter=4,
        keepWithNext=True
    )
    
    body_style = ParagraphStyle(
        'Body_Custom',
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=colors.HexColor("#334155"),
        spaceAfter=5
    )
    
    bullet_style = ParagraphStyle(
        'Bullet_Custom',
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=colors.HexColor("#334155"),
        leftIndent=12,
        spaceAfter=3.5
    )
    
    tip_box_style = ParagraphStyle(
        'Tip_Text',
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=colors.HexColor("#065F46")
    )
    
    gdrm_box_style = ParagraphStyle(
        'Gdrm_Text',
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=colors.HexColor("#0E7490")
    )

    story = []
    
    # Title Banner Block
    story.append(Paragraph("Zen PDF Studio & GDRM Ecosystem", title_style))
    story.append(Paragraph("Comprehensive User Guide, Architecture & Technical Manual", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor("#2563EB"), spaceAfter=10))
    
    # Overview Box
    intro_html = """<b>Executive Overview:</b><br/>
<b>Zen PDF Studio</b> is a modern, ultra-fast, and privacy-first universal document application for Android and Windows. It provides native in-app editing studios for Office documents (Word, Excel, PowerPoint), code, and HTML, combined with enterprise-grade <b>GDRM (Granular Digital Right Manager) Zero-Trust</b> encryption, Aadhaar/PAN cryptographic signature verification, and instant zero-latency photo-to-PDF compilation."""
    intro_table = Table([[Paragraph(intro_html, body_style)]], colWidths=[495])
    intro_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#CBD5E1")),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(intro_table)
    story.append(Spacer(1, 10))
    
    # SECTION 1: GDRM ZERO-TRUST ECOSYSTEM
    story.append(Paragraph("1. GDRM Zero-Trust Encryption & Cryptographic Container (.gdrm)", h1_style))
    story.append(Paragraph("Zen PDF integrates the <b>GDRM (Granular Digital Right Manager)</b> ecosystem (powered by <code>gdrm_sdk</code>), allowing users to lock PDF documents into military-grade encrypted <code>.gdrm</code> packages with hardware and biometric-level security policies:", body_style))
    
    story.append(Paragraph("• <b>Machine Hardware Binding (K<sub>device</sub>):</b> Cryptographically locks document decryption exclusively to the authoring machine or a specified target device ID. If forwarded to another PC or phone, the container remains mathematically impenetrable.", bullet_style))
    story.append(Paragraph("• <b>ChronoLock Time Bomb Expiry:</b> Configure auto-expiring documents (1 hour, 24 hours, 3 days, 7 days, or precise UTC timestamps). After expiration, access is permanently refused.", bullet_style))
    story.append(Paragraph("• <b>Target User Locking:</b> Seal sensitive materials to a designated <code>@username</code> identity.", bullet_style))
    story.append(Paragraph("• <b>Indelible Forensic Watermark:</b> Overlays dynamic, non-removable diagonal watermarks with host hardware fingerprint, IP, and timestamp across all rendered pages.", bullet_style))
    story.append(Paragraph("• <b>Physical Print & Clipboard Restrictions:</b> Hard-disables OS text extraction, screenshots, and unauthorized physical printing.", bullet_style))
    story.append(Paragraph("• <b>SnailTrail Immutable Audit Logs:</b> Embedded cryptographic ledger tracking authoring timestamp, device fingerprint, and tampering verification.", bullet_style))
    story.append(Spacer(1, 8))

    # SECTION 2: UNIVERSAL DOCUMENT STUDIOS
    story.append(Paragraph("2. Universal In-App Document Studios", h1_style))
    story.append(Paragraph("Zen PDF goes beyond traditional PDF readers with 5 built-in, 100% offline document creation & editing studios:", body_style))
    story.append(Paragraph("• <b>Word Studio (.docx, .doc):</b> Rich-text word processor with heading presets, custom typography, alignments, image inserts, and instant Word/PDF export.", bullet_style))
    story.append(Paragraph("• <b>Spreadsheet Studio (.xlsx, .xls, .csv):</b> High-performance 2D formula grid supporting <code>=SUM</code>, <code>=AVERAGE</code>, <code>=COUNT</code>, cell styling, auto-formatting, and multi-sheet workbooks.", bullet_style))
    story.append(Paragraph("• <b>Presentation Studio (.pptx, .ppt):</b> 16:9 interactive slide deck designer with animated thumbnail strip, layout templates, color themes, and full-screen presentation mode.", bullet_style))
    story.append(Paragraph("• <b>HTML Web Studio (.html, .htm):</b> Triple-view HTML/CSS editor with live real-time split-screen DOM rendering, viewport switcher (Mobile/Tablet/Desktop), and auto-formatter.", bullet_style))
    story.append(Paragraph("• <b>Universal Code & Text IDE:</b> High-speed code editor for 50+ programming languages (JSON, Dart, JS, Python, SQL, XML, TXT) with search & replace and line counters.", bullet_style))
    story.append(Spacer(1, 8))

    # SECTION 3: FAST-PATH IMAGE TO PDF
    story.append(Paragraph("3. Zero-Latency High-Speed Images to PDF", h1_style))
    story.append(Paragraph("Optimized image-to-PDF compilation pipeline eliminates CPU bottle-necks:", body_style))
    story.append(Paragraph("• <b>Direct Byte Pass-Through:</b> When images are in standard orientation without post-filters, raw byte streams are embedded directly into PDF raster pages, creating multi-page PDFs instantly.", bullet_style))
    story.append(Paragraph("• <b>Optional Enhancement Filters:</b> Clean Scan, Document Magic Color, and B&W high-contrast modes available for specialized document scanning.", bullet_style))
    story.append(Paragraph("• <b>Direct .gdrm Export:</b> One-tap option to seal photo scans directly into zero-trust encrypted <code>.gdrm</code> files without intermediary saving.", bullet_style))
    story.append(Spacer(1, 8))

    # SECTION 4: UNIVERSAL OS INTENT ASSOCIATIONS & BACK-TO-APP
    story.append(Paragraph("4. Universal 'Open With' Association & Back-to-App Flow", h1_style))
    story.append(Paragraph("Seamless operating system integration on Android and Windows:", body_style))
    story.append(Paragraph("• <b>Universal File Associations:</b> Zen PDF is registered as the default handler for <code>.pdf</code>, <code>.gdrm</code>, <code>.docx</code>, <code>.pptx</code>, <code>.xlsx</code>, <code>.csv</code>, <code>.html</code>, <code>.json</code>, and <code>.txt</code>.", bullet_style))
    story.append(Paragraph("• <b>Seamless Back-to-App Exit Flow:</b> When documents are opened from WhatsApp, Gmail, Telegram, or file managers, closing the viewer immediately invokes <code>SystemNavigator.pop()</code> to return directly to the calling app without trapping the user on Zen PDF's home screen.", bullet_style))
    story.append(Spacer(1, 8))

    # SECTION 5: SIGNATURE VERIFICATION & PDF TOOLS
    story.append(Paragraph("5. Digital Signature Verification & Stamping (Aadhaar & PAN)", h1_style))
    story.append(Paragraph("• <b>Aadhaar & PAN Certificate Verification:</b> Analyzes embedded SHA-256 PKCS#7 digital signatures, transforming unverified yellow question marks (<b>?</b>) into authentic Adobe Acrobat green ticks (<b>✔</b>).", bullet_style))
    story.append(Paragraph("• <b>Digital Signing:</b> Stamp verified digital certificates with signer name, location, timestamp, and custom approval reasons.", bullet_style))
    story.append(Paragraph("• <b>Whiteout & Annotations:</b> Cover sensitive numbers or add ink signatures with pixel precision.", bullet_style))
    story.append(Paragraph("• <b>Page Organizer:</b> Drag-and-drop page reordering, merging, rotating, and splitting.", bullet_style))
    story.append(Spacer(1, 8))

    # SECTION 6: QUICK SPECIFICATION TABLE
    story.append(Paragraph("6. Feature Specifications & Compatibility Matrix", h1_style))
    table_data = [
        [Paragraph("<b>Component</b>", h2_style), Paragraph("<b>Key Capabilities</b>", h2_style), Paragraph("<b>Supported Formats</b>", h2_style)],
        [Paragraph("<b>GDRM Security</b>", body_style), Paragraph("Hardware Lock ($K_{device}$), ChronoLock, Watermark, SnailTrail", body_style), Paragraph(".gdrm, .pdf", body_style)],
        [Paragraph("<b>Universal Studio</b>", body_style), Paragraph("Word, Spreadsheet, Presentation, HTML, Code IDE", body_style), Paragraph(".docx, .xlsx, .pptx, .html, .json, .txt", body_style)],
        [Paragraph("<b>Chrome PDF Viewer</b>", body_style), Paragraph("120 FPS render, search, infinite zoom, rotate, thumbnails", body_style), Paragraph(".pdf, .gdrm", body_style)],
        [Paragraph("<b>Fast Image Scanner</b>", body_style), Paragraph("Zero-latency pass-through, multi-page binding", body_style), Paragraph(".jpg, .png, .webp, .heic", body_style)],
        [Paragraph("<b>Signature Engine</b>", body_style), Paragraph("PKCS#7 SHA-256 verification & Adobe Acrobat checkmark", body_style), Paragraph("Aadhaar, PAN, Invoices, Contracts", body_style)],
        [Paragraph("<b>OS Integration</b>", body_style), Paragraph("System 'Open With' intent + Instant Back-to-App pop", body_style), Paragraph("Android 7.0+ / Windows 10/11", body_style)]
    ]
    summary_table = Table(table_data, colWidths=[105, 230, 160])
    summary_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#F1F5F9")),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E1")),
    ]))
    story.append(summary_table)
    story.append(Spacer(1, 10))

    # SECTION 7: PRIVACY & SECURITY COMMITMENT
    story.append(Paragraph("7. Privacy & Offline-First Security Guarantee", h1_style))
    privacy_text = """<b>Zero Cloud Dependency • 100% On-Device Privacy:</b><br/>
Zen PDF Studio and the GDRM SDK operate entirely on-device. No telemetry, analytics, ad networks, or cloud trackers are bundled. All cryptographic hashing, document rendering, and PDF conversions occur within isolated local application memory."""
    privacy_box = Table([[Paragraph(privacy_text, tip_box_style)]], colWidths=[495])
    privacy_box.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F0FDF4")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#BBF7D0")),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(privacy_box)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Documentation PDF generated successfully at: {output_filename}")

if __name__ == '__main__':
    create_documentation_pdf("Zen_PDF_User_Guide.pdf")
    create_documentation_pdf("website/downloads/Zen_PDF_User_Guide.pdf")
