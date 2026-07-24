# Write-Host "Success" -ForegroundColor Green
# Write-Host "Warning" -ForegroundColor Yellow
# Write-Host "Error" -ForegroundColor Red
# Write-Host "Info" -ForegroundColor Cyan

Push-Location $PSScriptRoot

try {

	# Define URLs and filenames
	$url1 = "https://raw.githubusercontent.com/badmojr/1Hosts/master/Lite/hosts.txt"
	$url2 = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
	$file1 = "hosts_1_badmojr.txt"
	$file2 = "hosts_2_StevenBlack.txt"
	$outputFile = "combined_hosts.txt"
	$bypass = "bypass.txt"

	$abuseIpUrl = "https://raw.githubusercontent.com/borestad/blocklist-abuseipdb/refs/heads/main/abuseipdb-s100-365d.ipv4"
	$abuseIpFile = "abuseipdb-s100-365d.txt"
	$abuseIpTemp = "abuseipdb-s100-365d_temp.txt"
	$abuseIpCombined = "combined_portmaster_abuseipdb_list.txt"
	$abuseIpUpToDate = 0
	$source1UpToDate = 0
	$source2UpToDate = 0

	# Define temporary file names
	$tempFile1 = "hosts_1_badmojr_temp.txt"
	$tempFile2 = "hosts_2_StevenBlack_temp.txt"

	# Ensure required files exist
	if (-not (Test-Path $bypass)) {
		"0" | Set-Content $bypass
		Write-Host "$bypass not found. Created with default content 0." -ForegroundColor Yellow
	}

	foreach ($file in @($file1, $file2, $outputFile, $abuseIpFile)) {
		if (-not (Test-Path $file)) {
			New-Item -ItemType File -Path $file -Force | Out-Null
			Write-Host "$file not found. Created empty." -ForegroundColor Cyan
		}
	}

	# --- HELPER FUNCTION FOR SAFE DOWNLOAD ---
	function Download-FileSafe {
		param (
			[string]$Url,
			[string]$Output
		)

		$maxRetries = 5
		$delaySeconds = 5

		for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
			try {
				Invoke-WebRequest -Uri $Url -OutFile $Output -Headers @{
					"User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
					"Referer" = "https://github.com/"
				} -UseBasicParsing -ErrorAction Stop
				Write-Host "Downloaded $Url successfully."
				return
			} catch {
				if ($_.Exception.Response.StatusCode -eq 429) {
					Write-Warning "429 Too Many Requests. Waiting $delaySeconds seconds before retry ($attempt/$maxRetries)..."
					Start-Sleep -Seconds $delaySeconds
				} else {
					Write-Error "Failed to download $Url. Error: $_"
					break
				}
			}
		}
		throw "Could not download $Url after $maxRetries attempts."
	}

	# --- MAIN LOGIC ---
	$bypassValue = Get-Content $bypass -Raw

	if ($bypassValue -eq "0") {
		# --- DOWNLOAD MODE ---
		Write-Host "Downloading hosts (GitHub-safe) ..." -ForegroundColor Cyan
		Download-FileSafe -Url $url1 -Output $tempFile1
		Start-Sleep -Milliseconds 500
		Download-FileSafe -Url $url2 -Output $tempFile2

		# --- HASH COMPARISON ---
		if ((Test-Path $file1) -and (Test-Path $file2)) {
			$existingHash1 = Get-FileHash $file1 -Algorithm MD5
			$existingHash2 = Get-FileHash $file2 -Algorithm MD5
			$tempHash1 = Get-FileHash $tempFile1 -Algorithm MD5
			$tempHash2 = Get-FileHash $tempFile2 -Algorithm MD5

			if ($existingHash1.Hash -ne $tempHash1.Hash) {
				Write-Host "$file1 is different. Updating." -ForegroundColor Yellow
				Remove-Item $file1 -Force
				Move-Item $tempFile1 $file1
			} else {
				Write-Host "$file1 is up to date." -ForegroundColor Green
				$source1UpToDate = 1
				Remove-Item $tempFile1 -Force
			}

			if ($existingHash2.Hash -ne $tempHash2.Hash) {
				Write-Host "$file2 is different. Updating." -ForegroundColor Yellow
				Remove-Item $file2 -Force
				Move-Item $tempFile2 $file2
			} else {
				Write-Host "$file2 is up to date." -ForegroundColor Green
				$source2UpToDate = 1
				Remove-Item $tempFile2 -Force
			}
		} else {
			Write-Host "No previous hosts sources found. Using temporary files..." -ForegroundColor Cyan
			Move-Item $tempFile1 $file1
			Move-Item $tempFile2 $file2
		}

	} else {
		# --- BYPASS MODE ---
		Write-Host "Bypass enabled. Using existing host files directly." -ForegroundColor Yellow
		if (-not (Test-Path $file1) -or -not (Test-Path $file2)) {
			Write-Error "Bypass mode selected, but one or both host files do not exist."
			Write-Host "Press ENTER to close this window..."
			do { $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").VirtualKeyCode } while ($key -ne 13)
			exit 1
		}

		# Force reprocess (skip download logic)
		$source1UpToDate = 0
		$source2UpToDate = 0
	}

	# --- COMBINATION + CLEANUP ---
	if (($source1UpToDate -eq 0) -or ($source2UpToDate -eq 0)) {
		Write-Host "Hosts download and update complete." -ForegroundColor Green

		if (Test-Path $outputFile) {
			Write-Host "$outputFile exists, deleting."
			Remove-Item $outputFile -Force
		}

		Write-Host "Combining $file1 and $file2 ..."
		$content1 = Get-Content $file1
		$content2 = Get-Content $file2
		$combinedContent = $content1 + $content2
		$combinedContent | Set-Content $outputFile

		Write-Host "Contents of $file1 and $file2 have been combined and saved to $outputFile." -ForegroundColor Green

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
			   -replace '0.0.0.0 freedns.afraid.org','#0.0.0.0 freedns.afraid.org' `
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
		Write-Host "Allowed hosts entries and removed duplicates in $outputFile." -ForegroundColor Green
	}

	# ------------------------------------------------------------
	# AbuseIPDB update check
	# ------------------------------------------------------------

	Write-Host ""
	Write-Host "Checking AbuseIPDB source..." -ForegroundColor Cyan

	Download-FileSafe -Url $abuseIpUrl -Output $abuseIpTemp

	if (Test-Path $abuseIpFile) {

		$existingHash = Get-FileHash $abuseIpFile -Algorithm MD5
		$tempHash = Get-FileHash $abuseIpTemp -Algorithm MD5

		if ($existingHash.Hash -ne $tempHash.Hash) {
			Write-Host "$abuseIpFile is different. Updating." -ForegroundColor Yellow

			Remove-Item $abuseIpFile -Force
			Move-Item $abuseIpTemp $abuseIpFile
		}
		else {
			Write-Host "$abuseIpFile is up to date." -ForegroundColor Green
			Remove-Item $abuseIpTemp -Force
			$abuseIpUpToDate = 1
		}
	}
	else {
		Move-Item $abuseIpTemp $abuseIpFile
	}

	# ------------------------------------------------------------
	# Create combined_hosts_abuseipdb.txt
	# ------------------------------------------------------------

	$portmasterNeedsUpdate =
		($source1UpToDate -eq 0) -or
		($source2UpToDate -eq 0) -or
		($abuseIpUpToDate -eq 0)

	if ($portmasterNeedsUpdate) {
		Write-Host "Creating $abuseIpCombined ..."

		$hostsContent = Get-Content $outputFile

		Write-Host "Cleaning AbuseIPDB list ..."

		$abuseRaw = Get-Content $abuseIpFile
		$totalLines = $abuseRaw.Count

		$abuseContent = New-Object System.Collections.Generic.List[string]

		[System.Console]::WriteLine("Completion: [                    ]")

		for ($i = 0; $i -lt $totalLines; $i++) {

			$percentage = [int](($i / $totalLines) * 100)
			$barLength = [int](($percentage / 2))

			$progressBarText = ("#" * $barLength).PadRight(50)
			$progressBarText = $progressBarText.Insert($barLength, "|")
			$progressBarText = $progressBarText.Insert(0, "|")
			$progressBarText = $progressBarText.PadRight(52)
			$progressBarText += " $percentage%"

			[System.Console]::SetCursorPosition(0, [System.Console]::CursorTop - 1)
			[System.Console]::WriteLine($progressBarText)

			$line = $abuseRaw[$i]

			$matches = [regex]::Matches(
				$line,
				'(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)'
			)

			foreach ($match in $matches) {
				$abuseContent.Add($match.Value)
			}
		}

		[System.Console]::SetCursorPosition(0, [System.Console]::CursorTop - 1)
		[System.Console]::WriteLine("|##################################################| 100%")

		Write-Host "Found $($abuseContent.Count) valid IPv4 addresses." -ForegroundColor Green

		$combinedUnique = @{}
		Write-Host "Cleaning hosts list for Portmaster format ..."

		$cleanHostsContent = New-Object System.Collections.Generic.List[string]
		
		$excludedDomains = @(
			'thepiratebay.org',
			'www.thepiratebay.org',
			'poloniex.com',
			'api2.poloniex.com',
			'm.poloniex.com',
			'public.poloniex.com',
			'js.gleam.io',
			'www.g2a.com',
			'nllapps.com',
			'gleamio.com',
			'www.ustream.tv',
			'www.ipify.org',
			'ipify.org',
			'api.ipify.org',
			'coinfaucet.eu',
			'api64.ipify.org',
			'api6.ipify.org',
			'api4.ipify.org',
			'geo.ipify.org',
			'smartlock.google.com',
			'id.google.com.uy',
			'click.redditmail.com',
			'freedns.afraid.org',
			'adx.telegram.com'
		)

		[System.Console]::WriteLine("Completion: [                    ]")

		for ($i = 0; $i -lt $hostsContent.Count; $i++) {

			$percentage = [int](($i / $hostsContent.Count) * 100)
			$barLength = [int](($percentage / 2))

			$progressBarText = ("#" * $barLength).PadRight(50)
			$progressBarText = $progressBarText.Insert($barLength, "|")
			$progressBarText = $progressBarText.Insert(0, "|")
			$progressBarText = $progressBarText.PadRight(52)
			$progressBarText += " $percentage%"

			[System.Console]::SetCursorPosition(0, [System.Console]::CursorTop - 1)
			[System.Console]::WriteLine($progressBarText)

			$line = $hostsContent[$i]

			# Remove comments and everything after them
			$line = $line -replace '\s*#.*$', ''

			# Remove leading hosts IPs
			$line = $line -replace '^0\.0\.0\.0\s+', ''
			$line = $line -replace '^127\.0\.0\.1\s+', ''
			$line = $line -replace '^::1\s+', ''

			$line = $line.Trim()
			
			if (
				$line.Length -gt 0 -and
				$line -notin $excludedDomains
			) {
				$cleanHostsContent.Add($line)
			}
		}

		[System.Console]::SetCursorPosition(0, [System.Console]::CursorTop - 1)
		[System.Console]::WriteLine("|##################################################| 100%")

		$mergedContent = $cleanHostsContent + $abuseContent

		Write-Host "Merging and removing duplicates ..."

		[System.Console]::WriteLine("Completion: [                    ]")

		for ($i = 0; $i -lt $mergedContent.Count; $i++) {

			$percentage = [int](($i / $mergedContent.Count) * 100)
			$barLength = [int](($percentage / 2))

			$progressBarText = ("#" * $barLength).PadRight(50)
			$progressBarText = $progressBarText.Insert($barLength, "|")
			$progressBarText = $progressBarText.Insert(0, "|")
			$progressBarText = $progressBarText.PadRight(52)
			$progressBarText += " $percentage%"

			[System.Console]::SetCursorPosition(0, [System.Console]::CursorTop - 1)
			[System.Console]::WriteLine($progressBarText)

			$line = $mergedContent[$i]

			if (-not $combinedUnique.ContainsKey($line)) {
				$combinedUnique[$line] = $null
			}
		}

		[System.Console]::SetCursorPosition(0, [System.Console]::CursorTop - 1)
		[System.Console]::WriteLine("|##################################################| 100%")

		$combinedUnique.Keys | Set-Content $abuseIpCombined

		Write-Host "$abuseIpCombined created." -ForegroundColor Green
	}

	else {
		Write-Host "All sources are up to date. Skipping Portmaster list rebuild." -ForegroundColor Green
	}

	Write-Host ""
	Write-Host "Press ENTER to close this window..."
	do { $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").VirtualKeyCode } while ($key -ne 13)

}
finally {
    Pop-Location
}