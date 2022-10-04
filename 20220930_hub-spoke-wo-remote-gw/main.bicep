param location01 string = 'eastasia'

param circuit01 object
param circuit02 object

param sshKeyRGName string

param isInitialDeploy bool = false
var useExisting = !isInitialDeploy

param publicKeyName string

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
          routeTable: { id: rt_hub00_GatewaySubnet.id }
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

resource rt_hub00_GatewaySubnet 'Microsoft.Network/routeTables@2022-01-01' = {
  name: 'rt-hub00-GatewaySubnet'
  location: location01
  properties: {
    routes: [
      {
        name: '10_10_0_0_16'
        properties: {
          addressPrefix: '10.10.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.0.4'
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

var rs00Name = 'rs-hub00'
module rs00 '../lib/route-server.bicep' = {
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

var bast00Name = 'bast-hub00'
module bast00 '../lib/bastion.bicep' = {
  name: bast00Name
  params: {
    location: location01
    bastionName: bast00Name
    vnetName: vnet_hub00.name
  }
}

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
          routeTable: { id: rt_spoke10_defaultSubnet.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.10.200.0/24'
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

resource rt_spoke10_defaultSubnet 'Microsoft.Network/routeTables@2022-01-01' = {
  name: 'rt-defaultSubnet-spoke10'
  location: location01
  properties: {
    routes: [
      {
        name: '10_100_0_0_16'
        properties: {
          addressPrefix: '10.100.0.0/16'
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

var ergw10Name = 'ergw-hub10'
module ergw10 '../lib/ergw.bicep' = {
  name: ergw10Name
  params: {
    location: location01
    gatewayName: ergw10Name
    vnetName: vnet_spoke10.name
    useExisting: useExisting
  }
}

var conn10Name = 'conn-hub10'
resource conn_spoke10 'Microsoft.Network/connections@2022-01-01' = {
  name: conn10Name
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergw10.outputs.ergwId
    }
    peer: {
      id: circuit02.id
    }
    authorizationKey: circuit02.authorizationKey1
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
          networkSecurityGroup: { id: vnet_hub100_default_nsg_eastasia.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.100.100.0/24'
          networkSecurityGroup: { id: nsg_hub100_AzureBastionSubnet.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.100.200.0/24'
        }
      }
    ]
  }
}

resource vnet_hub100_default_nsg_eastasia 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub100-default-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_hub100_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub100-AzureBastionSubnet-nsg-eastasia'
  location: location01
  properties: {
    securityRules: concat(default_securityRules, AzureBastionSubnet_additional_securityRules)
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

var bast100Name = 'bast-hub100'
module bast100 '../lib/bastion.bicep' = {
  name: bast100Name
  params: {
    location: location01
    bastionName: bast100Name
    vnetName: vnet_hub100.name
  }
}

var vm100Name = 'vm-hub100'
module vm_hub100 '../lib/ubuntu2004.bicep' = {
  name: vm100Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub100.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm100Name
  }
}

/* ****************************** hub200 ****************************** */

resource vnet_hub200 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-hub200'
  location: location01
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.200.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.200.0.0/24'
          networkSecurityGroup: { id: vnet_hub200_default_nsg_eastasia.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.200.100.0/24'
          networkSecurityGroup: { id: nsg_hub200_AzureBastionSubnet.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.200.200.0/24'
        }
      }
    ]
  }
}

resource vnet_hub200_default_nsg_eastasia 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub200-default-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_hub200_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hu200-AzureBastionSubnet-nsg-eastasia'
  location: location01
  properties: {
    securityRules: concat(default_securityRules, AzureBastionSubnet_additional_securityRules)
  }
}

var ergw200Name = 'ergw-hub200'
module ergw200 '../lib/ergw.bicep' = {
  name: ergw200Name
  params: {
    location: location01
    gatewayName: ergw200Name
    vnetName: vnet_hub200.name
    useExisting: useExisting
  }
}

var conn200Name = 'conn-hub200'
resource conn_hub200 'Microsoft.Network/connections@2022-01-01' = {
  name: conn200Name
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergw200.outputs.ergwId
    }
    peer: {
      id: circuit02.id
    }
    authorizationKey: circuit02.authorizationKey2
  }
  dependsOn: [
    conn_spoke10
  ]
}

var bast200Name = 'bast-hub200'
module bast200 '../lib/bastion.bicep' = {
  name: bast200Name
  params: {
    location: location01
    bastionName: bast200Name
    vnetName: vnet_hub200.name
  }
}

var vm200Name = 'vm-hub200'
module vm_hub200 '../lib/ubuntu2004.bicep' = {
  name: vm200Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub200.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm200Name
  }
}
