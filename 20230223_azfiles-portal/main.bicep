param location01 string = resourceGroup().location

param kvName string
param kvRGName string
param secretName string

resource kv 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: kvName
  scope: resourceGroup(kvRGName)
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
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.100.0/24'
          networkSecurityGroup: { id: nsg_AzureBastionSubnet.id }
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

resource nsg_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'vnet-hub00-AzureBastionSubnet-nsg-${location01}'
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

var vm00Name = 'vm-filescli00'
module vm_hub00 '../lib/ws2019.bicep' = {
  name: vm00Name
  params: {
    location: location01
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm00Name
  }
}

var sa00name = uniqueString(resourceGroup().id)
resource sa00 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: sa00name
  location: location01
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Disabled'
  }

  resource fs01 'fileServices' = {
    name: 'default'

    resource share01 'shares' = {
      name: 'share01'
    }
  }
}

resource pdns00 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'

  resource vnetlink00 'virtualNetworkLinks' = {
    name: uniqueString(vnet_hub00.id)
    location: 'global'
    properties: {
      virtualNetwork: { id: vnet_hub00.id }
      registrationEnabled: false
    }
  }
}

var pe00Name = 'endp-${sa00name}'
resource pe_sa00 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: pe00Name
  location: location01
  properties: {
    subnet: { id: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id }
    customNetworkInterfaceName: 'nic-${sa00name}'
    privateLinkServiceConnections: [
      {
        name: pe00Name
        properties: {
          privateLinkServiceId: sa00.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }

  resource zonegroup00 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: replace(pdns00.name, '.', '-')
          properties: {
            privateDnsZoneId: pdns00.id
          }
        }
      ]
    }
  }
}
