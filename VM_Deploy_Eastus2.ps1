# Azure Authentication and Context Setup
Connect-AzAccount
Set-AzContext -Subscription "a-prod-002"

# Input Variables
$region = Read-Host "Enter the Region for Deployment (e.g., eastus2)"
$computerName = Read-Host "Enter the Computer Name"
$tagValue2 = Read-Host "Enter Tag for APT-Customer"
$password = Read-Host "Enter the VM Local Admin's Password"
$subnetname = Read-Host "Enter the available Subnet Name"
$clientnumber = Read-Host "Enter the Client number"
$storageaccountneeded = Read-Host "Do you need to created a Storage Account? (Yes/No)"

# Resource Group and VNet Details
$resourceGroupName = "rg-$region-prd"
$Vnet = "vnet-$region-prd"
$subnetname = "snet-$region-prd-$subnetname"
$VMSize = "Standard_B4ms"
$storageAccountName = "strg$region" + "prd$clientnumber"
$publicIPname = "$computerName-PIP"
$nicname = "$computerName-NIC"
$securityType = "Standard"
$VMLocalAdminUser = "cloudops_admin"
$VMLocalAdminSecurePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($VMLocalAdminUser, $VMLocalAdminSecurePassword)
$tagKey1 = "APT-Product"
$tagValue1 = "Paragon R&S"
$tagValue3 = "Paragon-US"
$tags = @{$tagKey1 = $tagValue1; "APT-Customer" = $tagValue2; "Patching Mode" = $tagValue3}

# ASG and NSG Details
$asg1 = "asg-$region-prd-rds-session-host-servers"
$asg2 = "asg-$region-prd-ips"
$asg3 = "asg-$region-prd-dc"


# Fetch Existing Resources
$getVnet = Get-AzVirtualNetwork -Name $Vnet -ResourceGroupName $resourceGroupName



# Create Public IP Address
$newPublicIP = New-AzPublicIpAddress -Name $publicIPname `
    -ResourceGroupName $resourceGroupName `
    -Location "eastus2"`
    -AllocationMethod Static `
    -Sku Standard `
    -Tag $tags
$getPublicIPid = $newPublicIP.Id


switch ($storageaccountneeded.ToLower()) {
    "yes" { Write-Host "You chose to Create New Storage Account."
    New-AzStorageAccount -Name $storageAccountName `
    -ResourceGroupName $resourceGroupName `
    -Location "eastus2" `
    -SkuName "Standard_RAGRS" `
    -Kind "StorageV2"  `
    -AccessTier "Hot" `
    -Tag $tags }
    "no"  { Write-Host "You chose to use Exisiting Storage Account. Using $storageAccountName " }
    default { Write-Host "Invalid input. Please enter Yes or No." }
}


# Get Subnet ID and ASGs
$getSubnetId = ($getVnet.Subnets | Where-Object {$_.Name -eq $subnetname}).Id
$asg1Retrieved = Get-AzApplicationSecurityGroup -Name $asg1 -ResourceGroupName $resourceGroupName
$asg2Retrieved = Get-AzApplicationSecurityGroup -Name $asg2 -ResourceGroupName $resourceGroupName
$asg3Retrieved = Get-AzApplicationSecurityGroup -Name $asg3 -ResourceGroupName $resourceGroupName


# Create Network Interface with ASGs
$newNic = New-AzNetworkInterface -Name $nicname `
    -ResourceGroupName $resourceGroupName `
    -Location "eastus2" `
    -SubnetId $getSubnetId `
    -PublicIpAddressId $getPublicIPid

$newNic.IpConfigurations[0].ApplicationSecurityGroups = @($asg1Retrieved, $asg2Retrieved, $asg3Retrieved)
Set-AzNetworkInterface -NetworkInterface $newNic
$getNicId = $newNic.Id


# Create and Configure the VM
$vmConfig = New-AzVMConfig -VMName $computerName -VMSize $VMSize -SecurityType $securityType 
$vmConfig = Set-AzVMSourceImage -VM $vmConfig `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2019-Datacenter" `
    -Version "latest"
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $getNicId -Primary
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig `
    -Windows -ComputerName $computerName -Credential $cred -EnableAutoUpdate $false
$vmConfig = Set-AzVMOSDisk -VM $vmConfig `
    -Name "${computerName}_osdisk" -CreateOption FromImage -DiskSizeInGB 128 -Caching ReadWrite
#$vmConfig = Add-AzVMDataDisk -VM $vmConfig `
 #   -Name "${computerName}_datadisk_01" -DiskSizeInGB 32 -Lun 0 -Caching ReadOnly -CreateOption Empty
$vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
$vmConfig.OSProfile.WindowsConfiguration.EnableAutomaticUpdates = $false


# Deploy the VM
New-AzVM -ResourceGroupName $resourceGroupName -Location "eastus2" -VM $vmConfig -Tag $tags -DisableBginfoExtension -LicenseType "Windows_Server"

# Get the newly created VM
$getnewvm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $computerName
                             

Write-Output "VM '$computerName' deployed successfully in '$region'!"

$getvm = Get-AzVM -Name $computerName -ResourceGroupName $resourceGroupName
$getvmprovisioningstate = $getvm.ProvisioningState


if ($getvmprovisioningstate -like "Succeeded"){
    Set-AzVMBootDiagnostic -VM $getnewvm `
                        -ResourceGroupName $resourceGroupName `
                        -Enable `
                        -StorageAccountName $storageAccountName
Update-AzVM -ResourceGroupName $resourceGroupName -VM $getnewvm
$getnewvm.DiagnosticsProfile.BootDiagnostics
Write-Host "Boot diagnostics added successfully"
}
else {
    Write-Host "Provisioning state not succeded, delete if any resourses created"
}
