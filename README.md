# HiveMQ with File RBAC Extension on Azure Container Apps

This repo will walk you through how to deploy HiveMQ with the File RBAC Extension on Azure Container Apps, with public TCP ingress enabled and access restrictions.

<video  controls>
  <source src="./docs/hivemq-azure-container-apps-ip-restrictions.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>


## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Docker](https://docs.docker.com/get-docker/)

## Steps

Login to Azure CLI.

```bash
az login
```

Enable the required providers.

```bash
az provider register --namespace Microsoft.Network --wait
az provider register --namespace Microsoft.ManagedIdentity --wait
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait
```

Prepare environment variables.

```bash
RESOURCE_GROUP=hivemq-poc
LOCATION=australiaeast
NAME=hivemqpoc
VNET_NAME=hivemq-poc-vnet
SNET_NAME=hivemq-poc-snet1
CONTAINERAPPS_ENVIRONMENT="hivemq-poc"
```

Create a resource group to hold the resources.
```bash
az group create --name $RESOURCE_GROUP --location $LOCATION
```

Create an Azure Container Registry to store the container image.
```bash
az acr create --resource-group $RESOURCE_GROUP --name ${NAME} --sku Basic
```

Enable admin user for ACR to allow access to the registry.
```bash
az acr update --name ${NAME} --admin-enabled true
```

Log in to the Azure Container Registry to push the image.
```bash
az acr login --name ${NAME}
```

Build the Docker image.
```bash
docker build -t ${NAME}.azurecr.io/hivemq-ce-rbac:latest .
```

Push the Docker image to the Azure Container Registry.
```bash
docker push ${NAME}.azurecr.io/hivemq-ce-rbac:latest
```

Create a user-assigned identity to be used by the Azure Container Apps environment to pull the image from the Azure Container Registry
```bash
az identity create --resource-group $RESOURCE_GROUP --name ${NAME}
```

Get resource ID of the user-assigned identity, service principal ID of the user-assigned identity and the resource ID of the Azure Container Registry.
```bash
USERID=$(az identity show --resource-group $RESOURCE_GROUP --name ${NAME} --query id --output tsv)
SPID=$(az identity show --resource-group $RESOURCE_GROUP --name ${NAME} --query principalId --output tsv)
ACR_ID=$(az acr show --name ${NAME} --query "id" --output tsv)
```

Assign the acrpull role to the user-assigned identity for the Azure Container Registry to allow pulling the image.
```bash
az role assignment create --assignee $SPID --scope $ACR_ID --role acrpull
```



Create a virtual network and a subnet for the Azure Container Apps environment.
```bash
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --location $LOCATION \
  --address-prefix 10.0.0.0/16
```

Delegate the subnet to the Azure Container Apps environment to allow it to deploy resources in the subnet.
```bash
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $SNET_NAME \
  --address-prefixes 10.0.0.0/21
```

Delegate the subnet to the Azure Container Apps environment to allow it to deploy resources in the subnet.
```bash
az network vnet subnet update \
    --name $SNET_NAME \
    --vnet-name $VNET_NAME \
    --resource-group $RESOURCE_GROUP \
    --delegations Microsoft.App/environments
```

Get the resource ID of the subnet to be used by the Azure Container Apps environment.

```bash
INFRASTRUCTURE_SUBNET=`az network vnet subnet show --resource-group ${RESOURCE_GROUP} --vnet-name $VNET_NAME --name ${SNET_NAME} --query "id" -o tsv | tr -d '[:space:]'`
```

Create an Azure Container Apps environment with the delegated subnet.

```bash
az containerapp env create \
    --name $CONTAINERAPPS_ENVIRONMENT \
    --resource-group $RESOURCE_GROUP \
    --location "$LOCATION" \
    --logs-destination none \
    --internal-only false \
    --infrastructure-subnet-resource-id $INFRASTRUCTURE_SUBNET
```

Deploy the Azure Container App using the `hivemq-ce-rbac:latest` image from the Azure Container Registry.
```bash
az containerapp create \
    --name $NAME \
    --resource-group $RESOURCE_GROUP \
    --environment $CONTAINERAPPS_ENVIRONMENT \
    --image ${NAME}.azurecr.io/hivemq-ce-rbac:latest \
    --registry-server $NAME.azurecr.io \
    --registry-identity $USERID 
```

Enable public TCP ingress for the Azure Container App with target port 1883 and exposed port 1883.
```bash
az containerapp ingress enable \
  --name $NAME \
  --resource-group $RESOURCE_GROUP \
  --target-port 1883 \
  --exposed-port 1883 \
  --transport tcp \
  --allow-insecure false \
  --type external
```

Get your public IP address. 
```bash
curl ipinfo.io
```

```bash
# ExpressVPN - Singapore
{
  "ip": "85.203.21.193",
  "city": "Singapore",
  "region": "Singapore",
  "country": "SG",
  "loc": "1.2897,103.8501",
  "org": "AS206092 IPXO LIMITED",
  "postal": "018989",
  "timezone": "Asia/Singapore",
  "readme": "https://ipinfo.io/missingauth"
}%
```

Create an access restriction rule to allow access to the Azure Container App from a specific IP address.
```bash
IP_ADDRESS="85.203.21.193"
az containerapp ingress access-restriction set \
   --name $NAME \
   --resource-group $RESOURCE_GROUP \
   --rule-name "Allow My IP" \
   --description "Some description" \
   --ip-address ${IP_ADDRESS}/16 \
   --action Allow
```


## Testing

To test the deployment, you can use the HiveMQ MQTT CLI tool:

Get the public hostname/FQDN of the Azure Container App.
```bash
HOSTNAME=$(az containerapp ingress show --name $NAME --resource-group $RESOURCE_GROUP --output json | jq -r '.fqdn')

docker run hivemq/mqtt-cli test -h $HOSTNAME -p 1883 -u user1 -pw pass1
```

`user1` is configured via the file-rbac-extension located in the `./hivemq-file-rbac-extension/conf/credentials.xml` file.


## Misc

The HiveMQ File RBAC Extension was downloaded using the following commands:

```bash
curl --silent --location https://github.com/hivemq/hivemq-file-rbac-extension/releases/download/4.6.0/hivemq-file-rbac-extension-4.6.0.zip --output ./hivemq-file-rbac-extension.zip

unzip ./hivemq-file-rbac-extension.zip -d .

rm ./hivemq-file-rbac-extension.zip
```

Refer to [hivemq/hivemq-file-rbac-extension](https://github.com/hivemq/hivemq-file-rbac-extension) for more information.