# Bicep

## Quickstart

Provision supporting infrastructure, Network, Azure Container Registry, Azure Container App Environment. 
```bash
# Login to Azure CLI.
az login

# Deploy the ARM template as a subcription level deployment.
az deployment sub create \
    --name hivemq-poc \
    --location australiaeast \
    --template-file ./main.bicep \
    --parameters projectName=hivemq envName=poc
```

Build and Push custom hivemq container image:


```bash
cd ..

az acr login --name hivemqpocacr

docker build -t hivemqpocacr.azurecr.io/hivemq-ce-rbac:latest .

docker push hivemqpocacr.azurecr.io/hivemq-ce-rbac:latest
```

Get the user assigned identity id.

```bash
USERID=$(az identity show --resource-group hivemq-poc-rg --name hivemqpocacr --query id --output tsv)
```

Deploy the Azure Container App using the `hivemq-ce-rbac:latest` image from the Azure Container Registry.
```bash
az containerapp create \
    --name hivemq-app \
    --resource-group hivemq-poc-rg \
    --environment hivemq-poc \
    --image hivemqpocacr.azurecr.io/hivemq-ce-rbac:latest \
    --registry-server hivemqpocacr.azurecr.io \
    --registry-identity $USERID
```

Enable public TCP ingress for the Azure Container App with target port 1883 and exposed port 1883.
```bash
az containerapp ingress enable \
  --name hivemq-app \
  --resource-group hivemq-poc-rg \
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
  "ip": "193.37.32.150",
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
IP_ADDRESS="193.37.32.150"
az containerapp ingress access-restriction set \
   --name hivemq-app \
   --resource-group hivemq-poc-rg \
   --rule-name "Allow My IP" \
   --description "Some description" \
   --ip-address ${IP_ADDRESS}/16 \
   --action Allow
```

## Testing

To test the deployment, you can use the HiveMQ MQTT CLI tool:

Get the public hostname/FQDN of the Azure Container App.
```bash
HOSTNAME=$(az containerapp ingress show --name hivemq-app --resource-group hivemq-poc-rg --output json | jq -r '.fqdn')

docker run hivemq/mqtt-cli test -h $HOSTNAME -p 1883 -u user1 -pw pass1
```

`user1` is configured via the file-rbac-extension located in the `./hivemq-file-rbac-extension/conf/credentials.xml` file.

## Clean up

Delete the resource group to clean up the resources.

```bash
az group delete --name hivemq-poc-rg --yes --no-wait
```