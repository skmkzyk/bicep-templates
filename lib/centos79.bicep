param location string = 'eastasia'
param zones array = []

param subnetId string
param vmName string
param adminUsername string = 'ikko'
param keyData string

param vmSize string = 'Standard_B2ms'
param privateIpAddress string = ''
param customData string = ''
param enableNetWatchExtention bool = false
param enableIPForwarding bool = false
param usePublicIP bool = false
param enableAcceleratedNetworking bool = false
param avsetId string = ''
param applicationGatewayBackendAddressPoolsId string = ''
param loadBalancerBackendAddressPoolsId string = ''

var vmNameSuffix = replace(vmName, 'vm-', '')

resource pip 'Microsoft.Network/publicIPAddresses@2022-01-01' = if (usePublicIP) {
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
          privateIPAllocationMethod: privateIpAddress != '' ? 'Static' : 'Dynamic'
          privateIPAddress: privateIpAddress != '' ? privateIpAddress : null
          publicIPAddress: usePublicIP ? { id: pip.id } : null
          loadBalancerBackendAddressPools: loadBalancerBackendAddressPoolsId != '' ? [
            { id: loadBalancerBackendAddressPoolsId }
          ] : []
          applicationGatewayBackendAddressPools: applicationGatewayBackendAddressPoolsId != '' ? [
            { id: applicationGatewayBackendAddressPoolsId }
          ] : []
        }
      }
    ]
    enableIPForwarding: enableIPForwarding
    enableAcceleratedNetworking: enableAcceleratedNetworking
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
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
      imageReference: {
        publisher: 'OpenLogic'
        offer: 'CentOS'
        sku: '7_9-gen2'
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
      customData: customData == '' ? null : customData
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: keyData
            }
          ]
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    availabilitySet: avsetId == '' ? null : { id: avsetId }
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

output vmName string = vm.name
output vmId string = vm.id
output nicName string = nic.name
output privateIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress
