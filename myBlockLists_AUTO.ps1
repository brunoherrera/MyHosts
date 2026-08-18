Push-Location $PSScriptRoot

# Track temp files for guaranteed cleanup in finally block
$script:tempFilesToClean = [System.Collections.Generic.List[string]]::new()

try {
	# --- CONFIGURATION ---
	$url1 = "https://raw.githubusercontent.com/badmojr/1Hosts/master/Lite/hosts.txt"
	$url2 = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
	$file1 = "hosts_1_badmojr.txt"
	$file2 = "hosts_2_StevenBlack.txt"
	$outputFile = "combined_hosts.txt"
	$bypass = "bypass.txt"

	$abuseIpUrl = "https://raw.githubusercontent.com/borestad/blocklist-abuseipdb/refs/heads/main/abuseipdb-s100-365d.ipv4"
	$abuseIpFile = "abuseipdb-s100-365d.txt"

	# Blocklist.de (Plain 1 IP per line)
	$blocklistDeUrl = "https://lists.blocklist.de/lists/all.txt"
	$blocklistDeFile = "blocklist_de_all.txt"

	$abuseIpCombined = "combined_portmaster_abuseipdb_list.txt"
	$pythonPushScript = "D:\GITHUB\gitPushHosts.py"
	$logFile = "hostsUPDATE.log"

	$source1UpToDate = $false
	$source2UpToDate = $false
	$abuseIpUpToDate = $false
	$blocklistDeUpToDate = $false

	# Domains and system local entries to exclude from blocking ($O(1) HashSet)
	[string[]]$excludedDomainsList = @(
		'thepiratebay.org', 'www.thepiratebay.org', 'poloniex.com', 'api2.poloniex.com',
		'm.poloniex.com', 'public.poloniex.com', 'js.gleam.io', 'www.g2a.com',
		'nllapps.com', 'gleamio.com', 'www.ustream.tv', 'www.ipify.org',
		'ipify.org', 'api.ipify.org', 'coinfaucet.eu', 'api64.ipify.org',
		'api6.ipify.org', 'api4.ipify.org', 'geo.ipify.org', 'smartlock.google.com',
		'id.google.com.uy', 'click.redditmail.com', 'freedns.afraid.org', 'adx.telegram.com',
		# Localhost & Loopback exclusions
		'localhost', 'localhost.localdomain', 'local', 'broadcasthost', '255.255.255.255 broadcasthost',
		'ip6-localhost', 'ip6-loopback', 'fe80::1%lo0 localhost', 'ip6-localnet', 'ff00::0 ip6-localnet',
		'ip6-mcastprefix', 'ff00::0 ip6-mcastprefix', 'ip6-allnodes', 'ff02::1 ip6-allnodes',
		'ip6-allrouters', 'ff02::2 ip6-allrouters', 'ip6-allhosts', 'ff02::3 ip6-allhosts',
		'0.0.0.0', '255.255.255.255'
	)
	$excludedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	$excludedSet.UnionWith($excludedDomainsList)

	# --- HELPER FUNCTIONS ---
	function Download-StringSafe {
		param ([string]$Url)
		$maxRetries = 5
		$delaySeconds = 5

		for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
			try {
				$response = Invoke-WebRequest -Uri $Url -Headers @{
					"User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
					"Referer"    = "https://github.com/"
				} -UseBasicParsing -ErrorAction Stop
				return $response.Content
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

	function Get-MemoryHash {
		param ([string]$Text)
		$md5 = [System.Security.Cryptography.MD5]::Create()
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
		return ([System.BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-', '').ToUpper()
	}

	function Get-FileHashMd5 {
		param ([string]$Path)
		if (-not (Test-Path $Path)) { return "" }
		return (Get-FileHash -Path $Path -Algorithm MD5).Hash
	}

	# Throttled console progress (only updates on integer % change)
	function Write-ProgressConsole {
		param ([int]$Current, [int]$Total, [ref]$LastPercent)
		if ($Total -le 0) { return }
		$percent = [int](($Current / $Total) * 100)
		if ($percent -ne $LastPercent.Value) {
			$LastPercent.Value = $percent
			$barLength = [int]($percent / 2)
			$progressBarText = ("#" * $barLength).PadRight(50)
			$progressBarText = $progressBarText.Insert($barLength, "|").Insert(0, "|").PadRight(52) + " $percent%"
			[System.Console]::SetCursorPosition(0, [System.Console]::CursorTop - 1)
			[System.Console]::WriteLine($progressBarText)
		}
	}

	# Safe File Saving with Explicit Path Resolution
	function Save-FileAtomic {
		param (
			[string]$Path,
			[object]$Content
		)
		$fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
		$leaf = Split-Path -Leaf $fullPath
		$dir = Split-Path -Parent $fullPath
		$tempPath = Join-Path $dir (".$leaf.commit.$PID.tmp")
		$script:tempFilesToClean.Add($tempPath)

		if ($Content -is [string]) {
			[System.IO.File]::WriteAllText($tempPath, $Content)
		} else {
			[System.IO.File]::WriteAllLines($tempPath, [string[]]$Content)
		}

		Move-Item -LiteralPath $tempPath -Destination $fullPath -Force
	}

	# --- INITIAL CHECKS ---
	if (-not (Test-Path $bypass)) {
		"0" | Set-Content $bypass
		Write-Host "$bypass not found. Created with default content 0." -ForegroundColor Yellow
	}

	$bypassValue = (Get-Content $bypass -Raw).Trim()

	$rawContent1 = ""
	$rawContent2 = ""

	if ($bypassValue -eq "0") {
		# --- DOWNLOAD MODE (IN-MEMORY) ---
		Write-Host "Downloading hosts (GitHub-safe) ..." -ForegroundColor Cyan
		$rawContent1 = Download-StringSafe -Url $url1
		Start-Sleep -Milliseconds 500
		$rawContent2 = Download-StringSafe -Url $url2

		# Hash Comparison
		$hash1 = Get-MemoryHash $rawContent1
		$hash2 = Get-MemoryHash $rawContent2

		if ((Get-FileHashMd5 $file1) -ne $hash1) {
			Write-Host "$file1 is different. Staging update." -ForegroundColor Yellow
			Save-FileAtomic -Path $file1 -Content $rawContent1
		} else {
			Write-Host "$file1 is up to date." -ForegroundColor Green
			$source1UpToDate = $true
		}

		if ((Get-FileHashMd5 $file2) -ne $hash2) {
			Write-Host "$file2 is different. Staging update." -ForegroundColor Yellow
			Save-FileAtomic -Path $file2 -Content $rawContent2
		} else {
			Write-Host "$file2 is up to date." -ForegroundColor Green
			$source2UpToDate = $true
		}
	} else {
		# --- BYPASS MODE ---
		Write-Host "Bypass enabled. Using existing host files directly." -ForegroundColor Yellow
		if (-not (Test-Path $file1) -or -not (Test-Path $file2)) {
			Write-Error "Bypass mode selected, but one or both host files do not exist."
			exit 1
		}
		$file1Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file1)
		$file2Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file2)
		$rawContent1 = [System.IO.File]::ReadAllText($file1Path)
		$rawContent2 = [System.IO.File]::ReadAllText($file2Path)
	}

	# --- COMBINATION + CLEANUP IN MEMORY ---
	if (-not $source1UpToDate -or -not $source2UpToDate -or -not (Test-Path $outputFile)) {
		Write-Host "Processing hosts sources in memory..." -ForegroundColor Cyan

		$lines1 = $rawContent1 -split "\r?\n"
		$lines2 = $rawContent2 -split "\r?\n"
		$allLines = [System.Collections.Generic.List[string]]::new($lines1.Length + $lines2.Length)
		$allLines.AddRange($lines1)
		$allLines.AddRange($lines2)

		$uniqueHosts = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
		$lastPct = -1
		$total = $allLines.Count

		Write-Host "Cleaning comments, applying allowlist rules, and removing duplicates..."
		[System.Console]::WriteLine("Completion: [                    ]")

		for ($i = 0; $i -lt $total; $i++) {
			Write-ProgressConsole -Current $i -Total $total -LastPercent ([ref]$lastPct)

			$line = $allLines[$i]
			
			if ($line -match '^\s*#') { continue }

			if ($line -match '^(0\.0\.0\.0|127\.0\.0\.1)\s+(\S+)') {
				$domain = $Matches[2]
				if ($excludedSet.Contains($domain)) {
					$line = "#$line"
				}
			}

			[void]$uniqueHosts.Add($line)
		}
		
		[System.Console]::SetCursorPosition(0, [System.Console]::CursorTop - 1)
		[System.Console]::WriteLine("|##################################################| 100%")

		Save-FileAtomic -Path $outputFile -Content $uniqueHosts
		Write-Host "Replaced $outputFile atomically." -ForegroundColor Green
	}

	# --- ABUSEIPDB UPDATE CHECK (IN-MEMORY) ---
	Write-Host ""
	Write-Host "Checking AbuseIPDB source..." -ForegroundColor Cyan

	$rawAbuseText = Download-StringSafe -Url $abuseIpUrl
	$abuseHash = Get-MemoryHash $rawAbuseText

	if ((Get-FileHashMd5 $abuseIpFile) -ne $abuseHash) {
		Write-Host "$abuseIpFile is different. Staging update." -ForegroundColor Yellow
		Save-FileAtomic -Path $abuseIpFile -Content $rawAbuseText
	} else {
		Write-Host "$abuseIpFile is up to date." -ForegroundColor Green
		$abuseIpUpToDate = $true
	}

	# --- BLOCKLIST.DE UPDATE CHECK (IN-MEMORY) ---
	Write-Host ""
	Write-Host "Checking Blocklist.de source..." -ForegroundColor Cyan

	$rawBlocklistDeText = Download-StringSafe -Url $blocklistDeUrl
	$blocklistDeHash = Get-MemoryHash $rawBlocklistDeText

	if ((Get-FileHashMd5 $blocklistDeFile) -ne $blocklistDeHash) {
		Write-Host "$blocklistDeFile is different. Staging update." -ForegroundColor Yellow
		Save-FileAtomic -Path $blocklistDeFile -Content $rawBlocklistDeText
	} else {
		Write-Host "$blocklistDeFile is up to date." -ForegroundColor Green
		$blocklistDeUpToDate = $true
	}

	# --- CREATE COMBINED PORTMASTER LIST (IN-MEMORY) ---
	$portmasterNeedsUpdate = (-not $source1UpToDate) -or (-not $source2UpToDate) -or (-not $abuseIpUpToDate) -or (-not $blocklistDeUpToDate) -or (-not (Test-Path $abuseIpCombined))

	if ($portmasterNeedsUpdate) {
		Write-Host ""
		Write-Host "Creating $abuseIpCombined in memory..." -ForegroundColor Cyan

		Write-Host "Extracting IPv4 addresses from AbuseIPDB list..."
		$ipMatches = [regex]::Matches(
			$rawAbuseText,
			'(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)'
		)

		$abuseContent = [System.Collections.Generic.List[string]]::new($ipMatches.Count)
		foreach ($m in $ipMatches) {
			$abuseContent.Add($m.Value)
		}
		Write-Host "Found $($abuseContent.Count) valid IPv4 addresses in AbuseIPDB." -ForegroundColor Green

		Write-Host "Parsing Blocklist.de list..."
		$blocklistDeLines = $rawBlocklistDeText -split "\r?\n"
		Write-Host "Found $($blocklistDeLines.Length) IP lines in Blocklist.de." -ForegroundColor Green

		Write-Host "Cleaning hosts list for Portmaster format..."
		$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputFile)
		$hostsLines = [System.IO.File]::ReadAllLines($outputPath)
		$cleanHostsList = [System.Collections.Generic.List[string]]::new($hostsLines.Length)

		$lastPct = -1
		$total = $hostsLines.Length
		[System.Console]::WriteLine("Completion: [                    ]")

		for ($i = 0; $i -lt $total; $i++) {
			Write-ProgressConsole -Current $i -Total $total -LastPercent ([ref]$lastPct)

			$line = $hostsLines[$i]
			$line = $line -replace '\s*#.*$', ''
			# Strip standard host prefixes (IPv4, IPv6, Broadcast)
			$line = $line -replace '^(0\.0\.0\.0|127\.0\.0\.1|::1|fe80::1%lo0|ff00::0|ff02::[123]|255\.255\.255\.255)\s+', ''
			$line = $line.Trim()

			if ($line.Length -gt 0 -and -not $excludedSet.Contains($line)) {
				$cleanHostsList.Add($line)
			}
		}

		[System.Console]::SetCursorPosition(0, [System.Console]::CursorTop - 1)
		[System.Console]::WriteLine("|##################################################| 100%")

		Write-Host "Merging lists and removing duplicates..."
		$portmasterSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
		$portmasterSet.UnionWith([string[]]$cleanHostsList)
		
		# Merge AbuseIPDB entries
		foreach ($ip in $abuseContent) {
			if (-not $excludedSet.Contains($ip)) {
				[void]$portmasterSet.Add($ip)
			}
		}

		# Merge Blocklist.de entries
		foreach ($line in $blocklistDeLines) {
			$ip = $line.Trim()
			if ($ip.Length -gt 0 -and -not $excludedSet.Contains($ip)) {
				[void]$portmasterSet.Add($ip)
			}
		}

		Save-FileAtomic -Path $abuseIpCombined -Content $portmasterSet
		Write-Host "Replaced $abuseIpCombined atomically." -ForegroundColor Green
	} else {
		Write-Host "All sources are up to date. Skipping Portmaster list rebuild." -ForegroundColor Green
	}

	# --- EXECUTE PYTHON SCRIPT HIDDEN ---
	if (Test-Path $pythonPushScript) {
		Write-Host "Executing Python script silently..." -ForegroundColor Cyan
		Start-Process -FilePath "python.exe" -ArgumentList "`"$pythonPushScript`"" -WindowStyle Hidden -Wait
	} else {
		Write-Warning "Python script not found at path: $pythonPushScript"
	}

	# --- LOG SUCCESSFUL RUN ---
	$timestamp = (Get-Date).ToString("MM/dd/yyyy HH:mm:ss")
	$logEntry = "$timestamp - Success"
	Add-Content -Path $logFile -Value $logEntry -Encoding UTF8

} finally {
	# Cleanup leftover temp commit files if script was interrupted
	foreach ($temp in $script:tempFilesToClean) {
		if (Test-Path $temp) {
			Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
		}
	}
	Pop-Location
}