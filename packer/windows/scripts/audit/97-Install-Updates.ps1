powershell.exe -ExecutionPolicy Bypass -NonInteractive -NoProfile -WindowStyle Maximized -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/rgl/packer-plugin-windows-update/fe8eafebc57f71c0a55e2aa902c2abd3a4012300/update/windows-update.ps1'))"
if ((New-Object -ComObject 'Microsoft.Update.SystemInfo').RebootRequired) {exit 2}
