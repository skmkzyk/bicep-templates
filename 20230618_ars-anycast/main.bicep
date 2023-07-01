param location01 string = resourceGroup().location

param circuit01 object
param circuit02 object

param kvName string
param kvRGName string
param secretName string

resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: kvName
  scope: resourceGroup(kvRGName)
}

param sshKeyRGName string
param publicKeyName string

resource public_key 'Microsoft.Compute/sshPublicKeys@2023-03-01' existing = {
  name: publicKeyName
  scope: resourceGroup(sshKeyRGName)
}

param default_securityRules array
param AzureBastionSubnet_additional_securityRules array = [
  {
    name: 'AllowGatewayManager'
    properties: {
      description: 'Allow GatewayManager'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'GatewayManager'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 2702
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowHttpsInBound'
    properties: {
      description: 'Allow HTTPs'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 2703
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowSshRdpOutbound'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 100
      direction: 'Outbound'
      destinationPortRanges: [
        '22'
        '3389'
      ]
    }
  }
  {
    name: 'AllowAzureCloudOutbound'
    properties: {
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'AzureCloud'
      access: 'Allow'
      priority: 110
      direction: 'Outbound'
    }
  }
]

var useExisting = false

/* ****************************** hub00 ****************************** */

resource vnet_hub00 'Microsoft.Network/virtualNetworks@2022-11-01' = {
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
          networkSecurityGroup: { id: nsg_default.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.100.0/24'
          networkSecurityGroup: { id: nsg_AzureBastionSubnet.id }
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

resource nsg_default 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'vnet-hub00-default-nsg-${location01}'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'vnet-hub00-AzureBastionSubnet-nsg-${location01}'
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
resource conn_hub00 'Microsoft.Network/connections@2022-11-01' = {
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

var bast00Name = 'bast-hub00'
module bast00 '../lib/bastion.bicep' = {
  name: bast00Name
  params: {
    location: location01
    bastionName: bast00Name
    vnetName: vnet_hub00.name
  }
}

var vm00Name = 'vm-nva00'
module vm_hub00 '../lib/ubuntu2204.bicep' = {
  name: vm00Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm00Name
    privateIpAddress: '10.0.0.10'
    enableIPForwarding: true
  }
}

var vm01Name = 'vm-web00'
module vm_web00 '../lib/ubuntu2204.bicep' = {
  name: vm01Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm01Name
    privateIpAddress: '10.0.0.20'
  }
}

/* ****************************** hub10 ****************************** */

resource vnet_hub10 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: 'vnet-hub10'
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
          networkSecurityGroup: { id: nsg_default.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.10.100.0/24'
          networkSecurityGroup: { id: nsg_AzureBastionSubnet.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.10.200.0/24'
        }
      }
      {
        name: 'RouteServerSubnet'
        properties: {
          addressPrefix: '10.10.210.0/24'
        }
      }
    ]
  }
}

var ergw10Name = 'ergw-hub10'
module ergw10 '../lib/ergw.bicep' = {
  name: ergw10Name
  params: {
    location: location01
    gatewayName: ergw10Name
    vnetName: vnet_hub10.name
    useExisting: useExisting
  }
}

var conn10Name = 'conn-hub10'
resource conn_hub10 'Microsoft.Network/connections@2022-11-01' = {
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

var rs10Name = 'rs-hub10'
module rs_hub10 '../lib/route-server.bicep' = {
  name: rs10Name
  params: {
    location: location01
    routeServerName: rs10Name
    vnetName: vnet_hub10.name
    bgpConnections: [
      {
        name: vm_hub10.name
        ip: vm_hub10.outputs.privateIP
        asn: '65001'
      }
    ]
    useExisting: useExisting
  }
  dependsOn: [
    conn_hub10
  ]
}

var bast10Name = 'bast-hub10'
module bast10 '../lib/bastion.bicep' = {
  name: bast10Name
  params: {
    location: location01
    bastionName: bast10Name
    vnetName: vnet_hub10.name
  }
}

var vm10Name = 'vm-nva10'
module vm_hub10 '../lib/ubuntu2204.bicep' = {
  name: vm10Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub10.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm10Name
    privateIpAddress: '10.10.0.10'
    enableIPForwarding: true
  }
}

var vm11Name = 'vm-web10'
module vm_web10 '../lib/ubuntu2204.bicep' = {
  name: vm11Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub10.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm11Name
    privateIpAddress: '10.10.0.20'
  }
}

/* ****************************** hub100 ****************************** */

resource vnet_hub100 'Microsoft.Network/virtualNetworks@2022-11-01' = {
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
          networkSecurityGroup: { id: nsg_default.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.100.100.0/24'
          networkSecurityGroup: { id: nsg_AzureBastionSubnet.id }
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
resource conn_hub100 'Microsoft.Network/connections@2022-11-01' = {
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

var conn101Name = 'conn-hub101'
resource conn_hub101 'Microsoft.Network/connections@2022-11-01' = {
  name: conn101Name
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergw100.outputs.ergwId
    }
    peer: {
      id: circuit02.id
    }
    authorizationKey: circuit02.authorizationKey2
  }
  dependsOn: [
    conn_hub10
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
module vm_hub100 '../lib/ubuntu2204.bicep' = {
  name: vm100Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub100.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm100Name
  }
}
