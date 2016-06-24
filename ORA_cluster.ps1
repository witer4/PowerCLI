<####################################################################################################
Title:			ORA cluster nodes deployment script
Description:	This script is to create customerized oracle VMs
Requirements:	PowerCLI 5.5
Author:		    
Date:			6/20/2016
Version:		V1.1
Update:			
####################################################################################################>

Clear-Host
# Verify PowerCLI version
if((Get-PowerCLIVersion).Major -ne 6){
	if(((Get-PowerCLIVersion).Major -eq 5) -and ((Get-PowerCLIVersion).minor -lt 5)) {
		Write-Host "PowerCLI is required at least 5.5, please upgrade it !"
		Start-Process -FilePath 'http://communities.vmware.com/community/vmtn/server/vsphere/automationtools/powercli'
			exit
	}
	elseif((Get-PowerCLIVersion).Major -lt 5){
		Write-Host "PowerCLI is required at least 5.5, please upgrade it !"
		Start-Process -FilePath 'http://communities.vmware.com/community/vmtn/server/vsphere/automationtools/powercli'
			exit
	}
	else{}
}

$FileLocation = Read-Host "Please Enter Complete Path of CSV file name"
if (!$FileLocation)
{
	$FileLocation=".\Nodeinfo.csv"
}


$date = ((Get-Date).ToString("MMddyyyyHHmm"))
$vmdatastore=".\vmdatastore$date.csv"
Set-Content -Path $vmdatastore "vmName,CapacityGB,FileName,DiskNumber"
$nodelist = Import-CSV $FileLocation

function ChangeSCSIID
{
	param([string]$strVMToUpdate,[int]$id)

	# get the VM
	$vmToUpdate = Get-VM $strVMToUpdate
	# get the hard disk to change
	$hdskToChange = Get-HardDisk -VM $vmToUpdate -Name "Hard disk $id"

	# create a new VirtualMachineConfigSpec, with which to make the change to the VM's disk
	$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	# create a new VirtualDeviceConfigSpec
	$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
	$spec.deviceChange[0].operation = "edit"
	# populate the "device" property with the existing info from the hard disk to change
	$spec.deviceChange[0].device = $hdskToChange.ExtensionData

	# then, change the second part of the SCSI ID (the UnitNumber)
	$spec.deviceChange[0].device.unitNumber = 0
	# reconfig the VM with the updated ConfigSpec (VM must be powered off)
	$vmToUpdate.ExtensionData.ReconfigVM_Task($spec) |out-null

}

function MultiWriter
{

	param([string]$vmname,[int]$id)
	
	$diskName = "Hard disk "+"$id"
	Write-Host "Configuring Multiwriter on $diskName..." -ForegroundColor Cyan 
	# Retrieve VM and only its Devices

	$vmview = Get-View -VIobject $vmname -Property Name,Config.Hardware.Device
	# Array of Devices on VM
	$vmDevices = $vmview.Config.Hardware.Device

	# Find the Virtual Disk that we care about
	foreach ($device in $vmDevices) {
		if($device -is  [VMware.Vim.VirtualDisk] -and $device.deviceInfo.Label -eq $diskName) {
			$diskDevice = $device
			$diskDeviceBaking = $device.backing
			break
		}
	}

	# Create VM Config Spec
	$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
	$spec.deviceChange[0].operation = 'edit'
	$spec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
	$spec.deviceChange[0].device = $diskDevice
	$spec.DeviceChange[0].device.backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
	$spec.DeviceChange[0].device.backing = $diskDeviceBaking
	$spec.DeviceChange[0].device.Backing.Sharing = "sharingMultiWriter"

	#Write-Host "`nEnabling Multiwriter flag on on VMDK:" $diskName "for VM:" $vmname -BackgroundColor yellow
	$task = $vmview.ReconfigVM_Task($spec)
	$task1 = Get-Task -Id ("Task-$($task.value)")
	sleep 5
	$task1 | Wait-Task
	

}

$MemorySize = 24576
$CPUSize = 2

