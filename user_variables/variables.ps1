param (
    [Parameter()]
    [string]$import_file_name = "users.xlsx"
)

#write-host $PSScriptRoot
#write-host (Get-Location).Path

class Student {
    $name = ""
    $full_name = ""
    $age = 0
    $email = ""
    $password = ""
    $group1 = ""
    $group2 = ""

    [string]ToString(){
        return "Name: $($this.name), Age: $($this.age), Email: $($this.email)"
    }

    CreateWindowsUser() {
        # Check if user already exists
        if (Get-LocalUser -Name $this.name -ErrorAction SilentlyContinue) {
            Write-Host "User $($this.name) already exists."
            return
        }
        $pw = ConvertTo-SecureString -String "SuperEasyPassword" -AsPlainText -Force
        New-LocalUser -Name $this.name -fullname $this.full_name -Password $pw -AccountNeverExpires -Description "Student user account"
    }
    RemoveWindowsUser() {
        Remove-LocalUser -Name $this.name
    }
    DisableWindowsUser() {
        Disable-LocalUser -Name $this.name
    }

    AddUserToWindowsGroup([string]$groupName) {
        # Create group if it doesn't exist
        if (-not (Get-LocalGroup -Name $groupName -ErrorAction SilentlyContinue)) {
            New-LocalGroup -Name $groupName -Description "Group for $groupName"
        }
        # Check if user is already in the group
        if (Get-LocalGroupMember -Group $groupName -Member $this.name -ErrorAction SilentlyContinue) {
            Write-Host "User $($this.name) is already a member of group $groupName."
            return
        }
        Add-LocalGroupMember -Group $groupName -Member $this.name
    }
}

# List of students
$students = @()

# Create bob
# $bob = [Student]::new()
# # Add bob to the list of students
# $students += $bob
# $bob.name = "bob"
# $bob.age = 30
# $bob.email = "bob@smith.com"


# Open an excel file with the list of students
$excelFilePath = [System.IO.Path]::GetFullPath($import_file_name)
#  "C:\Users\RPulsipher\OneDrive - pencol.edu\Desktop\git_projects\pc\it275\user_variables\users.xlsx"

$excel = New-Object -ComObject Excel.Application
$workbook = $excel.Workbooks.Open($excelFilePath)
$worksheet = $workbook.Sheets.Item(1)
$row = 2
while ($worksheet.Cells.Item($row, 1).Value() -ne $null) {
    $student = [Student]::new()
    $student.name = $worksheet.Cells.Item($row, 1).Value()
    $student.full_name = $worksheet.Cells.Item($row, 2).Value()
    $student.password = $worksheet.Cells.Item($row, 3).Value()
    $student.group1 = $worksheet.Cells.Item($row, 4).Value()
    $student.group2 = $worksheet.Cells.Item($row, 5).Value()
    $student.age = $worksheet.Cells.Item($row, 6).Value()
    $student.email = $worksheet.Cells.Item($row, 7).Value()
    $students += $student
    $row++
}
$workbook.Close($false)
$excel.Quit()



# Loop through students and display info and create Windows user accounts
foreach ($student in $students) {
    Write-Host $student.ToString()
    $student.CreateWindowsUser()
    Write-Host "Created Windows user for $($student.name)"
    # Add to windows group "Students"
    #$student.AddUserToWindowsGroup("Students")
    #Write-Host "Added $($student.name) to Windows group 'Students'"
    # If student has a group1, add to that group
    if ($student.group1) {
        $student.AddUserToWindowsGroup($student.group1)
        Write-Host "Added $($student.name) to Windows group '$($student.group1)'"
    }
    # If student has a group2, add to that group
    if ($student.group2) {
        $student.AddUserToWindowsGroup($student.group2)
        Write-Host "Added $($student.name) to Windows group '$($student.group2)'"
    }
}

#Write-Host "Loaded students: " $students

