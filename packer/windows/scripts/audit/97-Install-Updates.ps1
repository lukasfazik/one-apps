powershell.exe -ExecutionPolicy Bypass -NonInteractive -NoProfile -WindowStyle Maximized -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/rgl/packer-plugin-windows-update/c3721215ced494a4e18c3145110513de06c5e24e/update/windows-update.ps1'))"
if ((New-Object -ComObject 'Microsoft.Update.SystemInfo').RebootRequired) {exit 2}
