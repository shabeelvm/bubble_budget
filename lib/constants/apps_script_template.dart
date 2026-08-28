const String kAppsScriptCode = r'''
/**
 * Google Apps Script for Bubble Budget Sync
 * 
 * Instructions:
 * 1. Open a Google Sheet.
 * 2. Extensions > Apps Script.
 * 3. Paste this code and click 'Save'.
 * 4. Deploy > New Deployment > Web App.
 * 5. Set 'Who has access' to 'Anyone'.
 * 6. Copy the Web App URL and paste it into Bubble Budget Settings.
 */

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let sheet = ss.getSheetByName("Expenses");
    
    if (!sheet) {
      sheet = ss.insertSheet("Expenses");
      sheet.appendRow(["Timestamp", "Date", "Time", "Category", "Amount", "Note", "Month-Year"]);
      sheet.setFrozenRows(1);
    }

    if (data.type === 'ping') {
      return ContentService.createTextOutput(JSON.stringify({ "status": "success", "message": "pong" }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    const timestamp = new Date(data.timestamp);
    const date = Utilities.formatDate(timestamp, ss.getSpreadsheetTimeZone(), "yyyy-MM-dd");
    const time = Utilities.formatDate(timestamp, ss.getSpreadsheetTimeZone(), "HH:mm:ss");
    const monthYear = Utilities.formatDate(timestamp, ss.getSpreadsheetTimeZone(), "MMMM yyyy");

    sheet.appendRow([
      data.timestamp,
      date,
      time,
      data.category,
      data.amount,
      data.note || "",
      monthYear
    ]);

    return ContentService.createTextOutput(JSON.stringify({ "status": "success" }))
      .setMimeType(ContentService.MimeType.JSON);
      
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({ "status": "error", "error": err.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function doGet(e) {
  return ContentService.createTextOutput("Bubble Budget Webhook Active. Use POST to sync data.");
}
''';
