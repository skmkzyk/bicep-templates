param location01 string = resourceGroup().location

param sshKeyRGName string
param publicKeyName string

resource public_key 'Microsoft.Compute/sshPublicKeys@2022-03-01' existing = {
  name: publicKeyName
  scope: resourceGroup(sshKeyRGName)
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

var bast01Name = 'bast-hub00'
module bast01 '../lib/bastion.bicep' = {
  name: bast01Name
  params: {
    location: location01
    bastionName: bast01Name
    vnetName: vnet_hub00.name
  }
}

var rs01Name = 'rs-hub00'
module rs01 '../lib/route-server.bicep' = {
  name: rs01Name
  params: {
    location: location01
    routeServerName: rs01Name
    vnetName: vnet_hub00.name
    useExisting: useExisting
    bgpConnections: [
      {
        name: vm_hub00.name
        ip: vm_hub00.outputs.privateIP
        asn: '65001'
      }
    ]
  }
}

var vm01Name = 'vm-nva00'
module vm_hub00 '../lib/ubuntu2004.bicep' = {
  name: vm01Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm01Name
    enableIPForwarding: true
    customData: loadFileAsBase64('./cloud-init.yml')
  }
}