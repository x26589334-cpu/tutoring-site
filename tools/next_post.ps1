param([string]$Day = '')
$ErrorActionPreference='Stop'
# 오늘 올릴 2편을 골라 준다.
#   1편(고정) = 지역 + 과목 글  — 안 쓴 (동네 x 과목) 조합, 학교 많은 동네부터
#   2편(변동) = 요일별          — 월화목금: 질문형(FAQ) / 수토: 인포그래픽
# 사용법:  .\tools\next_post.ps1            (오늘 요일 자동)
#          .\tools\next_post.ps1 -Day 수    (요일 지정)

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

# ---------- 이미 쓴 글 ----------
$usedCombo = @{}
$usedArea  = @{}
$usedTitle = New-Object System.Collections.Generic.List[string]
foreach($f in (Get-ChildItem "$BLOG\*.html" -ErrorAction SilentlyContinue)){
  $h = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $ct = MetaOf $h 'article:center'
  $sj = MetaOf $h 'article:subject'
  if($ct -and $sj){ $usedCombo["$ct|$sj"] = $true; $usedArea[$ct] = 1 + $usedArea[$ct] }
  $mt = [regex]::Match($h, '<title>([^<]*)</title>')
  if($mt.Success){ $usedTitle.Add(($mt.Groups[1].Value -replace '\s*\|\s*공부의 온도\s*$','')) }
}

# ---------- 트랙 A ----------
$CEN = Load-Js "$SITE\centers-data.js" 'window.CENTERS='
$SUBJECTS = '수학','영어','국어','과학','사회'

