param([string]$Day = '')
$ErrorActionPreference='Stop'
# 인천과외 — 오늘 올릴 3편을 골라 준다. (2026-09-28 사용자 요청으로 2편 → 3편, 3트랙 고정)
#   1편 = 중학교 내신  : "{중학교} 내신 영어과외 수학과외 기초 심화 전략은?"
#   2편 = 고등학교 내신: "{고등학교} 내신 과학과외 물리 화학 수능대비"
#   3편 = 동네 + 과목  : "인천 {동} {과목}과외 {세부키워드}"
# 세 편 모두 하루하루 키워드가 겹치지 않게 고른다 — 이미 쓴 글의 meta 를 읽어 안 쓴 조합만 남긴다.
# 사용법:  .\tools\next_post.ps1
# 데일리 자동화(사이트관리/데일리/지시서/인천과외.md)가 이 출력을 그대로 따른다.

$SITE = Split-Path $PSScriptRoot -Parent
$BLOG = "$SITE\blog"

function Load-Js($path, $marker){
  $raw = Get-Content $path -Raw -Encoding UTF8
  $js  = $raw.Substring($raw.IndexOf($marker) + $marker.Length).TrimEnd()
  if($js.EndsWith(';')){ $js = $js.Substring(0, $js.Length-1) }
  return ($js | ConvertFrom-Json)
}
function MetaOf($html, $name){
  $m = [regex]::Match($html, '<meta\s+name="' + [regex]::Escape($name) + '"\s+content="([^"]*)"')
  if($m.Success){ return $m.Groups[1].Value }
  return ''
}

$SCH = Load-Js "$SITE\incheon-schools.js" 'window.INC_SCHOOLS='
$CEN = @(Load-Js "$SITE\centers-data.js" 'window.CENTERS=')

