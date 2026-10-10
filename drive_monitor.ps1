# ==============================================================================
# Retro Game Manager - Real-Time Drive Monitor & Cover Search Companion (Port 38999)
# Zero-dependency, lightweight background service (built into Windows PowerShell)
# ==============================================================================

# Check if an instance is already listening on port 38999
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $tcp.Connect("127.0.0.1", 38999)
    $tcp.Close()
    exit 0
} catch {}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:38999/")

try {
    $listener.Start()
} catch {
    exit 1
}

function Search-GameCovers($query, $consoleName) {
    if (-not $query) { return @() }

    # Map all console folders and aliases to accurate search keywords
    $consoleMap = @{
        "psx" = "PS1"; "ps1" = "PS1"; "psp" = "PSP"; "ps2" = "PS2"; "playstation" = "PlayStation"
        "gba" = "GBA"; "gbc" = "GBC"; "gb" = "Game Boy"; "nds" = "NDS"; "3ds" = "3DS"; "pokemini" = "Pokemon Mini"
        "sfc" = "SNES"; "snes" = "SNES"; "nes" = "NES"; "fc" = "Famicom"; "famicom" = "Famicom"; "n64" = "N64"
        "gc" = "GameCube"; "gamecube" = "GameCube"; "wii" = "Wii"
        "megadrive" = "Mega Drive"; "genesis" = "Genesis"; "md" = "Mega Drive"; "gen" = "Genesis"
        "saturn" = "Saturn"; "dreamcast" = "Dreamcast"; "dc" = "Dreamcast"; "gamegear" = "Game Gear"; "gg" = "Game Gear"
        "mastersystem" = "Master System"; "sms" = "Master System"; "segacd" = "Sega CD"; "sega32x" = "Sega 32X"; "sg1000" = "SG-1000"
        "neogeo" = "Neo Geo"; "ng" = "Neo Geo"; "ngp" = "Neo Geo Pocket"; "ngpc" = "Neo Geo Pocket Color"
        "pcengine" = "PC Engine"; "pce" = "PC Engine"; "tg16" = "TurboGrafx-16"; "turbografx" = "TurboGrafx-16"; "pcecd" = "PC Engine CD"
        "wonderswan" = "WonderSwan"; "ws" = "WonderSwan"; "wsc" = "WonderSwan Color"
        "arcade" = "Arcade"; "mame" = "MAME"; "fbneo" = "FBNeo"; "fba" = "Arcade"; "cps1" = "CPS1"; "cps2" = "CPS2"; "cps3" = "CPS3"
        "atari2600" = "Atari 2600"; "atari7800" = "Atari 7800"; "lynx" = "Atari Lynx"
        "msx" = "MSX"; "c64" = "Commodore 64"; "amiga" = "Amiga"; "pico8" = "PICO-8"; "pico-8" = "PICO-8"; "scummvm" = "ScummVM"
    }

    $cKey = if ($consoleName) { $consoleName.ToLower().Trim() } else { "" }
    $mappedConsole = if ($consoleMap.ContainsKey($cKey)) { $consoleMap[$cKey] } else { $consoleName }

    # Clean query (strip release numbers, Thai tags, bracketed codes)
    $clean = $query -replace '^\d+\s*[-_.]\s*', '' -replace '(?i)\s*-\s*TH.*|\s*\[.*?\]|\s*\(.*?\)', ''
    $clean = $clean -replace '[_\.]+', ' ' -replace '\s+', ' '
    $clean = $clean.Trim()

    # Short / nearby candidate (strip subtitle after ' - ' or ' : ')
    $shortClean = ($clean -split '\s*[-:]\s*')[0].Trim()

    $results = @()
    $seen = [System.Collections.Generic.HashSet[string]]::new()

    $terms = @("$clean $mappedConsole cover")
    if ($shortClean -ne $clean -and $shortClean.Length -ge 3) {
        $terms += "$shortClean $mappedConsole cover"
    }
    if ($shortClean.Length -ge 3) {
        $terms += "$shortClean box art"
    }

    foreach ($term in $terms) {
        if ($results.Count -ge 20) { break }
        $bingUrl = "https://www.bing.com/images/search?q=" + [Uri]::EscapeDataString($term) + "&form=HDRSC2&first=1"
        try {
            $web = Invoke-WebRequest -Uri $bingUrl -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" -TimeoutSec 6
            $matches = [regex]::Matches($web.Content, 'murl&quot;:&quot;(http[^&]+)&quot;')
            foreach ($m in $matches) {
                $u = $m.Groups[1].Value
                if (-not $seen.Contains($u)) {
                    $seen.Add($u) | Out-Null
                    $results += @{
                        url = $u
                        title = $clean
                    }
                    if ($results.Count -ge 24) { break }
                }
            }
        } catch {}
    }

    return $results
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $req = $context.Request
        $res = $context.Response

        $res.Headers.Add("Access-Control-Allow-Origin", "*")
        $res.Headers.Add("Access-Control-Allow-Methods", "GET, OPTIONS")
        $res.Headers.Add("Access-Control-Allow-Headers", "*")
        $res.Headers.Add("Referrer-Policy", "no-referrer")

        if ($req.HttpMethod -eq "OPTIONS") {
            $res.StatusCode = 200
            $res.Close()
            continue
        }

        $path = $req.Url.AbsolutePath

        if ($path -eq "/ping") {
            $json = '{"status":"ok","version":"2.0","engine":"live_cover_search"}'
            $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
            $res.ContentType = "application/json; charset=utf-8"
            $res.ContentLength64 = $buf.Length
            $res.OutputStream.Write($buf, 0, $buf.Length)
            $res.OutputStream.Close()
            continue
        }

        if ($path -eq "/search_cover") {
            $q = $req.QueryString["q"]
            $c = $req.QueryString["console"]
            # Strict Query Validation & Sanitization
            if ($q) {
                $q = ($q -replace '[^\p{L}\p{N}\s\-_.]', '').Trim()
                if ($q.Length -gt 100) { $q = $q.Substring(0, 100) }
            }
            if ($c) {
                $c = ($c -replace '[^a-zA-Z0-9_\-]', '').Trim()
                if ($c.Length -gt 32) { $c = $c.Substring(0, 32) }
            }
            $covers = Search-GameCovers $q $c
            if ($null -eq $covers -or $covers.Count -eq 0) {
                $json = "[]"
            } else {
                $json = ConvertTo-Json -InputObject @($covers) -Compress
                if (-not $json.StartsWith("[")) {
                    $json = "[$json]"
                }
            }
            $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
            $res.ContentType = "application/json; charset=utf-8"
            $res.ContentLength64 = $buf.Length
            $res.OutputStream.Write($buf, 0, $buf.Length)
            $res.OutputStream.Close()
            continue
        }

        if ($path -eq "/fetch_image") {
            $imgUrl = $req.QueryString["url"]
            # Strict URL Validation & SSRF Protection
            if (-not $imgUrl -or -not ($imgUrl -match '^https?://') -or ($imgUrl -match '(?i)^https?://(?:localhost|127\.|\[::1\]|10\.|192\.168\.|172\.(?:1[6-9]|2[0-9]|3[0-1])\.|169\.254\.)')) {
                $res.StatusCode = 403
                $res.Close()
                continue
            }
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
                $wc.Headers.Add("Referer", "")
                $bytes = $wc.DownloadData($imgUrl)
                if ($bytes.Length -gt 10485760) { # Max 10MB protection
                    $res.StatusCode = 413
                    $res.Close()
                    continue
                }
                $ct = if ($imgUrl -match '\.png') { "image/png" } elseif ($imgUrl -match '\.webp') { "image/webp" } else { "image/jpeg" }
                $res.ContentType = $ct
                $res.ContentLength64 = $bytes.Length
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            } catch {
                $res.StatusCode = 500
            }
            $res.OutputStream.Close()
            continue
        }

        # Query all storage drives (USB drives, Removable, Fixed)
        $drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }
        $list = @()
        foreach ($d in $drives) {
            $tot = [math]::Round($d.Size / 1GB, 2)
            $fre = [math]::Round($d.FreeSpace / 1GB, 2)
            $usd = [math]::Round(($d.Size - $d.FreeSpace) / 1GB, 2)
            $pct = if ($tot -gt 0) { [math]::Round(($usd / $tot) * 100, 1) } else { 0 }
            $list += @{
                device = $d.DeviceID
                letter = $d.DeviceID.Replace(":", "").ToUpper()
                volume = $d.VolumeName
                totalGB = $tot
                freeGB = $fre
                usedGB = $usd
                pct = $pct
            }
        }

        $json = ConvertTo-Json -InputObject $list -Compress
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json; charset=utf-8"
        $res.ContentLength64 = $buf.Length
        $res.OutputStream.Write($buf, 0, $buf.Length)
        $res.OutputStream.Close()
    } catch {
        # continue loop
    }
}
