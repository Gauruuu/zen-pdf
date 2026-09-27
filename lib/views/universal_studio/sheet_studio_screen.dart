import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/utils/file_helper.dart';
import '../../models/universal_document_model.dart';
import '../../services/recent_files_service.dart';
import '../../services/xlsx_engine_service.dart';
import '../common/fidget_spinner_loader.dart';
import '../pdf_viewer/chrome_pdf_viewer_screen.dart';
import '../gdrm/gdrm_export_dialog.dart';
import 'package:flutter/services.dart';

class SheetStudioScreen extends StatefulWidget {
  final String? initialFilePath;
  final String? initialSheetTitle;
  final SheetTab? initialSheet;
  final bool isExternalIntent;

  const SheetStudioScreen({
    super.key,
    this.initialFilePath,
    this.initialSheetTitle,
    this.initialSheet,
    this.isExternalIntent = false,
  });

  @override
  State<SheetStudioScreen> createState() => _SheetStudioScreenState();
}

class _SheetStudioScreenState extends State<SheetStudioScreen> {
  late String _sheetTitle;
  late SheetTab _sheet;
  bool _isLoading = true;
  String? _filePath;

  String _selectedCoord = 'A1';
  final TextEditingController _formulaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sheetTitle = widget.initialSheetTitle ?? 'Workbook 1';
    _filePath = widget.initialFilePath;
    _initSheet();
  }

  @override
  void dispose() {
    _formulaController.dispose();
    super.dispose();
  }

  Future<void> _initSheet() async {
    setState(() => _isLoading = true);

    if (widget.initialSheet != null) {
      _sheet = widget.initialSheet!;
    } else if (_filePath != null && File(_filePath!).existsSync()) {
      final bytes = await File(_filePath!).readAsBytes();
      _sheet = XlsxEngineService.parseSpreadsheet(bytes, title: _sheetTitle);
      _sheetTitle = FileHelper.getFileName(_filePath!).replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    } else {
      // Create default starter sheet
      _sheet = SheetTab(title: 'Sheet1', rowCount: 30, colCount: 10);
      _sheet.setCell('A1', SheetCell(rawValue: 'Item', isBold: true));
      _sheet.setCell('B1', SheetCell(rawValue: 'Quantity', isBold: true));
      _sheet.setCell('C1', SheetCell(rawValue: 'Unit Price', isBold: true));
      _sheet.setCell('D1', SheetCell(rawValue: 'Total', isBold: true));

      _sheet.setCell('A2', SheetCell(rawValue: 'Laptops'));
      _sheet.setCell('B2', SheetCell(rawValue: '5'));
      _sheet.setCell('C2', SheetCell(rawValue: '1200'));
      _sheet.setCell('D2', SheetCell(rawValue: '=B2*C2'));

      _sheet.setCell('A3', SheetCell(rawValue: 'Monitors'));
      _sheet.setCell('B3', SheetCell(rawValue: '10'));
      _sheet.setCell('C3', SheetCell(rawValue: '300'));
      _sheet.setCell('D3', SheetCell(rawValue: '=B3*C3'));

      _sheet.setCell('A4', SheetCell(rawValue: 'Keyboards'));
      _sheet.setCell('B4', SheetCell(rawValue: '15'));
      _sheet.setCell('C4', SheetCell(rawValue: '50'));
      _sheet.setCell('D4', SheetCell(rawValue: '=B4*C4'));

      _sheet.setCell('A6', SheetCell(rawValue: 'Grand Total', isBold: true));
      _sheet.setCell('D6', SheetCell(rawValue: '=SUM(D2:D4)', isBold: true));

      XlsxEngineService.recalculateSheet(_sheet);
    }

    _updateFormulaBarForCoord(_selectedCoord);
    setState(() => _isLoading = false);
  }

  void _selectCell(String coord) {
    setState(() {
      _selectedCoord = coord;
      _updateFormulaBarForCoord(coord);
    });
  }

  void _updateFormulaBarForCoord(String coord) {
    final cell = _sheet.getCell(coord);
    _formulaController.text = cell.rawValue;
  }

  void _commitFormulaValue(String val) {
    final existing = _sheet.getCell(_selectedCoord);
    existing.rawValue = val;
    XlsxEngineService.recalculateSheet(_sheet);
    setState(() {});
  }

  void _insertQuickFormula(String func) {
    _formulaController.text = '=$func(';
    _formulaController.selection = TextSelection.fromPosition(
      TextPosition(offset: _formulaController.text.length),
    );
  }

  void _toggleCellBold() {
    final cell = _sheet.getCell(_selectedCoord);
    setState(() {
      cell.isBold = !cell.isBold;
      _sheet.setCell(_selectedCoord, cell);
    });
  }

  void _setCellAlignment(TextAlign align) {
    final cell = _sheet.getCell(_selectedCoord);
    setState(() {
      cell.alignment = align;
      _sheet.setCell(_selectedCoord, cell);
    });
  }

  void _addRow() {
    setState(() {
      _sheet.rowCount++;
    });
  }

  void _deleteRow() {
    if (_sheet.rowCount <= 2) return;
    setState(() {
      _sheet.rowCount--;
    });
  }

  void _addColumn() {
    setState(() {
      _sheet.colCount++;
    });
  }

  void _deleteColumn() {
    if (_sheet.colCount <= 2) return;
    setState(() {
      _sheet.colCount--;
    });
  }

  Future<void> _exportXlsx() async {
    try {
      final bytes = XlsxEngineService.exportToXlsx(_sheet);
      final cleanName = _sheetTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = await FileHelper.saveDocumentFile(
        bytes: bytes,
        fileName: '$cleanName.xlsx',
      );
      await RecentFilesService.addRecentFile(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved Excel file: ${FileHelper.getFileName(file.path)}'),
          backgroundColor: const Color(0xFF10B981),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => FileHelper.openFile(file.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save Excel: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportCsv() async {
    try {
      final csvText = XlsxEngineService.exportToCsv(_sheet);
      final cleanName = _sheetTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = await FileHelper.saveDocumentText(
        content: csvText,
        fileName: '$cleanName.csv',
      );
      await RecentFilesService.addRecentFile(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved CSV: ${FileHelper.getFileName(file.path)}'),
          backgroundColor: const Color(0xFF0D9488),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => FileHelper.openFile(file.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save CSV: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportPdf() async {
    try {
      final pdfBytes = await XlsxEngineService.exportToPdf(_sheet, title: _sheetTitle);
      final cleanName = _sheetTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = await FileHelper.savePdfFile(
        bytes: pdfBytes,
        fileName: '$cleanName.pdf',
      );
      await RecentFilesService.addRecentFile(file.path);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChromePdfViewerScreen(initialFilePath: file.path)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _shareSheet() async {
    try {
      final bytes = XlsxEngineService.exportToXlsx(_sheet);
      final cleanName = _sheetTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = await FileHelper.saveDocumentFile(
        bytes: bytes,
        fileName: '$cleanName.xlsx',
      );
      await FileHelper.shareFile(file.path, text: 'Sharing $_sheetTitle');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  Future<void> _exportGdrm() async {
    try {
      final pdfBytes = await XlsxEngineService.exportToPdf(_sheet, title: _sheetTitle);
      if (!mounted) return;
      GdrmExportDialog.show(
        context,
        pdfBytes: pdfBytes,
        defaultFileName: _sheetTitle,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to prepare GDRM: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: FidgetSpinnerLoader(message: 'Loading Spreadsheet...')),
      );
    }

    final activeCell = _sheet.getCell(_selectedCoord);

    return PopScope(
      canPop: !widget.isExternalIntent,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.isExternalIntent) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          titleSpacing: 0,
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () {
              if (widget.isExternalIntent) {
                SystemNavigator.pop();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.table_chart, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: _sheetTitle,
                  onChanged: (val) => _sheetTitle = val,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Workbook Title',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save, color: Color(0xFF10B981)),
              tooltip: 'Save as Excel (.xlsx)',
              onPressed: _exportXlsx,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              onSelected: (val) {
                if (val == 'gdrm') _exportGdrm();
                if (val == 'pdf') _exportPdf();
                if (val == 'csv') _exportCsv();
                if (val == 'share') _shareSheet();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'gdrm',
                  child: Row(
                    children: [
                      Icon(Icons.shield_moon_rounded, color: Color(0xFF06B6D4), size: 18),
                      SizedBox(width: 8),
                      Text('Export as .gdrm File'),
                    ],
                  ),
                ),
                PopupMenuItem(value: 'pdf', child: Text('Export PDF Table')),
                PopupMenuItem(value: 'csv', child: Text('Export CSV')),
                PopupMenuItem(value: 'share', child: Text('Share Workbook')),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            // Toolbar & Formula Bar
            _buildSpreadsheetRibbon(activeCell),

          // Formula Bar Row
          _buildFormulaBar(),

          // Interactive 2D Grid
          Expanded(
            child: _buildGridMatrix(),
          ),

          // Bottom Status & Sheet Tab Bar
          _buildBottomBar(),
        ],
      ),
    ),
  );
}

  Widget _buildSpreadsheetRibbon(SheetCell activeCell) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Formatting
            IconButton(
              icon: Icon(Icons.format_bold, color: activeCell.isBold ? const Color(0xFF10B981) : Colors.black87),
              tooltip: 'Bold',
              onPressed: _toggleCellBold,
            ),
            IconButton(
              icon: Icon(Icons.format_align_left, color: activeCell.alignment == TextAlign.left ? const Color(0xFF10B981) : Colors.black54),
              tooltip: 'Align Left',
              onPressed: () => _setCellAlignment(TextAlign.left),
            ),
            IconButton(
              icon: Icon(Icons.format_align_center, color: activeCell.alignment == TextAlign.center ? const Color(0xFF10B981) : Colors.black54),
              tooltip: 'Align Center',
              onPressed: () => _setCellAlignment(TextAlign.center),
            ),
            IconButton(
              icon: Icon(Icons.format_align_right, color: activeCell.alignment == TextAlign.right ? const Color(0xFF10B981) : Colors.black54),
              tooltip: 'Align Right',
              onPressed: () => _setCellAlignment(TextAlign.right),
            ),
            const VerticalDivider(width: 16, thickness: 1, color: Color(0xFFE2E8F0)),

            // Quick Formula buttons
            ActionChip(
              avatar: const Text('∑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              label: const Text('SUM'),
              onPressed: () => _insertQuickFormula('SUM'),
            ),
            const SizedBox(width: 6),
            ActionChip(
              label: const Text('AVERAGE'),
              onPressed: () => _insertQuickFormula('AVERAGE'),
            ),
            const SizedBox(width: 6),
            ActionChip(
              label: const Text('MIN'),
              onPressed: () => _insertQuickFormula('MIN'),
            ),
            const SizedBox(width: 6),
            ActionChip(
              label: const Text('MAX'),
              onPressed: () => _insertQuickFormula('MAX'),
            ),
            const VerticalDivider(width: 16, thickness: 1, color: Color(0xFFE2E8F0)),

            // Row / Column Operations
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('+ Row'),
              onPressed: _addRow,
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              icon: const Icon(Icons.remove, size: 14),
              label: const Text('- Row'),
              onPressed: _deleteRow,
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('+ Col'),
              onPressed: _addColumn,
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              icon: const Icon(Icons.remove, size: 14),
              label: const Text('- Col'),
              onPressed: _deleteColumn,
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulaBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Coordinate badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _selectedCoord,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
            ),
          ),
          const SizedBox(width: 8),
          const Text('fx', style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Colors.grey)),
          const SizedBox(width: 8),
          // Formula Input Field
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: TextField(
                controller: _formulaController,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.black87),
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'Enter value or formula e.g. =SUM(A1:A5) or =A1*B1',
                ),
                onSubmitted: _commitFormulaValue,
                onChanged: _commitFormulaValue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridMatrix() {
    const double colHeaderWidth = 44.0;
    const double colWidth = 90.0;
    const double rowHeight = 30.0;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Letters A, B, C...)
            Row(
              children: [
                // Top-left origin cell
                Container(
                  width: colHeaderWidth,
                  height: rowHeight,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    border: Border(
                      right: BorderSide(color: Color(0xFFCBD5E1)),
                      bottom: BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: const Icon(Icons.grid_on, size: 14, color: Colors.grey),
                ),
                ...List.generate(_sheet.colCount, (c) {
                  final letter = XlsxEngineService.colIndexToLetter(c);
                  return Container(
                    width: colWidth,
                    height: rowHeight,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      border: Border(
                        right: BorderSide(color: Color(0xFFCBD5E1)),
                        bottom: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Text(
                      letter,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)),
                    ),
                  );
                }),
              ],
            ),

            // Data Rows (1, 2, 3...)
            ...List.generate(_sheet.rowCount, (r) {
              final rowNum = r + 1;
              return Row(
                children: [
                  // Row Number Header
                  Container(
                    width: colHeaderWidth,
                    height: rowHeight,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      border: Border(
                        right: BorderSide(color: Color(0xFFCBD5E1)),
                        bottom: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Text(
                      '$rowNum',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),

                  // Row Cells
                  ...List.generate(_sheet.colCount, (c) {
                    final coord = '${XlsxEngineService.colIndexToLetter(c)}$rowNum';
                    final cell = _sheet.getCell(coord);
                    final isSelected = coord == _selectedCoord;

                    return GestureDetector(
                      onTap: () => _selectCell(coord),
                      onDoubleTap: () => _showCellEditorDialog(coord, cell),
                      child: Container(
                        width: colWidth,
                        height: rowHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFDCFCE7) : (cell.fillColor ?? Colors.white),
                          border: isSelected
                              ? Border.all(color: const Color(0xFF10B981), width: 2)
                              : const Border(
                                  right: BorderSide(color: Color(0xFFE2E8F0)),
                                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                        ),
                        child: Text(
                          cell.displayValue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: cell.alignment,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: cell.isBold ? FontWeight.bold : FontWeight.normal,
                            fontStyle: cell.isItalic ? FontStyle.italic : FontStyle.normal,
                            color: cell.textColor,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showCellEditorDialog(String coord, SheetCell cell) {
    final controller = TextEditingController(text: cell.rawValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Cell $coord'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Cell Value or Formula'),
          onSubmitted: (_) {
            _commitFormulaValue(controller.text);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _commitFormulaValue(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Text(
                  _sheet.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                ),
              ),
            ],
          ),
          Text(
            '${_sheet.rowCount} Rows × ${_sheet.colCount} Columns',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
