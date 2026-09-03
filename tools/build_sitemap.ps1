$ErrorActionPreference='Stop'
$SITE = Split-Path $PSScriptRoot -Parent
$today = Get-Date -Format 'yyyy-MM-dd'
$sb = New-Object Text.StringBuilder
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sb.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/</loc><lastmod>$today</lastmod><priority>1.0</priority></url>")
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/teachers.html</loc><lastmod>$today</lastmod><priority>0.9</priority></url>")
[void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/status.html</loc><lastmod>$today</lastmod><priority>0.6</priority></url>")
$n = 0
Get-ChildItem "$SITE\t\*.html" | Sort-Object Name | ForEach-Object {
  [void]$sb.AppendLine("  <url><loc>https://firststudy.co.kr/t/$($_.Name)</loc><lastmod>$today</lastmod><priority>0.7</priority></url>")
  $n++
}
[void]$sb.AppendLine('</urlset>')
[IO.File]::WriteAllText("$SITE\sitemap.xml", $sb.ToString(), (New-Object Text.UTF8Encoding $false))
"sitemap.xml 갱신: 선생님 $n 개 + 주요 3개 = $($n+3) URL"