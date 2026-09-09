#!/usr/bin/env bash
set -euo pipefail

. /etc/weather-care-relay.env

printf 'Authorization: Bearer %s\n' "$RELAY_TOKEN" \
  | curl --fail --silent --show-error \
      --request POST \
      --header @- \
      --header 'Content-Type: application/json' \
      --data '{"minLongitude":126.9948,"maxLongitude":127.0624,"minLatitude":37.2367,"maxLatitude":37.2905}' \
      http://127.0.0.1:8788/v1/its/event-info \
  | node --input-type=module -e '
      let raw = "";
      process.stdin.setEncoding("utf8");
      process.stdin.on("data", (chunk) => { raw += chunk; });
      process.stdin.on("end", () => {
        const payload = JSON.parse(raw);
        const response = payload.response ?? payload;
        const resultCode = String(response.header?.resultCode ?? response.resultCode ?? "");
        if (resultCode !== "0") throw new Error(`ITS resultCode=${resultCode || "missing"}`);
        const totalCount = response.body?.totalCount ?? "unknown";
        console.log(`ITS_RELAY_OK resultCode=0 totalCount=${totalCount}`);
      });
    '
