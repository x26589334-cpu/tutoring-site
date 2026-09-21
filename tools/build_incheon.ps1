$ErrorActionPreference='Stop'
# 인천과외 — 인천 초·중·고 학교별 과외 페이지 생성기 (2026-09-21)
#   입력: ~/gwaoe-page/schools-data.js (NEIS 기반 전국 학교 목록) 중 '인천' 만
#         teachers-data.js / centers-data.js (이 저장소)
#   출력: incheon-schools.js, schools.html, school/{학교명}.html
# 11개 지역과외 사이트(사이트관리/도구/지역과외)의 학교 페이지 구성을 참고했다.
# 단, 그쪽 템플릿의 "○○중 사회는 서술형 비중이 큽니다" 처럼 특정 학교 시험 특징을
# 단정하는 문장은 쓰지 않는다(지어낸 사실이 된다). 학년·과목 일반론으로만 쓴다.
$SITE = Split-Path $PSScriptRoot -Parent
$OUT  = "$SITE\school"
if(-not (Test-Path $OUT)){ New-Item -ItemType Directory $OUT | Out-Null }
$V = '8'   # style.css 캐시버전 — 전 페이지와 같이 맞출 것

function Load-Js($path, $marker){
  $raw = Get-Content $path -Raw -Encoding UTF8
  $js  = $raw.Substring($raw.IndexOf($marker) + $marker.Length).TrimEnd()
  if($js.EndsWith(';')){ $js = $js.Substring(0, $js.Length-1) }
  return ($js | ConvertFrom-Json)
}
function Esc($s){ if($null -eq $s){ return '' }; return ([string]$s).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;') }
function Enc($s){ return [Uri]::EscapeDataString($s) }
# 받침 여부로 조사 고르기 (은/는, 을/를, 이/가, 과/와)
function HasJong($w){ if(-not $w){ return $false }; $c = [int][char]$w[$w.Length-1]; if($c -lt 0xAC00 -or $c -gt 0xD7A3){ return $false }; return ((($c - 0xAC00) % 28) -ne 0) }
function J($w, $a, $b){ if(HasJong $w){ return "$w$a" } else { return "$w$b" } }
# 약칭: 초등학교→초, 여자중학교→여중, 중학교→중, 여자고등학교→여고, 고등학교→고
function Short($n){
  if($n -match '초등학교$'){ return ($n -replace '초등학교$','초') }
  if($n -match '여자중학교$'){ return ($n -replace '여자중학교$','여중') }
  if($n -match '중학교$'){ return ($n -replace '중학교$','중') }
  if($n -match '여자고등학교$'){ return ($n -replace '여자고등학교$','여고') }
  if($n -match '고등학교$'){ return ($n -replace '고등학교$','고') }
  return $n
}

# ---------- 데이터 ----------
$srcTxt = Get-Content "$HOME\gwaoe-page\schools-data.js" -Raw -Encoding UTF8
$ms = [regex]::Matches($srcTxt, '\{n:"([^"]+)",\s*r:"(인천[^"]*)",\s*t:"([^"]+)"')
$SCH = New-Object System.Collections.Generic.List[object]
foreach($m in $ms){
  $n = $m.Groups[1].Value
  if($n -match '개교예정'){ continue }          # 아직 학생이 없다
  $SCH.Add([pscustomobject]@{ n=$n; a=(Short $n); gu=($m.Groups[2].Value -replace '^인천\s*',''); t=$m.Groups[3].Value })
}
$TCH = Load-Js "$SITE\teachers-data.js" 'window.TEACHERS='
$CEN = @(Load-Js "$SITE\centers-data.js" 'window.CENTERS=' | Where-Object { $_.region -eq '인천' })
$GU_ORDER = @('연수구','남동구','부평구','서해구','계양구','미추홀구','검단구','중구','동구','제물포구','강화군','옹진군')
$GUS = @($SCH | ForEach-Object { $_.gu } | Sort-Object -Unique | Sort-Object { $i=[array]::IndexOf($GU_ORDER,$_); if($i -lt 0){99}else{$i} })
$TYPE_NAME = @{ '초'='초등학교'; '중'='중학교'; '고'='고등학교' }

# ---------- 공통 머리·꼬리 ----------
function Head($p, $title, $desc, $canon, $ld){
@"
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$(Esc $title)</title>
<meta name="description" content="$(Esc $desc)">
<link rel="canonical" href="$canon">
<meta property="og:type" content="website">
<meta property="og:title" content="$(Esc $title)">
<meta property="og:description" content="$(Esc $desc)">
<meta property="og:url" content="$canon">
<meta property="og:locale" content="ko_KR">
<meta property="og:image" content="https://firststudy.co.kr/apple-touch-icon.png">
<link rel="icon" href="${p}favicon.ico" sizes="any">
<link rel="icon" href="${p}favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="${p}apple-touch-icon.png">
<meta name="theme-color" content="#FDFBF7">
<script type="application/ld+json">
$ld
</script>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Gowun+Dodum&family=Noto+Sans+KR:wght@300;400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="${p}style.css?v=$V">
  <script src="${p}analytics.js" defer></script>
</head>
<body>

<header>
  <div class="wrap nav">
    <a href="${p}index.html" class="logo"><span class="logo-dot"></span>인천과외</a>
    <nav class="nav-menu" id="menu">
      <div class="nav-item">
        <a class="nav-top">과외 <span class="caret">▼</span></a>
        <div class="nav-sub">
          <a href="${p}index.html#visit"><span class="dot visit"></span>방문과외</a>
          <a href="${p}index.html#online"><span class="dot online"></span>화상과외</a>
        </div>
      </div>
      <a href="${p}schools.html">학교별 과외</a>
      <a href="${p}centers.html">학습센터</a>
      <a href="${p}teachers.html">선생님 찾기</a>
      <a href="${p}blog.html">공부 이야기</a>
      <a href="${p}status.html">수업 현황</a>
    </nav>
    <a href="${p}index.html#contact" class="btn btn-main nav-cta">무료 상담</a>
    <button class="burger" id="burger" aria-label="메뉴 열기">☰</button>
  </div>
</header>
"@
}
function Foot($p){
@"

<footer>
  <div class="wrap foot">
    <div>
      <div class="logo"><span class="logo-dot"></span>인천과외</div>
      <div>인천 초·중·고 학생을 위한 1:1 맞춤 과외</div>
    </div>
    <div>
      <div class="foot-links">
        <a href="${p}index.html#visit">방문과외</a>
        <a href="${p}index.html#online">화상과외</a>
        <a href="${p}schools.html">학교별 과외</a>
        <a href="${p}centers.html">학습센터</a>
        <a href="${p}teachers.html">선생님 찾기</a>
        <a href="${p}blog.html">공부 이야기</a>
        <a href="${p}grade-calculator.html">내신 등급 계산기</a>
        <a href="${p}status.html">수업 현황</a>
      </div>
      <div style="margin-top:16px">© 2026 인천과외. All rights reserved.</div>
    </div>
  </div>
</footer>

<script>
var burger = document.getElementById('burger');
var menu = document.getElementById('menu');
burger.addEventListener('click', function(){ menu.classList.toggle('open'); });
menu.addEventListener('click', function(e){ if(e.target.tagName === 'A' && e.target.getAttribute('href')) menu.classList.remove('open'); });
</script>
</body>
</html>
"@
}

# ---------- 학교급별 문장 ----------
$GRADE = @{
  '초' = @(
    @('1·2학년','읽기와 연산이 몸에 붙는 시기입니다. 문제집 양보다 매일 짧게 앉아 있는 습관을 먼저 만듭니다.'),
    @('3·4학년','분수와 도형, 영어 교과가 시작되면서 처음으로 차이가 벌어집니다. 여기서 막힌 곳을 바로 메웁니다.'),
    @('5·6학년','중학교 공부의 바로 앞 칸입니다. 수학 개념 정리와 영어 문장 읽기를 중학교 진도에 맞춰 준비합니다.'))
  '중' = @(
    @('중1','자유학기로 시험 부담이 적은 대신, 여기서 만든 공부 습관이 중2 성적이 됩니다.'),
    @('중2','수학 일차함수·연립방정식, 영어 문법에서 많이 갈립니다. 막히면 그 단원으로 바로 돌아가 보강합니다.'),
    @('중3','고등학교 진학을 앞둔 시기입니다. 2학기 내신을 챙기면서 고1 공통과목 선행을 함께 준비합니다.'))
  '고' = @(
    @('고1','첫 내신이 5등급제로 매겨집니다. 공통국어·공통수학·통합사회·통합과학의 시험 형태에 먼저 익숙해져야 합니다.'),
    @('고2','선택과목이 갈리면서 과목별로 전략이 달라집니다. 내신과 모의고사를 함께 끌고 갑니다.'),
    @('고3','수시 원서와 수능을 동시에 준비합니다. 남은 내신 한 번과 최저학력기준을 기준으로 시간을 나눕니다.'))
}
$EXAM = @{
  '초' = @('단원평가·수행평가 대비', '초등학교는 점수로 줄을 세우지 않는 대신 단원평가와 수행평가로 이해도를 봅니다. 틀린 단원을 그 주 안에 다시 풀어 보고, 서술형 답을 문장으로 쓰는 연습을 함께 합니다.')
  '중' = @('중간고사·기말고사 내신 대비', '중학교 내신은 원점수로 성취도(A~E)가 정해집니다. 시험 범위와 교과서 출판사를 먼저 확인하고, 자주 나오는 유형 → 서술형·수행평가 → 시험 3주 전 실전 연습 순서로 갑니다.')
  '고' = @('중간고사·기말고사 내신 대비', '고등학교 내신은 같은 과목 수강생 사이의 석차로 등급이 매겨집니다. 시험 범위와 부교재를 먼저 확인하고, 기본 유형 → 고난도·서술형 → 실전 시간 맞추기 순서로 준비합니다.')
}
$SUBJ = @{
  '국어' = @{ '초'='읽기 이해와 어휘, 글쓰기를 함께 봅니다. 지문을 끝까지 읽고 질문에 맞는 답을 고르는 힘부터 만듭니다.'; '중'='교과서 지문 정리와 문법, 서술형 답안 쓰기를 나눠서 준비합니다. 처음 보는 지문을 읽어내는 연습도 같이 합니다.'; '고'='문학·비문학 독해 속도와 문법을 함께 잡습니다. 교과서 수록 작품은 내신용으로, 새 지문은 모의고사용으로 따로 연습합니다.' }
  '영어' = @{ '초'='파닉스에서 문장 읽기로 넘어가는 시기라, 소리 내 읽기와 기본 문장 구조를 먼저 다집니다.'; '중'='본문 암기만으로는 한계가 있습니다. 본문 분석과 어법 포인트, 서술형 영작까지 학교 시험지 형태로 연습합니다.'; '고'='구문 분석과 어법, 어휘를 한 번에 잡고 내신 서술형과 모의고사 독해를 나눠서 준비합니다.' }
  '수학' = @{ '초'='연산 정확도와 문장제 해석을 함께 봅니다. 틀린 문제를 다시 풀리게 하는 데서 끝내지 않고 왜 틀렸는지 말로 설명하게 합니다.'; '중'='막힌 단원을 찾는 것이 먼저입니다. 1:1이라 필요하면 이전 학년으로 돌아가 다시 쌓고, 서술형은 풀이 과정을 쓰는 훈련을 따로 합니다.'; '고'='개념 → 기본 유형 → 고난도 순서로 올라갑니다. 학교 시험 난이도에 맞춰 문제집 수준을 조절하고 서술형 부분점수까지 챙깁니다.' }
  '사회' = @{ '초'='지도와 그래프 읽기, 우리 지역과 역사 이야기를 연결해서 외우는 양을 줄입니다.'; '중'='흐름과 인과로 묶어 외우는 양을 줄이고, 자료 해석과 서술형 답안 쓰기를 따로 연습합니다.'; '고'='통합사회와 선택과목의 개념을 설명할 수 있게 만들고, 자료·도표 해석 문항을 반복합니다.' }
  '과학' = @{ '초'='실험과 관찰 내용을 자기 말로 정리하게 합니다. 외우기 전에 왜 그런지부터 짚습니다.'; '중'='공식을 외우기 전에 원리를 먼저 이해하고, 계산·그래프 문항을 유형별로 익힙니다.'; '고'='통합과학과 물리·화학·생명과학·지구과학 선택과목을 개념과 계산으로 나눠 준비합니다.' }
}

$made = 0
$byGuType = @{}
foreach($s in $SCH){ $k = "$($s.gu)|$($s.t)"; if(-not $byGuType.ContainsKey($k)){ $byGuType[$k] = New-Object System.Collections.Generic.List[object] }; $byGuType[$k].Add($s) }

foreach($s in $SCH){
  $n = $s.n; $a = $s.a; $gu = $s.gu; $lv = $s.t
  $area = "인천 $gu"
  $canon = "https://firststudy.co.kr/school/$(Enc $n).html"
  $title = "$n 과외 | 인천 $gu $a 수학과외·영어과외·국어과외 — 인천과외"
  $examNote = if($lv -eq '초'){ '단원평가·수행평가' } else { '중간·기말 내신' }
  $desc  = "인천 $gu $n($a) 학생을 위한 1:1 맞춤 과외. 국어·영어·수학·사회·과학을 방문수업·화상수업으로, $examNote 까지 학교 시험 범위에 맞춰 준비합니다."

  # 키워드 줄 (11개 사이트 형식)
  $kw = @('국어','영어','수학','사회','과학' | ForEach-Object { "$a $($_)과외" }) + @("$n 과외", "인천 $a 과외", "$gu $a 과외")
  $kwHtml = ($kw | ForEach-Object { "<span>$(Esc $_)</span>" }) -join ''

  $gradeHtml = ($GRADE[$lv] | ForEach-Object { "          <li><b>$($_[0])</b> — $($_[1])</li>" }) -join "`n"

  $subjHtml = ''
  foreach($sj in '국어','영어','수학','사회','과학'){
    $subjHtml += @"
        <div class="cd-subj">
          <h3>$(Esc $n) $($sj)과외</h3>
          <p>$($SUBJ[$sj][$lv])</p>
        </div>

"@
  }

  # 방문 가능 여부 — 이 구를 방문하는 선생님이 실제로 있는지로 판단한다(없으면 없다고 쓴다)
  $visitT = @($TCH | Where-Object { $_.r -and (($_.r -split '\|') -contains $area) })
  $isIsland = ($gu -eq '강화군' -or $gu -eq '옹진군')
  if($visitT.Count -gt 0){
    $visitTxt = "$(J $area '은' '는') 방문수업이 가능한 지역입니다. 지금 $area 방문이 가능한 선생님이 $($visitT.Count)명 있습니다."
  } elseif($isIsland){
    $visitTxt = "$(J $area '은' '는') 섬·읍면 지역이 넓어 방문 선생님을 구하기 어려운 경우가 많습니다. 이 지역은 화상수업을 먼저 권합니다."
  } else {
    $visitTxt = "$area 방문이 가능한 선생님은 상담 때 가까운 분을 찾아 드립니다. 일정이 맞는 분이 없으면 화상수업으로 연결합니다."
  }
  $cenHere = @($CEN | Where-Object { (($_.addr -split '\s+')[1]) -eq $gu })
  if($cenHere.Count -gt 0){
    $cenLinks = ($cenHere | Group-Object name | ForEach-Object { $_.Group[0] } | ForEach-Object { "<a href=""../c/$(Enc $_.name).html"">$(Esc $_.dong) 학습센터</a>" }) -join ' · '
    $cenTxt = "$area 안에 학습센터가 있습니다 — $cenLinks. 정해진 시간에 나와 공부하고, 막히면 바로 물어봅니다."
  } else {
    $cenTxt = "$area 안에는 아직 학습센터가 없습니다. 가까운 구의 센터는 <a href=""../centers.html"">학습센터 찾기</a>에서 볼 수 있습니다."
  }

  # 선생님 3명: 이 구 방문 선생님 먼저, 모자라면 학교급에 맞는 화상 선생님
  $lvChar = @{ '초'='초'; '중'='중'; '고'='고' }[$lv]
  $pick = @($visitT | Select-Object -First 3)
  if($pick.Count -lt 3){
    $need = 3 - $pick.Count
    $online = @($TCH | Where-Object { $_.c -match '화상' -and (($_.gr -join ' ') -match $lvChar) } | Select-Object -Skip (($made * 3) % 600) -First $need)
    $pick = @($pick) + @($online)
  }
  $tCards = ''
  foreach($tc in $pick){
    $w = if($tc.c -eq '방문+화상'){'both'}else{$tc.c}
    $where = if($tc.r -and ($tc.r -split '\|') -contains $area){ $area } elseif($tc.c -match '화상'){ '전국 어디서나 · 화상 수업' } else { ($tc.r -split '\|')[0] }
    $tCards += @"
        <a class="t-card w-$w" href="../t/$($tc.i).html">
          <span class="t-badge w-$w">$($tc.c)과외</span>
          <p class="t-tag">$(Esc $tc.tag)</p>
          <p class="t-name"><b>$(Esc $tc.n)</b> 선생님</p>
          <p class="t-where">📍 $(Esc $where)</p>
        </a>

"@
  }

  # 인근 학교: 같은 구·같은 학교급
  $near = @($byGuType["$gu|$lv"] | Where-Object { $_.n -ne $n } | Select-Object -First 12)
  $nearHtml = ($near | ForEach-Object { "          <a href=""$(Enc $_.n).html"">$(Esc $_.n) 과외</a>" }) -join "`n"
  # 다른 학교급 한두 곳도 (초→중, 중→고 진학 연결)
  $nextLv = @{ '초'='중'; '중'='고'; '고'='' }[$lv]
  $nextHtml = ''
  if($nextLv){
    $nx = @($byGuType["$gu|$nextLv"] | Select-Object -First 4)
    if($nx.Count){ $nextHtml = "`n" + (($nx | ForEach-Object { "          <a href=""$(Enc $_.n).html"">$(Esc $_.n) 과외</a>" }) -join "`n") }
  }

  $ld = @"
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "인천과외", "item": "https://firststudy.co.kr/" },
    { "@type": "ListItem", "position": 2, "name": "학교별 과외", "item": "https://firststudy.co.kr/schools.html" },
    { "@type": "ListItem", "position": 3, "name": "$(Esc $n) 과외", "item": "$canon" }
  ]
}
"@

  $calcLine = if($lv -ne '초'){ "`n        <p class=""cd-note"" style=""margin-top:14px"">시험이 끝났다면 <a href=""../grade-calculator.html"" style=""color:#B96A48;text-decoration:underline"">내신 등급 계산기</a>로 지금 위치부터 확인해 보세요.</p>" } else { '' }

  $html = (Head '../' $title $desc $canon $ld) + @"

