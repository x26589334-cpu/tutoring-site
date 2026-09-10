param([int]$Count = 3)

# 오늘 쓸 글감을 골라 준다. 이미 쓴 (동네 × 과목) 조합은 빼고,
# 학교가 많아 본문에 쓸 재료가 풍부한 동네부터 제안한다.
#   사용법:  .\tools\next_post.ps1            → 3개 제안
#            .\tools\next_post.ps1 -Count 5   → 5개 제안
$ErrorActionPreference='Stop'

$SITE = Split-Path $PSScriptRoot -Parent

function Load-Js($path, $marker){
  $raw = Get-Content $path -Raw -Encoding UTF8
  $js  = $raw.Substring($raw.IndexOf($marker) + $marker.Length).TrimEnd()
  if($js.EndsWith(';')){ $js = $js.Substring(0, $js.Length-1) }
  return ($js | ConvertFrom-Json)
}
$CEN = Load-Js "$SITE\centers-data.js" 'window.CENTERS='

# 이미 쓴 조합
$used = @{}
$usedArea = @{}
foreach($f in (Get-ChildItem "$SITE\blog\*.html" -ErrorAction SilentlyContinue)){
  $h = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $a = [regex]::Match($h,'<meta\s+name="article:center"\s+content="([^"]*)"')
  $s = [regex]::Match($h,'<meta\s+name="article:subject"\s+content="([^"]*)"')
  if($a.Success -and $s.Success){
    $used["$($a.Groups[1].Value)|$($s.Groups[1].Value)"] = $true
    $usedArea[$a.Groups[1].Value] = 1 + $usedArea[$a.Groups[1].Value]
  }
}

$SUBJECTS = '수학','영어','국어','과학','사회'

# 센터를 이름으로 묶고(같은 이름 여러 지점) 학교 목록을 합친다
$rows = foreach($g in ($CEN | Group-Object name)){
  $rs = @($g.Group)
  $e  = @($rs | ForEach-Object { $_.elem -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
  $mi = @($rs | ForEach-Object { $_.mid  -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
  $hi = @($rs | ForEach-Object { $_.high -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
  $addr = $rs[0].addr
  $sgg = ''
  $parts = ($addr -split '\s+') | Where-Object { $_ }
  if($parts.Count -ge 2 -and $parts[1] -match '(시|군|구)$'){ $sgg = $parts[1] }
  [pscustomobject]@{
    center = $g.Name
    region = $rs[0].region
    dong   = $rs[0].dong
    sgg    = $sgg
    초     = $e
    중     = $mi
    고     = $hi
    학교수 = $e.Count + $mi.Count + $hi.Count
    쓴횟수 = [int]$usedArea[$g.Name]
  }
}

# 아직 안 쓴 동네 먼저, 그다음 학교가 많은 순
$cand = $rows | Sort-Object @{e='쓴횟수'}, @{e='학교수'; Descending=$true}

$picked = 0
foreach($r in $cand){
  foreach($sj in $SUBJECTS){
    if($used.ContainsKey("$($r.center)|$sj")){ continue }
    $area = (@($r.sgg, $r.dong) | Where-Object { $_ }) -join ' '
    ""
    "─────────────────────────────────────────────"
    "제안 $($picked+1)   $area · $sj"
    "─────────────────────────────────────────────"
    "  article:center   $($r.center)"
    "  article:area     $area"
    "  article:subject  $sj"
    "  지역(시도)        $($r.region)"
    "  센터 페이지       c/$($r.center).html"
    "  중학교($($r.중.Count))  $($r.중 -join ', ')"
    "  고등학교($($r.고.Count)) $($r.고 -join ', ')"
    "  초등학교($($r.초.Count)) $($r.초 -join ', ')"
    "  제목 예시        $area $($sj)과외 — {증상 한 문장}"
    $picked++
    break
  }
  if($picked -ge $Count){ break }
}

""
"쓴 글 $($used.Count)편 / 남은 조합 $((($rows.Count * $SUBJECTS.Count) - $used.Count))개"
