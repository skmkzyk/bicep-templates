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

var ergw00Name = 'ergw-hub00'
resource ergw00 'Microsoft.Network/virtualNetworkGateways@2022-11-01' existing = {
  name: ergw00Name
}

var conn00Name = 'conn-hub00'
resource conn_hub00 'Microsoft.Network/connections@2022-11-01' = {
  name: conn00Name
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergw00.id
    }
    peer: {
      id: circuit01.id
    }
    authorizationKey: circuit01.authorizationKey1
  }
}

/* ****************************** hub10 ****************************** */

var ergw10Name = 'ergw-hub10'
resource ergw10 'Microsoft.Network/virtualNetworkGateways@2022-11-01' existing = {
  name: ergw10Name
}

var conn10Name = 'conn-hub10'
resource conn_hub10 'Microsoft.Network/connections@2022-11-01' = {
  name: conn10Name
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergw10.id
    }
    peer: {
      id: circuit02.id
    }
    authorizationKey: circuit02.authorizationKey1
  }
}