<section class="cd-hero">
  <div class="wrap">
    <p class="sc-crumb"><a href="../index.html">인천과외</a> › <a href="../schools.html">학교별 과외</a> › <a href="../schools.html#$(Esc $gu)">$(Esc $gu)</a> › $(Esc $n)</p>
    <p class="eyebrow">인천 $(Esc $gu) · $($TYPE_NAME[$lv])</p>
    <h1>$(Esc $n)<br><em>1:1 맞춤 과외</em></h1>
    <p class="cd-lead">인천 $(Esc $gu) $(Esc $n)($(Esc $a)) 학생과 학부모님을 위한 과외 안내입니다. 국어·영어·수학·사회·과학을 방문수업이나 화상수업으로, 학교 시험 범위에 맞춰 1:1로 준비합니다.</p>
    <div class="sc-kw">$kwHtml</div>
  </div>
</section>

<section style="padding-top:10px">
  <div class="wrap">
    <div class="cd-box">
      <h2>$(Esc $n) 학년별 준비</h2>
      <ul class="bl-list" style="margin:6px 0 0">
$gradeHtml
      </ul>
    </div>
  </div>
</section>

<section style="background:var(--bg-soft)">
  <div class="wrap">
    <h2 class="sec-title" style="text-align:center">$(Esc $n) 과목별 1:1 과외</h2>
    <div class="cd-subjects">
