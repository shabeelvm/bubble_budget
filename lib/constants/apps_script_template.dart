const String kAppsScriptCode = r'''/**
 * Standalone Generator: Expenses Log + Dashboard with Donut Chart
 * Run setupBudgetSheet() once to build the structure and populate test data.
 */
function setupBudgetSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  
  // 1. SETUP "Expenses" TAB
  let expenseSheet = ss.getSheetByName("Expenses");
  if (!expenseSheet) {
    expenseSheet = ss.insertSheet("Expenses");
  }
  expenseSheet.clear();
  
  const headers = [["Date", "Category", "Amount", "Note", "MonthKey", "YearKey"]];
  expenseSheet.getRange("A1:F1").setValues(headers)
    .setBackground("#0F172A")
    .setFontColor("#FFFFFF")
    .setFontWeight("bold");

  expenseSheet.getRange("C2:C").setNumberFormat("$#,##0.00");
  expenseSheet.autoResizeColumns(1, 6);

  // 2. SETUP "Dashboard" TAB
  let dashSheet = ss.getSheetByName("Dashboard");
  if (!dashSheet) {
    dashSheet = ss.insertSheet("Dashboard");
  }
  dashSheet.clear();
  
  const existingCharts = dashSheet.getCharts();
  existingCharts.forEach(c => dashSheet.removeChart(c));

  dashSheet.getRange("A1").setValue("BUDGET & EXPENSES OVERVIEW")
    .setFontSize(14)
    .setFontWeight("bold")
    .setFontColor("#0F172A");

  // KPI Cards
  dashSheet.getRange("A3:B3").merge()
    .setValue("THIS MONTH (Current)")
    .setBackground("#F1F5F9")
    .setFontWeight("bold")
    .setFontSize(9)
    .setFontColor("#475569");
  dashSheet.getRange("A4:B4").merge()
    .setFormula('=SUMIFS(Expenses!C2:C, Expenses!E2:E, TEXT(TODAY(), "yyyy-mm"))')
    .setBackground("#F8FAFC")
    .setFontSize(16)
    .setFontWeight("bold")
    .setNumberFormat("$#,##0.00")
    .setHorizontalAlignment("center");

  dashSheet.getRange("A6:B6").merge()
    .setValue("THIS YEAR (Total)")
    .setBackground("#F1F5F9")
    .setFontWeight("bold")
    .setFontSize(9)
    .setFontColor("#475569");
  dashSheet.getRange("A7:B7").merge()
    .setFormula('=SUMIFS(Expenses!C2:C, Expenses!F2:F, YEAR(TODAY()))')
    .setBackground("#F8FAFC")
    .setFontSize(16)
    .setFontWeight("bold")
    .setNumberFormat("$#,##0.00")
    .setHorizontalAlignment("center");

  dashSheet.getRange("A9:B9").merge()
    .setValue("ALL-TIME SPEND")
    .setBackground("#F1F5F9")
    .setFontWeight("bold")
    .setFontSize(9)
    .setFontColor("#475569");
  dashSheet.getRange("A10:B10").merge()
    .setFormula('=SUM(Expenses!C2:C)')
    .setBackground("#F8FAFC")
    .setFontSize(16)
    .setFontWeight("bold")
    .setNumberFormat("$#,##0.00")
    .setHorizontalAlignment("center");

  // Category Breakdown Table
  dashSheet.getRange("A13").setValue("Category").setFontWeight("bold");
  dashSheet.getRange("B13").setValue("This Month").setFontWeight("bold").setHorizontalAlignment("right");
  dashSheet.getRange("C13").setValue("This Year").setFontWeight("bold").setHorizontalAlignment("right");
  dashSheet.getRange("A13:C13").setBackground("#E2E8F0");

  dashSheet.getRange("A14").setFormula(
    '=IFERROR(SORT(UNIQUE(FILTER(Expenses!B2:B, Expenses!B2:B<>""))), {"No Data"})'
  );
  dashSheet.getRange("B14").setFormula(
    '=MAP(A14:INDEX(A14:A, COUNTA(A14:A)), LAMBDA(cat, IF(cat="", "", SUMIFS(Expenses!C:C, Expenses!B:B, cat, Expenses!E:E, TEXT(TODAY(), "yyyy-mm")))))'
  );
  dashSheet.getRange("C14").setFormula(
    '=MAP(A14:INDEX(A14:A, COUNTA(A14:A)), LAMBDA(cat, IF(cat="", "", SUMIFS(Expenses!C:C, Expenses!B:B, cat, Expenses!F:F, YEAR(TODAY())))))'
  );
  dashSheet.getRange("B14:C30").setNumberFormat("$#,##0.00");

  // Donut Chart
  const chart = dashSheet.newChart()
    .setChartType(Charts.ChartType.PIE)
    .addRange(dashSheet.getRange("A13:B25"))
    .setPosition(3, 5, 10, 10)
    .setOption("title", "Spending by Category (This Month)")
    .setOption("titleTextStyle", { color: "#0F172A", fontSize: 13, bold: true })
    .setOption("pieHole", 0.5)
    .setOption("width", 480)
    .setOption("height", 320)
    .setOption("legend", { position: "right" })
    .build();

  dashSheet.insertChart(chart);

  dashSheet.setColumnWidth(1, 140);
  dashSheet.setColumnWidth(2, 110);
  dashSheet.setColumnWidth(3, 110);
  dashSheet.setColumnWidth(4, 30);

  ss.setActiveSheet(dashSheet);
  const defaultSheet = ss.getSheetByName("Sheet1");
  if (defaultSheet) ss.deleteSheet(defaultSheet);
}

function doPost(e) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let expenseSheet = ss.getSheetByName("Expenses");
    if (!expenseSheet) {
      setupBudgetSheet();
      expenseSheet = ss.getSheetByName("Expenses");
    }
    const data = JSON.parse(e.postData.contents);
    const date = data.date || new Date().toISOString().split('T')[0];
    const category = data.category || "Uncategorized";
    const amount = parseFloat(data.amount) || 0;
    const note = data.note || "";
    const monthKey = date.substring(0, 7);
    const yearKey = parseInt(date.substring(0, 4));

    expenseSheet.appendRow([date, category, amount, note, monthKey, yearKey]);
    return ContentService.createTextOutput(JSON.stringify({ status: "success" }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({ status: "error", message: err.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}''';

const String kGoogleSheetTemplateUrl = 'https://docs.google.com/spreadsheets/d/1Xl_g4tU2eW7m8pUfQYy6g5R_NfNf8mC87bU9eC1W8o/copy';
