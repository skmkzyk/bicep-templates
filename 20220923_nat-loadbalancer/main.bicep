param location01 string = 'eastasia'

param circuit01 object

param sshKeyRGName string
param publicKeyName string

param useExisting bool = false

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
  }
}

var pe00Name = 'pe-hub00'
resource pe_hub00 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: pe00Name
  location: location01
  properties: {
    subnet: { id: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id }
    privateLinkServiceConnections: [
      {
        name: pe00Name
        properties: {
          privateLinkServiceId: pls_hub10.id
        }
      }
    ]
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
        name: 'privateLinkServiceSubnet'
        properties: {
          addressPrefix: '10.10.0.0/24'
          networkSecurityGroup: { id: nsg_spoke10_privateLinkServiceSubnet.id }
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'backend'
        properties: {
          addressPrefix: '10.10.10.0/24'
          networkSecurityGroup: { id: nsg_spoke10_backendSubnet.id }
        }
      }
    ]
  }
}

resource nsg_spoke10_privateLinkServiceSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke10-privateLinkServiceSubnet-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_spoke10_backendSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke10-backend-nsg-eastasia'
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
  }
}

var vm10Name = 'vm-spoke10'
module vm_spoke10 '../lib/ubuntu2004.bicep' = {
  name: vm10Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_spoke10.properties.subnets, subnet => subnet.name == 'backend')[0].id
    vmName: vm10Name
    loadBalancerBackendAddressPoolsId: lb_hub10::bp01.id
  }
}

var lb10Name = 'slb-hub10'
var fipc10Name = 'ipconfig1'
var hp10Name = 'hp01'
var bp10Name = 'bp01'
resource lb_hub10 'Microsoft.Network/loadBalancers@2022-01-01' = {
  name: lb10Name
  location: location01
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: fipc10Name
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: filter(vnet_spoke10.properties.subnets, subnet => subnet.name == 'privateLinkServiceSubnet')[0].id }
        }
        zones: [
          '1'
          '2'
          '3'
        ]
      }
    ]
    backendAddressPools: [
      {
        name: bp10Name
      }
    ]
    probes: [
      {
        name: hp10Name
        properties: {
          protocol: 'Tcp'
          port: 22
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'lbr01'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', lb10Name, fipc10Name)
          }
          protocol: 'All'
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lb10Name, hp10Name)
          }
          backendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lb10Name, bp10Name)
            }
          ]
        }
      }
    ]
  }

  resource fipc01 'frontendIPConfigurations' existing = {
    name: fipc10Name
  }

  resource bp01 'backendAddressPools' existing = {
    name: bp10Name
  }
}

var pls10Name = 'pls-hub10'
resource pls_hub10 'Microsoft.Network/privateLinkServices@2022-01-01' = {
  name: pls10Name
  location: location01
  properties: {
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      { id: lb_hub10::fipc01.id }
    ]
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          subnet: { id: filter(vnet_spoke10.properties.subnets, subnet => subnet.name == 'privateLinkServiceSubnet')[0].id }
          primary: false
        }
      }
    ]
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
  location: location01
  properties: {
    securityRules: default_securityRules
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
