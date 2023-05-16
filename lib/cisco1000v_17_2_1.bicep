param location string
param zones array = []

param subnetId string
param vmName string
param adminUsername string = 'ikko'
param keyData string

param hostGroupId string = ''
param hostId string = ''
param vmSize string = 'Standard_B2ms'
param enableManagedIdentity bool = false
param privateIpAddress string = ''
param customData string = ''
param enableIPForwarding bool = false
param usePublicIP bool = false
param enableAcceleratedNetworking bool = false
param avsetId string = ''
param applicationGatewayBackendAddressPoolsId string = ''
param loadBalancerBackendAddressPoolsId string = ''

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

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  identity: enableManagedIdentity ? { type: 'SystemAssigned' } : null
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
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption: 'Delete'
      }
      imageReference: {
        publisher: 'cisco'
        offer: 'cisco-csr-1000v'
        sku: '17_2_1-byol'
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
output principalId string = enableManagedIdentity ? vm.identity.principalId : ''
