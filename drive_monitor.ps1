# ==============================================================================
# Retro Game Manager - Real-Time Drive Monitor Companion (Port 38999)
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

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $req = $context.Request
        $res = $context.Response

        $res.Headers.Add("Access-Control-Allow-Origin", "*")
        $res.Headers.Add("Access-Control-Allow-Methods", "GET, OPTIONS")
        $res.Headers.Add("Access-Control-Allow-Headers", "*")

        if ($req.HttpMethod -eq "OPTIONS") {
            $res.StatusCode = 200
            $res.Close()
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
