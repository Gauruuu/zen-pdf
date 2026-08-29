import os
from reportlab.lib.pagesizes import letter, A4
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
            self.drawString(54, 11.2 * inch, "Zen PDF Studio — User Guide & Documentation")
            self.setStrokeColor(colors.HexColor("#E2E8F0"))
            self.setLineWidth(0.75)
            self.line(54, 11.1 * inch, 8.27 * inch - 54, 11.1 * inch)
            
        # Footer
        footer_text = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(8.27 * inch - 54, 36, footer_text)
        self.drawString(54, 36, "Zen PDF • 100% Free • Offline First • Zero Ads")
        self.setStrokeColor(colors.HexColor("#E2E8F0"))
        self.setLineWidth(0.75)
        self.line(54, 48, 8.27 * inch - 54, 48)
        self.restoreState()

def create_documentation_pdf(output_filename):
    doc = SimpleDocTemplate(
        output_filename,
        pagesize=A4,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )
    
    styles = getSampleStyleSheet()
    
    # Custom Sobar & Clean Typography Styles
    title_style = ParagraphStyle(
        'DocTitle',
        fontName='Helvetica-Bold',
        fontSize=24,
        leading=28,
        textColor=colors.HexColor("#0F172A"),
        spaceAfter=6
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        fontName='Helvetica',
        fontSize=13,
        leading=17,
        textColor=colors.HexColor("#475569"),
        spaceAfter=14
    )
    
    h1_style = ParagraphStyle(
        'Heading1_Custom',
        fontName='Helvetica-Bold',
        fontSize=15,
        leading=19,
        textColor=colors.HexColor("#0F172A"),
        spaceBefore=16,
        spaceAfter=8,
        keepWithNext=True
    )
    
    h2_style = ParagraphStyle(
        'Heading2_Custom',
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=colors.HexColor("#1E3A8A"),
        spaceBefore=10,
        spaceAfter=4,
        keepWithNext=True
    )
    
    body_style = ParagraphStyle(
        'Body_Custom',
        fontName='Helvetica',
        fontSize=10,
        leading=14.5,
        textColor=colors.HexColor("#334155"),
        spaceAfter=6
    )
    
    bullet_style = ParagraphStyle(
        'Bullet_Custom',
        fontName='Helvetica',
        fontSize=10,
        leading=14,
        textColor=colors.HexColor("#334155"),
        leftIndent=14,
        spaceAfter=4
    )
    
    tip_box_style = ParagraphStyle(
        'Tip_Text',
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=colors.HexColor("#065F46")
    )
    
    story = []
    
    # Title Banner Block
    story.append(Paragraph("Zen PDF Studio", title_style))
    story.append(Paragraph("Simple & Sober User Manual — Plain English Guide", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor("#2563EB"), spaceAfter=14))
    
    # Overview Box
    intro_html = """<b>What is Zen PDF?</b><br/>
Zen PDF is a free, fast, and simple tool to view, edit, sign, and organize PDF documents on your Android phone and Windows PC. Everything runs completely on your device without internet, and no personal files are ever uploaded."""
    intro_table = Table([[Paragraph(intro_html, body_style)]], colWidths=[500])
    intro_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#CBD5E1")),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('RIGHTPADDING', (0,0), (-1,-1), 12),
    ]))
    story.append(intro_table)
    story.append(Spacer(1, 14))
    
    # SECTION 1: PDF VIEWER
    story.append(Paragraph("1. Chrome-Style PDF Viewer", h1_style))
    story.append(Paragraph("Zen PDF includes a clean, dark-canvas PDF viewer just like Google Chrome:", body_style))
    story.append(Paragraph("• <b>Instant Page Opening:</b> PDFs open in under a second with smooth 60fps scrolling.", bullet_style))
    story.append(Paragraph("• <b>Infinite Zoom:</b> Zoom in from 10% up to 10,000% to inspect tiny text, barcodes, or fine print without blurry pixels.", bullet_style))
    story.append(Paragraph("• <b>Page Thumbnails:</b> Tap the <i>Thumbnails</i> button on the top-left to view page cards and jump directly to any page.", bullet_style))
    story.append(Paragraph("• <b>Rotate & Print:</b> Tap <i>Rotate (↻)</i> to turn sideways pages upright, or tap <i>Print</i> to print directly.", bullet_style))
    story.append(Paragraph("• <b>Open from WhatsApp or Gmail:</b> When you tap any PDF on your phone, choose <b>Zen PDF</b> in the 'Open With' menu to view it immediately.", bullet_style))
    story.append(Spacer(1, 10))
    
    # SECTION 2: VERIFY SIGNATURES
    story.append(Paragraph("2. Verifying Digital Signatures (Aadhaar, PAN & Govt Forms)", h1_style))
    story.append(Paragraph("Many official documents in India (like Aadhaar cards, e-PAN, bank statements, and tax forms) have digital signatures that show a yellow question mark (?) when unverified. Zen PDF verifies them just like Adobe Acrobat:", body_style))
    story.append(Paragraph("• <b>Step 1:</b> Tap <b>Verify Signatures</b> on the Home screen and choose your PDF file.", bullet_style))
    story.append(Paragraph("• <b>Step 2:</b> If the file is locked (like an Aadhaar PDF), enter the password (e.g. first 4 letters of name in capital + birth year).", bullet_style))
    story.append(Paragraph("• <b>Step 3:</b> Zen PDF reads the cryptographic SHA-256 certificate inside the document.", bullet_style))
    story.append(Paragraph("• <b>Step 4:</b> The yellow question mark <b>(?)</b> turns into an official <b>Green Tick (✔)</b> with signer name, date, and reason.", bullet_style))
    story.append(Spacer(1, 10))

    # SECTION 3: SIGN PDFS DIGITALLY
    story.append(Paragraph("3. Signing PDFs Digitally", h1_style))
    story.append(Paragraph("You can add your own verified digital signature stamp to any contract, application, or form:", body_style))
    story.append(Paragraph("• Open the document in <b>Edit & Sign PDF</b>.", bullet_style))
    story.append(Paragraph("• Tap <b>Sign Digitally</b> in the top toolbar.", bullet_style))
    story.append(Paragraph("• Type your Name, Reason (e.g. <i>'I approve this document'</i> or <i>'Document Authenticity Verified'</i>), and Location.", bullet_style))
    story.append(Paragraph("• Tap <b>Apply Digital Signature</b> and place the signature stamp anywhere on the page.", bullet_style))
    story.append(Spacer(1, 10))
    
    # SECTION 4: TURNING PICTURES TO PDF
    story.append(Paragraph("4. Turning Photos & Scans into PDF", h1_style))
    story.append(Paragraph("Easily turn camera photos or gallery pictures into clean single or multi-page PDFs:", body_style))
    story.append(Paragraph("• Tap <b>Images to PDF</b> and pick one or more pictures.", bullet_style))
    story.append(Paragraph("• <b>Filters:</b> Choose <i>Clean Scan</i>, <i>Black & White</i>, or <i>Vivid</i> to remove shadows and enhance text.", bullet_style))
    story.append(Paragraph("• <b>Reorder:</b> Long-press and drag any photo to arrange page order.", bullet_style))
    story.append(Paragraph("• <b>Page Settings:</b> Choose Page Size (A4, Letter) and Margins (None, Normal).", bullet_style))
    story.append(Paragraph("• Tap <b>Convert to PDF</b> to save and share.", bullet_style))
    story.append(Spacer(1, 10))

    # SECTION 5: EDITING & WHITEOUT
    story.append(Paragraph("5. Editing Text & Whiteout (Cover-up)", h1_style))
    story.append(Paragraph("Fix text or hide sensitive numbers in any existing PDF document:", body_style))
    story.append(Paragraph("• <b>Replace Words:</b> Type the word to find and the replacement word to fix typos cleanly.", bullet_style))
    story.append(Paragraph("• <b>Whiteout Tool:</b> Draw a clean white box over private details (like account numbers or phone numbers) to hide them.", bullet_style))
    story.append(Paragraph("• <b>Draw Signature:</b> Use your finger or mouse to draw a handwritten ink signature and place it on the dotted line.", bullet_style))
    story.append(Paragraph("• <b>Watermark:</b> Add text watermarks like <i>CONFIDENTIAL</i> or <i>COPY</i> across pages.", bullet_style))
    story.append(Spacer(1, 10))

    # SECTION 6: MERGE & SPLIT PAGES
    story.append(Paragraph("6. Combining & Splitting Pages", h1_style))
    story.append(Paragraph("• <b>Combine PDFs:</b> Select 2 or more PDF files to join them into one single clean file.", bullet_style))
    story.append(Paragraph("• <b>Split Pages:</b> Enter page numbers (e.g. <i>1-3, 5</i>) to extract only the specific pages you need.", bullet_style))
    story.append(Spacer(1, 10))

    # SECTION 7: PASSWORDS & SECURITY
    story.append(Paragraph("7. Lock & Unlock Passwords", h1_style))
    story.append(Paragraph("• <b>Lock with Password:</b> Add AES-256 password protection to keep sensitive financial or legal files private.", bullet_style))
    story.append(Paragraph("• <b>Unlock Protected Files:</b> Type the existing password once to permanently remove password lock from statements.", bullet_style))
    story.append(Spacer(1, 10))

    # SECTION 8: QUICK REFERENCE TABLE
    story.append(Paragraph("8. Quick Tools Summary", h1_style))
    table_data = [
        [Paragraph("<b>Tool</b>", h2_style), Paragraph("<b>What it does</b>", h2_style), Paragraph("<b>Common Use Case</b>", h2_style)],
        [Paragraph("<b>PDF Viewer</b>", body_style), Paragraph("Fast viewing with infinite zoom & rotate", body_style), Paragraph("Reading receipts, bills, eBooks", body_style)],
        [Paragraph("<b>Verify Signatures</b>", body_style), Paragraph("Turns yellow ? into green ✔ tick mark", body_style), Paragraph("Aadhaar cards, PAN cards, invoices", body_style)],
        [Paragraph("<b>Sign Digitally</b>", body_style), Paragraph("Places official Acrobat certificate stamp", body_style), Paragraph("Signing letters, contracts, forms", body_style)],
        [Paragraph("<b>Images to PDF</b>", body_style), Paragraph("Scans & enhances photos to PDF", body_style), Paragraph("Notes, bills, ID proofs, receipts", body_style)],
        [Paragraph("<b>Edit in Studio</b>", body_style), Paragraph("Whiteout, draw signature, fix text", body_style), Paragraph("Hiding sensitive data, signing forms", body_style)],
        [Paragraph("<b>Manage Pages</b>", body_style), Paragraph("Merge multiple files or split pages", body_style), Paragraph("Combining bank statements, reports", body_style)],
        [Paragraph("<b>Lock & Protect</b>", body_style), Paragraph("Set or remove AES-256 passwords", body_style), Paragraph("Securing confidential files", body_style)]
    ]
    summary_table = Table(table_data, colWidths=[110, 210, 180])
    summary_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#F1F5F9")),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E1")),
    ]))
    story.append(summary_table)
    story.append(Spacer(1, 14))

    # SECTION 9: PRIVACY PROMISE
    story.append(Paragraph("9. Privacy & Safety Guarantee", h1_style))
    privacy_text = """<b>Your files never leave your device.</b><br/>
Zen PDF is designed with an offline-first architecture. It does not contain ads, tracking trackers, or telemetry. All password checking, digital signature verification, photo scanning, and PDF editing happen directly in your phone or PC memory."""
    privacy_box = Table([[Paragraph(privacy_text, tip_box_style)]], colWidths=[500])
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
    print(f"Documentation PDF created at: {output_filename}")

if __name__ == '__main__':
    create_documentation_pdf("Zen_PDF_User_Guide.pdf")
