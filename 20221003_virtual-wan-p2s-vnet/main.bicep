param location01 string = 'eastasia'

param publicKeyName string
param sshKeyRGName string

resource public_key 'Microsoft.Compute/sshPublicKeys@2022-03-01' existing = {
  name: publicKeyName
  scope: resourceGroup(sshKeyRGName)
}

param default_securityRules array
param AzureBastionSubnet_additional_securityRules array

param vpnClientRootCertificates object
param tenantId string

/* ****************************** hub00 ****************************** */

resource vnet_hub00 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-hub00'
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
          networkSecurityGroup: { id: nsg_hub00_defaultSubnet.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.10.100.0/24'
          networkSecurityGroup: { id: nsg_hub00_AzureBastionSubnet.id }
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

/* ****************************** Virtual WAN P2S VPN ****************************** */

var vwan01Name = 'vwan01'
resource vwan01 'Microsoft.Network/virtualWans@2022-01-01' = {
  name: vwan01Name
  location: location01
  properties: {
    type: 'Standard'
  }
}

var vhub01Name = 'vhub-ea01'
resource vhub_ea01 'Microsoft.Network/virtualHubs@2022-01-01' = {
  name: vhub01Name
  location: location01
  properties: {
    addressPrefix: '10.0.0.0/16'
    virtualWan: {
      id: vwan01.id
    }
    sku: 'Standard'
  }

  resource conn 'hubVirtualNetworkConnections' = {
    name: 'conn-${vnet_hub00.name}'
    properties: {
      remoteVirtualNetwork: { id: vnet_hub00.id }
      enableInternetSecurity: true
    }
  }
}

resource vpnServerConf01 'Microsoft.Network/vpnServerConfigurations@2022-01-01' = {
  name: 'vpn-server-conf01'
  location: location01
  properties: {
    aadAuthenticationParameters: {
      aadAudience: '41b23e61-6c1e-4545-b367-cd054e0ed4b4'
      aadIssuer: 'https://sts.windows.net/${tenantId}/'
      aadTenant: '${environment().authentication.loginEndpoint}${tenantId}/'
    }
    vpnAuthenticationTypes: [
      'AAD'
      'Certificate'
    ]
    vpnClientRootCertificates: [
      vpnClientRootCertificates
    ]
    vpnProtocols: [
      'OpenVPN'
    ]
  }
}

resource default_route_table 'Microsoft.Network/virtualHubs/hubRouteTables@2022-01-01' = {
  parent: vhub_ea01
  name: 'defaultRouteTable'
  properties: {
    labels: [
      'default'
    ]
    routes: [
      {
        name: 'public_traffic'
        destinationType: 'CIDR'
        destinations: [
          '0.0.0.0/0'
        ]
        nextHop: vhubfw_ea01.id
        nextHopType: 'ResourceId'
      }
    ]
  }
}

var p2sgw01Name = 'p2svpngw-ea01'
resource p2sgw_ea01 'Microsoft.Network/p2svpnGateways@2022-01-01' = {
  name: p2sgw01Name
  location: location01
  properties: {
    p2SConnectionConfigurations: [
      {
        name: 'P2SConnectionConfigDefault'
        properties: {
          routingConfiguration: {
            associatedRouteTable: { id: default_route_table.id }
            propagatedRouteTables: {
              ids: [
                { id: default_route_table.id }
              ]
              labels: [
                'default'
              ]
            }
          }
          vpnClientAddressPool: {
            addressPrefixes: [
              '192.168.10.0/24'
            ]
          }
        }
      }
    ]
    virtualHub: { id: vhub_ea01.id }
    vpnServerConfiguration: { id: vpnServerConf01.id }
  }
}

var vhubfw01Name = 'vhubfw-ea01'
resource vhubfw_ea01 'Microsoft.Network/azureFirewalls@2022-01-01' = {
  name: vhubfw01Name
  location: location01
  properties: {
    virtualHub: { id: vhub_ea01.id }
    sku: {
      name: 'AZFW_Hub'
      tier: 'Standard'
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    firewallPolicy: { id: firewall_policy.id }
  }
}

resource firewall_policy 'Microsoft.Network/firewallPolicies@2022-01-01' = {
  name: 'fwpol-${vhubfw01Name}'
  location: location01
  properties: {
    sku: {
      tier: 'Standard'
    }
  }
}

resource firewall_network_rules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-01-01' = {
  parent: firewall_policy
  name: 'fwpolnw01'
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'allowAll'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            ipProtocols: [
              'Any'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}