$subjHtml    </div>
  </div>
</section>

<section>
  <div class="wrap">
    <div class="cd-box">
      <h2>$(Esc $n) $($EXAM[$lv][0])</h2>
      <p class="cd-note" style="margin-bottom:0">$($EXAM[$lv][1])</p>$calcLine
    </div>

    <div class="cd-box" style="margin-top:20px">
      <h2>학원 대신 1:1 과외를 권하는 경우</h2>
      <p class="cd-note">여러 학교 학생을 한 반에서 같은 진도로 가르치는 학원과 달리, 1:1은 $n의 시험 범위와 우리 아이가 막힌 자리에만 시간을 씁니다.</p>
      <div class="sc-table-wrap"><table class="sc-table">
        <tr><th></th><th>학원</th><th>1:1 과외</th></tr>
        <tr><th>진도</th><td>여러 학교 공통</td><td>학교 시험 범위에 맞춤</td></tr>
        <tr><th>질문</th><td>수업 뒤 짧게</td><td>막히는 그 자리에서</td></tr>
        <tr><th>시간</th><td>정해진 시간표</td><td>학생 일정에 맞춤</td></tr>
        <tr><th>빈 곳 메우기</th><td>반 전체 속도</td><td>필요하면 이전 학년으로</td></tr>
      </table></div>
    </div>
  </div>
