param location01 string = resourceGroup().location

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
        name: 'frontend'
        properties: {
          addressPrefix: '10.0.10.0/24'
          networkSecurityGroup: { id: nsg_hub00_frontendSubnet.id }
        }
      }
      {
        name: 'backend'
        properties: {
          addressPrefix: '10.0.20.0/24'
          networkSecurityGroup: { id: nsg_hub00_backendSubnet.id }
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

resource nsg_hub00_frontendSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub00-frontend-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_hub00_backendSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub00-backend-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub00-AzureBastionSubnet-nsg-eastasia'
  location: location01
  properties: {
    securityRules: concat(default_securityRules, AzureBastionSubnet_additional_securityRules)
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

var vm01Name = 'vm-certbot01'
module vm_hub01 '../lib/ubuntu2004.bicep' = {
  name: vm01Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm01Name
  }
}

var vm00Name = 'vm-client01'
module vm_hub00 '../lib/ws2019.bicep' = {
  name: vm00Name
  params: {
    location: location01
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm00Name
  }
}

var vm10Name = 'vm-frontiis01'
module vm_hub10 '../lib/ws2019.bicep' = {
  name: vm10Name
  params: {
    location: location01
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'frontend')[0].id
    vmName: vm10Name
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
          subnet: { id: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'backend')[0].id }
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
          port: 443
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
}

var vm20Name = 'vm-backiis01'
module vm_hub20 '../lib/ws2019.bicep' = {
  name: vm20Name
  params: {
    location: location01
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'backend')[0].id
    vmName: vm20Name
    loadBalancerBackendAddressPoolsId: filter(lb_hub10.properties.backendAddressPools, _ => _.name == bp10Name)[0].id
  }
}

var vm21Name = 'vm-backiis02'
module vm_hub21 '../lib/ws2019.bicep' = {
  name: vm21Name
  params: {
    location: location01
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'backend')[0].id
    vmName: vm21Name
    loadBalancerBackendAddressPoolsId: filter(lb_hub10.properties.backendAddressPools, _ => _.name == bp10Name)[0].id
  }
}
