$ErrorActionPreference='Stop'
$SITE = Split-Path $PSScriptRoot -Parent
$today = Get-Date -Format 'yyyy-MM-dd'
$sb = New-Object Text.StringBuilder
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sb.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/</loc><lastmod>$today</lastmod><priority>1.0</priority></url>")
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/schools.html</loc><lastmod>$today</lastmod><priority>0.95</priority></url>")
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/teachers.html</loc><lastmod>$today</lastmod><priority>0.9</priority></url>")
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/centers.html</loc><lastmod>$today</lastmod><priority>0.9</priority></url>")
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/grade-calculator.html</loc><lastmod>$today</lastmod><priority>0.9</priority></url>")
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/status.html</loc><lastmod>$today</lastmod><priority>0.6</priority></url>")
$n = 0
# 인천 전담(2026-09-21): 선생님 목록(teachers.html)에 나오는 사람만 싣는다 = 화상 가능 또는 인천 방문
$tRaw = Get-Content "$SITE\teachers-data.js" -Raw -Encoding UTF8; $tMk = 'window.TEACHERS='
$tList = $tRaw.Substring($tRaw.IndexOf($tMk) + $tMk.Length).TrimEnd().TrimEnd(';') | ConvertFrom-Json
$listed = @{}; foreach($x in $tList){ if($x.c -match '화상' -or $x.sd -match '인천'){ $listed[$x.i] = 1 } }
$sn = 0
Get-ChildItem "$SITE\school\*.html" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
  $enc = [Uri]::EscapeDataString($_.BaseName) + '.html'
  [void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/school/$enc</loc><lastmod>$today</lastmod><priority>0.85</priority></url>")
  $sn++
}
Get-ChildItem "$SITE\t\*.html" | Where-Object { $listed.ContainsKey($_.BaseName) } | Sort-Object Name | ForEach-Object {
  [void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/t/$($_.Name)</loc><lastmod>$today</lastmod><priority>0.7</priority></url>")
  $n++
}
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/blog.html</loc><lastmod>$today</lastmod><priority>0.9</priority></url>")
$bn = 0
Get-ChildItem "$SITE\blog\*.html" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | ForEach-Object {
  [void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/blog/$($_.Name)</loc><lastmod>$today</lastmod><priority>0.8</priority></url>")
  $bn++
}
$cn = 0
# 센터 페이지는 디스크에 한글 파일명으로 저장돼 있다. 사이트맵 URL 은 퍼센트 인코딩해야 한다.
Get-ChildItem "$SITE\c\*.html" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
  $enc = [Uri]::EscapeDataString($_.BaseName) + '.html'
  [void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/c/$enc</loc><lastmod>$today</lastmod><priority>0.8</priority></url>")
  $cn++
}
[void]$sb.AppendLine('</urlset>')
[IO.File]::WriteAllText("$SITE\sitemap.xml", $sb.ToString(), (New-Object Text.UTF8Encoding $false))
"sitemap.xml 갱신: 학교 $sn + 선생님 $n + 센터 $cn + 글 $bn + 주요 7개 = $($sn+$n+$cn+$bn+7) URL"