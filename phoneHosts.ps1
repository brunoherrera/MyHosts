# Define URLs and filenames
$url1 = "https://raw.githubusercontent.com/badmojr/1Hosts/master/Lite/hosts.txt"
$url2 = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
$file1 = "hosts_1_badmojr.txt"
$file2 = "hosts_2_StevenBlack.txt"
$outputFile = "combined_hosts.txt"
$bypass = "bypass.txt"
$source1UpToDate = 0
$source2UpToDate = 0

# Define temporary file names
$tempFile1 = "hosts_1_badmojr_temp.txt"
$tempFile2 = "hosts_2_StevenBlack_temp.txt"

# Ensure required files exist
if (-not (Test-Path $bypass)) {
    "0" | Set-Content $bypass
    Write-Host "$bypass not found. Created with default content 0."
}

foreach ($file in @($file1, $file2, $outputFile)) {
    if (-not (Test-Path $file)) {
        New-Item -ItemType File -Path $file -Force | Out-Null
        Write-Host "$file not found. Created empty."
    }
}

# --- MAIN LOGIC ---
$bypassValue = Get-Content $bypass -Raw

if ($bypassValue -eq "0") {
    # --- DOWNLOAD MODE ---
    $client = New-Object System.Net.WebClient
    $client.Headers["User-Agent"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Mobile Safari/537.36"

    Write-Host "Downloading hosts ..."

    try {
        $client.DownloadFile($url1, $tempFile1)
        $client.DownloadFile($url2, $tempFile2)
    } catch {
        Write-Error "Failed to download one or more files. Error: $_"
        Write-Host ""
        Write-Host "Press ENTER to close this window..."
        do {
            $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").VirtualKeyCode
        } while ($key -ne 13)
        exit 1
    }

    # --- HASH COMPARISON ---
    if ((Test-Path $file1) -and (Test-Path $file2)) {
        $existingHash1 = Get-FileHash $file1 -Algorithm MD5
        $existingHash2 = Get-FileHash $file2 -Algorithm MD5
        $tempHash1 = Get-FileHash $tempFile1 -Algorithm MD5
        $tempHash2 = Get-FileHash $tempFile2 -Algorithm MD5

        if ($existingHash1.Hash -ne $tempHash1.Hash) {
            Write-Host "$file1 is different. Updating."
            Remove-Item $file1 -Force
            Move-Item $tempFile1 $file1
        } else {
            Write-Host "$file1 is up to date."
            $source1UpToDate = 1
            Remove-Item $tempFile1 -Force
        }

        if ($existingHash2.Hash -ne $tempHash2.Hash) {
            Write-Host "$file2 is different. Updating."
            Remove-Item $file2 -Force
            Move-Item $tempFile2 $file2
        } else {
            Write-Host "$file2 is up to date."
            $source2UpToDate = 1
            Remove-Item $tempFile2 -Force
        }
    } else {
        Write-Host "No previous hosts sources found. Using temporary files..."
        Move-Item $tempFile1 $file1
        Move-Item $tempFile2 $file2
    }

} else {
    # --- BYPASS MODE ---
    Write-Host "Bypass enabled. Using existing host files directly."
    if (-not (Test-Path $file1) -or -not (Test-Path $file2)) {
        Write-Error "Bypass mode selected, but one or both host files do not exist."
        Write-Host "Press ENTER to close this window..."
        do {
            $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").VirtualKeyCode
        } while ($key -ne 13)
        exit 1
    }

    # Force reprocess (skip download logic)
    $source1UpToDate = 0
    $source2UpToDate = 0
}

# --- COMBINATION + CLEANUP ---
if (($source1UpToDate -eq 0) -or ($source2UpToDate -eq 0)) {
    Write-Host "Hosts download and update complete."

    if (Test-Path $outputFile) {
        Write-Host "$outputFile exists, deleting."
        Remove-Item $outputFile -Force
    }

    Write-Host "Combining $file1 and $file2 ..."
    $content1 = Get-Content $file1
    $content2 = Get-Content $file2
    $combinedContent = $content1 + $content2
    $combinedContent | Set-Content $outputFile

    Write-Host "Contents of $file1 and $file2 have been combined and saved to $outputFile."

    Write-Host "Removing all commented lines ..."
    $content = Get-Content $outputFile | Where-Object { $_ -notmatch '^\s*#' }
    $content | Set-Content $outputFile
    Write-Host "Removed all commented lines from $outputFile."

    Write-Host "Allowing hosts entries ..."
    $content = Get-Content -Path $outputFile
    $totalLines = $content.Count
    [System.Console]::WriteLine("Completion: [                    ]")
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
           -replace '0.0.0.0 api64.ipify.org','#0.0.0.0 api64.ipify.org' `
           -replace '0.0.0.0 api6.ipify.org','#0.0.0.0 api6.ipify.org' `
           -replace '0.0.0.0 api4.ipify.org','#0.0.0.0 api4.ipify.org' `
           -replace '0.0.0.0 geo.ipify.org','#0.0.0.0 geo.ipify.org' `
           -replace '0.0.0.0 smartlock.google.com','#0.0.0.0 smartlock.google.com' `
           -replace '0.0.0.0 id.google.com.uy','#0.0.0.0 id.google.com.uy' `
           -replace '0.0.0.0 click.redditmail.com','#0.0.0.0 click.redditmail.com' `
           -replace '0.0.0.0 adx.telegram.com','#0.0.0.0 adx.telegram.com'
    }

    Write-Host "Removing duplicates ..."
    $uniqueContent = @{}
    [System.Console]::WriteLine("Completion: [                    ]")
    for ($i = 0; $i -lt $content.Count; $i++) {
        $percentage = [int](($i / $content.Count) * 100)
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

    $uniqueContent.Keys | Set-Content $outputFile
    Write-Host "Allowed hosts entries and removed duplicates in $outputFile."
}

Write-Host ""
Write-Host "Press ENTER to close this window..."
do {
    $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").VirtualKeyCode
} while ($key -ne 13)
