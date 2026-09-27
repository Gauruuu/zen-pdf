import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';
import '../models/universal_document_model.dart';

class XlsxEngineService {
  /// Converts a column index (0-based) to Excel letters (0 -> 'A', 25 -> 'Z', 26 -> 'AA')
  static String colIndexToLetter(int index) {
    String result = '';
    int temp = index;
    while (temp >= 0) {
      result = String.fromCharCode(65 + (temp % 26)) + result;
      temp = (temp ~/ 26) - 1;
    }
    return result;
  }

  /// Converts Excel letter to 0-based column index ('A' -> 0, 'Z' -> 25, 'AA' -> 26)
  static int colLetterToIndex(String letter) {
    int sum = 0;
    for (int i = 0; i < letter.length; i++) {
      sum *= 26;
      sum += (letter.codeUnitAt(i) - 64);
    }
    return sum - 1;
  }

  /// Parses coordinate like "B5" into [colIndex, rowIndex] (0-based)
  static (int, int)? parseCoordinate(String coord) {
    final match = RegExp(r'^([A-Z]+)(\d+)$', caseSensitive: false).firstMatch(coord.trim().toUpperCase());
    if (match == null) return null;
    final colLetter = match.group(1)!;
    final rowNum = int.parse(match.group(2)!);
    return (colLetterToIndex(colLetter), rowNum - 1);
  }

  /// Expands a range like "A1:B3" to list of coordinates ["A1", "A2", "A3", "B1", "B2", "B3"]
  static List<String> expandRange(String range) {
    final parts = range.split(':');
    if (parts.length != 2) return [range.trim().toUpperCase()];
    final c1 = parseCoordinate(parts[0]);
    final c2 = parseCoordinate(parts[1]);
    if (c1 == null || c2 == null) return [range.trim().toUpperCase()];

    final minCol = c1.$1 < c2.$1 ? c1.$1 : c2.$1;
    final maxCol = c1.$1 > c2.$1 ? c1.$1 : c2.$1;
    final minRow = c1.$2 < c2.$2 ? c1.$2 : c2.$2;
    final maxRow = c1.$2 > c2.$2 ? c1.$2 : c2.$2;

    final List<String> coords = [];
    for (int col = minCol; col <= maxCol; col++) {
      final colLetter = colIndexToLetter(col);
      for (int row = minRow; row <= maxRow; row++) {
        coords.add('$colLetter${row + 1}');
      }
    }
    return coords;
  }

  /// Calculates the evaluated display value of a cell given the current sheet state
  static String evaluateCell(String raw, SheetTab sheet) {
    if (!raw.startsWith('=')) return raw;

    final formula = raw.substring(1).trim().toUpperCase();

    try {
      // Function: SUM(range or comma-separated)
      if (formula.startsWith('SUM(') && formula.endsWith(')')) {
        final inner = formula.substring(4, formula.length - 1);
        final values = _getNumericValues(inner, sheet);
        final sum = values.fold<double>(0.0, (prev, elem) => prev + elem);
        return _formatNumber(sum);
      }

      // Function: AVERAGE / AVG
      if ((formula.startsWith('AVERAGE(') || formula.startsWith('AVG(')) && formula.endsWith(')')) {
        final startIdx = formula.startsWith('AVERAGE(') ? 8 : 4;
        final inner = formula.substring(startIdx, formula.length - 1);
        final values = _getNumericValues(inner, sheet);
        if (values.isEmpty) return '0';
        final avg = values.fold<double>(0.0, (prev, elem) => prev + elem) / values.length;
        return _formatNumber(avg);
      }

      // Function: MIN
      if (formula.startsWith('MIN(') && formula.endsWith(')')) {
        final inner = formula.substring(4, formula.length - 1);
        final values = _getNumericValues(inner, sheet);
        if (values.isEmpty) return '0';
        final min = values.reduce((curr, next) => curr < next ? curr : next);
        return _formatNumber(min);
      }

      // Function: MAX
      if (formula.startsWith('MAX(') && formula.endsWith(')')) {
        final inner = formula.substring(4, formula.length - 1);
        final values = _getNumericValues(inner, sheet);
        if (values.isEmpty) return '0';
        final max = values.reduce((curr, next) => curr > next ? curr : next);
        return _formatNumber(max);
      }

      // Function: COUNT
      if (formula.startsWith('COUNT(') && formula.endsWith(')')) {
        final inner = formula.substring(6, formula.length - 1);
        final values = _getNumericValues(inner, sheet);
        return values.length.toString();
      }

      // Basic Arithmetic: e.g. A1+B2, A1*10, A1/2, A1-B1
      return _evaluateSimpleArithmetic(formula, sheet);
    } catch (_) {
      return '#ERROR!';
    }
  }

