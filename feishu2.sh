#!/bin/sh
# ---------------------------------------------------------------------------
# Download Feishu “stream/preview” PDFs listed in tokens.txt and name them
# PREFIX1.pdf, PREFIX2.pdf, PREFIX3.pdf, … (default PREFIX="", e.g. 1.pdf)
#
# Usage:  ./download_tokens.sh [tokens_file] [prefix] [out_dir] [start#]
# Example: ./download_tokens.sh tokens.txt INV ~/Desktop/2024 1
# ---------------------------------------------------------------------------

TOKENS="
BhAWbpHppoxxYQxFDDjchAQJnCj
DUR1bvECco9ip4xN0i7cnWFkntb
WJ6Pb6Y7ioV0qTxOoSPc7cXEnag
UMDwbkh0So6QRxxOnGGcZQCsn0c
Gh4CbqywqorMLHxVPTec59FlnOb
OW95bs3sDoQeZdxudKBcR2Uqnjf
UzQibM0kYoTLS5x7B1cc0AUDnKe
UBUwbDW6poIZtJxB6x4cFak5nmb
Ua09bu9ZAo2WlMxt0oCckFoEnwg
QZFjbvNhJooesNxVTkUcyzzVnyc
VVhYba8SgoLnvBx1x0Xc0jYenie
GLnObvkkYoXnBFxOiRkcjIOfnxc
WMH4bgsLOoa0mhxsxbEcvMWPn2b
DpT8beq6OozQy8xzsOHcju5Bnec
NIBdbAgTroWukCx5nkJcJ4R5nAd
JCkdbaT4qoYMsixFErVcTg1wnrc
NnUwbgpL4o4noOxLHIpcvExwnaf
EjoZbbLb1ogMQQxaeE8ctvGUnoh
ZIKpbzqvNovoglxdmatcwUOsnxb
FXjmbGAYlorh67xaKsocP5jOnIc
HfYlbnKeHoWzLgx8PdRcIw5YnIg
IcJvbMsVmo7wvyxkSnbcr4Bsnqc
QQh0b0JCHoMva2xL3Xycwj1cnih
NiYVbprClon7QaxysgMceBbBnnf
"

OUT_DIR="$HOME/Desktop/2024"
BASE_URL="https://internal-api-drive-stream.feishu.cn/space/api/box/stream/download/preview"
QUERY="?preview_type=16&mount_point=wiki"
PREFIX="12."
SEQ_START=1

