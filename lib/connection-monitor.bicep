param location string = 'eastasia'
param connectionMonitorName string
param srcVmName string
param soruceVmResouceGroup string
param dstVmName string
param dstVmResourceGroup string

resource srcVm 'Microsoft.Compute/virtualMachines@2021-03-01' existing = {
  scope: resourceGroup(soruceVmResouceGroup)
  name: srcVmName
}

resource dstVm 'Microsoft.Compute/virtualMachines@2021-03-01' existing = {
  scope: resourceGroup(dstVmResourceGroup)
  name: dstVmName
}

var srcVmEndpoints = [
  {
    name: '${srcVmName}(${soruceVmResouceGroup})'
    resourceId: srcVm.id
    type: 'AzureVM'
  }
]

var dstVmEndpoints = [
  {
    name: '${dstVmName}(${dstVmResourceGroup})'
    resourceId: dstVm.id
    type: 'AzureVM'
  }
]

var endpoints = concat(srcVmEndpoints, dstVmEndpoints)

resource connection_monitor 'Microsoft.Network/networkWatchers/connectionMonitors@2020-11-01' = {
  name: 'NetworkWatcher_eastasia/${connectionMonitorName}'
  location: location
  properties: {
    endpoints: endpoints
    testConfigurations: [
      {
        name: 'ssh'
        testFrequencySec: 30
        protocol: 'Tcp'
        successThreshold: {}
        tcpConfiguration: {
          port: 22
          disableTraceRoute: false
        }
      }
    ]
    testGroups: [
      {
        name: 'ssh'
        sources: [
          '${srcVmName}(${soruceVmResouceGroup})'
        ]
        destinations: [
          '${dstVmName}(${dstVmResourceGroup})'
        ]
        testConfigurations: [
          'ssh'
        ]
        disable: false
      }
    ]
  }
}
