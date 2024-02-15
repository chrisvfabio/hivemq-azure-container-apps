param name string
param location string = resourceGroup().location
param subnetResourceId string

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: name
  location: location
  properties: {
    vnetConfiguration: {
      internal: false
      infrastructureSubnetId: subnetResourceId
    }
    appLogsConfiguration: {
      destination: null
    }
  }
}

output environment resource 'Microsoft.App/managedEnvironments@2023-05-01' = containerAppEnvironment
