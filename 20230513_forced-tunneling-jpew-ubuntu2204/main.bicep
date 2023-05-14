param location01 string = resourceGroup().location
param location02 string = 'japanwest'

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
    routingWeight: 100
  }
}

var conn01Name = 'conn-hub00-cross'
resource conn_hub01 'Microsoft.Network/connections@2022-11-01' = {
  name: conn01Name
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergw00.outputs.ergwId
    }
    peer: {
      id: circuit02.id
    }
    authorizationKey: circuit02.authorizationKey3
  }
  dependsOn: [
    conn_hub00
    conn_hub10
  ]
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

/* ****************************** hub10 ****************************** */

resource vnet_hub10 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: 'vnet-hub10'
  location: location02
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
          networkSecurityGroup: { id: nsg_default02.id }
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
      {
        name: 'jump'
        properties: {
          addressPrefix: '10.10.220.0/24'
          networkSecurityGroup: { id: nsg_jump02.id }
          routeTable: { id: rt_hub10_jumpSubnet.id }
        }
      }
    ]
  }
}

resource nsg_default02 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'vnet-hub10-default-nsg-${location02}'
  location: location02
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_jump02 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'vnet-hub10-jump-nsg-${location02}'
  location: location02
  properties: {
    securityRules: concat(default_securityRules, home_additional_securityRules)
  }
}

resource rt_hub10_jumpSubnet 'Microsoft.Network/routeTables@2022-01-01' = {
  name: 'rt-jumpSubnet-hub10'
  location: location02
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

var ergw10Name = 'ergw-hub10'
module ergw10 '../lib/ergw.bicep' = {
  name: ergw10Name
  params: {
    location: location02
    gatewayName: ergw10Name
    vnetName: vnet_hub10.name
    sku: 'Standard'
    useExisting: useExisting
  }
}

var conn10Name = 'conn-hub10'
resource conn_hub10 'Microsoft.Network/connections@2022-11-01' = {
  name: conn10Name
  location: location02
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

var conn11Name = 'conn-hub10-cross'
resource conn_hub11 'Microsoft.Network/connections@2022-11-01' = {
  name: conn11Name
  location: location02
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergw10.outputs.ergwId
    }
    peer: {
      id: circuit01.id
    }
    authorizationKey: circuit01.authorizationKey3
    routingWeight: 100
  }
  dependsOn: [
    conn_hub00
    conn_hub10
  ]
}

var vm10Name = 'vm-hub10'
module vm_hub10 '../lib/ws2019.bicep' = {
  name: vm10Name
  params: {
    location: location02
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnet_hub10.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm10Name
    vmSize: 'Standard_D2ds_v5'
  }
}

var vm11Name = 'vm-jump10'
module vm_hub11 '../lib/ws2019.bicep' = {
  name: vm11Name
  params: {
    location: location02
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnet_hub10.properties.subnets, subnet => subnet.name == 'jump')[0].id
    vmName: vm11Name
    vmSize: 'Standard_D2ds_v5'
    privateIpAddress: '10.10.220.10'
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
          routeTable: { id: rt_hub100_nvaSubnet.id }
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

resource rt_hub100_nvaSubnet 'Microsoft.Network/routeTables@2022-11-01' = {
  name: 'rt-nvaSubnet-hub100'
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
  dependsOn: [
    conn_hub00
    rs100
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
        name: vm_nva100.name
        ip: vm_nva100.outputs.privateIP
        asn: '65001'
      }
    ]
    useExisting: useExisting
  }
}

var vm100Name = 'vm-nva100'
module vm_nva100 '../lib/ubuntu2204.bicep' = {
  name: vm100Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub100.properties.subnets, subnet => subnet.name == 'nva')[0].id
    vmName: vm100Name
    privateIpAddress: '10.100.0.10'
    enableIPForwarding: true
    usePublicIP: true
    customData: loadFileAsBase64('./cloud-init_vm-nva100.yml')
  }
}

/* ****************************** hub110 ****************************** */

resource vnet_hub110 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: 'vnet-hub110'
  location: location02
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.110.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'nva'
        properties: {
          addressPrefix: '10.110.0.0/24'
          networkSecurityGroup: { id: nsg_nva02.id }
          routeTable: { id: rt_hub110_nvaSubnet.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.110.200.0/24'
        }
      }
      {
        name: 'RouteServerSubnet'
        properties: {
          addressPrefix: '10.110.210.0/24'
        }
      }
    ]
  }
}

resource nsg_nva02 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'vnet-hub110-nva-nsg-${location02}'
  location: location02
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

resource rt_hub110_nvaSubnet 'Microsoft.Network/routeTables@2022-01-01' = {
  name: 'rt-nvaSubnet-hub110'
  location: location02
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

var ergw110Name = 'ergw-hub110'
module ergw110 '../lib/ergw.bicep' = {
  name: ergw110Name
  params: {
    location: location02
    gatewayName: ergw110Name
    vnetName: vnet_hub110.name
    sku: 'Standard'
    useExisting: useExisting
  }
}

var conn110Name = 'conn-hub110'
resource conn_hub110 'Microsoft.Network/connections@2022-11-01' = {
  name: conn110Name
  location: location02
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergw110.outputs.ergwId
    }
    peer: {
      id: circuit02.id
    }
    authorizationKey: circuit02.authorizationKey2
  }
  dependsOn: [
    conn_hub10
    rs110
  ]
}

var rs110Name = 'rs-hub110'
module rs110 '../lib/route-server.bicep' = {
  name: rs110Name
  params: {
    location: location02
    routeServerName: rs110Name
    vnetName: vnet_hub110.name
    bgpConnections: [
      {
        name: vm_nva110.name
        ip: vm_nva110.outputs.privateIP
        asn: '65001'
      }
    ]
    useExisting: useExisting
  }
}

var vm110Name = 'vm-nva110'
module vm_nva110 '../lib/ubuntu2204.bicep' = {
  name: vm110Name
  params: {
    location: location02
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub110.properties.subnets, subnet => subnet.name == 'nva')[0].id
    vmName: vm110Name
    vmSize: 'Standard_D2ds_v5'
    privateIpAddress: '10.110.0.10'
    enableIPForwarding: true
    usePublicIP: true
    customData: loadFileAsBase64('./cloud-init_vm-nva110.yml')
  }
}
