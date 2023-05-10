param location string = 'eastasia'
param zones array = []

param subnetId string
param vmName string
param adminUsername string = 'ikko'
@secure()
param adminPassword string

param hostGroupId string = ''
param hostId string = ''
param vmSize string = 'Standard_B2ms'

@allowed([
  'PremiumV2_LRS'
  'Premium_LRS'
  'Premium_ZRS'
  'StandardSSD_LRS'
  'StandardSSD_ZRS'
  'Standard_LRS'
])
param storageAccountType string = 'StandardSSD_LRS'

param privateIpAddress string = ''
param enableNetworkWatcherExtention bool = false
param usePublicIP bool = false
param enableAcceleratedNetworking bool = false
param loadBalancerBackendAddressPoolId string = ''
param loadBalancerBackendAddressPools array = []

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
          publicIPAddress: usePublicIP ? { id: pip.id } : null
          loadBalancerBackendAddressPools: loadBalancerBackendAddressPools != [] ? loadBalancerBackendAddressPools : loadBalancerBackendAddressPoolId != '' ? [
            { id: loadBalancerBackendAddressPoolId }
          ] : []
        }
      }
    ]
    enableAcceleratedNetworking: enableAcceleratedNetworking
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  zones: zones
  properties: {
    hostGroup: hostGroupId != '' ? { id: hostGroupId } : null
    host: hostId != '' ? { id: hostId } : null
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storageAccountType
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

  resource NetworkWatcherExt 'extensions' = if (enableNetworkWatcherExtention) {
    name: 'AzureNetworkWatcherExtension'
    location: location
    properties: {
      autoUpgradeMinorVersion: true
      publisher: 'Microsoft.Azure.NetworkWatcher'
      type: 'NetworkWatcherAgentWindows'
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
