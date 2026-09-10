$ErrorActionPreference='Stop'
# blog/*.html 을 훑어 목록 페이지(blog.html)와 RSS(rss.xml)를 다시 만든다.
# 글마다 <head> 의 meta 를 읽으므로, 새 글에는 아래 4개가 반드시 있어야 한다.
#   <meta name="article:published" content="YYYY-MM-DD">
#   <meta name="article:area"      content="용인시 풍덕천동">
#   <meta name="article:subject"   content="수학">
#   <meta name="article:center"    content="수지점">      ← c/{센터명}.html 로 연결
$SITE = Split-Path $PSScriptRoot -Parent
$BLOG = "$SITE\blog"
if(-not (Test-Path $BLOG)){ New-Item -ItemType Directory $BLOG | Out-Null }

function Esc($s){
  if($null -eq $s){ return '' }
  return ([string]$s).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}
function MetaOf($html, $name){
  $m = [regex]::Match($html, '<meta\s+name="' + [regex]::Escape($name) + '"\s+content="([^"]*)"')
  if($m.Success){ return $m.Groups[1].Value }
  return ''
}

$posts = @()
foreach($f in (Get-ChildItem "$BLOG\*.html" -ErrorAction SilentlyContinue)){
  $h = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $title = ''
  $mt = [regex]::Match($h, '<title>([^<]*)</title>')
  if($mt.Success){ $title = $mt.Groups[1].Value -replace '\s*\|\s*공부의 온도\s*$','' }
  $desc = ''
  $md = [regex]::Match($h, '<meta\s+name="description"\s+content="([^"]*)"')
  if($md.Success){ $desc = $md.Groups[1].Value }

  $posts += [pscustomobject]@{
    file    = $f.Name
    title   = $title
    desc    = $desc
    date    = (MetaOf $h 'article:published')
    kind    = (MetaOf $h 'article:kind')
    area    = (MetaOf $h 'article:area')
    subject = (MetaOf $h 'article:subject')
    center  = (MetaOf $h 'article:center')
  }
}
$posts = @($posts | Where-Object { $_.date } | Sort-Object date -Descending)
if(-not $posts.Count){ "blog/ 에 글이 없다. 중단."; return }

# ---------------- 목록 페이지 ----------------
$cards = foreach($p in $posts){
  $d = ([datetime]$p.date).ToString('yyyy.MM.dd')
  $tags = @()
  if($p.kind){    $tags += $p.kind }
  if($p.area){    $tags += $p.area }
  if($p.subject){ $tags += $p.subject + '과외' }
  $tagHtml = ($tags | ForEach-Object { "<span>$(Esc $_)</span>" }) -join ''
  @"
      <a class="bl-item" href="blog/$($p.file)">
        <span class="d">$d</span>
        <h3>$(Esc $p.title)</h3>
        <p>$(Esc $p.desc)</p>
        <div class="bl-tags">$tagHtml</div>
      </a>
"@
}

$latest = $posts[0]
$listHtml = @"
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>공부 이야기 | 공부의 온도 — 지역·학교별 과외 이야기</title>
<meta name="description" content="동네와 학교에 맞춘 과외 이야기, 상담에서 자주 나오는 질문을 매일 씁니다. 우리 아이가 다니는 학교, 지금 막힌 과목에서 시작하세요.">
<link rel="canonical" href="https://firststudy.co.kr/blog.html">
<meta property="og:type" content="website">
<meta property="og:title" content="공부 이야기 | 공부의 온도">
<meta property="og:description" content="동네와 학교 이야기, 자주 나오는 질문을 매일.">
<meta property="og:url" content="https://firststudy.co.kr/blog.html">
<meta property="og:locale" content="ko_KR">
<meta property="og:image" content="https://firststudy.co.kr/apple-touch-icon.png">
<link rel="icon" href="favicon.ico" sizes="any">
<link rel="icon" href="favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<meta name="theme-color" content="#FDFBF7">
<link rel="alternate" type="application/rss+xml" title="공부의 온도" href="rss.xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Gowun+Dodum&family=Noto+Sans+KR:wght@300;400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="style.css?v=7">
</head>
<body>

