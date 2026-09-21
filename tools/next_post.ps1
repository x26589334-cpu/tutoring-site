param([string]$Day = '')
$ErrorActionPreference='Stop'
# 인천과외 — 오늘 올릴 2편을 골라 준다. (2026-09-21 인천 전담으로 개편)
#   1편(고정) = 인천 학교 + 과목 글  — 안 쓴 (학교 x 과목) 조합
#               과목·구·학교급이 골고루 돌도록: 적게 쓴 과목 → 적게 쓴 구 → 적게 쓴 학교급 순
#   2편(변동) = 요일별                — 월화목금: 질문형(FAQ) / 수토: 인포그래픽
# 사용법:  .\tools\next_post.ps1            (오늘 요일 자동)
#          .\tools\next_post.ps1 -Day 수    (요일 지정)
# 데일리 자동화(사이트관리/데일리/지시서/공부의온도.md)가 이 출력을 그대로 따른다.

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
$SUBJECTS = '수학','영어','국어','과학','사회'
$LV_NAME = @{ '초'='초등학교'; '중'='중학교'; '고'='고등학교' }

# ---------- 이미 쓴 글 ----------
$usedCombo = @{}   # "학교명|과목"
$usedSchool = @{}
$subjCount = @{}; foreach($s in $SUBJECTS){ $subjCount[$s] = 0 }
$guCount = @{}; $lvCount = @{ '초'=0; '중'=0; '고'=0 }
$usedTitle = New-Object System.Collections.Generic.List[string]
$schByName = @{}; foreach($s in $SCH){ $schByName[$s.n] = $s }
foreach($f in (Get-ChildItem "$BLOG\*.html" -ErrorAction SilentlyContinue)){
  $h = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $mt = [regex]::Match($h, '<title>([^<]*)</title>')
  if($mt.Success){ $usedTitle.Add(($mt.Groups[1].Value -replace '\s*\|\s*(인천과외|공부의 온도)\s*$','')) }
  $sc = MetaOf $h 'article:school'
  $sj = MetaOf $h 'article:subject'
  if($sc -and $sj -and $schByName.ContainsKey($sc)){
    $usedCombo["$sc|$sj"] = $true
    $usedSchool[$sc] = 1 + $usedSchool[$sc]
    if($subjCount.ContainsKey($sj)){ $subjCount[$sj]++ }
    $g = $schByName[$sc].g; $guCount[$g] = 1 + $guCount[$g]
    $lvCount[$schByName[$sc].t]++
  }
}

# ---------- 증상 은행 (학교급 x 과목) ----------
$SYM_MH = @{
  '수학' = @('계산은 맞는데 서술형에서만 깎인다면','학원은 다니는데 시험만 보면 무너진다면','개념은 아는데 응용문제에서 손이 멈춘다면','오답노트를 쓰는데 같은 걸 또 틀린다면','진도는 나갔는데 앞 단원이 비어 있다면','문제는 푸는데 시간이 늘 모자란다면')
  '영어' = @('단어는 외우는데 문장이 안 읽힌다면','지문은 읽었는데 답이 틀린다면','내신은 되는데 모의고사가 안 된다면','문법 문제만 나오면 찍는다면','영작 서술형에서 다 깎인다면')
  '국어' = @('문제집은 푸는데 점수가 그대로라면','비문학만 나오면 시간이 모자란다면','문학 해석이 매번 제각각이라면','수행평가 글쓰기에서 감점된다면','어휘를 몰라 지문이 안 읽힌다면')
  '과학' = @('공식은 외웠는데 단위에서 틀린다면','실험 문제만 나오면 막힌다면','암기는 되는데 계산이 안 된다면','그래프 해석에서 막힌다면')
  '사회' = @('외울 게 많아 손을 못 대고 있다면','역사 흐름이 안 잡힌다면','자료·지도 해석에서 틀린다면','서술형에서 키워드를 못 쓴다면')
}
$SYM_E = @{
  '수학' = @('연산은 되는데 문장제만 나오면 막힌다면','분수에서 처음 막혔다면','구구단은 외웠는데 곱셈 응용이 안 된다면','단원평가 점수가 들쭉날쭉하다면')
  '영어' = @('파닉스는 뗐는데 문장이 안 읽힌다면','단어 시험만 보고 나면 잊어버린다면','영어 교과가 시작되고 흥미를 잃었다면')
  '국어' = @('책은 읽는데 내용을 설명하지 못한다면','맞춤법·받아쓰기가 계속 틀린다면','글쓰기 숙제 앞에서 멈춘다면')
  '과학' = @('실험은 좋아하는데 정리를 못 한다면','관찰 기록을 쓰기 어려워한다면')
  '사회' = @('지도·그래프 읽기가 어렵다면','5학년 역사가 처음이라 막막하다면','외울 게 많다고 사회를 싫어한다면')
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
  '인천에서 방문과외와 화상과외 중 어느 쪽이 나을까요?'
  '강화·옹진 같은 섬 지역도 1:1 과외를 받을 수 있나요?'
  '고1 5등급제 첫 내신, 인천 고등학생은 무엇부터 준비해야 하나요?'
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
  '인천 구·군별 초·중·고 학교 수 한눈에 보기'
)

# ---------- 요일 ----------
$dayMap = @{0='일';1='월';2='화';3='수';4='목';5='금';6='토'}
if(-not $Day){ $Day = $dayMap[ [int]((Get-Date).DayOfWeek) ] }
$trackB = if($Day -eq '수' -or $Day -eq '토'){ '인포그래픽' } else { '질문형' }