</section>

<section style="background:var(--bg-soft)">
  <div class="wrap">
    <h2 class="sec-title" style="text-align:center">$(Esc $area) 공부하는 방법 세 가지</h2>
    <div class="cd-ways">
      <div class="cd-way w-visit">
        <h3>방문과외</h3>
        <p>$visitTxt</p>
        <a href="../teachers.html?way=방문">방문 선생님 보기 →</a>
      </div>
      <div class="cd-way w-online">
        <h3>화상과외</h3>
        <p>화면에 풀이 과정을 함께 띄우고 진행해서 어디서 틀렸는지가 그대로 보입니다. 이동 시간이 없어 저녁 시간을 아낄 수 있습니다.</p>
        <a href="../teachers.html?way=화상">화상 선생님 보기 →</a>
      </div>
      <div class="cd-way w-center">
        <h3>학습센터</h3>
        <p>$cenTxt</p>
        <a href="../centers.html">학습센터 찾기 →</a>
      </div>
    </div>
  </div>
</section>

<section>
  <div class="wrap">
    <h2 class="sec-title" style="text-align:center">$(Esc $n) 학생에게 맞는 선생님</h2>
    <div class="t-grid">
$tCards    </div>
    <div style="text-align:center;margin-top:30px">
      <a href="../teachers.html" class="btn btn-ghost">선생님 전체 보기</a>
    </div>
  </div>
