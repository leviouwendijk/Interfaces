// import Foundation
// import AppKit
// import Quartz

// func createIncomeStatementPDF(viewModel: TrialBalanceViewModel, filename: String, exportDirectory: URL) {
//     let pdfFilePath = exportDirectory.appendingPathComponent("\(filename).pdf")
//     var pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)  // Standard US Letter

//     let margin: CGFloat = 40
// //    let contentWidth = pageBounds.width - 2 * margin
    
//     let dividerHeight: CGFloat = 1
//     let dividerColor = NSColor.gray.cgColor
    
//     guard let pdfContext = CGContext(pdfFilePath as CFURL, mediaBox: &pageBounds, nil) else {
//         print("Failed to create PDF context")
//         return
//     }

//     pdfContext.beginPDFPage(nil)
//     let titleAttributes: [NSAttributedString.Key: Any] = [
//         .font: NSFont.boldSystemFont(ofSize: 12),
//         .foregroundColor: NSColor.black
//     ]
    
//     let notBoldTitleAttributes: [NSAttributedString.Key: Any] = [
//         .font: NSFont.systemFont(ofSize: 12),
//         .foregroundColor: NSColor.black
//     ]
    
//     let textAttributes: [NSAttributedString.Key: Any] = [
//         .font: NSFont.systemFont(ofSize: 8),
//         .foregroundColor: NSColor.black
//     ]
    
//     let boldTextAttributes: [NSAttributedString.Key: Any] = [
//         .font: NSFont.boldSystemFont(ofSize: 8),
//         .foregroundColor: NSColor.black
//     ]
    
//     let italicTextAttributes: [NSAttributedString.Key: Any] = [
//         .font: NSFontManager.shared.convert(NSFont.systemFont(ofSize: 8), toHaveTrait: .italicFontMask),
//         .foregroundColor: NSColor.black
//     ]
    
//     // Draw the title and metadata
//     drawText("COUNTER", at: CGPoint(x: 80, y: 700), attributes: notBoldTitleAttributes, in: pdfContext)
//     print("Drew title")
    
//     drawText("Income Statement", at: CGPoint(x: (3 * 80), y: 700), attributes: titleAttributes, in: pdfContext)
//     print("Drew type of report")
    
//     drawText(viewModel.period.periodDescription, at: CGPoint(x: 530, y: 700), attributes: notBoldTitleAttributes, rightAligned: true, in: pdfContext)
//     print("Drew description of report")
    
//     let formattedStartDate = simplifiedDateFormatter.string(from: viewModel.period.periodStartDate)
//     let formattedEndDate = simplifiedDateFormatter.string(from: viewModel.period.periodEndDate)
//     let formattedDateRange = "\(formattedStartDate) to \(formattedEndDate)"
    
//     drawText("\(formattedDateRange)", at: CGPoint(x: 80, y: 650), attributes: textAttributes, in: pdfContext)
//     print("Drew date range")
    
//     drawText("De Hondenmeesters", at: CGPoint(x: 530, y: 650), attributes: boldTextAttributes, rightAligned: true, in: pdfContext)
//     print("Drew name of company")
    
//     drawText("86854992", at: CGPoint(x: 530, y: 650 - ( 1 * 18) ), attributes: textAttributes, rightAligned: true, in: pdfContext)
//     print("Drew kvk number of company")
    
//     drawText("by Ouwendijk, L.C.", at: CGPoint(x: 530, y: 650 - ( 2 * 18) ), attributes: italicTextAttributes, rightAligned: true, in: pdfContext)
//     print("Drew author of report")
    

//     var yOffset: CGFloat = 580
//     let lineHeight: CGFloat = 18
//     let additionalPadding: CGFloat = 40  // Add extra padding to ensure there's space at the bottom
//     let entryHeight = 6 * lineHeight + dividerHeight + 10 + 10  // Adjust this based on the number of lines and spacing
    
//     drawDivider(at: CGPoint(x: 80, y: yOffset), width: pageBounds.width - (80 * 2), color: dividerColor, in: pdfContext)
//     yOffset -= dividerHeight + 10

//     if let value = viewModel.standardIncomeStatementResults["Revenue"] {
//         drawText("Revenue", at: CGPoint(x: 80, y: yOffset), attributes: textAttributes, in: pdfContext)
//         drawText(formatAmount(value), at: CGPoint(x: 530 , y: yOffset), attributes: textAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight  // Move down the page
//     }
    
//     if let value = viewModel.standardIncomeStatementResults["Cost of Revenue"] {
//         drawText("Cost of Revenue", at: CGPoint(x: 80, y: yOffset), attributes: textAttributes, in: pdfContext)
//         drawText(formatAmount(value), at: CGPoint(x: 530, y: yOffset), attributes: textAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight
//     }
    
//     if let value = viewModel.standardIncomeStatementResults["Gross Profit (Loss)"] {
//         drawText("Gross Profit (Loss)", at: CGPoint(x: 100, y: yOffset), attributes: italicTextAttributes, in: pdfContext)
//         drawText(formatAmount(value), at: CGPoint(x: 530, y: yOffset), attributes: italicTextAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight  // Move down the page
//     }
    
//     yOffset -= lineHeight
    
//     if let value = viewModel.standardIncomeStatementResults["Overhead Expenses"] {
//         drawText("Overhead Expenses", at: CGPoint(x: 80, y: yOffset), attributes: textAttributes, in: pdfContext)
//         drawText(formatAmount(value), at: CGPoint(x: 530, y: yOffset), attributes: textAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight
//     }
    
