# Bicep

## Quickstart

```bash
# Login to Azure CLI.
az login

# Generate ARM template from Bicep file.
az bicep build --file main.bicep

# Deploy the ARM template as a subcription level deployment.
az deployment sub create \
    --name hivemq-poc \
    --location australiaeast \
    --template-file ./main.bicep \
    --parameters projectName=hivemq envName=poc
```