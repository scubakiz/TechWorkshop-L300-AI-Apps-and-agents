# Variables
$SUBSCRIPTION_ID="f78f59ad-cf27-4eff-8f5e-6f97b34798aa"
$RG="techworkshop-l300-ai-agents"
$ACCOUNT="ndszanuxkmdys-cosmosdb"
$PRINCIPAL_ID="b9ce58c2-3ee3-46aa-923e-2c3ddf78bcfa"
#$PRINCIPAL_ID="134b6b4b-5b03-45b3-b922-e67210528eaf"
$ROLE_DEF="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG/providers/Microsoft.DocumentDB/databaseAccounts/$ACCOUNT/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"

# 1) Log in and select subscription
#az login
#az account set --subscription "$SUBSCRIPTION_ID"

# 2) Create data-plane role assignment (root scope "/")
az cosmosdb sql role assignment create `
    --account-name "$ACCOUNT" `
    --resource-group "$RG" `
    --role-definition-id "$ROLE_DEF" `
    --principal-id "$PRINCIPAL_ID" `
    --scope "/"

# 3) Verify
az cosmosdb sql role assignment list `
    --account-name "$ACCOUNT" `
    --resource-group "$RG" `
    --query "[?principalId=='$PRINCIPAL_ID']"
