# Set variables
workspaceId="<Your Workspace ID>"
workspaceKey="<Your Workspace Key>"
logType="CustomLogType"

# File containing the JSON payload
jsonFile="logs.json"

# Create a RFC1123 date string
rfc1123date=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")

# Read the JSON payload
jsonPayload=$(cat $jsonFile)
contentLength=${#jsonPayload}
contentType="application/json"
resource="/api/logs"
method="POST"

# Create the string to sign
stringToSign="${method}\n${contentLength}\n${contentType}\n${rfc1123date}\n${resource}"

# Decode the workspace key from base64
decodedKey=$(echo $workspaceKey | base64 --decode -i -)

# Create the signature
signature=$(echo -n $stringToSign | openssl dgst -sha256 -hmac $decodedKey -binary | base64)

# Construct the authorization header
authorization="SharedKey ${workspaceId}:${signature}"

# Send the request using curl
curl -X POST "https://${workspaceId}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01" \
     -d "$jsonPayload" \
     -H "Content-Type: $contentType" \
     -H "Log-Type: $logType" \
     -H "x-ms-date: $rfc1123date" \
     -H "Authorization: $authorization"