</section>

<section style="background:var(--bg-soft)">
  <div class="wrap" style="text-align:center">
    <h2 class="sec-title">$(Esc $gu) 인근 학교 과외</h2>
    <div class="cd-near">
$nearHtml$nextHtml
    </div>
    <p style="margin-top:22px"><a href="../schools.html#$(Esc $gu)" class="btn btn-ghost">$(Esc $gu) 학교 전체 보기</a></p>
  </div>
</section>

<section id="contact">
  <div class="wrap" style="text-align:center;padding:70px 0">
    <h2 class="sec-title">$(Esc $n) 과외, 무료 상담부터</h2>
    <p class="sec-desc">학년과 과목, 지금 막힌 부분을 알려주시면 $(Esc $n) 시험 범위에 맞는 선생님과 수업 방식을 함께 골라 드립니다.</p>
    <a href="../index.html#contact" class="btn btn-main" style="margin-top:26px;padding:16px 44px">무료 상담 신청하기</a>
  </div>
</section>
"@ + (Foot '../')

  [IO.File]::WriteAllText("$OUT\$n.html", $html, (New-Object Text.UTF8Encoding $false))
  $made++
}

# ---------- 데이터 파일 ----------
$arr = $SCH | ForEach-Object { [ordered]@{ n=$_.n; a=$_.a; g=$_.gu; t=$_.t } }
$json = ConvertTo-Json -InputObject @($arr) -Depth 3 -Compress
[IO.File]::WriteAllText("$SITE\incheon-schools.js", "/* 인천과외 — 인천 초·중·고 목록 (자동 생성: tools/build_incheon.ps1, 수정하지 말 것)`n   n=정식 명칭, a=약칭, g=구·군, t=초/중/고 */`nwindow.INC_SCHOOLS=" + $json + ";`n", (New-Object Text.UTF8Encoding $false))

