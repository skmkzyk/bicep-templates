Function Set-VmSizeToNoTempDisk() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string] $ResourceGroupName,
        [Parameter(Mandatory = $true)] [string] $LocationName,
        [Parameter(Mandatory = $true)] [string] $VMName,
        [Parameter(Mandatory = $true)] [string] $VMSize
    )

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Change pagefile location for VM `"${VMName}`"."
    Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName -CommandId RunPowerShellScript -ScriptPath .\set-pagefile-location.ps1 | Out-Null

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Restart VM `"${VMName}`" to reflect changing pagefile location."
    Restart-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName | Out-Null

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Wait for VM `"${VMName}`" restart."
    $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
    $provisioningState = $VM.provisioningState
    while ($provisioningState -ne 'Succeeded') {
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Wait for another 5 seconds."
        Start-Sleep 5
        $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
        $provisioningState = $VM.provisioningState
    }

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Show delete option for VM `"${VMName}`"."
    $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
    $OsDiskDeleteOption = $VM.StorageProfile.OsDisk.DeleteOption
    $NetworkInterfacesDeleteOption = $VM.NetworkProfile.NetworkInterfaces[0].DeleteOption
    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - The delete option for StorageProfile.OsDisk.DeleteOption is `"${OsDiskDeleteOption}`"."
    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - The delete option for NetworkProfile.NetworkInterfaces[0].DeleteOption is `"${NetworkInterfacesDeleteOption}`"."

    if (($OsDiskDeleteOption -ne 'Detach') -or ($NetworkInterfacesDeleteOption -ne 'Detach')) {
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Change delete option for VM `"${VMName}`"."
        $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
        $VM.StorageProfile.OsDisk.DeleteOption = 'Detach'
        $VM.NetworkProfile.NetworkInterfaces[0].DeleteOption = 'Detach'
        Update-AzVM -ResourceGroupName $ResourceGroupName -VM $VM | Out-Null

        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Show delete option for VM `"${VMName}`"."
        $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
        $OsDiskDeleteOption = $VM.StorageProfile.OsDisk.DeleteOption
        $NetworkInterfacesDeleteOption = $VM.NetworkProfile.NetworkInterfaces[0].DeleteOption
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - The delete option for StorageProfile.OsDisk.DeleteOption is `"${OsDiskDeleteOption}`" for now."
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - The delete option for NetworkProfile.NetworkInterfaces[0].DeleteOption is `"${NetworkInterfacesDeleteOption}`" for now."
    } else {
        Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - The delete option is already set to `"Detach`" for OSDisk and NIC."
    }

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Get existing resource info to recreate VM `"${VMName}`"."
    $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
    $NIC = Get-AzResource -ResourceId $VM.NetworkProfile.NetworkInterfaces[0].Id
    Write-Verbose $($NIC | Out-String)
    $OSDisk = Get-AzDisk -DiskName $VM.StorageProfile.OsDisk.Name -ResourceGroupName $ResourceGroupName
    Write-Verbose $($OSDisk | Out-String)

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Delete exising VM `"${VMName}`" resource."
    Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName | Out-Null

    Write-Verbose "$(Get-Date -Format "h:MM:ss tt") - Recreate VM `"${VMName}`" from existing resource."
    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
    $VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $OSDisk.Id -Windows -CreateOption Attach
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable

    New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -DisableBginfoExtension | Out-Null
}
