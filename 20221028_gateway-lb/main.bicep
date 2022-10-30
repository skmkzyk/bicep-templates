param location01 string = resourceGroup().location

param sshKeyRGName string
param publicKeyName string

resource public_key 'Microsoft.Compute/sshPublicKeys@2022-03-01' existing = {
  name: publicKeyName
  scope: resourceGroup(sshKeyRGName)
}

param default_securityRules array
param allowHttp_securityRules array
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
          natGateway: { id: natgw_hub00.outputs.natGatewayId }
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
  name: 'vnet-hub00-default-nsg-${location01}'
  location: location01
  properties: {
    securityRules: concat(allowHttp_securityRules, default_securityRules)
  }
}

resource nsg_hub00_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub00-AzureBastionSubnet-nsg-${location01}'
  location: location01
  properties: {
    securityRules: concat(default_securityRules, AzureBastionSubnet_additional_securityRules)
  }
}

var natgw01Name = 'natgw-hub00'
module natgw_hub00 '../lib/nat-gateway.bicep' = {
  name: natgw01Name
  params: {
    natGatewayName: natgw01Name
    location: location01
    zone: [ '1' ]
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

var lb01Name = 'pslb-hub00'
var fipc01Name = 'ipconfig1'
var hp01Name = 'hp01'
var bp01Name = 'bp01'
resource pip_lb_hub00 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: 'pip-${lb01Name}'
  location: location01
  sku: {
    name: 'Standard'
  }
  zones: [ '1', '2', '3' ]
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource slb_hub00 'Microsoft.Network/loadBalancers@2022-01-01' = {
  name: lb01Name
  location: location01
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: fipc01Name
        properties: {
          publicIPAddress: { id: pip_lb_hub00.id }
          gatewayLoadBalancer: { id: filter(gwlb_hub10.properties.frontendIPConfigurations, _ => _.name == fipc10Name)[0].id }
        }
      }
    ]
    backendAddressPools: [
      {
        name: bp01Name
      }
    ]
    probes: [
      {
        name: hp01Name
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
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', lb01Name, fipc01Name)
          }
          frontendPort: 80
          backendPort: 80
          protocol: 'Tcp'
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lb01Name, hp01Name)
          }
          backendAddressPools: [
            { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lb01Name, bp01Name) }
          ]
          disableOutboundSnat: true
        }
      }
    ]
    outboundRules: [
      {
        name: 'outrr01'
        properties: {
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', lb01Name, fipc01Name)
            }
          ]
          backendAddressPool: { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lb01Name, bp01Name) }
          protocol: 'All'
          allocatedOutboundPorts: 0
        }
      }
    ]
  }
}

var vm01Name = 'vm-nginx01'
module vm_hub01 '../lib/ubuntu2004.bicep' = {
  name: vm01Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm01Name
    customData: loadFileAsBase64('./cloud-init_nginx.yml')
    loadBalancerBackendAddressPoolsId: filter(slb_hub00.properties.backendAddressPools, _ => _.name == bp01Name)[0].id
  }
}

/* ****************************** hub10 ****************************** */

resource vnet_hub10 'Microsoft.Network/virtualNetworks@2022-01-01' = {
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
          networkSecurityGroup: { id: nsg_hub10_defaultSubnet.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.10.100.0/24'
          networkSecurityGroup: { id: nsg_hub10_AzureBastionSubnet.id }
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

resource nsg_hub10_defaultSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub10-default-nsg-${location01}'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_hub10_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub10-AzureBastionSubnet-nsg-${location01}'
  location: location01
  properties: {
    securityRules: concat(default_securityRules, AzureBastionSubnet_additional_securityRules)
  }
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

var lb10Name = 'gwlb-hub10'
var fipc10Name = 'ipconfig1'
var hp10Name = 'hp01'
var bp10Name = 'bp01'

resource gwlb_hub10 'Microsoft.Network/loadBalancers@2022-01-01' = {
  name: lb10Name
  location: location01
  sku: {
    name: 'Gateway'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: fipc10Name
        zones: [ '1', '2', '3' ]
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: filter(vnet_hub10.properties.subnets, subnet => subnet.name == 'default')[0].id }
        }
      }
    ]
    backendAddressPools: [
      {
        name: bp10Name
        properties: {
          tunnelInterfaces: [
            {
              port: 10800
              identifier: 800
              protocol: 'VXLAN'
              type: 'Internal'
            }
            {
              port: 10801
              identifier: 801
              protocol: 'VXLAN'
              type: 'External'
            }
          ]
        }
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
            { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lb10Name, bp10Name) }
          ]
          disableOutboundSnat: true
        }
      }
    ]
  }
}

var vm10Name = 'vm-nva01'
module vm_hub10 '../lib/ubuntu2004.bicep' = {
  name: vm10Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub10.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm10Name
    customData: loadFileAsBase64('./cloud-init_nva.yml')
    loadBalancerBackendAddressPoolsId: filter(gwlb_hub10.properties.backendAddressPools, _ => _.name == bp10Name)[0].id
  }
}