<header>
  <div class="wrap nav">
    <a href="index.html" class="logo"><span class="logo-dot"></span>공부의 온도</a>
    <nav class="nav-menu" id="menu">
      <div class="nav-item">
        <a class="nav-top">과외 <span class="caret">▼</span></a>
        <div class="nav-sub">
          <a href="index.html#visit"><span class="dot visit"></span>방문과외</a>
          <a href="index.html#online"><span class="dot online"></span>화상과외</a>
        </div>
      </div>
      <a href="centers.html">학습센터</a>
      <a href="teachers.html">선생님 찾기</a>
      <a href="blog.html">공부 이야기</a>
      <a href="status.html">수업 현황</a>
    </nav>
    <a href="index.html#contact" class="btn btn-main nav-cta">무료 상담</a>
    <button class="burger" id="burger" aria-label="메뉴 열기">☰</button>
  </div>
</header>

<section class="t-hero">
  <div class="wrap">
    <p class="eyebrow">공부 이야기</p>
    <h1>우리 동네, 우리 학교<br><em>이야기부터</em></h1>
    <p>같은 학년이어도 다니는 학교가 다르면 준비도 달라집니다.<br>동네와 학교 이야기, 상담에서 자주 나오는 질문을 매일 씁니다. 지금 <b>$($posts.Count)편</b>.</p>
  </div>
</section>

<section style="padding-top:20px">
  <div class="wrap">
    <div class="bl-grid">
$($cards -join "`n")
    </div>
  </div>
</section>

<section style="background:var(--bg-soft);margin-top:70px">
  <div class="wrap" style="text-align:center;padding:70px 0">
    <h2 class="sec-title">우리 아이 이야기도 들려주세요</h2>
    <p class="sec-desc">지금 어디서 막혀 있는지 알려주시면, 방문·화상·학습센터 중 어울리는 방식과 선생님을 함께 골라 드립니다.</p>
    <a href="index.html#contact" class="btn btn-main" style="margin-top:26px;padding:16px 44px">무료 상담 신청하기</a>
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
        <a href="index.html#visit">방문과외</a>
        <a href="index.html#online">화상과외</a>
        <a href="centers.html">학습센터</a>
        <a href="teachers.html">선생님 찾기</a>
        <a href="blog.html">공부 이야기</a>
        <a href="grade-calculator.html">내신 등급 계산기</a>
        <a href="status.html">수업 현황</a>
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
[IO.File]::WriteAllText("$SITE\blog.html", $listHtml, (New-Object Text.UTF8Encoding $false))

# ---------------- RSS ----------------
$now = (Get-Date).ToUniversalTime().ToString('ddd, dd MMM yyyy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) + ' GMT'
$items = foreach($p in ($posts | Select-Object -First 100)){
  $pub = ([datetime]$p.date).ToUniversalTime().ToString('ddd, dd MMM yyyy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) + ' GMT'
  $url = "https://firststudy.co.kr/blog/$($p.file)"
  @"
    <item>
      <title>$(Esc $p.title)</title>
      <link>$url</link>
      <guid isPermaLink="true">$url</guid>
      <pubDate>$pub</pubDate>
      <description>$(Esc $p.desc)</description>
    </item>
"@
}
$rss = @"
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>공부의 온도 — 공부 이야기</title>
    <link>https://firststudy.co.kr/blog.html</link>
    <description>동네와 학교 이야기, 상담에서 자주 나오는 질문을 매일.</description>
    <language>ko</language>
    <lastBuildDate>$now</lastBuildDate>
$($items -join "`n")
  </channel>
</rss>
"@
[IO.File]::WriteAllText("$SITE\rss.xml", $rss, (New-Object Text.UTF8Encoding $false))

"blog.html 갱신: $($posts.Count)편 / rss.xml 갱신: $([Math]::Min(100,$posts.Count))건"
"최신 글: $($latest.date) $($latest.title)"
