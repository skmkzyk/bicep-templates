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

var vnet_number = range(4, 2)
var vnet_number_offset = 4
var branch_number = range(0, 32)

resource nsg_default 'Microsoft.Network/networkSecurityGroups@2022-09-01' existing = {
  name: 'vnet-default-nsg-${location01}'
}

resource circuits 'Microsoft.Network/expressRouteCircuits@2022-09-01' existing = [for i in branch_number: {
  name: 'cct${i + 100}'
}]

resource vnet200 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  name: 'vnet200'
}

resource vnet210 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  name: 'vnet210'
}

resource vnet220 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  name: 'vnet220'
}

/* ****************************** DIY Virtual Networks ****************************** */

resource vnets_diy 'Microsoft.Network/virtualNetworks@2022-09-01' = [for i in vnet_number: {
  name: 'vnet${padLeft(i * 10, 3, '0')}'
  location: location01
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.${i * 10}.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.${i * 10}.0.0/24'
          networkSecurityGroup: { id: nsg_default.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.${i * 10}.100.0/24'
          networkSecurityGroup: { id: nsg_hub00_AzureBastionSubnet.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.${i * 10}.200.0/24'
        }
      }
      {
        name: 'RouteServerSubnet'
        properties: {
          addressPrefix: '10.${i * 10}.210.0/24'
        }
      }
    ]
  }
}]

resource nsg_hub00_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: 'vnet-hub00-AzureBastionSubnet-nsg-eastasia'
  location: location01
  properties: {
    securityRules: concat(default_securityRules, AzureBastionSubnet_additional_securityRules)
  }
}

module peerings_diy200 '../lib/vnet-peering.bicep' = [for i in vnet_number: {
  name: 'peering-${vnets_diy[i - vnet_number_offset].name}-${vnet200.name}'
  params: {
    vnet01Name: vnets_diy[i - vnet_number_offset].name
    vnet02Name: vnet200.name
  }
}]

module peerings_diy210 '../lib/vnet-peering.bicep' = [for i in vnet_number: {
  name: 'peering-${vnets_diy[i - vnet_number_offset].name}-${vnet210.name}'
  params: {
    vnet01Name: vnets_diy[i - vnet_number_offset].name
    vnet02Name: vnet210.name
  }
}]

// module peerings_diy220 '../lib/vnet-peering.bicep' = [for i in vnet_number: {
//   name: 'peering-${vnets_diy[i - vnet_number_offset].name}-${vnet220.name}'
//   params: {
//     vnet01Name: vnets_diy[i - vnet_number_offset].name
//     vnet02Name: vnet220.name
//   }
// }]

/* ****************************** ExpressRoute Gateways for DIY VNet ****************************** */

module ergws_diy '../lib/ergw.bicep' = [for i in vnet_number: {
  name: 'ergw${padLeft(i * 10, 3, '0')}'
  params: {
    location: location01
    gatewayName: 'ergw${padLeft(i * 10, 3, '0')}'
    vnetName: vnets_diy[i - vnet_number_offset].name
    useExisting: useExisting
  }
}]

/* ****************************** ExpressRoute circuit connections for DIY VNet ****************************** */

@batchSize(1)
resource connections_diy40 'Microsoft.Network/connections@2022-09-01' = [for i in [ 16, 17, 18, 19 ]: {
  name: 'conn-${ergws_diy[0].name}-${circuits[i].name}'
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergws_diy[0].outputs.ergwId
    }
    peer: {
      id: circuits[i].id
    }
  }
}]

@batchSize(1)
resource connections_diy50 'Microsoft.Network/connections@2022-09-01' = [for i in [ 20, 21, 22, 23 ]: {
  name: 'conn-${ergws_diy[1].name}-${circuits[i].name}'
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergws_diy[1].outputs.ergwId
    }
    peer: {
      id: circuits[i].id
    }
  }
}]

// @batchSize(1)
// resource connections_diy60 'Microsoft.Network/connections@2022-09-01' = [for i in [ 24, 25, 26, 27 ]: {
//   name: 'conn-${ergws_diy[2].name}-${circuits[i].name}'
//   location: location01
//   properties: {
//     connectionType: 'ExpressRoute'
//     virtualNetworkGateway1: {
//       id: ergws_diy[2].outputs.ergwId
//     }
//     peer: {
//       id: circuits[i].id
//     }
//   }
// }]

// @batchSize(1)
// resource connections_diy70 'Microsoft.Network/connections@2022-09-01' = [for i in [ 28, 29, 30, 31 ]: {
//   name: 'conn-${ergws_diy[3].name}-${circuits[i].name}'
//   location: location01
//   properties: {
//     connectionType: 'ExpressRoute'
//     virtualNetworkGateway1: {
//       id: ergws_diy[3].outputs.ergwId
//     }
//     peer: {
//       id: circuits[i].id
//     }
//   }
// }]

module rss_diy '../lib/route-server.bicep' = [for i in vnet_number: {
  name: 'rs${padLeft(i * 10, 3, '0')}'
  params: {
    location: location01
    routeServerName: 'rs${padLeft(i * 10, 3, '0')}'
    vnetName: vnets_diy[i - vnet_number_offset].name
    bgpConnections: [
      {
        name: nva_dyi[i - vnet_number_offset].name
        ip: nva_dyi[i - vnet_number_offset].outputs.privateIP
        asn: '65001'
      }
    ]
    useExisting: useExisting
  }
  dependsOn: [
    connections_diy40
    connections_diy50
    // connections_diy60
    // connections_diy70
  ]
}]

module basts_diy '../lib/bastion.bicep' = [for i in vnet_number: {
  name: 'bast${i * 10}'
  params: {
    location: location01
    bastionName: 'bast${i * 10}'
    vnetName: vnets_diy[i - vnet_number_offset].name
  }
}]

/* ****************************** Test Virtual Machines for DIY VNet ****************************** */

// module vms_diy '../lib/ws2019.bicep' = [for i in vnet_number: {
//   name: 'vm${i * 10}'
//   params: {
//     location: location01
//     adminPassword: kv.getSecret(secretName)
//     subnetId: filter(vnets_diy[i - vnet_number_offset].properties.subnets, subnet => subnet.name == 'default')[0].id
//     vmName: 'vm${i * 10}'
//     privateIpAddress: '10.${i * 10}.0.10'
//     enableNetworkWatcherExtention: true
//   }
// }]

/* ****************************** NVA Virtual Machines for DIY VNet ****************************** */

module nva_dyi '../lib/ubuntu2004.bicep' = [for i in vnet_number: {
  name: 'nva${i * 10}'
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnets_diy[i - vnet_number_offset].properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: 'nva${i * 10}'
    enableIPForwarding: true
    privateIpAddress: '10.${i * 10}.0.100'
  }
}]