  static List<double> _getNumericValues(String inner, SheetTab sheet) {
    final tokens = inner.split(',');
    final List<double> values = [];

    for (final token in tokens) {
      final trimmed = token.trim();
      if (trimmed.contains(':')) {
        for (final coord in expandRange(trimmed)) {
          final cell = sheet.getCell(coord);
          final numVal = double.tryParse(cell.displayValue.replaceAll(',', ''));
          if (numVal != null) values.add(numVal);
        }
      } else {
        final cell = sheet.getCell(trimmed);
        final numVal = double.tryParse(cell.displayValue.replaceAll(',', ''));
        if (numVal != null) {
          values.add(numVal);
        } else {
          final directVal = double.tryParse(trimmed);
          if (directVal != null) values.add(directVal);
        }
      }
    }
    return values;
  }

  static String _evaluateSimpleArithmetic(String expr, SheetTab sheet) {
    // Replace cell references with numbers
    final replaced = expr.replaceAllMapped(RegExp(r'\b[A-Z]+\d+\b'), (match) {
      final coord = match.group(0)!;
      final cell = sheet.getCell(coord);
      final val = double.tryParse(cell.displayValue.replaceAll(',', '')) ?? 0.0;
      return val.toString();
    });

    // Simple 2-operand or sequential math
    if (replaced.contains('+')) {
      final parts = replaced.split('+');
      double sum = 0;
      for (final p in parts) {
        sum += double.tryParse(p.trim()) ?? 0;
      }
      return _formatNumber(sum);
    } else if (replaced.contains('*')) {
      final parts = replaced.split('*');
      double product = 1;
      for (final p in parts) {
        product *= double.tryParse(p.trim()) ?? 1;
      }
      return _formatNumber(product);
    } else if (replaced.contains('-')) {
      final parts = replaced.split('-');
      if (parts.length == 2) {
        final v1 = double.tryParse(parts[0].trim()) ?? 0;
        final v2 = double.tryParse(parts[1].trim()) ?? 0;
        return _formatNumber(v1 - v2);
      }
    } else if (replaced.contains('/')) {
      final parts = replaced.split('/');
      if (parts.length == 2) {
        final v1 = double.tryParse(parts[0].trim()) ?? 0;
        final v2 = double.tryParse(parts[1].trim()) ?? 1;
        if (v2 == 0) return '#DIV/0!';
        return _formatNumber(v1 / v2);
      }
    }

    final singleNum = double.tryParse(replaced);
    if (singleNum != null) return _formatNumber(singleNum);

    return expr;
  }

  static String _formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  /// Recalculates all formulas across the entire sheet
  static void recalculateSheet(SheetTab sheet) {
    for (int pass = 0; pass < 2; pass++) {
      for (final entry in sheet.cells.entries) {
        if (entry.value.rawValue.startsWith('=')) {
          entry.value.displayValue = evaluateCell(entry.value.rawValue, sheet);
        } else {
          entry.value.displayValue = entry.value.rawValue;
        }
      }
    }
  }

  /// Parses bytes from an .xlsx or .csv file into a SheetTab
  static SheetTab parseSpreadsheet(Uint8List bytes, {String title = 'Sheet1'}) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
      final sheetFile = archive.findFile('xl/worksheets/sheet1.xml') ??
          archive.files.firstWhere((f) => f.name.startsWith('xl/worksheets/sheet'), orElse: () => archive.files.first);

      List<String> sharedStrings = [];
      if (sharedStringsFile != null) {
        final ssXml = utf8.decode(sharedStringsFile.content as List<int>, allowMalformed: true);
        final doc = XmlDocument.parse(ssXml);
        for (final si in doc.findAllElements('si')) {
          final tElements = si.findAllElements('t');
          sharedStrings.add(tElements.map((t) => t.innerText).join());
        }
      }

