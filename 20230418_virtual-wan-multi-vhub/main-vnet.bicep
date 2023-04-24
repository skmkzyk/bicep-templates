param location01 string = resourceGroup().location

param kvName string
param kvRGName string
param secretName string

resource kv 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: kvName
  scope: resourceGroup(kvRGName)
}

param sshKeyRGName string
param publicKeyName string

resource public_key 'Microsoft.Compute/sshPublicKeys@2022-03-01' existing = {
  name: publicKeyName
  scope: resourceGroup(sshKeyRGName)
}

param default_securityRules array
param AzureBastionSubnet_additional_securityRules array

var useExisting = false

var vnet_number = range(0, 2)

/* ****************************** Virtual Networks ****************************** */

resource vnets 'Microsoft.Network/virtualNetworks@2022-09-01' = [for i in vnet_number: {
  name: 'vnet${i * 10 + 200}'
  location: location01
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.${i * 10 + 200}.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.${i * 10 + 200}.0.0/24'
          networkSecurityGroup: { id: nsg_default.id }
          routeTable: { id: rt_vnet_defaultSubnet.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.${i * 10 + 200}.200.0/24'
        }
      }
      // {
      //   name: 'RouteServerSubnet'
      //   properties: {
      //     addressPrefix: '10.${i * 10 + 200}.210.0/24'
      //   }
      // }
    ]
  }
}]

resource nsg_default 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'vnet-default-nsg-${location01}'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource rt_vnet_defaultSubnet 'Microsoft.Network/routeTables@2022-01-01' = {
  name: 'rt-vnet-defaultSubnet'
  location: location01
  properties: {
    routes: [
      // 1st four branches are connected via Virtual WAN

      /* ****************************** 2rd four branches ****************************** */
      {
        name: '10_116_0_0_16'
        properties: {
          addressPrefix: '10.116.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.40.0.100'
        }
      }
      {
        name: '10_117_0_0_16'
        properties: {
          addressPrefix: '10.117.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.40.0.100'
        }
      }
      {
        name: '10_118_0_0_16'
        properties: {
          addressPrefix: '10.118.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.40.0.100'
        }
      }
      {
        name: '10_119_0_0_16'
        properties: {
          addressPrefix: '10.119.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.40.0.100'
        }
      }
      /* ****************************** 3rd four branches ****************************** */
      {
        name: '10_120_0_0_16'
        properties: {
          addressPrefix: '10.120.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.50.0.100'
        }
      }
      {
        name: '10_121_0_0_16'
        properties: {
          addressPrefix: '10.121.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.50.0.100'
        }
      }
      {
        name: '10_122_0_0_16'
        properties: {
          addressPrefix: '10.122.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.50.0.100'
        }
      }
      {
        name: '10_123_0_0_16'
        properties: {
          addressPrefix: '10.123.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.50.0.100'
        }
      }
      /* ****************************** 4th four branches ****************************** */
      {
        name: '10_124_0_0_16'
        properties: {
          addressPrefix: '10.124.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.60.0.100'
        }
      }
      {
        name: '10_125_0_0_16'
        properties: {
          addressPrefix: '10.125.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.60.0.100'
        }
      }
      {
        name: '10_126_0_0_16'
        properties: {
          addressPrefix: '10.126.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.60.0.100'
        }
      }
      {
        name: '10_127_0_0_16'
        properties: {
          addressPrefix: '10.127.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.60.0.100'
        }
      }
    ]
  }
}

// module rss_diy '../lib/route-server.bicep' = [for i in vnet_number: {
//   name: 'rs${padLeft(i * 10 + 200, 3, '0')}'
//   params: {
//     location: location01
//     routeServerName: 'rs${padLeft(i * 10 + 200, 3, '0')}'
//     vnetName: vnets[i].name
//     bgpConnections: [
//       {
//         name: 'nva40'
//         ip: '10.40.0.100'
//         asn: '65001'
//       }
//       {
//         name: 'nva50'
//         ip: '10.50.0.100'
//         asn: '65001'
//       }
//       {
//         name: 'nva60'
//         ip: '10.60.0.100'
//         asn: '65001'
//       }
//       {
//         name: 'nva70'
//         ip: '10.70.0.100'
//         asn: '65001'
//       }
//     ]
//     useExisting: useExisting
//   }
// }]

/* ****************************** Test Virtual Machines for VNet ****************************** */

module vms_vnets '../lib/ws2019.bicep' = [for i in vnet_number: {
  name: 'vm${i * 10 + 200}'
  params: {
    location: location01
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnets[i].properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: 'vm${i * 10 + 200}'
    privateIpAddress: '10.${i * 10 + 200}.0.10'
    enableNetworkWatcherExtention: true
  }
}]
