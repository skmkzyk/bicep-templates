param location01 string = resourceGroup().location

param circuit01 object

param sshKeyRGName string
param publicKeyName string

resource public_key 'Microsoft.Compute/sshPublicKeys@2022-03-01' existing = {
  name: publicKeyName
  scope: resourceGroup(sshKeyRGName)
}

param kvName string
param kvRGName string
param s2svpnSecretName string

resource kv 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: kvName
  scope: resourceGroup(kvRGName)
}

param default_securityRules array
param AzureBastionSubnet_additional_securityRules array

var useExisting = false

/* ****************************** hub00 ****************************** */

resource vnet_hub00 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-hub00'
  location: location01
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: { id: nsg_hub00_defaultSubnet.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.100.0/24'
          networkSecurityGroup: { id: nsg_hub00_AzureBastionSubnet.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.200.0/24'
        }
      }
      {
        name: 'RouteServerSubnet'
        properties: {
          addressPrefix: '10.0.210.0/24'
        }
      }
    ]
  }
}

resource nsg_hub00_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub00-default-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_hub00_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub00-AzureBastionSubnet-nsg-eastasia'
  location: location01
  properties: {
    securityRules: concat(default_securityRules, AzureBastionSubnet_additional_securityRules)
  }
}

var ergw00Name = 'ergw-hub00'
module ergw00 '../lib/ergw.bicep' = {
  name: ergw00Name
  params: {
    location: location01
    gatewayName: ergw00Name
    vnetName: vnet_hub00.name
    useExisting: useExisting
  }
}

var conn00Name = 'conn-hub00'
resource conn_hub00 'Microsoft.Network/connections@2022-01-01' = {
  name: conn00Name
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergw00.outputs.ergwId
    }
    peer: {
      id: circuit01.id
    }
    authorizationKey: circuit01.authorizationKey1
  }
}

var rs00Name = 'rs-hub00'
module rs_hub00 '../lib/route-server.bicep' = {
  name: rs00Name
  params: {
    location: location01
    routeServerName: rs00Name
    vnetName: vnet_hub00.name
    bgpConnections: [
      {
        name: vm_hub00.name
        ip: vm_hub00.outputs.privateIP
        asn: '65001'
      }
    ]
    useExisting: useExisting
  }
  dependsOn: [
    conn_hub00
  ]
}

// var bast00Name = 'bast-hub00'
// module bast00 '../lib/bastion.bicep' = {
//   name: bast00Name
//   params: {
//     location: location01
//     bastionName: bast00Name
//     vnetName: vnet_hub00.name
//   }
// }

var vm00Name = 'vm-hub00'
module vm_hub00 '../lib/ubuntu2004.bicep' = {
  name: vm00Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm00Name
    enableIPForwarding: true
    customData: loadFileAsBase64('./cloud-init.yml')
  }
}

/* ****************************** spoke10 ****************************** */

resource vnet_spoke10 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-spoke10'
  location: location01
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.10.0.0/24'
          networkSecurityGroup: { id: nsg_spoke10_defaultSubnet.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.10.200.0/24'
          routeTable: { id: rt_spoke10_GatewaySubnet.id }
        }
      }
    ]
  }
}

resource nsg_spoke10_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke10-default-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource rt_spoke10_GatewaySubnet 'Microsoft.Network/routeTables@2022-01-01' = {
  name: 'rt-spoke10-GatewaySubnet'
  location: location01
  properties: {
    routes: [
      {
        name: '10_100_20_1_32'
        properties: {
          addressPrefix: '10.100.20.1/32'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: vm_hub00.outputs.privateIP
        }
      }
    ]
  }
}

module peering_hub0010 '../lib/vnet-peering.bicep' = {
  name: 'peering-hub00-spoke10'
  params: {
    vnet01Name: vnet_hub00.name
    vnet02Name: vnet_spoke10.name
  }
}

var vpngw10Name = 'vpngw-spoke10'
module _vpngw_spoke10 '../lib/vpngw_act-act.bicep' = {
  name: vpngw10Name
  params: {
    location: location01
    gatewayName: vpngw10Name
    vnetName: vnet_spoke10.name
    enablePrivateIpAddress: true
    useExisting: useExisting
    bgpAsn: 65155
  }
}

var lng01Name = 'lng-onprem01'
resource lng_onprem01 'Microsoft.Network/localNetworkGateways@2022-05-01' = {
  name: lng01Name
  location: location01
  properties: {
    gatewayIpAddress: '10.100.20.1'
    bgpSettings: {
      asn: 65150
      bgpPeeringAddress: '10.100.20.1'
    }
  }
}

resource vpngw_spoke10 'Microsoft.Network/virtualNetworkGateways@2022-05-01' existing = {
  name: _vpngw_spoke10.outputs.vpngwName
}

var conn10Name = 'conn-spoke10-onprem01'
resource connection01 'Microsoft.Network/connections@2022-01-01' = {
  name: conn10Name
  location: location01
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: {
      id: vpngw_spoke10.id
    }
    connectionProtocol: 'IKEv2'
    localNetworkGateway2: {
      id: lng_onprem01.id
    }
    sharedKey: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
    useLocalAzureIpAddress: true
    enableBgp: true
  }
}

var vm10Name = 'vm-spoke10'
module vm_spoke10 '../lib/ubuntu2004.bicep' = {
  name: vm10Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_spoke10.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm10Name
  }
}