# ---------- schools.html ----------
$total = $SCH.Count
$cnt = @{ '초'=@($SCH|?{$_.t -eq '초'}).Count; '중'=@($SCH|?{$_.t -eq '중'}).Count; '고'=@($SCH|?{$_.t -eq '고'}).Count }
$guChips = ($GUS | ForEach-Object { $g=$_; $c=@($SCH|?{$_.gu -eq $g}).Count; "<a class=""t-chip"" href=""#$(Esc $g)"">$g <span style=""opacity:.55"">$c</span></a>" }) -join ''
$guBlocks = ''
foreach($g in $GUS){
  $guBlocks += "    <div class=""sc-gu"" id=""$(Esc $g)"" data-gu=""$(Esc $g)"">`n      <h2>인천 $g 학교별 과외</h2>`n"
  foreach($lv in '초','중','고'){
    $items = @($SCH | Where-Object { $_.gu -eq $g -and $_.t -eq $lv })
    if(-not $items.Count){ continue }
    $links = ($items | ForEach-Object { "<a href=""school/$(Enc $_.n).html"" data-n=""$(Esc ($_.n + ' ' + $_.a))"" data-t=""$lv"">$(Esc $_.n)</a>" }) -join ''
    $guBlocks += "      <div class=""sc-row""><b>$($TYPE_NAME[$lv]) $($items.Count)</b><div class=""sc-links"">$links</div></div>`n"
  }
  $guBlocks += "    </div>`n"
}
$ldS = @"
{
  "@context": "https://schema.org",
  "@type": "CollectionPage",
  "name": "인천 학교별 과외",
  "url": "https://firststudy.co.kr/schools.html",
  "inLanguage": "ko",
  "isPartOf": { "@type": "WebSite", "name": "인천과외", "url": "https://firststudy.co.kr/" }
}
"@
$sHtml = (Head '' "인천 학교별 과외 — 초·중·고 $($total)곳 수학과외·영어과외 | 인천과외" "인천 초등학교·중학교·고등학교 $($total)곳의 학교별 1:1 과외 안내. 연수구·남동구·부평구·서해구·계양구·미추홀구 등 우리 아이 학교를 찾아 시험 범위에 맞는 과외를 알아보세요." "https://firststudy.co.kr/schools.html" $ldS) + @"

