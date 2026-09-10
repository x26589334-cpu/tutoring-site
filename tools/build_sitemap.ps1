$ErrorActionPreference='Stop'
$SITE = Split-Path $PSScriptRoot -Parent
$today = Get-Date -Format 'yyyy-MM-dd'
$sb = New-Object Text.StringBuilder
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sb.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/</loc><lastmod>$today</lastmod><priority>1.0</priority></url>")
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/teachers.html</loc><lastmod>$today</lastmod><priority>0.9</priority></url>")
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/centers.html</loc><lastmod>$today</lastmod><priority>0.9</priority></url>")
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/status.html</loc><lastmod>$today</lastmod><priority>0.6</priority></url>")
$n = 0
Get-ChildItem "$SITE\t\*.html" | Sort-Object Name | ForEach-Object {
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
"sitemap.xml 갱신: 선생님 $n + 센터 $cn + 글 $bn + 주요 5개 = $($n+$cn+$bn+5) URL"