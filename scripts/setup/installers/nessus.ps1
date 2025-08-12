Write-Host "[*] Downloading nessus." -ForegroundColor Yellow

iwr "https://www.tenable.com/downloads/api/v2/pages/nessus/files/Nessus-10.9.2-x64.msi" -OutFile "Nessus-10.9.2-x64.msi"

Write-Host "[+] Nessus successfully downloaded." -ForegroundColor Green

Write-Host "[*] Installing on disk." -ForegroundColor Yellow

msiexec.exe /i "Nessus-10.9.2-x64.msi" /qn /norestart

Write-Host "[+] Finished Installation." -ForegroundColor Green
