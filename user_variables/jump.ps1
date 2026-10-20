param (
    [Parameter(Mandatory=$true)]
    [int]$HowHigh = 5 # Default value if not provided
)
write-host "Jump $($HowHigh)"
