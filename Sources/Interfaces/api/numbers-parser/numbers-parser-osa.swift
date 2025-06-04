import Foundation

public enum NumbersParserScript {
    case open
    case setInvoice
    case debug
    case debugCells
    case exportCSV
    case exportPDF
    case close
    case ghostty
    case responder
    case map
}

public func numbersParserOsaScript(_ type: NumbersParserScript,_ arguments: NumbersParserArguments) -> String {
    switch type {
        case .open:
            return """
            set numbersFilePath to POSIX file "\(arguments.src)" as alias

            tell application "Numbers"
                activate
                open numbersFilePath
            end tell
            """
        case .debug:
            return """
            tell application "Numbers"
                activate
                tell document 1
                    -- Debug: List all sheets
                    set sheetList to ""
                    repeat with i from 1 to count of sheets
                        set sheetList to sheetList & i & ": " & name of sheet i & "\\n"
                    end repeat
                    display dialog "Sheets:\\n" & sheetList
                    
                    -- Check if the requested sheet exists
                    if \(arguments.data.sheet) > (count of sheets) then
                        display dialog "Error: Sheet index \(arguments.data.sheet) is out of bounds."
                        return
                    end if
                    
                    tell sheet \(arguments.data.sheet)
                        -- Debug: List all tables in the sheet
                        set tableList to ""
                        repeat with i from 1 to count of tables
                            set tableList to tableList & i & ": " & name of table i & "\\n"
                        end repeat
                        display dialog "Tables in Sheet \(arguments.data.sheet):\\n" & tableList
                        
                        -- Verify if the requested table exists
                        set tableExists to false
                        repeat with i from 1 to count of tables
                            if name of table i is "\(arguments.data.table)" then
                                set tableExists to true
                            end if
                        end repeat
                        
                        if not tableExists then
                            display dialog "Error: Table '\(arguments.data.table)' not found in sheet \(arguments.data.sheet)."
                            return
                        end tell
                    end tell
                end tell
            end tell
            """
        case .debugCells:
            return """
            tell application "Numbers"
                activate
                tell document 1
                    tell sheet 12 -- Replace with actual sheet index if necessary
                        tell table "Invoice Selection" -- Replace with actual table name if necessary
                            set debugMsg to "Debugging Table: Invoice Selection\n"

                            try
                                set cell1 to value of cell 1 of row 1
                                set debugMsg to debugMsg & "Row 1, Column 1: " & cell1 & "\n"
                            on error
                                set debugMsg to debugMsg & "Row 1, Column 1: ERROR\n"
                            end try

                            try
                                set cell2 to value of cell 2 of row 1
                                set debugMsg to debugMsg & "Row 1, Column 2: " & cell2 & "\n"
                            on error
                                set debugMsg to debugMsg & "Row 1, Column 2: ERROR\n"
                            end try

                            display dialog debugMsg
                        end tell
                    end tell
                end tell
            end tell
            """
        case .setInvoice:
            return """
            tell application "Numbers"
                activate
                    tell document 1
                        tell sheet \(arguments.data.sheet)
                            tell table "\(arguments.data.table)"
                                set the value of cell \(arguments.data.column) of row \(arguments.data.row) to \(arguments.data.value)
                            end tell
                        end tell
                    end tell
            end tell
            """
        case .exportCSV:
            return """
            set exportFilePath to POSIX file "\(arguments.dst)"
            set exportPDFPath to POSIX file "\(arguments.inv)"

            tell application "Numbers"
                activate

                tell document 1
                    export to exportFilePath as CSV
                end tell
            end tell
            """
        case .exportPDF:
            return """
            set exportPDFPath to POSIX file "\(arguments.inv)"

            tell application "Numbers"
                activate

                tell document 1
                    export to exportPDFPath as PDF
                end tell
            end tell
            """
        case .ghostty:
            return """
            tell application "Ghostty"
                activate
            end tell
            """
        case .responder:
            return """
            tell application "Responder"
                activate
            end tell
            """
        case .close:
            return """
            tell application "Numbers"
                activate

                tell document 1
                    close
                end tell
            end tell
            """
        case .map:
            return """
            tell application "Numbers"
                activate
                tell document 1
                    set result to "Sheet and Table Overview:\n"
                    repeat with sheetIndex from 1 to count of sheets
                        set currentSheet to sheet sheetIndex
                        set sheetName to name of currentSheet
                        set result to result & "Sheet " & sheetIndex & ": " & sheetName & "\n"

                        repeat with tableIndex from 1 to count of tables of currentSheet
                            set currentTable to table tableIndex of currentSheet
                            set tableName to name of currentTable
                            set result to result & "  Table " & tableIndex & ": " & tableName & "\n"
                        end repeat
                    end repeat
                    display dialog result
                end tell
            end tell
            """
    }
}
