targetScope = 'subscription'

param projectName string = 'hivemq'
param envName string = 'poc'

param resourceGroupName string = '${projectName}-${envName}-rg'
param resourceGroupLocation string = 'australiaeast'

// Create a resource group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
    name: resourceGroupName
    location: resourceGroupLocation
}

// Create a virtual network + subnet
module network 'network.bicep' = {
    name: 'network'
    scope: rg
    params: {
        location: rg.location
        vnetName: '${projectName}-${envName}-vnet'
        subnetName: '${projectName}-${envName}-subnet'
        vnetAddressPrefix: '10.0.0.0/16'
        subnetAddressPrefix: '10.0.0.0/21'
    }
}

// Create a container registry
module registry 'container-registry.bicep' = {
    name: 'container-registry'
    scope: rg
    params: {
        name: '${projectName}${envName}acr'
        location: rg.location
    }
}

// Create Azure Container App Environment
module containerAppEnvironment 'environment.bicep' = {
    name: 'container-app-environment'
    scope: rg
    params: {
        name: '${projectName}-${envName}'
        location: rg.location
        subnetResourceId: network.outputs.subnetId
    }
}

module hiveApp 'container-app.bicep' = {
    name: 'hive-app'
    scope: rg
    params: {
        name: 'hive-app'
        location: rg.location
        acrIdentityResource: registry.outputs.identity
        acrServer: registry.outputs.serverUrl
        appEnvironment: containerAppEnvironment.outputs.environment
        imageUri: '${registry.outputs.serverUrl}/hivemq-ce-rbac'
        imageTag: 'latest'
        ipRestrictions: [
            {
                name: 'Personal'
                ipAddressRange: ''
                action: 'Allow'
            }
        ]
    }
}