COOKIES='passport_web_did=7449843934668275713; passport_trace_id=7449843934672470044; QXV0aHpDb250ZXh0=900f4fc8dbc64d95ae1558ecc0017313; lang=en; i18n_locale=en; landing_url=https://www.feishu.cn/accounts/page/create?lang=en-US&redirect_uri=https%253A%252F%252Fwww.feishu.cn%252Finvitation%252Fpage%252Fadd_contact%252F%253Ftoken%253Dc89q6be6-1598-4266-9c2b-27df341c323a%2526amp%253Bunique_id%253D7butWXBAZV_FqqxfXtT_tA%253D%253D&utm_from=organic_invite_people_web; s_v_web_id=verify_mdpij9ks_qlLUuo51_WiJs_4kIz_8Rgt_1oJgMbTE9u8n; __tea__ug__uid=7532739371386471987; fid=f620016f-be81-43ef-95ea-b2ef1575c16b; login_recently=1; locale=en-US; msToken=uw3gJ6wPu8LZ2tHRAMc67l92IIbcPDd2bPjYLM0ftMTCB34M-xn2D4MiSRs7ZTI4pCqUvHj9xRBJ706TH-r600zKQtWMjzZqXxOKzmAH_z_yU6A8zNR06g==; is_anonymous_session=; _csrf_token=da0f6a3a364ce546a89ad88134b77befb1b692b0-1753860418; session=XN0YXJ0-e8as379e-171f-456e-bebe-e26a4d9cdb45-WVuZA; session_list=XN0YXJ0-e8as379e-171f-456e-bebe-e26a4d9cdb45-WVuZA_XN0YXJ0-276s8dfe-2494-49a8-8e0f-926803da7cf3-WVuZA_XN0YXJ0-e8as379e-171f-456e-bebe-e26a4d9cdb45-WVuZA; help_center_session=4375b12e-a1d4-4df4-a171-47810a9ccce0; _uuid_hera_ab_path_1=7532778060297240604; sl_session=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NTQyMjk0OTUsInVuaXQiOiJldV9uYyIsInJhdyI6eyJtZXRhIjoiQVdpSnF2WTJ4RUFFYUltcTcrMWJ3QU5uWXltV2JnQkFBV2RqS1padUFFQUJhSW1yQjBQQXdBTUNLZ0VBUVVGQlFVRkJRVUZCUVVKdmFXRnpTRlpuUVVGQmR6MDkiLCJpZGMiOlsxLDJdLCJzdW0iOiIzZjAzZGE3NDUxYTJmMmQ2YjFiOTNiNmVhN2ViMGQ1ZTkxZDU1NmYyZTZjMjNkMzMwODBjMGRkYWYzYjJiMzE3IiwibG9jIjoiZW5fdXMiLCJhcGMiOiJSZWxlYXNlIiwiaWF0IjoxNzU0MTg2Mjk1LCJzYWMiOnsiVXNlclN0YWZmU3RhdHVzIjoiMSIsIlVzZXJUeXBlIjoiNDIifSwibG9kIjpudWxsLCJucyI6ImxhcmsiLCJuc191aWQiOiI3NTMyNzM5ODI2MjExMzczMDYwIiwibnNfdGlkIjoiNzUzMjczOTc5OTIwOTk4NDAwMyIsIm90IjozLCJjdCI6MTc1Mzg1MjY3OSwicnQiOjE3NTQxMjEwMDN9fQ.V_SNG8ZZxQp6buBK5QR5xl4zOIXsgigh6AlUM1e2aNcqAyhXudMY31SaHg-DPh2y-22qlvVlxJSk-nh65udKLg; swp_csrf_token=74cdf7c0-7297-4dd6-b3ff-93f66e0faa64; t_beda37=b7db8b962f213be010907772e9702d0b306cb1e00c8bf38ccf15c69d79ee7955; passport_app_access_token=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NTQyMjk3MTQsInVuaXQiOiJldV9uYyIsInJhdyI6eyJtX2FjY2Vzc19pbmZvIjp7IjQiOnsiaWF0IjoxNzU0MTg2NTE0LCJhY2Nlc3MiOnRydWV9fSwic3VtIjoiM2YwM2RhNzQ1MWEyZjJkNmIxYjkzYjZlYTdlYjBkNWU5MWQ1NTZmMmU2YzIzZDMzMDgwYzBkZGFmM2IyYjMxNyJ9fQ.33IWb2v7aXtMP9hccHNzUKoL3PaAu0XhFIMxtBB5Bkm4lGUdQlMkUGlT7pyu5VytOT0ERU8MBrjvyKMdl5dlYg'
HEADERS_COMMON=(
  -H 'accept: */*'
  -H 'accept-language: en-US,en;q=0.9'
  -H 'priority: u=1, i'
  -H 'sec-ch-ua: "Not)A;Brand";v="8", "Chromium";v="138", "Google Chrome";v="138"'
  -H 'sec-ch-ua-mobile: ?0'
  -H 'sec-ch-ua-platform: "macOS"'
  -H 'sec-fetch-dest: empty'
  -H 'sec-fetch-mode: cors'
  -H 'sec-fetch-site: same-origin'
  -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36'
  -H 'x-command: stream.download.preview'
  --cookie "$COOKIES"
)

n=$SEQ_START

for token in $TOKENS; do
  outfile="$OUT_DIR/${PREFIX}${n}.pdf"
  url="${BASE_URL}/${token}${QUERY}"
  echo "⬇️  $token → $(basename "$outfile")"

  # shellcheck disable=SC2086 # intentional word splitting for array
  curl -fSL -o "$outfile" "$url" "${HEADERS_COMMON[@]}"

  n=$((n+1))
done
echo "✅  Done."
