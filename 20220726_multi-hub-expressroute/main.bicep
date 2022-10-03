param location01 string = 'eastasia'
param location02 string = 'eastasia'

param sshKeyRGName string
param publicKeyName string

resource public_key 'Microsoft.Compute/sshPublicKeys@2022-03-01' existing = {
  name: publicKeyName
  scope: resourceGroup(sshKeyRGName)
}

param default_securityRules array
param AzureBastionSubnet_additional_securityRules array

param circuit01 object

param isInitialDeploy bool = false
var useExisting = !isInitialDeploy

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

var bast00Name = 'bast-hub00'
module bast_hub00 '../lib/bastion.bicep' = {
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

module peering_hub0010 '../lib/vnet-peering.bicep' = {
  name: 'peering-hub00-spoke10'
  params: {
    vnet01Name: vnet_hub00.name
    vnet02Name: vnet_spoke10.name
    useRemoteGateways: true
  }
  dependsOn: [
    ergw00
  ]
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

/* ****************************** spoke20 ****************************** */

resource vnet_spoke20 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-spoke20'
  location: location01
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.20.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.20.0.0/24'
          networkSecurityGroup: { id: nsg_spoke20_defaultSubnet.id }
        }
      }
    ]
  }
}

resource nsg_spoke20_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke20-default-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

module peering_hub0020 '../lib/vnet-peering.bicep' = {
  name: 'peering-hub00-spoke20'
  params: {
    vnet01Name: vnet_hub00.name
    vnet02Name: vnet_spoke20.name
    useRemoteGateways: true
  }
  dependsOn: [
    ergw00
  ]
}

var vm20Name = 'vm-spoke20'
module vm_spoke02 '../lib/ubuntu2004.bicep' = {
  name: vm20Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_spoke20.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm20Name
  }
}

/* ****************************** hub100 ****************************** */

resource vnet_hub100 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-hub100'
  location: location02
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

resource nsg_hub100_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub100-default-nsg-eastasia'
  location: location02
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_hub100_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub100-AzureBastionSubnet-nsg-eastasia'
  location: location02
  properties: {
    securityRules: concat(default_securityRules, AzureBastionSubnet_additional_securityRules)
  }
}

var ergw100Name = 'ergw-hub100'
module ergw100 '../lib/ergw.bicep' = {
  name: ergw100Name
  params: {
    location: location02
    gatewayName: ergw100Name
    vnetName: vnet_hub100.name
    useExisting: useExisting
  }
}

var conn100Name = 'conn-hub100'
resource conn_hub100 'Microsoft.Network/connections@2022-01-01' = {
  name: conn100Name
  location: location02
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
module bast_hub100 '../lib/bastion.bicep' = {
  name: bast100Name
  params: {
    location: location02
    bastionName: bast100Name
    vnetName: vnet_hub100.name
  }
}

var vm100Name = 'vm-hub100'
module vm_hub100 '../lib/ubuntu2004.bicep' = {
  name: vm100Name
  params: {
    location: location02
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub100.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm100Name
  }
}

/* ****************************** spoke110 ****************************** */

resource vnet_spoke110 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-spoke110'
  location: location02
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
          networkSecurityGroup: { id: nsg_spoke110_defaultSubnet.id }
        }
      }
    ]
  }
}

resource nsg_spoke110_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke110-default-nsg-eastasia'
  location: location02
  properties: {
    securityRules: default_securityRules
  }
}

module peering_hub100110 '../lib/vnet-peering.bicep' = {
  name: 'peering-hub100-spoke110'
  params: {
    vnet01Name: vnet_hub100.name
    vnet02Name: vnet_spoke110.name
    useRemoteGateways: true
  }
  dependsOn: [
    ergw100
  ]
}

var vm110Name = 'vm-spoke110'
module vm_spoke110 '../lib/ubuntu2004.bicep' = {
  name: vm110Name
  params: {
    location: location02
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_spoke110.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm110Name
  }
}

/* ****************************** spoke120 ****************************** */

resource vnet_spoke120 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-spoke120'
  location: location02
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.120.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.120.0.0/24'
          networkSecurityGroup: { id: nsg_spoke120_defaultSubnet.id }
        }
      }
    ]
  }
}

resource nsg_spoke120_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke120-default-nsg-eastasia'
  location: location02
  properties: {
    securityRules: default_securityRules
  }
}

module peering_hub100120 '../lib/vnet-peering.bicep' = {
  name: 'peering-hub100-spoke120'
  params: {
    vnet01Name: vnet_hub100.name
    vnet02Name: vnet_spoke120.name
    useRemoteGateways: true
  }
  dependsOn: [
    ergw100
  ]
}

var vm120Name = 'vm-spoke120'
module vm_spoke120 '../lib/ubuntu2004.bicep' = {
  name: vm120Name
  params: {
    location: location02
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_spoke120.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm120Name
  }
}
