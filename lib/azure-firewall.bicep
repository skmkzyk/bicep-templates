param location string
param firewallName string
param firewallVNetName string
param useExisting bool = false

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: firewallVNetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: 'AzureFirewallSubnet'
  parent: vnet
}

resource pip_azfw01 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'pip-${firewallName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2022-01-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Premium'
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: { id: pip_azfw01.id }
          subnet: { id: subnet.id }
        }
      }
    ]
    firewallPolicy: { id: firewall_policy.id }
  }
}

resource firewall_policy 'Microsoft.Network/firewallPolicies@2022-01-01' = if (!useExisting) {
  name: 'fwpol-${firewallName}'
  location: location
  properties: {
    sku: {
      tier: 'Premium'
    }
  }
}

resource firewall_network_rules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-01-01' = if (!useExisting) {
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
