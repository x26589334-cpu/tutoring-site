$ErrorActionPreference='Stop'
# 센터별 개별 페이지 생성 — 지역·학교명·과목명을 정적 HTML 로 노출하는 게 목적.
# centers.html 은 JS 로만 그리기 때문에 학교명 1,700여 개가 검색엔진에 안 잡힌다.
$SITE   = Split-Path $PSScriptRoot -Parent
$OUTDIR = "$SITE\c"
if(-not (Test-Path $OUTDIR)){ New-Item -ItemType Directory $OUTDIR | Out-Null }

function Load-Js($path, $marker){
  $raw = Get-Content $path -Raw -Encoding UTF8
  $js  = $raw.Substring($raw.IndexOf($marker) + $marker.Length).TrimEnd()
  if($js.EndsWith(';')){ $js = $js.Substring(0, $js.Length-1) }
  return ($js | ConvertFrom-Json)
}
$CEN = Load-Js "$SITE\centers-data.js"  'window.CENTERS='
$TCH = Load-Js "$SITE\teachers-data.js" 'window.TEACHERS='

function Esc($s){
  if($null -eq $s){ return '' }
  return ([string]$s).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}
function SplitList($s){
  if(-not $s){ return @() }
  return @(($s -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
# 주소에서 시군구 뽑기 — "경기 하남시 덕풍동로 119 …" → "하남시"
function Sigungu($addr){
  $parts = ($addr -split '\s+') | Where-Object { $_ }
  if($parts.Count -ge 2){
    $p = $parts[1]
    if($p -match '(시|군|구)$'){ return $p }
  }
  return ''
}
# 학교명 뒤에 정식 명칭 붙이기 — "덕풍중" → "덕풍중학교"
function FullSchool($n, $kind){
  if($n -match '(초등학교|중학교|고등학교)$'){ return $n }
  switch($kind){
    '초' { if($n -match '초$'){ return $n + '등학교' } }
    '중' { if($n -match '중$'){ return $n + '학교' } }
    '고' { if($n -match '고$'){ return $n + '등학교' } }
  }
  return $n
}

$SUBJECTS = @(
  @{ n='국어'; d='지문을 끝까지 읽어내는 힘부터 만듭니다. 내신 서술형과 수행평가는 학교 기출 유형에 맞춰 따로 준비합니다.' },
  @{ n='영어'; d='단어와 문법을 따로 외우는 대신 문장 구조로 이해하도록 지도합니다. 학교별 교과서와 부교재 진도에 맞춥니다.' },
  @{ n='수학'; d='틀린 문제를 다시 풀리는 데서 그치지 않고, 어느 개념에서 막혔는지 거슬러 올라가 메웁니다.' },
  @{ n='과학'; d='공식을 외우기 전에 왜 그렇게 되는지부터 짚습니다. 중등 통합과학과 고등 물화생지 모두 지도합니다.' },
  @{ n='사회'; d='흐름과 인과로 묶어 외우는 양을 줄입니다. 한국사·통합사회 내신과 수행평가를 함께 관리합니다.' }
)

# 페이지마다 도입 문장을 달리해 205장이 서로 같은 글이 되지 않게 한다
$LEADS = @(
  '학원 시간표에 아이를 맞추는 대신, 아이 일정에 수업을 맞춥니다.',
  '같은 학교 시험지를 아는 선생님과 공부하면 준비가 빨라집니다.',
  '학교마다 시험 범위도 서술형 비중도 다릅니다. 거기에 맞춰 준비합니다.',
  '집에서 할지, 화면으로 할지, 센터에 나올지부터 같이 정합니다.',
  '진도를 따라가는 수업이 아니라, 막힌 자리를 찾아 메우는 수업입니다.'
)

# 같은 이름의 지점이 여러 곳 있다(수지점 3곳 등). 따로 만들면 거의 같은 페이지가 3장 생겨
# 유사 중복이 되므로 하나로 합친다 — 학교 목록은 합집합, 주소는 전부 싣는다.
$GROUPS = $CEN | Group-Object name

$made = 0
$idx  = 0
foreach($grpItem in $GROUPS){
  $rows   = @($grpItem.Group)
  $ct     = $rows[0]
  $name   = $ct.name
  $region = $ct.region
  $addr   = $ct.addr
  $dong   = $ct.dong
  $sgg    = Sigungu $addr
  $allAddr = @($rows | ForEach-Object { $_.addr } | Sort-Object -Unique)

  $elem = @($rows | ForEach-Object { SplitList $_.elem } | ForEach-Object { FullSchool $_ '초' } | Sort-Object -Unique)
  $mid  = @($rows | ForEach-Object { SplitList $_.mid  } | ForEach-Object { FullSchool $_ '중' } | Sort-Object -Unique)
  $high = @($rows | ForEach-Object { SplitList $_.high } | ForEach-Object { FullSchool $_ '고' } | Sort-Object -Unique)
  $allSchools = @($elem + $mid + $high)

  # 제목에 쓸 대표 학교 (중·고 우선 — 내신 검색이 몰리는 쪽)
  $headline = @($mid + $high + $elem) | Select-Object -First 3
  $headTxt  = ($headline -join '·')

  $areaTxt = (@($region, $sgg, $dong) | Where-Object { $_ }) -join ' '
  $shortArea = (@($sgg, $dong) | Where-Object { $_ }) -join ' '
  if(-not $shortArea){ $shortArea = $region }

  $title = "$shortArea 수학·영어 과외 — $headTxt 내신 | 공부의 온도"
  $desc  = "$areaTxt 일대 $($allSchools.Count)개 학교 학생을 지도합니다. $headTxt 내신을 국어·영어·수학·과학·사회 1:1로 준비하세요. 방문과외·화상과외·학습센터 중에서 고를 수 있습니다."
  $lead  = $LEADS[$idx % $LEADS.Count]

  # ---- 인근 학교 블록 ----
  $schoolBlocks = ''
  foreach($grp in @(@{k='초등학교';v=$elem}, @{k='중학교';v=$mid}, @{k='고등학교';v=$high})){
    if(@($grp.v).Count -gt 0){
      $schoolBlocks += @"
        <div class="cd-srow">
          <b>$($grp.k)</b>
          <span>$(Esc (($grp.v) -join ' · '))</span>
        </div>

"@
    }
  }

  # ---- 과목 블록 (학교명을 문장 안에 섞어 페이지마다 달라지게) ----
  $subjBlocks = ''
  $si = 0
  foreach($sj in $SUBJECTS){
    $pick = if(@($mid + $high).Count -gt 0){ @($mid + $high)[$si % @($mid + $high).Count] } else { '' }
    $tail = if($pick){ " $pick 시험 범위에 맞춰 진행합니다." } else { '' }
    $subjBlocks += @"
        <div class="cd-subj">
          <h3>$shortArea $($sj.n)과외</h3>
          <p>$($sj.d)$tail</p>
        </div>

"@
    $si++
  }

  # ---- 이 지역 선생님 ----
  $local = @($TCH | Where-Object { $_.sd -and ($_.sd -split ',') -contains $region -and $_.c -match '방문' } | Select-Object -First 3)
  if(@($local).Count -lt 3){
    $fill = @($TCH | Where-Object { $_.c -eq '화상' } | Select-Object -First (3 - @($local).Count))
    $local = @($local) + @($fill)
  }
  $teacherCards = ''
  foreach($tc in $local){
    $w = if($tc.c -eq '방문+화상'){'both'}else{$tc.c}
    $where = if($tc.r){ ($tc.r -split '\|')[0] } else { '전국 어디서나 · 화상 수업' }
    $teacherCards += @"
        <a class="t-card w-$w" href="../t/$($tc.i).html">
          <span class="t-badge w-$w">$($tc.c)과외</span>
          <p class="t-tag">$(Esc $tc.tag)</p>
          <p class="t-name"><b>$(Esc $tc.n)</b> 선생님</p>
          <p class="t-where">📍 $(Esc $where)</p>
        </a>

"@
  }

  # ---- 주변 센터 ----
  $near = @($CEN | Where-Object { $_.region -eq $region -and $_.name -ne $name } | Group-Object name | ForEach-Object { $_.Group[0] } | Select-Object -First 4)
  $nearLinks = ''
  foreach($nc in $near){
    $nsgg = Sigungu $nc.addr
    $label = (@($nsgg, $nc.dong) | Where-Object { $_ }) -join ' '
    if(-not $label){ $label = $nc.name }
    $nearLinks += "          <a href=""$([Uri]::EscapeDataString($nc.name)).html"">$(Esc $label) 과외</a>`n"
  }

  $ld = [ordered]@{
    '@context'='https://schema.org'
    '@type'='EducationalOrganization'
    'name'="공부의 온도 $shortArea"
    'description'=[string]$desc
    'url'="https://firststudy.co.kr/c/$([Uri]::EscapeDataString($name)).html"
    'address'=[ordered]@{ '@type'='PostalAddress'; 'addressLocality'=$sgg; 'addressRegion'=$region; 'streetAddress'=$addr; 'addressCountry'='KR' }
    'areaServed'=$areaTxt
    'parentOrganization'=[ordered]@{ '@type'='EducationalOrganization'; 'name'='공부의 온도'; 'url'='https://firststudy.co.kr/' }
  }
  $ldJson = $ld | ConvertTo-Json -Depth 6

  $fileName = "$name.html"   # 디스크에는 한글 그대로 저장한다(퍼센트 인코딩 이름으로 저장하면 링크가 깨진다)
  $canon    = "https://firststudy.co.kr/c/$([Uri]::EscapeDataString($name)).html"
  $q        = [Uri]::EscapeDataString($name)

  $html = @"
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
<link rel="icon" href="../favicon.ico" sizes="any">
<link rel="icon" href="../favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
<meta name="theme-color" content="#FDFBF7">
<script type="application/ld+json">
$ldJson
</script>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Gowun+Dodum&family=Noto+Sans+KR:wght@300;400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="../style.css?v=4">
</head>
<body>

<header>
  <div class="wrap nav">
    <a href="../index.html" class="logo"><span class="logo-dot"></span>공부의 온도</a>
    <nav class="nav-menu" id="menu">
      <div class="nav-item">
        <a class="nav-top">과외 <span class="caret">▼</span></a>
        <div class="nav-sub">
          <a href="../index.html#visit"><span class="dot visit"></span>방문과외</a>
          <a href="../index.html#online"><span class="dot online"></span>화상과외</a>
        </div>
      </div>
      <a href="../centers.html">학습센터</a>
      <a href="../teachers.html">선생님 찾기</a>
      <a href="../blog.html">공부 이야기</a>
      <a href="../status.html">수업 현황</a>
    </nav>
    <a href="../index.html?c=$q#contact" class="btn btn-main nav-cta">무료 상담</a>
    <button class="burger" id="burger" aria-label="메뉴 열기">☰</button>
  </div>
</header>

<section class="cd-hero">
  <div class="wrap">
    <a href="../centers.html" class="td-back">← 학습센터 전체 보기</a>
    <p class="eyebrow">$(Esc $areaTxt)</p>
    <h1>$(Esc $shortArea)에서 다니는 학교에 맞춰,<br><em>1:1로 준비합니다</em></h1>
    <p class="cd-lead">$(Esc $lead)</p>
    <div class="cd-meta">
      <span>📍 $(Esc ($allAddr -join ' / '))</span>
      <span>🏫 인근 $($allSchools.Count)개 학교</span>
    </div>
  </div>
</section>

<section>
  <div class="wrap">
    <div class="cd-box">
      <h2>$(Esc $shortArea) 인근 학교</h2>
      <p class="cd-note">아래 학교에 다니는 학생들을 지도하고 있습니다. 학교별 시험 범위와 서술형 비중에 맞춰 준비합니다.</p>
      <div class="cd-schools">
$schoolBlocks      </div>
    </div>
  </div>
</section>

<section style="background:var(--bg-soft)">
  <div class="wrap">
    <h2 class="sec-title" style="text-align:center">$(Esc $shortArea) 과목별 과외</h2>
    <div class="cd-subjects">
$subjBlocks    </div>
  </div>
</section>

<section>
  <div class="wrap">
    <h2 class="sec-title" style="text-align:center">공부하는 방법은 세 가지 중에</h2>
    <div class="cd-ways">
      <div class="cd-way w-visit">
        <h3>방문과외</h3>
        <p>선생님이 $(Esc $shortArea) 집으로 찾아갑니다. 이동 시간 없이 가장 편한 자리에서 수업합니다.</p>
        <a href="../teachers.html?way=방문">방문 선생님 보기 →</a>
      </div>
      <div class="cd-way w-online">
        <h3>화상과외</h3>
        <p>전국 선생님 중에서 고를 수 있습니다. 근처에 맞는 선생님이 없어도 괜찮습니다.</p>
        <a href="../teachers.html?way=화상">화상 선생님 보기 →</a>
      </div>
      <div class="cd-way w-center">
        <h3>학습센터</h3>
        <p>정해진 시간에 나와서 공부하고, 막히면 바로 물어봅니다. $(Esc ($allAddr -join ' / '))</p>
        <a href="../centers.html">센터 전체 보기 →</a>
      </div>
    </div>
  </div>
</section>

<section style="background:var(--bg-soft)">
  <div class="wrap">
    <h2 class="sec-title" style="text-align:center">$(Esc $region) 지역 선생님</h2>
    <div class="t-grid">
$teacherCards    </div>
    <div style="text-align:center;margin-top:30px">
      <a href="../teachers.html" class="btn btn-ghost">선생님 750명 전체 보기</a>
    </div>
  </div>
</section>

<section>
  <div class="wrap" style="text-align:center">
    <h2 class="sec-title">$(Esc $region)의 다른 동네</h2>
    <div class="cd-near">
$nearLinks    </div>
  </div>
</section>

<section id="contact" style="background:var(--bg-soft)">
  <div class="wrap" style="text-align:center;padding:70px 0">
    <h2 class="sec-title">$(Esc $shortArea)에서 상담받아 보세요</h2>
    <p class="sec-desc">아이 학교와 지금 상태를 알려주시면, 방문·화상·센터 중 어울리는 방식과 선생님을 함께 골라 드립니다.</p>
    <a href="../index.html?c=$q#contact" class="btn btn-main" style="margin-top:26px;padding:16px 44px">무료 상담 신청하기</a>
  </div>
</section>

<footer>
  <div class="wrap foot">
    <div>
      <div class="logo"><span class="logo-dot"></span>공부의 온도</div>
      <div>아이에게 맞는 공부 방식을 찾아 주는 곳</div>
    </div>
    <div>
      <div class="foot-links">
        <a href="../index.html#visit">방문과외</a>
        <a href="../index.html#online">화상과외</a>
        <a href="../centers.html">학습센터</a>
        <a href="../teachers.html">선생님 찾기</a>
        <a href="../blog.html">공부 이야기</a>
      <a href="../blog.html">공부 이야기</a>
        <a href="../grade-calculator.html">내신 등급 계산기</a>
        <a href="../status.html">수업 현황</a>
      </div>
      <div style="margin-top:16px">© 2026 공부의 온도. All rights reserved.</div>
    </div>
  </div>
</footer>

<script>
var burger = document.getElementById('burger');
var menu = document.getElementById('menu');
burger.addEventListener('click', function(){ menu.classList.toggle('open'); });
menu.addEventListener('click', function(e){ if(e.target.tagName === 'A') menu.classList.remove('open'); });
</script>
</body>
</html>
"@

  [IO.File]::WriteAllText("$OUTDIR\$fileName", $html, (New-Object Text.UTF8Encoding $false))
  $made++
  $idx++
}

"센터 페이지 $made 개 생성 → $OUTDIR"