$rows = foreach($g in ($CEN | Group-Object name)){
  $rs = @($g.Group)
  $e  = @($rs | ForEach-Object { $_.elem -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
  $mi = @($rs | ForEach-Object { $_.mid  -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
  $hi = @($rs | ForEach-Object { $_.high -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
  $sgg = ''
  $parts = ($rs[0].addr -split '\s+') | Where-Object { $_ }
  if($parts.Count -ge 2 -and $parts[1] -match '(시|군|구)$'){ $sgg = $parts[1] }
  [pscustomobject]@{
    center=$g.Name; region=$rs[0].region; dong=$rs[0].dong; sgg=$sgg
    ele=$e; mid=$mi; hig=$hi; total=($e.Count+$mi.Count+$hi.Count); used=[int]$usedArea[$g.Name]
  }
}

# ---------- 증상 은행 ----------
$SYMPTOM = @{
  '수학' = @('계산은 맞는데 서술형에서만 깎인다면','학원은 다니는데 시험만 보면 무너진다면','개념은 아는데 응용문제에서 손이 멈춘다면','오답노트를 쓰는데 같은 걸 또 틀린다면','진도는 나갔는데 앞 단원이 비어 있다면','문제는 푸는데 시간이 늘 모자란다면')
  '영어' = @('단어는 외우는데 문장이 안 읽힌다면','지문은 읽었는데 답이 틀린다면','내신은 되는데 모의고사가 안 된다면','문법 문제만 나오면 찍는다면','영작 서술형에서 다 깎인다면')
  '국어' = @('문제집은 푸는데 점수가 그대로라면','비문학만 나오면 시간이 모자란다면','문학 해석이 매번 제각각이라면','수행평가 글쓰기에서 감점된다면','어휘를 몰라 지문이 안 읽힌다면')
  '과학' = @('공식은 외웠는데 단위에서 틀린다면','실험 문제만 나오면 막힌다면','암기는 되는데 계산이 안 된다면','그래프 해석에서 막힌다면')
  '사회' = @('외울 게 많아 손을 못 대고 있다면','역사 흐름이 안 잡힌다면','자료·지도 해석에서 틀린다면','서술형에서 키워드를 못 쓴다면')
}

# ---------- 질문 은행 ----------
$QUESTIONS = @(
  '중2인데 수학 학원을 과외로 바꿔야 할까요?'
  '화상과외, 초등학생도 집중이 될까요?'
  '과외 선생님을 바꾸고 싶은데 언제 말해야 하나요?'
  '학원이랑 과외를 같이 시켜도 되나요?'
  '과외는 주 몇 회가 적당한가요?'
  '아이가 과외를 싫어하는데 계속 시켜야 할까요?'
  '초등학생도 과외가 필요한가요?'
  '중3 겨울방학에 고등 선행을 어디까지 해야 하나요?'
  '방문과외와 화상과외, 뭐가 더 효과가 좋나요?'
  '과외를 시작하면 학원은 바로 끊어야 하나요?'
  '성적이 안 오르면 선생님을 바꿔야 하나요?'
  '고1인데 지금 과외를 시작해도 늦지 않을까요?'
  '수업 시간에 부모가 같이 있어도 되나요?'
  '과외 첫 수업에서 무엇을 봐야 하나요?'
  '아이가 자꾸 숙제를 안 해 갑니다. 어떻게 해야 하나요?'
)

# ---------- 인포그래픽 은행 ----------
$INFOGRAPHICS = @(
  '중2 수학 한 해 단원 지도'
  '중3 수학 한 해 단원 지도'
  '고1 공통수학 단원 지도'
  '방문·화상·학습센터 한눈에 비교'
  '중간고사 4주 전부터 주차별 할 일'
  '학년별 영어 학습 순서'
  '내신 5등급제와 9등급제 비교표'
  '초·중·고 과목별 시험 유형 정리'
  '겨울방학 6주 학습 계획표'
  '수행평가 감점 유형 정리'
)

# ---------- 요일 ----------
$dayMap = @{0='일';1='월';2='화';3='수';4='목';5='금';6='토'}
if(-not $Day){ $Day = $dayMap[ [int]((Get-Date).DayOfWeek) ] }
$trackB = if($Day -eq '수' -or $Day -eq '토'){ '인포그래픽' } else { '질문형' }

"==============================================="
"  오늘($($Day)요일) 올릴 2편"
"==============================================="

# ---------- 1편 ----------
$cand = $rows | Sort-Object @{e='used'}, @{e='total'; Descending=$true}
$done = $false
foreach($r in $cand){
  if($done){ break }
  foreach($sj in $SUBJECTS){
    if($usedCombo.ContainsKey("$($r.center)|$sj")){ continue }
    $area = (@($r.sgg, $r.dong) | Where-Object { $_ }) -join ' '
    ""
    "[1] 지역 + 과목 --------------------------------"
    "   article:kind     지역"
    "   article:center   $($r.center)"
    "   article:area     $area"
    "   article:subject  $sj"
    "   센터 페이지       ../c/$($r.center).html"
    "   중학교($($r.mid.Count))  $($r.mid -join ', ')"
    "   고등학교($($r.hig.Count)) $($r.hig -join ', ')"
    "   초등학교($($r.ele.Count)) $($r.ele -join ', ')"
    ""
    "   제목 후보 (증상 하나 고르기)"
    foreach($sym in $SYMPTOM[$sj]){ "     - $area {학년}$($sj)과외 - $sym" }
    $done = $true
    break
  }
}

# ---------- 2편 ----------
""
"[2] $trackB ----------------------------------"
if($trackB -eq '질문형'){
  "   article:kind     질문"
  "   ** FAQPage 구조화 데이터를 반드시 넣을 것 (이 트랙의 목적)"
  ""
  "   안 쓴 질문"
  $n = 0
  foreach($q in $QUESTIONS){
    if($usedTitle -contains $q){ continue }
    "     - $q"; $n++
    if($n -ge 5){ break }
  }
} else {
  "   article:kind     인포그래픽"
  "   ** SVG 1장 + 짧은 해설. 파일명과 alt 에 키워드를 넣을 것"
  ""
  "   안 쓴 주제"
  $n = 0
  foreach($g in $INFOGRAPHICS){
    $hit = $false
    foreach($t in $usedTitle){ if($t -like "*$g*"){ $hit = $true; break } }
    if($hit){ continue }
    "     - $g"; $n++
    if($n -ge 5){ break }
  }
}

$written = @(Get-ChildItem "$BLOG\*.html" -ErrorAction SilentlyContinue).Count
""
"-----------------------------------------------"
"쓴 글 $written 편"
"  지역x과목 남은 조합 $((($rows.Count * $SUBJECTS.Count) - $usedCombo.Count))개"
"  질문 은행 $($QUESTIONS.Count)개 / 인포그래픽 은행 $($INFOGRAPHICS.Count)개"
""
"올린 뒤:  .\tools\build_blog.ps1  ->  .\tools\build_sitemap.ps1  ->  commit/push"
