param location01 string = resourceGroup().location

param circuit01 object

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
param home_additional_securityRules array

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
      {
        name: 'jump'
        properties: {
          addressPrefix: '10.0.220.0/24'
          networkSecurityGroup: { id: nsg_jump.id }
          routeTable: { id: rt_hub00_jumpSubnet.id }
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

resource nsg_jump 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'vnet-hub00-jump-nsg-${location01}'
  location: location01
  properties: {
    securityRules: concat(default_securityRules, home_additional_securityRules)
  }
}

resource rt_hub00_jumpSubnet 'Microsoft.Network/routeTables@2022-01-01' = {
  name: 'rt-jumpSubnet-hub00'
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

var vm01Name = 'vm-jump00'
module vm_hub01 '../lib/ws2019.bicep' = {
  name: vm01Name
  params: {
    location: location01
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'jump')[0].id
    vmName: vm01Name
    privateIpAddress: '10.0.220.10'
    usePublicIP: true
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
        name: 'nva'
        properties: {
          addressPrefix: '10.100.0.0/24'
          networkSecurityGroup: { id: nsg_nva.id }
          routeTable: { id: rt_hub00_nvaSubnet.id }
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

resource nsg_nva 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'vnet-hub100-nva-nsg-${location01}'
  location: location01
  properties: {
    securityRules: concat(default_securityRules,
      [
        {
          name: 'AllowForwardedTraffic'
          properties: {
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: 'Internet'
            access: 'Allow'
            priority: 110
            direction: 'Inbound'
          }
        }
      ]
    )
  }
}

resource rt_hub00_nvaSubnet 'Microsoft.Network/routeTables@2022-01-01' = {
  name: 'rt-nvaSubnet-hub00'
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
        name: vm_nva100.name
        ip: vm_nva100.outputs.privateIP
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
module vm_nva100 '../lib/ubuntu2004.bicep' = {
  name: vm100Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub100.properties.subnets, subnet => subnet.name == 'nva')[0].id
    vmName: vm100Name
    privateIpAddress: '10.100.0.10'
    enableIPForwarding: true
    usePublicIP: true
  }
}
