$ErrorActionPreference='Stop'
$SITE   = "$HOME\tutoring-site"
$OUTDIR = "$SITE\t"
if(-not (Test-Path $OUTDIR)){ New-Item -ItemType Directory $OUTDIR | Out-Null }

# ---------- 데이터 로드 ----------
$raw = Get-Content "$SITE\teachers-data.js" -Raw -Encoding UTF8
$marker = 'window.TEACHERS='
$js  = $raw.Substring($raw.IndexOf($marker) + $marker.Length).TrimEnd()
if($js.EndsWith(';')){ $js = $js.Substring(0,$js.Length-1) }
$LIST = $js | ConvertFrom-Json

$DET = Get-Content "$env:TEMP\td_detail.json" -Raw -Encoding UTF8 | ConvertFrom-Json

function Esc($s){
  if($null -eq $s){ return '' }
  return ([string]$s).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}

# 같은 과목·같은 방식의 다른 선생님 3명 (내부 링크)
$bySubj = @{}
foreach($p in $LIST){
  foreach($sj in $p.s){
    $key = "$sj|$($p.c)"
    if(-not $bySubj.ContainsKey($key)){ $bySubj[$key] = New-Object System.Collections.Generic.List[object] }
    $bySubj[$key].Add($p)
  }
}

$GRAD = @{
  '방문' = 'linear-gradient(135deg,#F2A98C,#E88E6C)'
  '화상' = 'linear-gradient(135deg,#93B8E8,#6E9BD8)'
  'both' = 'linear-gradient(135deg,#F2A98C,#93B8E8)'
}

