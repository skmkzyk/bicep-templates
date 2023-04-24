param location01 string = resourceGroup().location

resource connmon00 'Microsoft.Network/networkWatchers/connectionMonitors@2022-09-01' = {
  name: 'NetworkWatcher_japaneast/connmon00'
  location: location01
  properties: {
    endpoints: [
      /* ****************************** 1st four branches ****************************** */

      {
        name: 'vm100(vwan-multi-vhub)'
        type: 'AzureVM'
        resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm100')
      }
      {
        name: 'vm101(vwan-multi-vhub)'
        type: 'AzureVM'
        resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm101')
      }
      // {
      //   name: 'vm102(vwan-multi-vhub)'
      //   type: 'AzureVM'
      //   resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm102')
      // }
      // {
      //   name: 'vm103(vwan-multi-vhub)'
      //   type: 'AzureVM'
      //   resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm103')
      // }

      /* ****************************** 2nd four branches ****************************** */

      {
        name: 'vm116(vwan-multi-vhub)'
        type: 'AzureVM'
        resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm116')
      }
      {
        name: 'vm117(vwan-multi-vhub)'
        type: 'AzureVM'
        resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm117')
      }
      // {
      //   name: 'vm118(vwan-multi-vhub)'
      //   type: 'AzureVM'
      //   resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm118')
      // }
      // {
      //   name: 'vm119(vwan-multi-vhub)'
      //   type: 'AzureVM'
      //   resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm119')
      // }

      /* ****************************** 3rd four branches ****************************** */

      {
        name: 'vm120(vwan-multi-vhub)'
        type: 'AzureVM'
        resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm120')
      }
      {
        name: 'vm121(vwan-multi-vhub)'
        type: 'AzureVM'
        resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm121')
      }
      // {
      //   name: 'vm122(vwan-multi-vhub)'
      //   type: 'AzureVM'
      //   resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm122')
      // }
      // {
      //   name: 'vm123(vwan-multi-vhub)'
      //   type: 'AzureVM'
      //   resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm123')
      // }

      /* ****************************** 4th four branches ****************************** */

      // {
      //   name: 'vm124(vwan-multi-vhub)'
      //   type: 'AzureVM'
      //   resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm124')
      // }
      // {
      //   name: 'vm125(vwan-multi-vhub)'
      //   type: 'AzureVM'
      //   resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm125')
      // }
      // {
      //   name: 'vm126(vwan-multi-vhub)'
      //   type: 'AzureVM'
      //   resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm126')
      // }
      // {
      //   name: 'vm127(vwan-multi-vhub)'
      //   type: 'AzureVM'
      //   resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm127')
      // }

      /* ****************************** center VNets ****************************** */

      {
        name: 'vm200(vwan-multi-vhub)'
        type: 'AzureVM'
        resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm200')
      }
      {
        name: 'vm210(vwan-multi-vhub)'
        type: 'AzureVM'
        resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm210')
      }
      // {
      //   name: 'vm220(vwan-multi-vhub)'
      //   type: 'AzureVM'
      //   resourceId: resourceId('vwan-multi-vhub', 'Microsoft.Compute/virtualMachines', 'vm220')
      // }
    ]
    testConfigurations: [
      {
        name: 'rdp00'
        testFrequencySec: 30
        protocol: 'TCP'
        tcpConfiguration: {
          port: 3389
          disableTraceRoute: false
        }
      }
      {
        name: 'rdp01'
        testFrequencySec: 30
        protocol: 'TCP'
        tcpConfiguration: {
          port: 3389
          disableTraceRoute: false
        }
      }
    ]
    testGroups: [
      {
        name: 'tg00'
        disable: false
        testConfigurations: [
          'rdp00'
        ]
        sources: [
          'vm100(vwan-multi-vhub)'
          'vm101(vwan-multi-vhub)'
          // 'vm102(vwan-multi-vhub)'
          // 'vm103(vwan-multi-vhub)'
          'vm116(vwan-multi-vhub)'
          'vm117(vwan-multi-vhub)'
          // 'vm118(vwan-multi-vhub)'
          // 'vm119(vwan-multi-vhub)'
          'vm120(vwan-multi-vhub)'
          'vm121(vwan-multi-vhub)'
          // 'vm122(vwan-multi-vhub)'
          // 'vm123(vwan-multi-vhub)'
          // 'vm124(vwan-multi-vhub)'
          // 'vm125(vwan-multi-vhub)'
          // 'vm126(vwan-multi-vhub)'
          // 'vm127(vwan-multi-vhub)'
        ]
        destinations: [
          'vm200(vwan-multi-vhub)'
          'vm210(vwan-multi-vhub)'
          // 'vm220(vwan-multi-vhub)'
        ]
      }
      {
        name: 'tg01'
        disable: false
        testConfigurations: [
          'rdp01'
        ]
        sources: [
          'vm200(vwan-multi-vhub)'
          'vm210(vwan-multi-vhub)'
          // 'vm220(vwan-multi-vhub)'
        ]
        destinations: [
          'vm100(vwan-multi-vhub)'
          'vm101(vwan-multi-vhub)'
          // 'vm102(vwan-multi-vhub)'
          // 'vm103(vwan-multi-vhub)'
          'vm116(vwan-multi-vhub)'
          'vm117(vwan-multi-vhub)'
          // 'vm118(vwan-multi-vhub)'
          // 'vm119(vwan-multi-vhub)'
          'vm120(vwan-multi-vhub)'
          'vm121(vwan-multi-vhub)'
          // 'vm122(vwan-multi-vhub)'
          // 'vm123(vwan-multi-vhub)'
          // 'vm124(vwan-multi-vhub)'
          // 'vm125(vwan-multi-vhub)'
          // 'vm126(vwan-multi-vhub)'
          // 'vm127(vwan-multi-vhub)'
        ]
      }
    ]
    outputs: [
      {
        type: 'Workspace'
        workspaceSettings: {
          workspaceResourceId: resourceId('DefaultResourceGroup-EJP', 'Microsoft.OperationalInsights/workspaces', 'DefaultWorkspace-9e4d6321-d80d-4e43-8916-6f3b482d001d-EJP')
        }
      }
    ]
  }
}
