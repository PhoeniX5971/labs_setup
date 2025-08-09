# Paths
$certPath = "C:\CA\EnterpriseRootCA.cer"
New-Item -ItemType Directory -Force -Path "C:\CA" | Out-Null

# Export the public CA certificate
certutil -ca.cert $certPath

Write-Host "[+] CA certificate exported to $certPath"