<section class="t-hero">
  <div class="wrap">
    <p class="eyebrow">학교별 과외</p>
    <h1>인천 초·중·고 <em>$($total)곳</em>,<br>우리 아이 학교부터 찾으세요</h1>
    <p>초등학교 $($cnt['초']) · 중학교 $($cnt['중']) · 고등학교 $($cnt['고']). 학교마다 시험 범위와 교과서가 다르니, 과외도 학교에 맞춰 시작합니다.</p>
    <div class="t-search">
      <input id="scQ" type="search" autocomplete="off" aria-label="학교 검색" placeholder="학교 이름으로 검색 (예: 연수고, 송도중, 부평초)">
    </div>
  </div>
</section>

<section style="padding-top:10px">
  <div class="wrap">
    <div class="t-filters">
      <div class="t-row"><span class="lb">구·군</span><div class="t-chips">$guChips</div></div>
      <div class="t-row"><span class="lb">학교급</span><div class="t-chips" id="scT">
        <button type="button" class="t-chip on" data-t="">전체</button><button type="button" class="t-chip" data-t="초">초등학교</button><button type="button" class="t-chip" data-t="중">중학교</button><button type="button" class="t-chip" data-t="고">고등학교</button>
      </div></div>
    </div>
    <p class="t-count" id="scCount"></p>
$guBlocks  </div>
</section>

<section id="contact" style="background:var(--bg-soft)">
  <div class="wrap" style="text-align:center;padding:70px 0">
    <h2 class="sec-title">학교를 못 찾으셨다면</h2>
    <p class="sec-desc">목록에 없는 학교도 상담해 드립니다. 학교 이름과 학년만 알려주세요.</p>
    <a href="index.html#contact" class="btn btn-main" style="margin-top:26px;padding:16px 44px">무료 상담 신청하기</a>
  </div>
</section>

<script>
(function(){
  var q = document.getElementById('scQ'), tBox = document.getElementById('scT'), cnt = document.getElementById('scCount');
  var t = '';
  function norm(s){ return (s||'').replace(/\s+/g,'').replace(/초등학교/g,'초').replace(/여자중학교/g,'여중').replace(/중학교/g,'중').replace(/여자고등학교/g,'여고').replace(/고등학교/g,'고'); }
  function run(){
    var key = norm(q.value), shown = 0;
    [].forEach.call(document.querySelectorAll('.sc-links a'), function(a){
      var ok = (!t || a.getAttribute('data-t') === t) && (!key || norm(a.getAttribute('data-n')).indexOf(key) >= 0);
      a.style.display = ok ? '' : 'none'; if(ok) shown++;
    });
    [].forEach.call(document.querySelectorAll('.sc-row'), function(r){
      r.style.display = [].some.call(r.querySelectorAll('a'), function(a){ return a.style.display !== 'none'; }) ? '' : 'none';
    });
    [].forEach.call(document.querySelectorAll('.sc-gu'), function(g){
      g.style.display = [].some.call(g.querySelectorAll('.sc-row'), function(r){ return r.style.display !== 'none'; }) ? '' : 'none';
    });
    cnt.innerHTML = (key || t) ? '찾은 학교 <b>' + shown + '곳</b>' : '인천 학교 <b>$($total)곳</b>';
  }
  q.addEventListener('input', run);
  tBox.addEventListener('click', function(e){
    var b = e.target.closest('[data-t]'); if(!b) return;
    t = b.getAttribute('data-t');
    [].forEach.call(tBox.querySelectorAll('[data-t]'), function(x){ x.classList.toggle('on', x === b); });
    run();
  });
  var m = /[?&]q=([^&]*)/.exec(location.search); if(m){ q.value = decodeURIComponent(m[1]); }
  run();
})();
</script>
"@ + (Foot '')
[IO.File]::WriteAllText("$SITE\schools.html", $sHtml, (New-Object Text.UTF8Encoding $false))

"학교 페이지 $made 개 생성 → school/   (초 $($cnt['초']) / 중 $($cnt['중']) / 고 $($cnt['고']))"
"구·군: " + ($GUS -join ', ')
"schools.html · incheon-schools.js 갱신"
