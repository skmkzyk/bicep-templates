param location01 string = 'eastasia'

param circuit01 object

param kvName string
param kvRGName string
param secretName string

param sshKeyRGName string

param isInitialDeploy bool = false
var useExisting = !isInitialDeploy

param publicKeyName string

resource kv 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: kvName
  scope: resourceGroup(kvRGName)
}

resource public_key 'Microsoft.Compute/sshPublicKeys@2022-03-01' existing = {
  name: publicKeyName
  scope: resourceGroup(sshKeyRGName)
}

param default_securityRules array
param AzureBastionSubnet_additional_securityRules array

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
          routeTable: { id: rt_hub00_defaultSubnet.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.200.0/24'
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

resource rt_hub00_defaultSubnet 'Microsoft.Network/routeTables@2022-01-01' = {
  name: 'rt-defaultSubnet-hub00'
  location: location01
  properties: {
    routes: [
      {
        name: '0_0_0_0_0'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'Internet'
        }
      }
    ]
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

var vm00Name = 'vm-hub00'
module vm_hub00 '../lib/ws2019.bicep' = {
  name: vm00Name
  params: {
    location: location01
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm00Name
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
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.10.100.0/24'
          networkSecurityGroup: { id: nsg_spoke10_AzureBastionSubnet.id }
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
resource nsg_spoke10_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke10-AzureBastionSubnet-nsg-eastasia'
  location: location01
  properties: {
    securityRules: concat(default_securityRules, AzureBastionSubnet_additional_securityRules)
  }
}

var bast10Name = 'bast-spoke10'
module bast10 '../lib/bastion.bicep' = {
  name: bast10Name
  params: {
    location: location01
    bastionName: bast10Name
    vnetName: vnet_spoke10.name
  }
}

module peering_hub0010 '../lib/vnet-peering.bicep' = {
  name: 'peering-hub00-spoke10'
  params: {
    vnet01Name: vnet_hub00.name
    vnet02Name: vnet_spoke10.name
  }
}

/* ****************************** hub100 ****************************** */

resource vnet_hub100 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-hub100'
  location: location01
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.100.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.100.0.0/24'
          networkSecurityGroup: { id: nsg_hub100_defaultSubnet.id }
          routeTable: { id: rt_hub100_defaultSubnet.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.100.200.0/24'
        }
      }
      {
        name: 'RouteServerSubnet'
        properties: {
          addressPrefix: '10.100.210.0/24'
        }
      }
    ]
  }
}

resource nsg_hub100_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub100-default-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource rt_hub100_defaultSubnet 'Microsoft.Network/routeTables@2022-01-01' = {
  name: 'rt-defaultSubnet-hub100'
  location: location01
  properties: {
    routes: [
      {
        name: '0_0_0_0_0'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

var ergw100Name = 'ergw-hub100'
module ergw100 '../lib/ergw.bicep' = {
  name: ergw100Name
  params: {
    location: location01
    gatewayName: ergw100Name
    vnetName: vnet_hub100.name
    useExisting: useExisting
  }
}

var conn100Name = 'conn-hub100'
resource conn_hub100 'Microsoft.Network/connections@2022-01-01' = {
  name: conn100Name
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergw100.outputs.ergwId
    }
    peer: {
      id: circuit01.id
    }
    authorizationKey: circuit01.authorizationKey2
  }
  dependsOn: [
    conn_hub00
  ]
}

var rs100Name = 'rs-hub100'
module rs100 '../lib/route-server.bicep' = {
  name: rs100Name
  params: {
    location: location01
    routeServerName: rs100Name
    vnetName: vnet_hub100.name
    bgpConnections: [
      {
        name: vm_hub00.name
        ip: vm_hub100.outputs.privateIP
        asn: '65001'
      }
    ]
    useExisting: useExisting
  }
  dependsOn: [
    conn_hub100
  ]
}

var vm100Name = 'vm-nva100'
module vm_hub100 '../lib/ubuntu2004.bicep' = {
  name: vm100Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub100.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm100Name
  }
}

var vm101Name = 'vm-proxy100'
module vm_hub101 '../lib/ubuntu2004.bicep' = {
  name: vm101Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub100.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm101Name
  }
}

/* ****************************** spoke110 ****************************** */

resource vnet_spoke110 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-spoke110'
  location: location01
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.110.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.110.0.0/24'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.110.100.0/24'
          networkSecurityGroup: { id: nsg_spoke110_AzureBastionSubnet.id }
        }
      }
    ]
  }

  resource defaultSubnet 'subnets' existing = {
    name: 'default'
  }
}

resource nsg_spoke110_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke110-AzureBastionSubnet-nsg-eastasia'
  location: location01
  properties: {
    securityRules: concat(default_securityRules, AzureBastionSubnet_additional_securityRules)
  }
}

var bast110Name = 'bast-spoke110'
module bast110 '../lib/bastion.bicep' = {
  name: bast110Name
  params: {
    location: location01
    bastionName: bast110Name
    vnetName: vnet_spoke110.name
  }
}

module peering_hub100110 '../lib/vnet-peering.bicep' = {
  name: 'peering-hub100-spoke110'
  params: {
    vnet01Name: vnet_hub100.name
    vnet02Name: vnet_spoke110.name
  }
}
