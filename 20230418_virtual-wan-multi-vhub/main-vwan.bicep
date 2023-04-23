param location01 string = resourceGroup().location
param location02 string = 'japanwest'

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

var vhub_number = range(0, 2)
var vnet_number = range(0, 2)

var branch_number = range(0, 14)
// var branch_number = [ 0, 1, 2, 3, 4, 5 ]

/* ****************************** Virtual Networks ****************************** */

resource vnets 'Microsoft.Network/virtualNetworks@2022-09-01' existing = [for i in vnet_number: {
  name: 'vnet${i * 10 + 200}'
}]

/* ****************************** ExpressRoute circuits ****************************** */

resource circuits 'Microsoft.Network/expressRouteCircuits@2022-09-01' existing = [for i in branch_number: {
  name: 'cct${i + 100}'
}]

/* ****************************** Virtual WAN ****************************** */

// var vwan00Name = 'vwan00'
// resource vwan00 'Microsoft.Network/virtualWans@2022-09-01' = {
//   name: vwan00Name
//   location: location01
//   properties: {
//     type: 'Standard'
//   }
// }

/* ****************************** Virtual Hubs ****************************** */

// resource vhubs_jpe 'Microsoft.Network/virtualHubs@2022-09-01' = [for i in vhub_number: {
//   name: 'vhub${padLeft(i, 2, '0')}'
//   location: location01
//   properties: {
//     addressPrefix: '10.${i * 10}.0.0/16'
//     virtualWan: {
//       id: vwan00.id
//     }
//     sku: 'Standard'
//   }
// }]

// resource vhubs_jpw 'Microsoft.Network/virtualHubs@2022-09-01' = [for i in range(3, 1): {
//   name: 'vhub${padLeft(i, 2, '0')}'
//   location: location02
//   properties: {
//     addressPrefix: '10.${i * 10}.0.0/16'
//     virtualWan: {
//       id: vwan00.id
//     }
//     sku: 'Standard'
//   }
// }]

resource defaultRouteTable 'Microsoft.Network/virtualHubs/routeTables@2022-09-01' existing = {
  name: 'defaultRouteTable'
  parent: vhubs[0]
}

// resource ergws_vhub 'Microsoft.Network/expressRouteGateways@2022-09-01' = [for i in range(0, 4): {
//   name: 'ergw${padLeft(i, 2, '0')}'
//   location: location01
//   properties: {
//     virtualHub: {
//       id: vhubs[i].id
//     }
//     autoScaleConfiguration: {
//       bounds: {
//         min: 1
//       }
//     }
//   }
// }]

resource ergws_vhub 'Microsoft.Network/expressRouteGateways@2022-09-01' existing = [for i in range(0, 3): {
  name: 'ergw${padLeft(i, 2, '0')}'
}]

// resource ergws_vhub_jpw 'Microsoft.Network/expressRouteGateways@2022-09-01' = [for i in range(3, 1): {
//   name: 'ergw${padLeft(i, 2, '0')}'
//   location: location02
//   properties: {
//     virtualHub: {
//       id: vhubs_jpw[i - 3].id
//     }
//     autoScaleConfiguration: {
//       bounds: {
//         min: 1
//       }
//     }
//   }
// }]

resource ergws_vhub_jpw 'Microsoft.Network/expressRouteGateways@2022-09-01' existing = [for i in range(3, 1): {
  name: 'ergw${padLeft(i, 2, '0')}'
}]

/* ****************************** VNet Peering for vHub and VNets ****************************** */

// resource vnet_peering_vhub 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2022-09-01' = [for i in vnet_number: {
//   name: 'conn-vhub00-${vnets[i].name}'
//   parent: vhubs_jpe[0]
//   properties: {
//     remoteVirtualNetwork: {
//       id: vnets[i].id
//     }
//     enableInternetSecurity: true
//   }
// }]

/* ****************************** ExpressRoute circuit connections for vHub ****************************** */

// var branch_for_vhub00 = [ 0, 1 ]

// @batchSize(1)
// resource connections_vhub00 'Microsoft.Network/expressRouteGateways/expressRouteConnections@2022-09-01' = [for i in branch_for_vhub00: {
//   // name: 'ergw00/ExRConnection-japaneast-1682146460861'
//   parent: ergws_vhub[0]
//   name: 'ExRConnection-${ergws_vhub[0].name}-${circuits[i].name}'
//   properties: {
//     expressRouteCircuitPeering: {
//       id: filter(circuits[i].properties.peerings, peering => peering.name == 'AzurePrivatePeering')[0].id
//     }
//   }
// }]

// var branch_for_vhub01 = [ 4, 5 ]

// @batchSize(1)
// resource connections_vhub01 'Microsoft.Network/expressRouteGateways/expressRouteConnections@2022-09-01' = [for i in branch_for_vhub01: {
//   parent: ergws_vhub[1]
//   name: 'ExRConnection-${ergws_vhub[1].name}-${circuits[i].name}'
//   properties: {
//     expressRouteCircuitPeering: {
//       id: filter(circuits[i].properties.peerings, peering => peering.name == 'AzurePrivatePeering')[0].id
//     }
//   }
// }]

// var branch_for_vhub02 = [ 8, 9 ]

// @batchSize(1)
// resource connections_vhub02 'Microsoft.Network/expressRouteGateways/expressRouteConnections@2022-09-01' = [for i in branch_for_vhub02: {
//   parent: ergws_vhub[2]
//   name: 'ExRConnection-${ergws_vhub[2].name}-${circuits[i].name}'
//   properties: {
//     expressRouteCircuitPeering: {
//       id: filter(circuits[i].properties.peerings, peering => peering.name == 'AzurePrivatePeering')[0].id
//     }
//   }
// }]

// var branch_for_vhub03 = [ 12, 13 ]

// @batchSize(1)
// resource connections_vhub03 'Microsoft.Network/expressRouteGateways/expressRouteConnections@2022-09-01' = [for i in branch_for_vhub03: {
//   parent: ergws_vhub_jpw[0]
//   name: 'ExRConnection-${ergws_vhub_jpw[0].name}-${circuits[i].name}'
//   properties: {
//     expressRouteCircuitPeering: {
//       id: filter(circuits[i].properties.peerings, peering => peering.name == 'AzurePrivatePeering')[0].id
//     }
//   }
// }]
