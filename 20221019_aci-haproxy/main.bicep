param location01 string = resourceGroup().location

var acr01Name = 'acr${uniqueString(resourceGroup().id)}'
resource acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: acr01Name
  location: location01
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}
