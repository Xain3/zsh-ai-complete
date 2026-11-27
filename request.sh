#!/usr/bin/env bash
# Called by fzf. Configuration and the query are data, never shell source.
set -o pipefail

config_file=$1
selection_file=$2
query=$3
[[ -n $query ]] || exit 0
provider=$(cat -- "$selection_file") || exit 1
info=$(jq -ce --arg provider "$provider" '.[$provider] | objects' "$config_file") || exit 1
url=$(jq -er '.url | strings' <<< "$info") || exit 1
model=$(jq -er '.model | strings' <<< "$info") || exit 1
system_message=$(jq -er '.system_message | strings' <<< "$info") || exit 1
output_path=$(jq -er '.output_path | strings' <<< "$info") || exit 1
token=$(jq -r '.token // "" | strings' <<< "$info") || exit 1

# Only permit simple jq paths; never interpret configuration as shell syntax.
[[ $output_path =~ ^\.[a-zA-Z_][a-zA-Z0-9_]*(\[[0-9]+\])?(\.[a-zA-Z_][a-zA-Z0-9_]*(\[[0-9]+\])?)*$ ]] || exit 1
[[ $url == http://* || $url == https://* ]] || exit 1
[[ $token != *$'\n'* && $token != *$'\r'* ]] || exit 1

payload=$(jq -n --arg model "$model" --arg system "$system_message" --arg query "$query" \
  '{model:$model, messages:[{role:"system",content:$system},{role:"user",content:$query}], stream:false}') || exit 1

# Pass credentials via curl's configuration input, not its process arguments.
curl_config='header = "Content-Type: application/json"'
if [[ -n $token ]]; then
  header=$(printf 'Authorization: Bearer %s' "$token" | jq -Rs .) || exit 1
  curl_config+=$'\n'"header = $header"
fi
printf '%s' "$payload" | curl --silent --show-error --fail --max-time 30 \
  --config <(printf '%s\n' "$curl_config") --url "$url" --data-binary @- |
  jq -r "$output_path // empty | strings" | awk 'NF'
