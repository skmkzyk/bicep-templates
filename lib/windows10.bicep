param location string
param zones array = []

param subnetId string
param vmName string
param adminUsername string = 'ikko'
@secure()
param adminPassword string

param vmSize string = 'Standard_B2ms'
param privateIpAddress string = ''
param usePublicIP bool = false

@minValue(0)
param numberOfDataDisks int = 0

@allowed([
  ''
  'ConfidentialVM'
  'TrustedLaunch'
])
param securityType string = ''

var vmNameSuffix = replace(vmName, 'vm-', '')

resource pip 'Microsoft.Network/publicIPAddresses@2022-07-01' = if (usePublicIP) {
  name: 'pip-${vmNameSuffix}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    deleteOption: 'Delete'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
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
          privateIPAllocationMethod: privateIpAddress != '' ? 'Static' : 'Dynamic'
          privateIPAddress: privateIpAddress != '' ? privateIpAddress : null
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  zones: zones
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption: 'Delete'
      }
      dataDisks: [for i in range(0, numberOfDataDisks): {
        lun: i
        createOption: 'Attach'
        managedDisk: {
          id: dataDisks[i].id
        }
        deleteOption: 'Delete'
      }]
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-10'
        sku: 'win10-22h2-pro-g2'
        version: 'latest'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
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
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    licenseType: 'Windows_Client'
    securityProfile: securityType != '' ? {
      securityType: securityType
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    } : null
  }
}

resource dataDisks 'Microsoft.Compute/disks@2022-07-02' = [for i in range(0, numberOfDataDisks): {
  name: '${vmName}_DataDisk_${i}'
  location: location
  sku: {
    name: 'StandardSSD_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 32
  }
}]

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