      final sheetXml = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);
      final doc = XmlDocument.parse(sheetXml);
      final cElements = doc.findAllElements('c');

      final sheet = SheetTab(title: title, rowCount: 40, colCount: 15);

      for (final c in cElements) {
        final r = c.getAttribute('r'); // e.g. "A1"
        if (r == null) continue;
        final t = c.getAttribute('t'); // 's' for shared string
        final vElem = c.findAllElements('v').firstOrNull;
        final fElem = c.findAllElements('f').firstOrNull;

        String raw = '';
        if (fElem != null) {
          raw = '=${fElem.innerText}';
        } else if (vElem != null) {
          final val = vElem.innerText;
          if (t == 's') {
            final sIdx = int.tryParse(val) ?? -1;
            if (sIdx >= 0 && sIdx < sharedStrings.length) {
              raw = sharedStrings[sIdx];
            } else {
              raw = val;
            }
          } else {
            raw = val;
          }
        }

        final cell = SheetCell(rawValue: raw, displayValue: raw);
        sheet.setCell(r.toUpperCase(), cell);
      }

      recalculateSheet(sheet);
      return sheet;
    } catch (_) {
      // Fallback CSV parsing
      return parseCsv(utf8.decode(bytes, allowMalformed: true), title: title);
    }
  }

  /// Parses CSV string into SheetTab
  static SheetTab parseCsv(String csvText, {String title = 'Sheet1'}) {
    final lines = csvText.split('\n');
    final sheet = SheetTab(title: title, rowCount: lines.length < 30 ? 30 : lines.length + 5, colCount: 12);

    for (int r = 0; r < lines.length; r++) {
      final line = lines[r].trimRight();
      if (line.isEmpty) continue;
      final cols = _splitCsvLine(line);
      for (int c = 0; c < cols.length; c++) {
        final coord = '${colIndexToLetter(c)}${r + 1}';
        final val = cols[c];
        sheet.setCell(coord, SheetCell(rawValue: val, displayValue: val));
      }
    }

    recalculateSheet(sheet);
    return sheet;
  }

  static List<String> _splitCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  /// Exports SheetTab to CSV string
  static String exportToCsv(SheetTab sheet) {
    final buffer = StringBuffer();
    for (int r = 0; r < sheet.rowCount; r++) {
      final List<String> rowVals = [];
      bool hasData = false;
      for (int c = 0; c < sheet.colCount; c++) {
        final coord = '${colIndexToLetter(c)}${r + 1}';
        final cell = sheet.getCell(coord);
        var val = cell.displayValue;
        if (val.isNotEmpty) hasData = true;
        if (val.contains(',') || val.contains('"') || val.contains('\n')) {
          val = '"${val.replaceAll('"', '""')}"';
        }
        rowVals.add(val);
      }
      if (hasData || r < 10) {
        buffer.writeln(rowVals.join(','));
      }
    }
    return buffer.toString();
  }

  /// Exports SheetTab to valid Microsoft Excel (.xlsx) Zip Archive
  static Uint8List exportToXlsx(SheetTab sheet) {
    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    final rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsXml.length, utf8.encode(rootRelsXml)));

    // 3. xl/workbook.xml
    final workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="${sheet.title}" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
    archive.addFile(ArchiveFile('xl/workbook.xml', workbookXml.length, utf8.encode(workbookXml)));

    // 4. xl/_rels/workbook.xml.rels
    final wbRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('xl/_rels/workbook.xml.rels', wbRelsXml.length, utf8.encode(wbRelsXml)));

    // 5. xl/worksheets/sheet1.xml
    final sheetBuffer = StringBuffer();
    sheetBuffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    sheetBuffer.write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\n');
    sheetBuffer.write('  <sheetData>\n');

    for (int r = 0; r < sheet.rowCount; r++) {
      final rowNum = r + 1;
      final List<String> cellXmlList = [];

      for (int c = 0; c < sheet.colCount; c++) {
        final coord = '${colIndexToLetter(c)}$rowNum';
        final cell = sheet.getCell(coord);
        if (cell.rawValue.isEmpty && cell.displayValue.isEmpty) continue;

        final isFormula = cell.rawValue.startsWith('=');
        final escapedRaw = cell.rawValue
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        final escapedDisplay = cell.displayValue
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');

        if (isFormula) {
          final formulaText = escapedRaw.substring(1);
          cellXmlList.add('      <c r="$coord"><f>$formulaText</f><v>$escapedDisplay</v></c>');
        } else {
          final isNumber = double.tryParse(cell.displayValue) != null;
          if (isNumber) {
            cellXmlList.add('      <c r="$coord"><v>$escapedDisplay</v></c>');
          } else {
            cellXmlList.add('      <c r="$coord" t="inlineStr"><is><t>$escapedDisplay</t></is></c>');
          }
        }
      }

      if (cellXmlList.isNotEmpty) {
        sheetBuffer.write('    <row r="$rowNum">\n');
        for (final cx in cellXmlList) {
          sheetBuffer.write('$cx\n');
        }
        sheetBuffer.write('    </row>\n');
      }
    }

    sheetBuffer.write('  </sheetData>\n');
    sheetBuffer.write('</worksheet>');

    final sheetXml = sheetBuffer.toString();
    archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));

    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData);
  }

  /// Exports spreadsheet to PDF table report
  static Future<Uint8List> exportToPdf(SheetTab sheet, {String title = 'Spreadsheet'}) async {
    final pdf = pw.Document(title: title);

    // Find max active row and col
    int maxR = 10;
    int maxC = 5;
    for (int r = 0; r < sheet.rowCount; r++) {
      for (int c = 0; c < sheet.colCount; c++) {
        final cell = sheet.getCell('${colIndexToLetter(c)}${r + 1}');
        if (cell.displayValue.isNotEmpty) {
          if (r + 1 > maxR) maxR = r + 1;
          if (c + 1 > maxC) maxC = c + 1;
        }
      }
    }

    // Build Table Rows
    final List<List<String>> tableData = [];

    // Header row (Col letters)
    final List<String> headerRow = ['#'];
    for (int c = 0; c < maxC; c++) {
      headerRow.add(colIndexToLetter(c));
    }
    tableData.add(headerRow);

    // Data rows
    for (int r = 0; r < maxR; r++) {
      final List<String> row = ['${r + 1}'];
      for (int c = 0; c < maxC; c++) {
        final coord = '${colIndexToLetter(c)}${r + 1}';
        row.add(sheet.getCell(coord).displayValue);
      }
      tableData.add(row);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                ),
                pw.Text(
                  'Generated by Zen PDF Studio',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            context: context,
            data: tableData,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
