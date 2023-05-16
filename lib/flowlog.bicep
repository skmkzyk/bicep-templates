param location string
param nsgName string
param nsgRGName string
param stName string
param stRGName string

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' existing = {
  name: nsgName
  scope: resourceGroup(nsgRGName)
}

resource st 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: stName
  scope: resourceGroup(stRGName)
}

resource netWatch 'Microsoft.Network/networkWatchers@2022-01-01' existing = {
  name: 'NetworkWatcher_${location}'
}

var flowLogSuffix = uniqueString('${nsgName}-${nsgRGName}')
resource flowLog 'Microsoft.Network/networkWatchers/flowLogs@2022-01-01' = {
  parent: netWatch
  name: '${flowLogSuffix}-flowlog'
  location: location
  properties: {
    storageId: st.id
    targetResourceId: nsg.id
    enabled: true
  }
}