foreach($rec in $nodelist){
	$vm = $rec.vmname
	$node = $rec.nodenumber
	$template = $rec.template
	$datastoreSAN = $rec.DatastoreSAN
	$datastoreNFS = $rec.DatastoreNFS
	$cluster = $rec.cluster
	$OSCustomization = $rec.oscustomization
	$pg1 = $rec.portgroup1
	$IP1 = $rec.externalip
	$mask1 = $rec.externalmask
	$gw1 = $rec.externalgateway
	$pg2 = $rec.portgroup2
	$IP2 = $rec.heartbeatip
	$mask2 = $rec.heartbeatmask
	$gw2 = $rec.heartbeatgateway
	$size= @()
	$size += $rec.disk1
	$size += $rec.disk2
	$size += $rec.disk3
	$size += $rec.disk4
	$size += $rec.disk5
	$size += $rec.disk6
	$size += $rec.disk7
	$size += $rec.disk8
	$size += $rec.disk9
	$size += $rec.disk10
	$size += $rec.disk11
	$size += $rec.disk12
	$size += $rec.disk13
	$size += $rec.disk14
	$size += $rec.disk15
	$size += $rec.disk16

	#create VM
	Write-Host "Start to create VM $vm ..." -ForegroundColor Cyan
	#Assign NIC IP to the customization
	$mySpecification = Get-OSCustomizationSpec $OSCustomization
	Get-OSCustomizationNicMapping $OSCustomization | where { $_.Position -eq '1'}  |set-OSCustomizationNicMapping -IpMode UseStaticIP -IPaddress $IP1 -SubnetMask $mask1 -DefaultGateway $gw1 
	Get-OSCustomizationNicMapping $OSCustomization | where { $_.Position -eq '2'}  |set-OSCustomizationNicMapping -IpMode UseStaticIP -IPaddress $IP2 -SubnetMask $mask2 -DefaultGateway $gw2 
	
	New-vm -Name $vm -ResourcePool $cluster  -Template $template -Datastore $datastoreSAN -OSCustomizationspec $mySpecification
	
	Write-Host "Start to configure VM $vm ..." -ForegroundColor Cyan
	set-vm $vm  -MemoryMB $MemorySize -Numcpu $CPUSize -Confirm:$false
	
	get-vm $vm |get-networkadapter | where { $_.Name -like '*1'}| Set-NetworkAdapter -NetworkName $pg1 -StartConnected:$true -Confirm:$false
		#get-vm $vm |get-networkadapter | where { $_.Name -like '*1'}| Set-NetworkAdapter -NetworkName $pg1 -StartConnected:$true -Confirm:$false
	get-vm $vm |get-networkadapter | where { $_.Name -like '*2'}| Set-NetworkAdapter -NetworkName $pg2 -StartConnected:$true -Confirm:$false
	
	$diskID = 1
	$vm = get-vm $vm 
	
	Get-HardDisk -VM $vm | Set-HardDisk -CapacityGB $size[$diskID-1] -confirm:$false
	$diskID ++
	Write-Host "Creating Hard disk $diskID..." -ForegroundColor Cyan
	New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick
	$diskID ++
	Write-Host "Creating Hard disk $diskID..." -ForegroundColor Cyan
	New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick
	$diskID ++
	Write-Host "Creating Hard disk $diskID..." -ForegroundColor Cyan
	#disk 4
	$hd = New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick
	$ctrl1 = New-ScsiController -Type ParaVirtual -BusSharingMode NoSharing $hd
	
	ChangeSCSIID $vm $diskID
	sleep 5
	$diskID ++
	Write-Host "Creating Hard disk $diskID..." -ForegroundColor Cyan 	
	New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick -Controller $ctrl1
	$diskID ++
	New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick -Controller $ctrl1
	$diskID ++

	if($node -eq 1){
		#disk 7
		Write-Host "Creating Hard disk $diskID..." -ForegroundColor Cyan 
		$hd = New-HardDisk -vm $vm -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick
		$ctrl2 = New-ScsiController -Type ParaVirtual -BusSharingMode NoSharing $hd
		sleep 5		
		ChangeSCSIID $vm $diskID
		MultiWriter $vm $diskID
		$diskID ++
		
		New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick -Controller $ctrl2
		MultiWriter $vm $diskID
		$diskID ++
		New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick -Controller $ctrl2
		MultiWriter $vm $diskID
		$diskID ++
		New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick -Controller $ctrl2
		MultiWriter $vm $diskID
		$diskID ++
		New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick -Controller $ctrl2
		MultiWriter $vm $diskID
		$diskID ++
		#disk 12
		
	
		
		New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick -Controller $ctrl2
		MultiWriter $vm $diskID
		$diskID ++
				
		New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick -Controller $ctrl2
		MultiWriter $vm $diskID
		$diskID ++
		New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick -Controller $ctrl2
		MultiWriter $vm $diskID
		$diskID ++
	
		Write-Host "Creating Hard Disk $diskID" -ForegroundColor Cyan 
			$hd = New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1] -StorageFormat EagerZeroedThick
		$ctrl3 = New-ScsiController -Type ParaVirtual -BusSharingMode NoSharing $hd
		sleep 5
		MultiWriter $vm $diskID		
		ChangeSCSIID $vm $diskID
		$diskID ++
		#NFS...
		New-HardDisk -vm $vm -DiskType flat -CapacityGB $size[$diskID-1]  -ThinProvisioned -Controller $ctrl3 -Datastore $datastoreNFS
		$Diskpath = Get-HardDisk -vm $vm | select filename,name
	}
	
	else{
		for ($diskID=7; $diskID -le $Diskpath.length)
		{
			if(($diskID -eq 7) -or ($diskID -eq 15)){
				Write-Host "Creating Hard disk $diskID..." -ForegroundColor Cyan 
				$hd = New-HardDisk -vm $vm -diskpath $Diskpath[$diskID-1].filename -Controller $ctrl
				$ctrl = New-ScsiController -Type ParaVirtual -BusSharingMode NoSharing $hd
				MultiWriter $vm $diskID
				ChangeSCSIID $vm $diskID
				$diskID ++
				sleep 5
			}
			elseif($diskID -eq 16){
				Write-Host "Creating Hard disk $diskID..." -ForegroundColor Cyan 
				new-harddisk -vm $vm -diskpath $Diskpath[$diskID-1].filename -Controller $ctrl
				$diskID ++
				#MultiWriter $vm $diskID
			}
			else{
				Write-Host "Creating Hard disk $diskID..." -ForegroundColor Cyan 
				new-harddisk -vm $vm -diskpath $Diskpath[$diskID-1].filename -Controller $ctrl
				MultiWriter $vm $diskID
				$diskID ++
			}
		}
		
	}
	
	#configure vmx file
	New-AdvancedSetting -Entity $vm -Name ctkDisallowed -Value true -Confirm:$false -Force:$true |out-null
	New-AdvancedSetting -Entity $vm -Name disk.EnableUUID -Value true -Confirm:$false -Force:$true |out-null

	#check disk information and export to a csv file
	$vmview = Get-View -VIobject $vm	
	$diskdata=get-harddisk -vm $vm | select Filename,name
	
	$diskinfo = $cpgb = @()
	foreach ($VirtualSCSIController in ($vmview.Config.Hardware.Device | where {$_.DeviceInfo.Label -match "SCSI Controller"})) {
	 foreach ($VirtualDiskDevice in ($vmview.Config.Hardware.Device | where {$_.ControllerKey -eq $VirtualSCSIController.Key})) {
	 	$CapacityInGB = $VirtualDiskDevice.CapacityInKB/1024/1024
		$diskinfotmp = "SCSI " + "$($VirtualSCSIController.BusNumber):$($VirtualDiskDevice.UnitNumber) "+ $VirtualDiskDevice.DeviceInfo.Label 
		$DIL = $VirtualDiskDevice.DeviceInfo.Label
		$diskl = $diskdata | where {$_.name -eq "$DIL"}
		$disklabel = $diskl.filename
		$diskinfo = $diskinfotmp
		$cpgb = $CapacityInGB
		Add-Content -Path $vmdatastore "$vm,$cpgb,$disklabel,$diskinfo"
	 }
	}

	Write-Host "Completed $vm configuration" -ForegroundColor green
	
}

Invoke-Item .\$vmdatastore
