param(
    [Parameter(Mandatory = $false)]
    [string[]]$Users,

    [Parameter(Mandatory = $false)]
    [string[]]$Groups,

    [Parameter(Mandatory = $false)]
    [string[]]$InGroup
)

Import-Module ActiveDirectory

# Create groups if specified
if ($Groups) {
    foreach ($group in $Groups) {
        if (-not (Get-ADGroup -Filter { Name -eq $group } -ErrorAction SilentlyContinue)) {
            Write-Host "Creating group: $group"
            New-ADGroup -Name $group -SamAccountName $group -GroupScope Global -GroupCategory Security
        } else {
            Write-Host "Group already exists: $group"
        }
    }
}

# Create users if specified
if ($Users) {
    foreach ($user in $Users) {
        if (-not (Get-ADUser -Filter { SamAccountName -eq $user } -ErrorAction SilentlyContinue)) {
            Write-Host "Creating user: $user"
            $securePass = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force
            New-ADUser -Name $user -SamAccountName $user -AccountPassword $securePass -Enabled $true -PasswordNeverExpires $true
        } else {
            Write-Host "User already exists: $user"
        }

        # Add user to groups if -InGroup is specified
        if ($InGroup) {
            foreach ($group in $InGroup) {
                Write-Host "Adding $user to $group"
                Add-ADGroupMember -Identity $group -Members $user -ErrorAction SilentlyContinue
            }
        }
    }
}