//     if let value = viewModel.standardIncomeStatementResults["Operating Profit (Loss)"] {
//         drawText("Operating Profit (Loss)", at: CGPoint(x: 100, y: yOffset), attributes: italicTextAttributes, in: pdfContext)
//         drawText(formatAmount(value), at: CGPoint(x: 530, y: yOffset), attributes: italicTextAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight  // Move down the page
//     }
    
//     yOffset -= lineHeight
    
//     if let value = viewModel.standardIncomeStatementResults["Interest Expense"] {
//         drawText("Interest Expense", at: CGPoint(x: 80, y: yOffset), attributes: textAttributes, in: pdfContext)
//         drawText(formatAmount(value), at: CGPoint(x: 530, y: yOffset), attributes: textAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight
//     }
    
//     if let value = viewModel.standardIncomeStatementResults["Tax Expense"] {
//         drawText("Tax Expense", at: CGPoint(x: 80, y: yOffset), attributes: textAttributes, in: pdfContext)
//         drawText(formatAmount(value), at: CGPoint(x: 530, y: yOffset), attributes: textAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight  // Move down the page
//     }
    
//     if let value = viewModel.standardIncomeStatementResults["Depreciation and Amortization"] {
//         drawText("Depreciation and Amortization", at: CGPoint(x: 80, y: yOffset), attributes: textAttributes, in: pdfContext)
//         drawText(formatAmount(value), at: CGPoint(x: 530, y: yOffset), attributes: textAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight
//     }
    
//     if let value = viewModel.standardIncomeStatementResults["Other Income (Expense)"] {
//         drawText("Other Income (Expense)", at: CGPoint(x: 80, y: yOffset), attributes: textAttributes, in: pdfContext)
//         drawText(formatAmount(value), at: CGPoint(x: 530, y: yOffset), attributes: textAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight  // Move down the page
//     }
    
    
//     if let value = viewModel.standardIncomeStatementResults["Net Profit (Loss)"] {
//         drawText("Net Profit (Loss)", at: CGPoint(x: 100, y: yOffset), attributes: boldTextAttributes, in: pdfContext)
//         drawText(formatAmount(value), at: CGPoint(x: 530, y: yOffset), attributes: boldTextAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight
//     }
    
//     drawDivider(at: CGPoint(x: 80, y: yOffset), width: pageBounds.width - (80 * 2), color: dividerColor, in: pdfContext)
//     yOffset -= dividerHeight + 10
    
//     yOffset -= additionalPadding
    
//     drawDivider(at: CGPoint(x: 80, y: yOffset), width: pageBounds.width - (80 * 2), color: dividerColor, in: pdfContext)
//     yOffset -= dividerHeight + 10
    
//     if let value = viewModel.standardIncomeRatios["Gross Profit Margin"] {
//         drawText("Gross Profit Margin", at: CGPoint(x: 80, y: yOffset), attributes: textAttributes, in: pdfContext)
//         drawText(formatPercentage(value), at: CGPoint(x: 530 , y: yOffset), attributes: textAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight  // Move down the page
//     }
    
//     if let value = viewModel.standardIncomeRatios["Operating Profit Margin"] {
//         drawText("Operating Profit Margin", at: CGPoint(x: 80, y: yOffset), attributes: textAttributes, in: pdfContext)
//         drawText(formatPercentage(value), at: CGPoint(x: 530 , y: yOffset), attributes: textAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight  // Move down the page
//     }
    
//     if let value = viewModel.standardIncomeRatios["Net Profit Margin"] {
//         drawText("Net Profit Margin", at: CGPoint(x: 80, y: yOffset), attributes: textAttributes, in: pdfContext)
//         drawText(formatPercentage(value), at: CGPoint(x: 530 , y: yOffset), attributes: textAttributes, rightAligned: true, in: pdfContext)
//         yOffset -= lineHeight  // Move down the page
//     }
    
//     drawDivider(at: CGPoint(x: 80, y: yOffset), width: pageBounds.width - (80 * 2), color: dividerColor, in: pdfContext)
//     yOffset -= dividerHeight + 10
    
//     pdfContext.endPDFPage()
//     pdfContext.closePDF()
//     print("PDF created at \(pdfFilePath)")
// }

// private func getExportDirectory() -> URL {
//     let userDefaults = UserDefaults.standard
//     if let savedPath = userDefaults.url(forKey: "transactionsDirectory") {
//         return savedPath
//     } else {
//         let openPanel = NSOpenPanel()
//         openPanel.canChooseDirectories = true
//         openPanel.canCreateDirectories = true
//         openPanel.allowsMultipleSelection = false
//         openPanel.prompt = "Select Export Directory"
        
//         if openPanel.runModal() == .OK, let url = openPanel.url {
//             userDefaults.set(url, forKey: "transactionsDirectory")
//             return url
//         }
        
//         // Default to documents directory if no selection is made
//         return getDocumentsDirectory()
//     }
// }

// private func getDocumentsDirectory() -> URL {
//     FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
// }


// func exportIncomeStatement(viewModel: TrialBalanceViewModel) {
//     let dateFormatter = DateFormatter()
//     dateFormatter.dateStyle = .short
//     dateFormatter.timeStyle = .none
//     dateFormatter.locale = Locale(identifier: "en_US")
//     let formattedDate = dateFormatter.string(from: Date()).replacingOccurrences(of: "/", with: "-")
//     let dateLabel = viewModel.period.periodDescription
//     let defaultFilename = "Income_Statement_\(dateLabel)"
//     let exportDirectory = getDocumentsDirectory() // Make sure this function returns the correct directory
//     createIncomeStatementPDF(viewModel: viewModel, filename: defaultFilename, exportDirectory: exportDirectory)
// }

