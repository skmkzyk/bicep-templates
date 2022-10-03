param location string = 'eastasia'
param subnetId string
param vmName string
param adminUsername string = 'ikko'
@secure()
param adminPassword string
param enableNetWatchExtention bool = false

var vmNameSuffix = replace(vmName, 'vm-', '')

resource nic 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: 'nic-${vmNameSuffix}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ms'
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption: 'Delete'
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-datacenter-smalldisk-g2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }

  resource netWatchExt 'extensions' = if (enableNetWatchExtention) {
    name: 'AzureNetworkWatcherExtension'
    location: location
    properties: {
      autoUpgradeMinorVersion: true
      publisher: 'Microsoft.Azure.NetworkWatcher'
      type: 'NetworkWatcherAgentLinux'
      typeHandlerVersion: '1.4'
    }
  }
}

resource shutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '00:00'
    }
    timeZoneId: 'Tokyo Standard Time'
    targetResourceId: vm.id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}

output privateIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress
