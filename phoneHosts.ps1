# Define  URLs and filenames
$url1 = "https://raw.githubusercontent.com/badmojr/1Hosts/master/Lite/hosts.txt"
$url2 = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
$file1 = "hosts_1_badmojr.txt"
$file2 = "hosts_2_StevenBlack.txt"
$outputFile = "combined_hosts.txt"

# Check if hosts 1 origin exists and delete it if it does
if (Test-Path $file1) {
	Write-Host "$file1 exists, deleting."
    Remove-Item $file1
}

# Check if hosts 2 origin exists and delete it if it does
if (Test-Path $file2) {
	Write-Host "$file2 exists, deleting."
    Remove-Item $file2
}

# Create a new WebClient object
$client = New-Object System.Net.WebClient

# Update status to console
Write-Host "Downloading hosts ..."

# Download the first file and save it to the specified filename
$client.DownloadFile($url1, $file1)

# Download the second file and save it to the specified filename
$client.DownloadFile($url2, $file2)

# Output a message indicating that the downloads are complete
Write-Host "Hosts download complete."

# Check if the output file exists and delete it if it does
if (Test-Path $outputFile) {
	Write-Host "$outputFile exists, deleting."
    Remove-Item $outputFile
}

# Update status to console
Write-Host "Combining $file1 and $file2 ..."

# Read the contents of both files
$content1 = Get-Content $file1
$content2 = Get-Content $file2

# Combine the contents of both files
$combinedContent = $content1 + $content2

# Write the combined contents to a new file
$combinedContent | Set-Content $outputFile

# Output confirmation to console
Write-Host "Contents of $file1 and $file2 have been combined and saved to $outputFile."

# Read the contents of the file into the $content variable
$content = Get-Content $outputFile

# Update status to console
Write-Host "Removing all commented lines ..."

# Remove all lines that start with #
$content = $content | Where-Object { $_ -notmatch '^\s*#' }

# Write the filtered contents back to the file
$content | Set-Content $outputFile

# Output status to console
Write-Host "Removed all commented lines from $outputFile."

# Update status to console
Write-Host "Allowing hosts entries ..."

# Allow entries
$content = Get-Content -Path $outputFile
$totalLines = $content.Count
$progressBar1 = [System.Console]::WriteLine("Completion: [                    ]")
$content = $content | ForEach-Object -Begin { $counter = 0 } -Process {
    $counter++
    $percentage = [int](($counter / $totalLines) * 100)
    $barLength = [int](($percentage / 2))
    $progressBarText = ("#" * $barLength).PadRight(50)
    $progressBarText = $progressBarText.Insert($barLength, "|")
    $progressBarText = $progressBarText.Insert(0, "|")
    $progressBarText = $progressBarText.PadRight(52)
    $progressBarText += " $percentage%"
    [System.Console]::SetCursorPosition(0, [System.Console]::CursorTop - 1)
    [System.Console]::WriteLine($progressBarText)
    $_ -replace '0.0.0.0 thepiratebay.org','#0.0.0.0 thepiratebay.org' `
       -replace '0.0.0.0 www.thepiratebay.org','#0.0.0.0 www.thepiratebay.org' `
	   -replace '0.0.0.0 thepiratebay.org','#0.0.0.0 thepiratebay.org' `
	   -replace '0.0.0.0 www.thepiratebay.org','#0.0.0.0 www.thepiratebay.org' `
	   -replace '0.0.0.0 poloniex.com','#0.0.0.0 poloniex.com' `
	   -replace '0.0.0.0 api2.poloniex.com','#0.0.0.0 api2.poloniex.com' `
	   -replace '0.0.0.0 m.poloniex.com','#0.0.0.0 m.poloniex.com' `
	   -replace '0.0.0.0 public.poloniex.com','#0.0.0.0 public.poloniex.com' `
	   -replace '0.0.0.0 js.gleam.io','#0.0.0.0 js.gleam.io' `
	   -replace '0.0.0.0 www.g2a.com','#0.0.0.0 www.g2a.com' `
	   -replace '0.0.0.0 nllapps.com','#0.0.0.0 nllapps.com' `
	   -replace '0.0.0.0 gleamio.com','#0.0.0.0 gleamio.com' `
	   -replace '0.0.0.0 www.ustream.tv','#0.0.0.0 www.ustream.tv' `
	   -replace '0.0.0.0 www.ipify.org','#0.0.0.0 www.ipify.org' `
	   -replace '0.0.0.0 ipify.org','#0.0.0.0 ipify.org' `
	   -replace '0.0.0.0 api.ipify.org','#0.0.0.0 api.ipify.org' `
	   -replace '0.0.0.0 coinfaucet.eu','#0.0.0.0 coinfaucet.eu' `
	   -replace '0.0.0.0 ipify.org','#0.0.0.0 ipify.org' `
	   -replace '0.0.0.0 api.ipify.org','#0.0.0.0 api.ipify.org' `
	   -replace '0.0.0.0 api64.ipify.org','#0.0.0.0 api64.ipify.org' `
	   -replace '0.0.0.0 api6.ipify.org','#0.0.0.0 api6.ipify.org' `
	   -replace '0.0.0.0 api4.ipify.org','#0.0.0.0 api4.ipify.org' `
	   -replace '0.0.0.0 geo.ipify.org','#0.0.0.0 geo.ipify.org' `
	   -replace '0.0.0.0 www.ipify.org','#0.0.0.0 www.ipify.org' `
	   -replace '0.0.0.0 smartlock.google.com','#0.0.0.0 smartlock.google.com' `
	   -replace '0.0.0.0 id.google.com.uy','#0.0.0.0 id.google.com.uy' `
	   -replace '0.0.0.0 click.redditmail.com','#0.0.0.0 click.redditmail.com' `
	   -replace '0.0.0.0 adx.telegram.com','#0.0.0.0 adx.telegram.com'
}

# Output status to console
Write-Host "Removing duplicates ..."

# Remove duplicates
$contentCount = $content.Count
$uniqueContent = @{}
$progressBar2 = [System.Console]::WriteLine("Completion: [                    ]")
for ($i = 0; $i -lt $contentCount; $i++) {
    $percentage = [int](($i / $contentCount) * 100)
    $barLength = [int](($percentage / 2))
    $progressBarText = ("#" * $barLength).PadRight(50)
    $progressBarText = $progressBarText.Insert($barLength, "|")
    $progressBarText = $progressBarText.Insert(0, "|")
    $progressBarText = $progressBarText.PadRight(52)
    $progressBarText += " $percentage%"
    [System.Console]::SetCursorPosition(0, [System.Console]::CursorTop - 1)
    [System.Console]::WriteLine($progressBarText)
    
    $line = $content[$i]
    if (-not $uniqueContent.ContainsKey($line)) {
        $uniqueContent[$line] = $null
    }
}

# Convert the unique content back into an array
$content = $uniqueContent.Keys

# Write the updated content to the same file
$content | Set-Content $outputFile

# Output confirmation to console
Write-Host "Allowed hosts entries and removed duplicates in $outputFile."

# Pause and wait for user input before closing the console window
Write-Host "Press any key to close this window..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