"==============================================="
"  오늘($($Day)요일) 올릴 2편 — 인천과외"
"==============================================="

# ---------- 1편: 학교 x 과목 ----------
$subjOrder = $SUBJECTS | Sort-Object @{e={ $subjCount[$_] }}, @{e={ [array]::IndexOf($SUBJECTS, $_) }}
$lvOrder   = @('중','고','초') | Sort-Object @{e={ $lvCount[$_] }}, @{e={ [array]::IndexOf(@('중','고','초'), $_) }}
$pick = $null; $pickSj = $null
foreach($sj in $subjOrder){
  foreach($lv in $lvOrder){
    $pool = @($SCH | Where-Object { $_.t -eq $lv -and -not $usedCombo.ContainsKey("$($_.n)|$sj") })
    if(-not $pool.Count){ continue }
    # 한 학교·한 구에 몰리지 않게: 덜 쓴 학교 → 덜 쓴 구 → 이름순(매번 같은 결과)
    $pick = $pool | Sort-Object @{e={ [int]$usedSchool[$_.n] }}, @{e={ [int]$guCount[$_.g] }}, @{e='n'} | Select-Object -First 1
    $pickSj = $sj
    break
  }
  if($pick){ break }
}

if($pick){
  $s = $pick; $sj = $pickSj
  $area = "인천 $($s.g)"
  $near = @($SCH | Where-Object { $_.g -eq $s.g -and $_.t -eq $s.t -and $_.n -ne $s.n } | Select-Object -First 6)
  $next = @()
  if($s.t -eq '초'){ $next = @($SCH | Where-Object { $_.g -eq $s.g -and $_.t -eq '중' } | Select-Object -First 4) }
  if($s.t -eq '중'){ $next = @($SCH | Where-Object { $_.g -eq $s.g -and $_.t -eq '고' } | Select-Object -First 4) }
  $cen = @($CEN | Where-Object { (($_.addr -split '\s+')[1]) -eq $s.g } | Group-Object name | ForEach-Object { $_.Group[0] })
  $grades = @{ '초'='초3~초6'; '중'='중1~중3'; '고'='고1~고3' }[$s.t]
  ""
  "[1] 인천 학교 + 과목 ----------------------------"
  "   article:kind     지역"
  "   article:area     $area"
  "   article:school   $($s.n)"
  "   article:subject  $sj"
  if($cen.Count){ "   article:center   $($cen[0].name)" }
  "   학교            $($s.n) ($($s.a)) · $($LV_NAME[$s.t]) · $area"
  "   학교 페이지      ../school/$($s.n).html   ← 하단 '이어서 보기' 첫 줄에 반드시 링크"
  if($cen.Count){ "   센터 페이지      " + (($cen | ForEach-Object { "../c/$($_.name).html($($_.dong))" }) -join ', ') }
  else { "   센터            $area 에는 학습센터가 없다 → ../centers.html 로 링크" }
  "   같은 구 $($LV_NAME[$s.t])  " + (($near | ForEach-Object { $_.n }) -join ', ')
  if($next.Count){ "   진학하는 학교      " + (($next | ForEach-Object { $_.n }) -join ', ') }
  ""
  "   제목 형식: 인천 {구} {학교 정식명칭} {학년}{과목}과외 — {증상}   (학년: $grades 중 하나)"
  "   제목 후보 (증상 하나 고르기)"
  $bank = if($s.t -eq '초'){ $SYM_E[$sj] } else { $SYM_MH[$sj] }
  foreach($sym in $bank){ "     - $area $($s.n) {학년}$($sj)과외 — $sym" }
  ""
  "   ※ 학교명은 정식 명칭으로 쓰고 약칭은 첫 언급에 괄호로 한 번만: $($s.n)($($s.a))"
  "   ※ 그 학교의 시험 난이도·출제 경향 같은 건 우리가 모른다 → 지어내지 말고 학년·과목 일반론으로 쓴다"
} else {
  ""
  "[1] 인천 학교 x 과목 조합을 모두 썼다 — 은행을 늘리거나 코딩·전과목 축을 추가할 것"
}

# ---------- 2편 ----------
""
"[2] $trackB ----------------------------------"
if($trackB -eq '질문형'){
  "   article:kind     질문"
  "   ** FAQPage 구조화 데이터를 반드시 넣을 것 (이 트랙의 목적)"
  "   ** 가능하면 본문에 '인천' 맥락을 한두 문장 넣는다 (구 이름·통학·섬 지역 등 사실만)"
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
"쓴 글 $written 편 (인천 학교 글 $($usedCombo.Count)편)"
"  인천 학교 x 과목 남은 조합 $(($SCH.Count * $SUBJECTS.Count) - $usedCombo.Count)개 (학교 $($SCH.Count)곳)"
"  과목별  " + (($SUBJECTS | ForEach-Object { "$_ $($subjCount[$_])" }) -join ' / ')
"  학교급별 초 $($lvCount['초']) / 중 $($lvCount['중']) / 고 $($lvCount['고'])"
"  질문 은행 $($QUESTIONS.Count)개 / 인포그래픽 은행 $($INFOGRAPHICS.Count)개"
""
"올린 뒤:  .\tools\build_blog.ps1  ->  .\tools\build_sitemap.ps1  ->  commit/push"
