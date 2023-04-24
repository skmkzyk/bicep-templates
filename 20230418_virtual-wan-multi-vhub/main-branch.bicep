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

var useExisting = false

var branch_number = range(0, 32)
// var branch_number = [ 0, 1, 2, 3, 4, 5 ]

resource nsg_default 'Microsoft.Network/networkSecurityGroups@2022-09-01' existing = {
  name: 'vnet-default-nsg-${location01}'
}

/* ****************************** ExpressRoute circuits ****************************** */

resource circuits 'Microsoft.Network/expressRouteCircuits@2022-09-01' existing = [for i in branch_number: {
  name: 'cct${i + 100}'
}]

/* ****************************** Virtual Networks as branch ****************************** */

resource _vnets_branch 'Microsoft.Network/virtualNetworks@2022-09-01' = [for i in [ 0, 1, 16, 17, 20, 21 ]: {
  name: 'vnet${i + 100}'
  location: location01
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.${i + 100}.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.${i + 100}.0.0/24'
          networkSecurityGroup: { id: nsg_default.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.${i + 100}.200.0/24'
        }
      }
    ]
  }
}]

resource vnets_branch 'Microsoft.Network/virtualNetworks@2022-09-01' existing = [for i in branch_number: {
  name: 'vnet${i + 100}'
}]

/* ****************************** ExpressRoute Gateways for branch ****************************** */

module _ergws_branch '../lib/ergw.bicep' = [for i in [ 0, 1, 16, 17, 20, 21 ]: {
  name: 'ergw${i + 100}'
  params: {
    location: location01
    gatewayName: 'ergw${i + 100}'
    vnetName: vnets_branch[i].name
    useExisting: useExisting
  }
}]

resource ergws_branch 'Microsoft.Network/virtualNetworkGateways@2022-09-01' existing = [for i in branch_number: {
  name: 'ergw${i + 100}'
}]

/* ****************************** ExpressRoute circuit connections for branch ****************************** */

// resource connections_branch 'Microsoft.Network/connections@2022-09-01' = [for i in branch_number: {
resource connections_branch 'Microsoft.Network/connections@2022-09-01' = [for i in [ 0, 1, 16, 17, 20, 21 ]: {
  name: 'conn-${ergws_branch[i].name}-${circuits[i].name}'
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergws_branch[i].id
    }
    peer: {
      id: circuits[i].id
    }
  }
}]

/* ****************************** Test Virtual Machines for branch ****************************** */

// module vms_branch '../lib/ws2019.bicep' = [for i in branch_number: {
module vms_branch '../lib/ws2019.bicep' = [for i in [ 0, 1, 16, 17, 20, 21 ]: {
  name: 'vm${i + 100}'
  params: {
    location: location01
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnets_branch[i].properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: 'vm${i + 100}'
    privateIpAddress: '10.${i + 100}.0.10'
    enableNetworkWatcherExtention: true
  }
}]
