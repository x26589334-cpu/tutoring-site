$ErrorActionPreference='Stop'
$SITE = "$HOME\tutoring-site"
$SRC  = "$HOME\wawa-renewal\assets\js\centers-data.js"

$raw = Get-Content $SRC -Raw -Encoding UTF8
$marker = 'window.WAWA_CENTERS ='
$js = $raw.Substring($raw.IndexOf($marker) + $marker.Length).TrimEnd()
if($js.EndsWith(';')){ $js = $js.Substring(0,$js.Length-1) }
$js = [regex]::Replace($js,'([{,])(\s*)([A-Za-z_]\w*)\s*:','$1$2"$3":')
$SRCLIST = $js | ConvertFrom-Json

# 브랜드 표기 제거 — 공부의 온도에는 와와 계열 이름이 나오면 안 된다
$BRAND = '와와학습코칭학원|와와학습코칭센터|와와학습코칭|와와|모두오름학습코칭학원|모두오름|더블유플러스학원|더블유플러스|더블유|글로리드학습코칭학원|글로리드|WAWA|W\+'

function CleanName($s){
  $v = [regex]::Replace([string]$s, '\s*\(\s*(모두오름|모두|글로리드|더블유플러스|더블유|와와|WAWA|W\+)\s*\)\s*', '')
  return $v.Trim()
}
function CleanAddr($s){
  $v = [regex]::Replace([string]$s, "\s*($BRAND)[가-힣A-Za-z]*", ' ')
  $v = [regex]::Replace($v, '\s+', ' ')
  return $v.Trim()
}

$out = New-Object System.Collections.Generic.List[object]
foreach($c in $SRCLIST){
  $out.Add([pscustomobject][ordered]@{
    name   = CleanName $c.name
    region = [string]$c.region
    addr   = CleanAddr $c.addr
    elem   = [string]$c.elem
    mid    = [string]$c.mid
    high   = [string]$c.high
    dong   = [string]$c.dong
  })
}

$hdr = @"
/* 공부의 온도 — 학습센터 목록 데이터 (자동 생성, 수정하지 말 것)
   name=센터명, region=시도, addr=주소, elem/mid/high=인근 초/중/고, dong=동
   ※ 원본은 와와 센터 데이터. 브랜드 표기(와와·모두오름·글로리드·더블유플러스)는 제거하고 옮긴다. */
window.CENTERS=
"@
$body = ConvertTo-Json -InputObject $out.ToArray() -Depth 5 -Compress
[IO.File]::WriteAllText("$SITE\centers-data.js", $hdr + $body + ";`n", (New-Object Text.UTF8Encoding $false))

"센터 $($out.Count)개 → centers-data.js ({0:N0} bytes)" -f (Get-Item "$SITE\centers-data.js").Length
"--- 브랜드 잔존 검사 ---"
$leak = $out | Where-Object { $_.name -match $BRAND -or $_.addr -match $BRAND }
if($leak){ $leak | ForEach-Object { "  남음: $($_.name) / $($_.addr)" } } else { "  없음 (깨끗)" }
"--- 샘플 3건 ---"
$out | Select-Object -First 3 | ForEach-Object { "  $($_.name) | $($_.region) | $($_.addr)" }
