param location01 string = resourceGroup().location
param location02 string = resourceGroup().location

param kvName string
param kvRGName string

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

param s2svpnSecretName string

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

var vpngw01Name = 'vpngw-hub01'
module vpngw01 '../lib/vpngw_single.bicep' = {
  name: vpngw01Name
  params: {
    location: location01
    vnetName: vnet_hub00.name
    gatewayName: vpngw01Name
    bgpAsn: 65150
    useExisting: useExisting
  }
}

module conn_vpngw01_vpngw02 '../lib/connection-vpngw.bicep' = {
  name: 'conn-${vpngw01Name}-${vpngw02Name}'
  params: {
    vpnGateway01Name: vpngw01.outputs.vpngwName
    vpnGateway02Name: vpngw02.outputs.vpngwName
    psk: kv.getSecret(s2svpnSecretName)
    enableBgp: true
  }
}

var bast01Name = 'bast-hub00'
module bast01 '../lib/bastion.bicep' = {
  name: bast01Name
  params: {
    location: location01
    bastionName: bast01Name
    vnetName: vnet_hub00.name
  }
}

var vm01Name = 'vm-hub00'
module vm_hub00 '../lib/ubuntu2004.bicep' = {
  name: vm01Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm01Name
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

module peering_hub0010 '../lib/vnet-peering.bicep' = {
  name: 'peering-hub00-spoke10'
  params: {
    vnet01Name: vnet_hub00.name
    vnet02Name: vnet_spoke10.name
    useRemoteGateways: true
  }
  dependsOn: [
    vpngw01
  ]
}

resource nsg_spoke10_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke10-default-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

var vm02Name = 'vm-spoke10'
module vm_spoke10 '../lib/ubuntu2004.bicep' = {
  name: vm02Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_spoke10.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm02Name
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

module peering_hub0020 '../lib/vnet-peering.bicep' = {
  name: 'peering-hub00-spoke20'
  params: {
    vnet01Name: vnet_hub00.name
    vnet02Name: vnet_spoke20.name
    useRemoteGateways: true
  }
  dependsOn: [
    vpngw01
  ]
}

resource nsg_spoke20_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke20-default-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

var vm03Name = 'vm-spoke20'
module vm_spoke20 '../lib/ubuntu2004.bicep' = {
  name: vm03Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_spoke20.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm03Name
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

var vpngw02Name = 'vpngw-hub02'
module vpngw02 '../lib/vpngw_single.bicep' = {
  name: vpngw02Name
  params: {
    location: location02
    vnetName: vnet_hub100.name
    gatewayName: vpngw02Name
    bgpAsn: 65151
    useExisting: useExisting
  }
}

var bast02Name = 'bast-hub100'
module bast02 '../lib/bastion.bicep' = {
  name: bast02Name
  params: {
    location: location02
    bastionName: bast02Name
    vnetName: vnet_hub100.name
  }
}

var vm11Name = 'vm-hub100'
module vm_hub100 '../lib/ubuntu2004.bicep' = {
  name: vm11Name
  params: {
    location: location02
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub100.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm11Name
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

module peering_hub100110 '../lib/vnet-peering.bicep' = {
  name: 'peering-hub100-spoke110'
  params: {
    vnet01Name: vnet_hub100.name
    vnet02Name: vnet_spoke110.name
    useRemoteGateways: true
  }
  dependsOn: [
    vpngw02
  ]
}

resource nsg_spoke110_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke110-default-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

var vm12Name = 'vm-spoke110'
module vm_spoke11 '../lib/ubuntu2004.bicep' = {
  name: vm12Name
  params: {
    location: location02
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_spoke110.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm12Name
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

module peering_hub100120 '../lib/vnet-peering.bicep' = {
  name: 'peering-hub100-spoke120'
  params: {
    vnet01Name: vnet_hub100.name
    vnet02Name: vnet_spoke120.name
    useRemoteGateways: true
  }
  dependsOn: [
    vpngw02
  ]
}

resource nsg_spoke120_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-spoke120-default-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

var vm13Name = 'vm-spoke120'
module vm_spoke12 '../lib/ubuntu2004.bicep' = {
  name: vm13Name
  params: {
    location: location02
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_spoke120.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm13Name
  }
}
