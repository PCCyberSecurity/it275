# Define the Excel file path
$excelPath = "userlist.xlsx"

# Open Excel and read the file
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$workbook = $excel.Workbooks.Open($excelPath)
# Grab the first worksheet (assuming the user data is there)
$sheet = $workbook.Sheets.Item(1)

# Start from row 2 (assuming row 1 has headers)
$row = 2

while ($true) {
    # Assuming column A has the username, column B has the password, and column C has the full name
    $username = $sheet.Cells.Item($row, 1).Text
    $password = $sheet.Cells.Item($row, 2).Text
    $fullname = $sheet.Cells.Item($row, 3).Text

    # Exit loop if username is empty - assuming we are out of rows
    if ([string]::IsNullOrWhiteSpace($username)) { break }

    # Check if user already exists
    if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
        Write-Host "User '$username' already exists. Skipping..."
    } else {
        # Create secure password
        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

        # Create local user
        New-LocalUser -Name $username -Password $securePassword -FullName $fullname -Description "Created from Excel script"

        # Optionally add to 'Users' group
        Add-LocalGroupMember -Group "Users" -Member $username

        Write-Host "Created user: $username"
    }

    # Add 1 to the row counter so we grab the next row when we loop again
    $row++

}

# Cleanup - close the workbook and quit excel so that the process exits and doesn't keep running in the background
$workbook.Close($false)
$excel.Quit()

# Release COM objects to free up resources - COM is Component Object Model
# COM is what Excel and other Microsoft applications use to allow external programs
# (like our PowerShell script) to interact with them
# If we don't release these objects, we can end up with "ghost" Excel processes
# running in the background that consume resources and can cause issues if we try to run the script again.
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($sheet) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null


Write-Host "User creation process completed."