# ---------- 동 목록 (인천동목록.md) ----------
$DONG = @{}   # 구 -> 동[]
$GU_OK = @{}; foreach($s in $SCH){ $GU_OK[$s.g] = $true }   # 학교 데이터에 있는 구만 인정(설명문 줄이 섞여 들어오는 것 방지)
foreach($line in (Get-Content "$SITE\인천동목록.md" -Encoding UTF8)){
  if($line -match '^\s*#'){ continue }
  if($line -notmatch '^([^:]+):\s*(.+)$'){ continue }
  $gu = $Matches[1].Trim()
  if(-not $GU_OK.ContainsKey($gu)){ continue }
  $DONG[$gu] = @($Matches[2] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
if(-not $DONG.Count){ throw '인천동목록.md 에서 동을 하나도 읽지 못했다 — 구 이름이 incheon-schools.js 의 g 값과 같은지 확인할 것' }

# ---------- 트랙별 세부 키워드 (3편에서 돌려 쓴다) ----------
$DETAIL = @{
  '영어' = @('문법 독해 듣기 마스터하기','단어 문장 서술형까지','내신 서술형과 듣기평가 잡기','독해 속도와 어법 정리')
  '수학' = @('기초 개념부터 심화까지','서술형 감점 줄이기','연산 오답 잡고 응용까지','단원별 구멍 메우기')
  '국어' = @('문학 비문학 어휘 잡기','서술형 수행평가까지','독해력과 근거 찾기')
  '과학' = @('개념 실험 계산까지','물리 화학 기초 다지기','그래프와 단위 정리')
  '사회' = @('흐름 잡고 서술형까지','자료 지도 해석 연습','한국사 흐름 정리')
}
$SUBJ3 = '영어','수학','국어','과학','사회'

# ---------- 이미 쓴 글 ----------
$usedMid = @{}; $usedHigh = @{}; $usedDong = @{}   # 3번 글은 "동|과목"
$usedSchoolCnt = @{}; $guCnt = @{}; $dongGuCnt = @{}
$usedTitle = New-Object System.Collections.Generic.List[string]
$schByName = @{}; foreach($s in $SCH){ $schByName[$s.n] = $s }
foreach($f in (Get-ChildItem "$BLOG\*.html" -ErrorAction SilentlyContinue)){
  $h = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $mt = [regex]::Match($h, '<title>([^<]*)</title>')
  if($mt.Success){ $usedTitle.Add(($mt.Groups[1].Value -replace '\s*\|\s*(인천과외|공부의 온도)\s*$','')) }
  $kind = MetaOf $h 'article:kind'
  $sc   = MetaOf $h 'article:school'
  $ar   = MetaOf $h 'article:area'
  $sj   = MetaOf $h 'article:subject'
  if($sc -and $schByName.ContainsKey($sc)){
    $t = $schByName[$sc].t
    if($t -eq '중'){ $usedMid[$sc] = $true }
    if($t -eq '고'){ $usedHigh[$sc] = $true }
    $usedSchoolCnt[$sc] = 1 + $usedSchoolCnt[$sc]
    $g = $schByName[$sc].g; $guCnt[$g] = 1 + $guCnt[$g]
  }
  # 3번 글: article:kind=동네, article:area 에 동 이름이 들어간다
  if($kind -eq '동네' -and $ar){
    $d = ($ar -split '\s+')[-1]
    if($sj){ $usedDong["$d|$sj"] = $true }
    $dongGuCnt[$d] = 1 + $dongGuCnt[$d]
  }
}

function GuOfDong($dong){
  foreach($gu in $DONG.Keys){ if($DONG[$gu] -contains $dong){ return $gu } }
  return ''
}
function NearSchools($gu, $t, $exclude){
  # 지역 글에는 그 구의 학교를 "다" 넣는다 — 학교급별로 전부 돌려준다
  @($SCH | Where-Object { $_.g -eq $gu -and $_.t -eq $t -and $_.n -ne $exclude } | ForEach-Object { $_.n })
}
function CentersOf($gu){
  @($CEN | Where-Object { (($_.addr -split '\s+')[1]) -eq $gu } | Group-Object name | ForEach-Object { $_.Group[0] })
}

"==============================================="
"  오늘 올릴 3편 — 인천과외  ($(Get-Date -Format 'yyyy-MM-dd'))"
"==============================================="

# ---------- 1편: 중학교 내신 (영어+수학) ----------
$midPool = @($SCH | Where-Object { $_.t -eq '중' -and -not $usedMid.ContainsKey($_.n) })
$m = $midPool | Sort-Object @{e={ [int]$guCnt[$_.g] }}, @{e='n'} | Select-Object -First 1
""
"[1] 중학교 내신 — 영어과외 + 수학과외 --------------------"
if($m){
  $near = NearSchools $m.g '중' $m.n
  $go   = NearSchools $m.g '고' ''
  $cen  = CentersOf $m.g
  "   article:kind     중등내신"
  "   article:area     인천 $($m.g)"
  "   article:school   $($m.n)"
  "   article:subject  영어,수학"
  if($cen.Count){ "   article:center   $($cen[0].name)" }
  "   학교            $($m.n) (약칭 $($m.a)) · 인천 $($m.g)"
  "   학교 페이지      ../school/$($m.n).html   ← 본문에 반드시 링크"
  "   제목 (둘 중 하나, 어제와 다른 쪽으로)"
  "     - $($m.a) 내신 영어과외 수학과외 기초 심화 전략은?"
  "     - $($m.n) 내신 영어과외 수학과외 기초 심화 전략은?"
  "   같은 구 중학교 $($near.Count)곳  " + ($near -join ', ')
  if($go.Count){ "   진학 고등학교 $($go.Count)곳  " + ($go -join ', ') }
  if($cen.Count){ "   센터            " + (($cen | ForEach-Object { "../c/$($_.name).html($($_.dong))" }) -join ', ') }
} else { "   중학교를 모두 썼다 — 과목 축을 바꾸거나 2회차를 허용할 것" }

# ---------- 2편: 고등학교 내신 (과학/물리/화학 + 수능) ----------
$hiPool = @($SCH | Where-Object { $_.t -eq '고' -and -not $usedHigh.ContainsKey($_.n) })
$h2 = $hiPool | Sort-Object @{e={ [int]$guCnt[$_.g] }}, @{e='n'} | Select-Object -First 1
""
"[2] 고등학교 내신 — 과학과외(물리·화학) + 수능대비 --------"
if($h2){
  $nearH = NearSchools $h2.g '고' $h2.n
  $nearM = NearSchools $h2.g '중' ''
  $cen   = CentersOf $h2.g
  "   article:kind     고등내신"
  "   article:area     인천 $($h2.g)"
  "   article:school   $($h2.n)"
  "   article:subject  과학"
  if($cen.Count){ "   article:center   $($cen[0].name)" }
  "   학교            $($h2.n) (약칭 $($h2.a)) · 인천 $($h2.g)"
  "   학교 페이지      ../school/$($h2.n).html   ← 본문에 반드시 링크"
  "   제목 (둘 중 하나, 어제와 다른 쪽으로)"
  "     - $($h2.a) 내신 과학과외 물리 화학 수능대비"
  "     - $($h2.n) 내신 과학과외 물리 화학 수능대비"
  "   같은 구 고등학교 $($nearH.Count)곳  " + ($nearH -join ', ')
  if($nearM.Count){ "   같은 구 중학교 $($nearM.Count)곳  " + ($nearM -join ', ') }
  if($cen.Count){ "   센터            " + (($cen | ForEach-Object { "../c/$($_.name).html($($_.dong))" }) -join ', ') }
} else { "   고등학교를 모두 썼다 — 과목 축을 바꾸거나 2회차를 허용할 것" }

# ---------- 3편: 동네 + 과목 ----------
$cand = @()
foreach($gu in $DONG.Keys){
  foreach($d in $DONG[$gu]){
    foreach($sj in $SUBJ3){
      if($usedDong.ContainsKey("$d|$sj")){ continue }
      $cand += [pscustomobject]@{ gu=$gu; dong=$d; subj=$sj; used=[int]$dongGuCnt[$d]; guUsed=[int]$guCnt[$gu] }
    }
  }
}
""
"[3] 인천 {동} + 과목 --------------------------------------"
if($cand.Count){
  $p = $cand | Sort-Object used, guUsed, @{e={ [array]::IndexOf($SUBJ3, $_.subj) }}, dong | Select-Object -First 1
  $elem = NearSchools $p.gu '초' ''
  $mid  = NearSchools $p.gu '중' ''
  $high = NearSchools $p.gu '고' ''
  $cen  = CentersOf $p.gu
  "   article:kind     동네"
  "   article:area     인천 $($p.gu) $($p.dong)"
  "   article:subject  $($p.subj)"
  if($cen.Count){ "   article:center   $($cen[0].name)" }
  "   제목 (세부 키워드 하나 고르기)"
  foreach($dt in $DETAIL[$p.subj]){ "     - 인천 $($p.dong) $($p.subj)과외 $dt" }
  "   ※ 제목에 구 이름은 넣지 않는다(사용자 지정 형식: 인천 {동} {과목}과외 …)"
  ""
  "   ★ 본문에 이 구의 학교를 **전부** 넣는다 (사용자 지시). 학교 페이지로 링크할 것"
  "     초등학교 $($elem.Count)곳  " + ($elem -join ', ')
  "     중학교   $($mid.Count)곳  " + ($mid -join ', ')
  "     고등학교 $($high.Count)곳  " + ($high -join ', ')
  if($cen.Count){ "   센터            " + (($cen | ForEach-Object { "../c/$($_.name).html($($_.dong))" }) -join ', ') }
  else { "   센터            인천 $($p.gu) 에는 학습센터가 없다 → ../centers.html 로 링크" }
} else { "   동 x 과목 조합을 모두 썼다 — 인천동목록.md 를 늘리거나 세부 키워드 축을 추가할 것" }

# ---------- 남은 양 ----------
$written = @(Get-ChildItem "$BLOG\*.html" -ErrorAction SilentlyContinue).Count
$midAll = @($SCH | Where-Object { $_.t -eq '중' }).Count
$hiAll  = @($SCH | Where-Object { $_.t -eq '고' }).Count
$dongAll = 0; foreach($gu in $DONG.Keys){ $dongAll += $DONG[$gu].Count }
""
"-----------------------------------------------"
"쓴 글 $written 편"
"  [1] 중학교 남음 $($midPool.Count) / $midAll"
"  [2] 고등학교 남음 $($hiPool.Count) / $hiAll"
"  [3] 동 x 과목 남음 $($cand.Count) / $($dongAll * $SUBJ3.Count)  (동 $dongAll 곳)"
