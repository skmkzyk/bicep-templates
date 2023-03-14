Function Set-VmSizeToNoTempDisk() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string] $ResourceGroupName,
        [Parameter(Mandatory = $true)] [string] $LocationName,
        [Parameter(Mandatory = $true)] [string] $VMName,
        [Parameter(Mandatory = $true)] [string] $VMSize
    )

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Change pagefile location for VM `"$($VMName)`"."
    Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName -CommandId RunPowerShellScript -ScriptPath .\set-pagefile-location.ps1 | Out-Null

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Restart VM `"$($VMName)`" to reflect changing pagefile location."
    Restart-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName | Out-Null

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Wait for VM `"$($VMName)`" restart."
    $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
    $provisioningState = $VM.provisioningState
    while ($provisioningState -ne 'Succeeded') {
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Wait for another 5 seconds."
        Start-Sleep 5
        $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
        $provisioningState = $VM.provisioningState
    }

    $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
    $needsUpdateDeleteOption = $false

    if ($VM.StorageProfile.OsDisk.DeleteOption -ne 'Detach') {
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Needs to change delete option for VM `"$($VMName)`" OsDisk."
        $VM.StorageProfile.OsDisk.DeleteOption = 'Detach'
        $needsUpdateDeleteOption = $true
    } else {
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - The delete option is already set to `"Detach`" for OSDisk."
    }

    $VM.StorageProfile.DataDisks | Foreach-Object -Begin { $i = 0 } -Process {
        if ($_.DeleteOption -ne 'Detach') {
            Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Needs to change delete option for VM `"$($VMName)`" DataDisk[$($i)]."
            $_.DeleteOption = 'Detach'
            $needsUpdateDeleteOption = $true
        } else {
            Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - The delete option is already set to `"Detach`" for DataDisk[$($i)]."
        }
        $i++
    }

    if ($VM.NetworkProfile.NetworkInterfaces[0].DeleteOption -ne 'Detach') {
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Needs to change delete option for VM `"$($VMName)`" NetworkInterfaces[0]."
        $VM.NetworkProfile.NetworkInterfaces[0].DeleteOption = 'Detach'
        $needsUpdateDeleteOption = $true
    } else {
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - The delete option is already set to `"Detach`" for NetworkInterfaces[0]."
    }

    if ($needsUpdateDeleteOption) {
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Change delete option for VM `"$($VMName)`"."
        Update-AzVM -ResourceGroupName $ResourceGroupName -VM $VM | Out-Null

        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Show delete option for VM `"$($VMName)`"."
        $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - The delete option for StorageProfile.OsDisk.DeleteOption is `"$($VM.StorageProfile.OsDisk.DeleteOption)`" for now."
        $VM.StorageProfile.DataDisks | Foreach-Object -Begin { $i = 0 } -Process {
            Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - The delete option for StorageProfile.DataDisks[$($i)].DeleteOption is `"$($_.DeleteOption)`" for now."
            $i++
        }
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - The delete option for NetworkProfile.NetworkInterfaces[0].DeleteOption is `"$($VM.NetworkProfile.NetworkInterfaces[0].DeleteOption)`" for now."
    }

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Get existing resource info to recreate VM `"$($VMName)`"."
    $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
    $NIC = Get-AzResource -ResourceId $VM.NetworkProfile.NetworkInterfaces[0].Id
    $OSDisk = Get-AzDisk -DiskName $VM.StorageProfile.OsDisk.Name -ResourceGroupName $ResourceGroupName
    $DataDisks = @()
    $VM.StorageProfile.DataDisks | ForEach-Object {
        $DataDisks += Get-AzDisk -DiskName $_.Name -ResourceGroupName $ResourceGroupName
    }

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Delete exising VM `"$($VMName)`" resource."
    Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName | Out-Null

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Recreate VM `"$($VMName)`" from existing resource."
    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
    $VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $OSDisk.Id -Windows -CreateOption Attach
    $DataDisks | ForEach-Object -Begin { $i = 0 } -Process {
        $VirtualMachine = Add-AzVMDataDisk -VM $VirtualMachine -Name $_.Name -CreateOption Attach -ManagedDiskId $_.Id -Lun $i
        $i++
    }
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVmUefi -VM $VirtualMachine -EnableVtpm $true -EnableSecureBoot $true
    $VirtualMachine = Set-AzVmSecurityProfile -VM $VirtualMachine -SecurityType "TrustedLaunch"
    $VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable

    New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -DisableBginfoExtension | Out-Null
}
