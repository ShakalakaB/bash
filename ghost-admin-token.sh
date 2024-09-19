# Admin API key goes here
KEY="66aa76b16477dd0001d88037:b903d6e1e34ec77d4db6994f3295017e6ad9466eb238c5c48eebfc2755823bc3"

# Split the key into ID and SECRET
TMPIFS=$IFS
IFS=':' read ID SECRET <<< "$KEY"
IFS=$TMPIFS

echo $ID
echo $SECRET

# Prepare header and payload
NOW=$(date +'%s')
FIVE_MINS=$(($NOW + 300))
HEADER="{\"alg\": \"HS256\",\"typ\": \"JWT\", \"kid\": \"$ID\"}"
PAYLOAD="{\"iat\":$NOW,\"exp\":$FIVE_MINS,\"aud\": \"/admin/\"}"

# Helper function for performing base64 URL encoding
base64_url_encode() {
    declare input=${1:-$(</dev/stdin)}
    # Use `tr` to URL encode the output from base64.
    printf '%s' "${input}" | base64 | tr -d '=' | tr '+' '-' | tr '/' '_'
}

# Prepare the token body
header_base64=$(base64_url_encode "$HEADER")
payload_base64=$(base64_url_encode "$PAYLOAD")

header_payload="${header_base64}.${payload_base64}"

# Create the signature
signature=$(printf '%s' "${header_payload}" | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:$SECRET | base64_url_encode)

# Concat payload and signature into a valid JWT token

TOKEN="${header_payload}.${signature}"

echo $TOKEN
