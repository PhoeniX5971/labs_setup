Write-Host "[*] Downloading nessus." -ForegroundColor Yellow

curl --request GET \
  --url 'https://www.tenable.com/downloads/api/v2/pages/nessus/files/Nessus-10.9.2-x64.msi' \
  --output 'Nessus-10.9.2-x64.msi';


Write-Host "[+] Nessus successfully downloaded." -ForegroundColor Green

msiexec.exe /i "Nessus-10.9.2-x64.msi" /qn /norestart /l*v "$PWD\nessus_install.log"

Write-Host "[*] Installing on disk." -ForegroundColor Green