$made = 0
foreach($p in $LIST){
  $id   = $p.i
  $nm   = $p.n
  $way  = $p.c
  $wcls = if($way -eq '방문+화상'){'both'}else{$way}
  $d    = $DET.$id

  $subjTxt = ($p.s -join '·')
  $firstSubj = @($p.s)[0]
  $regions = @()
  if($p.r){ $regions = $p.r -split '\|' }
  $regionHead = if($regions.Count){ $regions[0] } else { '' }

  # ----- 제목 / 설명 (지역·과목 키워드를 앞세운다) -----
  if($way -eq '화상'){
    $h1sub  = "전국 화상 $subjTxt 과외"
    $title  = "$firstSubj 화상과외 — 전국 1:1 · $nm 선생님 | 공부의 온도"
    $desc   = "$($p.tag). 전국 어디서나 가능한 $subjTxt 1:1 화상과외 선생님입니다. 공부의 온도에서 무료 상담으로 시작하세요."
    $whereL = '전국 (화상 수업)'
  } else {
    $h1sub  = "$regionHead $subjTxt 과외"
    $title  = "$regionHead $firstSubj 과외 — 방문 1:1 · $nm 선생님 | 공부의 온도"
    $desc   = "$($p.tag). $regionHead 지역 $subjTxt 1:1 $way 과외 선생님입니다. 공부의 온도에서 무료 상담으로 시작하세요."
    $whereL = ($regions -join ' · ')
  }

  # ----- 과목·학년 -----
  $sgLines = @()
  for($k=0; $k -lt $p.s.Count; $k++){
    $g = if($k -lt $p.gr.Count -and $p.gr[$k]){ " <span style=""color:var(--ink-light)"">$(Esc $p.gr[$k])</span>" } else { '' }
    $sgLines += "$(Esc $p.s[$k])$g"
  }
  $sgHtml = $sgLines -join ' &nbsp;/&nbsp; '

  # ----- 소개글 (문장 단위 줄바꿈) -----
  $intro = [string]$d.intro
  $intro = $intro -replace '다\.\s+', "다.`n"
  $intro = $intro -replace '요\.\s+', "요.`n"
  $introHtml = Esc $intro

  # ----- 지도 가능 학교 -----
  $schoolBox = ''
  $schools = @($d.schools)
  if($schools.Count -gt 0){
    $show = $schools | Select-Object -First 40
    $rest = $schools.Count - $show.Count
    $tail = if($rest -gt 0){ " 외 $rest곳" } else { '' }
    $schoolBox = @"
      <div class="td-box" style="margin-top:20px">
        <h2>지도 경험이 있는 학교</h2>
        <p class="td-schools">$(Esc ($show -join ' · '))$tail</p>
      </div>
"@
  }

  # ----- 동네 -----
  $emdongLine = ''
  $emd = @($d.emdong)
  if($emd.Count -gt 0){
    $emdongLine = "        <li><i>주요 동네</i><span>$(Esc ($emd -join ', '))</span></li>`n"
  }

  # ----- 이런 선생님도 -----
  $relKey = "$firstSubj|$way"
  $rel = @()
  if($bySubj.ContainsKey($relKey)){
    $rel = $bySubj[$relKey] | Where-Object { $_.i -ne $id } | Select-Object -First 3
  }
  $relHtml = ''
  if(@($rel).Count -gt 0){
    $cards = foreach($r in $rel){
      $rw = if($r.c -eq '방문+화상'){'both'}else{$r.c}
      $rwhere = if($r.r){ (($r.r -split '\|')[0]) } else { '전국 어디서나 · 화상 수업' }
      @"
        <a class="t-card w-$rw" href="$($r.i).html">
          <span class="t-badge w-$rw">$($r.c)과외</span>
          <p class="t-tag">$(Esc $r.tag)</p>
          <p class="t-name"><b>$(Esc $r.n)</b> 선생님$(if($r.g){" · " + $r.g})</p>
          <p class="t-where">📍 $(Esc $rwhere)</p>
        </a>
"@
    }
    $relHtml = @"

<section style="padding:70px 0 10px">
  <div class="wrap">
    <h2 class="sec-title" style="font-size:24px;text-align:center;margin-bottom:26px">이런 선생님도 있어요</h2>
    <div class="t-grid">
$($cards -join "`n")
    </div>
    <div style="text-align:center;margin-top:30px">
      <a href="../teachers.html" class="btn btn-ghost">선생님 750명 전체 보기</a>
    </div>
  </div>
</section>
"@
  }

  $kidLine = if($p.k -eq 1){ "        <li><i>대상</i><span>유아·아동 전문 지도 가능</span></li>`n" } else { '' }

  # 키즈 데이터 43명은 성별 정보가 없다 — 없으면 표기하지 않는다
  $genderTxt = if($p.g){ " · $($p.g)선생님" } else { "" }

  $ld = @{
    '@context'='https://schema.org'
    '@type'='Person'
    'name'="$nm 선생님"
    'jobTitle'='1:1 과외 선생님'
    'description'=[string]$p.tag
    'knowsAbout'=@($p.s)
    'worksFor'=@{ '@type'='EducationalOrganization'; 'name'='공부의 온도'; 'url'='https://firststudy.co.kr/' }
    'url'="https://firststudy.co.kr/t/$id.html"
  }
  if($way -ne '화상' -and $regions.Count){ $ld['areaServed'] = @($regions) }
  $ldJson = $ld | ConvertTo-Json -Depth 5

  $html = @"
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$(Esc $title)</title>
<meta name="description" content="$(Esc $desc)">
<link rel="canonical" href="https://firststudy.co.kr/t/$id.html">
<meta property="og:type" content="profile">
<meta property="og:title" content="$(Esc $title)">
<meta property="og:description" content="$(Esc $desc)">
<meta property="og:url" content="https://firststudy.co.kr/t/$id.html">
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
<link rel="stylesheet" href="../style.css?v=2">
</head>
<body>

<header>
  <div class="wrap nav">
    <a href="../index.html" class="logo"><span class="logo-dot"></span>공부의 온도</a>
    <nav class="nav-menu" id="menu">
      <a href="../index.html#visit">방문과외</a>
      <a href="../index.html#online">화상과외</a>
      <a href="../index.html#center">학습센터</a>
      <a href="../teachers.html">선생님 찾기</a>
      <a href="../status.html">수업 현황</a>
    </nav>
    <a href="../index.html?t=$id&amp;n=$([Uri]::EscapeDataString($nm))#contact" class="btn btn-main nav-cta">무료 상담</a>
    <button class="burger" id="burger" aria-label="메뉴 열기">☰</button>
  </div>
</header>

<section class="td-hero">
  <div class="wrap">
    <a href="../teachers.html" class="td-back">← 선생님 찾기로 돌아가기</a>
    <div class="td-top">
      <div class="td-ini" style="background:$($GRAD[$wcls])">$($nm.Substring(0,1))</div>
      <div>
        <h1 class="td-h1">$(Esc $nm) 선생님</h1>
        <p class="td-sub">$(Esc $h1sub)$genderTxt</p>
      </div>
    </div>
  </div>
</section>

<section style="padding-top:0">
  <div class="wrap">
    <div class="td-body">
      <div>
        <div class="td-box">
          <h2>$(Esc $p.tag)</h2>
          <p class="td-intro">$introHtml</p>
        </div>
$schoolBox
      </div>

      <aside>
        <div class="td-box">
          <h2>수업 정보</h2>
          <ul class="td-facts">
            <li><i>수업 방식</i><span>$(Esc $way)과외</span></li>
            <li><i>과목·학년</i><span>$sgHtml</span></li>
            <li><i>수업 지역</i><span>$(Esc $whereL)</span></li>
$emdongLine$kidLine          </ul>
        </div>
        <div class="td-cta">
          <a href="../index.html?t=$id&amp;n=$([Uri]::EscapeDataString($nm))#contact" class="btn btn-main">$(Esc $nm) 선생님 상담 신청</a>
          <p class="td-note">신청하시면 선생님의 수업 가능 시간을 확인한 뒤 연락드립니다.<br>일정이 맞지 않으면 비슷한 선생님을 함께 안내해 드려요.</p>
        </div>
      </aside>
    </div>
  </div>
</section>
$relHtml

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
        <a href="../index.html#center">학습센터</a>
        <a href="../teachers.html">선생님 찾기</a>
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

  [IO.File]::WriteAllText("$OUTDIR\$id.html", $html, (New-Object Text.UTF8Encoding $false))
  $made++
}

"선생님 페이지 $made 개 생성 → $OUTDIR"
