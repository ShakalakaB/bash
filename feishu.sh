#!/bin/bash

# === Configuration ===
BASE_URL="https://r12ry3a66x7.feishu.cn/space/api/box/stream/download/preview_sub/MJRubHEauocvAUxPeUDc2AeInGq?preview_type=22&sub_id=img_%d.webp&version=7168503096190976001"
DEST_DIR="$HOME/Documents/Read & Learn/贝乐斯/202109/Week"
BASE_NAME="202109"
START=0   # img_0
END=18     # img_5 (inclusive)

mkdir -p "$DEST_DIR"

for ((i=START; i<=END; i++)); do
  FILE_NUM=$((i+1))
  OUTFILE="${DEST_DIR}/${BASE_NAME}-${FILE_NUM}.jpg"
  URL=$(printf "$BASE_URL" "$i")

  echo "Downloading $OUTFILE"

  curl -s -o "$OUTFILE" "$URL" \
  -H 'accept: application/json, text/plain, */*' \
  -H 'accept-language: en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7,zh-TW;q=0.6' \
  -H 'cache-control: no-cache' \
  -b 'passport_web_did=7449843934668275713; passport_trace_id=7449843934672470044; QXV0aHpDb250ZXh0=900f4fc8dbc64d95ae1558ecc0017313; lang=en; i18n_locale=en; landing_url=https://www.feishu.cn/accounts/page/create?lang=en-US&redirect_uri=https%253A%252F%252Fwww.feishu.cn%252Finvitation%252Fpage%252Fadd_contact%252F%253Ftoken%253Dc89q6be6-1598-4266-9c2b-27df341c323a%2526amp%253Bunique_id%253D7butWXBAZV_FqqxfXtT_tA%253D%253D&utm_from=organic_invite_people_web; s_v_web_id=verify_mdpij9ks_qlLUuo51_WiJs_4kIz_8Rgt_1oJgMbTE9u8n; __tea__ug__uid=7532739371386471987; fid=f620016f-be81-43ef-95ea-b2ef1575c16b; is_anonymous_session=; et=132eb79608e9336b9725a69bfca6b245; session=XN0YXJ0-e8as379e-171f-456e-bebe-e26a4d9cdb45-WVuZA; session_list=XN0YXJ0-e8as379e-171f-456e-bebe-e26a4d9cdb45-WVuZA_XN0YXJ0-276s8dfe-2494-49a8-8e0f-926803da7cf3-WVuZA_XN0YXJ0-e8as379e-171f-456e-bebe-e26a4d9cdb45-WVuZA; locale=en-US; js_version=1; ccm_cdn_host=//lf-package-sg.feishucdn.com/obj/lark-static-sg; _csrf_token=780c260cc239eac0f660c4c8f531aad9727df682-1756711657; _tea_utm_cache_592346=undefined; sl_session=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NTc3OTc0MjQsInVuaXQiOiJldV9uYyIsInJhdyI6eyJtZXRhIjoiQVdpSnF2WTJ4RUFFYUltcTcrMWJ3QU5uWXltV2JnQkFBV2RqS1padUFFQUJhSW1yQjBQQXdBTUNLZ0VBUVVGQlFVRkJRVUZCUVVKdmFXRnpTRlpuUVVGQmR6MDkiLCJpZGMiOlsxLDJdLCJzdW0iOiIzZjAzZGE3NDUxYTJmMmQ2YjFiOTNiNmVhN2ViMGQ1ZTkxZDU1NmYyZTZjMjNkMzMwODBjMGRkYWYzYjJiMzE3IiwibG9jIjoiZW5fdXMiLCJhcGMiOiJSZWxlYXNlIiwiaWF0IjoxNzU3NzU0MjI0LCJzYWMiOnsiVXNlclN0YWZmU3RhdHVzIjoiMSIsIlVzZXJUeXBlIjoiNDIifSwibG9kIjpudWxsLCJucyI6ImxhcmsiLCJuc191aWQiOiI3NTMyNzM5ODI2MjExMzczMDYwIiwibnNfdGlkIjoiNzUzMjczOTc5OTIwOTk4NDAwMyIsIm90IjozLCJjdCI6MTc1Mzg1MjY3OSwicnQiOjE3NTc2NjI5MjF9fQ.sm4zg94mYf4UuediAi6xZMRbrkA4N_gX-3HNzeB9whaehiKkDTJDGB59ypOcVeGbN_NL71r3pCu3LR4BLOStjg; passport_app_access_token=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NTc3OTc0NDIsInVuaXQiOiJldV9uYyIsInJhdyI6eyJtX2FjY2Vzc19pbmZvIjp7IjE0MSI6eyJpYXQiOjE3NTc3NTQyMzAsImFjY2VzcyI6dHJ1ZX0sIjEwMCI6eyJpYXQiOjE3NTc3NTQyMzEsImFjY2VzcyI6dHJ1ZX0sIjI5Ijp7ImlhdCI6MTc1Nzc1NDIzMiwiYWNjZXNzIjp0cnVlfSwiMTQzIjp7ImlhdCI6MTc1Nzc1NDIzMiwiYWNjZXNzIjp0cnVlfSwiNCI6eyJpYXQiOjE3NTc3NTQyNDIsImFjY2VzcyI6dHJ1ZX0sIjIiOnsiaWF0IjoxNzU3NzU0MjI2LCJhY2Nlc3MiOnRydWV9fSwic3VtIjoiM2YwM2RhNzQ1MWEyZjJkNmIxYjkzYjZlYTdlYjBkNWU5MWQ1NTZmMmU2YzIzZDMzMDgwYzBkZGFmM2IyYjMxNyJ9fQ.C8OD0Vk2TlWFnRf80eiQ5xZRZ3OIlxfsIqmtMsq7UkoGZGqG74Zc1BwVJx54VyhL7ycR9u2dxBbQY56dFQCKAQ; template-dev-mode=1; template-branch-list=release-web-2025.9.2; swp_csrf_token=384b848b-67a4-4359-b1e7-1ccc5fd2fec1; t_beda37=a6d327f8dbe8282e4453df7f717ce09422c24ff3643556a9c4272ad37d988ee9' \
  -H 'doc-biz: Lark' \
  -H 'doc-os: mac' \
  -H 'doc-platform: web' \
  -H 'pragma: no-cache' \
  -H 'priority: u=1, i' \
  -H 'referer: https://r12ry3a66x7.feishu.cn/wiki/SqrPwhLRmiZomoktJrEcUiHPnec' \
  -H 'rpc-persist-lane-c-lark-uid: 0' \
  -H 'sec-ch-ua: "Chromium";v="140", "Not=A?Brand";v="24", "Google Chrome";v="140"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-fetch-dest: empty' \
  -H 'sec-fetch-mode: cors' \
  -H 'sec-fetch-site: same-origin' \
  -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36' \
  -H 'x-command: space.api.box.stream.download.preview_sub.MJRubHEauocvAUxPeUDc2AeInGq' \
  -H 'x-csrftoken: 780c260cc239eac0f660c4c8f531aad9727df682-1756711657' \
  -H 'x-lgw-app-id: 1161' \
  -H 'x-lgw-os-type: 3' \
  -H 'x-lgw-terminal-type: 2' \
  -H 'x-request-id: 1OMjcYEYFagaSaJDxglwIKMWdChiHU2V'
done
echo "✅  Done."
