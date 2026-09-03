$ErrorActionPreference='Stop'
$OutputEncoding=[Text.Encoding]::UTF8
$SITE="$HOME\tutoring-site"

function Load-JsArray($path){
  $t=Get-Content $path -Raw -Encoding UTF8
  $j=$t.Substring($t.IndexOf('[')).TrimEnd()
  if($j.EndsWith(';')){$j=$j.Substring(0,$j.Length-1)}
  $j=[regex]::Replace($j,'([{,])(\s*)([A-Za-z_]\w*)\s*:','$1$2"$3":')
  return ($j | ConvertFrom-Json)
}

$W = Load-JsArray "$HOME\wawa-renewal\assets\js\coaches-data.js"
$T = Load-JsArray "$HOME\gwaoe-page\teachers-data.js"
if($W.Count -ne $T.Count){ throw "건수 불일치: $($W.Count) vs $($T.Count)" }


function AsList($v){
  if($null -eq $v){ return @() }
  if($v -is [string]){ if($v){return @($v)} else {return @()} }
  if($v -is [array]){ return @($v | Where-Object { $_ -is [string] -and $_ }) }
  return @()
}

$out=New-Object System.Collections.Generic.List[object]
$idx=@{}
for($n=0;$n -lt $W.Count;$n++){
  $cw=$W[$n]; $ct=$T[$n]
  $subs = ($ct.s -split ',') | Where-Object { $_ }
  $grs  = ($ct.gr -split ',')
  $emd  = AsList $cw.emdong
  $sch  = AsList $cw.schools
  $sgu  = AsList $cw.sigungu
  $sido = if($cw.sido -is [string]){$cw.sido}else{''}

  $o=[ordered]@{
    i  = $ct.i
    n  = $ct.n
    g  = $ct.g
    c  = $ct.c
    s  = @($subs)
    gr = @($grs)
    sd = $ct.sd
    r  = $ct.r
    tag= [string]$cw.tagline
    k  = [int]$ct.k
  }
  $out.Add([pscustomobject]$o)

  # 검색 색인: 읍면동 + 학교 + 소개 + 시군구
  $blob = (@($sgu + $emd + $sch) -join ' ') + ' ' + [string]$cw.intro + ' ' + [string]$cw.tagline
  $blob = ($blob -replace '\s+',' ').Trim().ToLower()
  $idx[$ct.i]=$blob
}

# 상세 페이지용 원본(intro/schools/emdong) 별도 보관
$detail=@{}
for($n=0;$n -lt $W.Count;$n++){
  $detail[$T[$n].i]=[pscustomobject]@{
    intro   = [string]$W[$n].intro
    schools = @(AsList $W[$n].schools)
    emdong  = @(AsList $W[$n].emdong)
    sigungu = @(AsList $W[$n].sigungu)
    sido    = $(if($W[$n].sido -is [string]){$W[$n].sido}else{''})
  }
}

$hdr = @"
/* 공부의 온도 — 선생님 목록 데이터 (자동 생성, 수정하지 말 것)
   i=id, n=이름(마스킹), g=성별, c=수업방식, s=과목[], gr=학년[], sd=시도, r=방문지역, tag=한줄소개, k=유아·아동
   ※ 검색 색인은 teachers-search.js 로 분리 (초기 로딩 경량화) */
window.TEACHERS=
"@
$body = ConvertTo-Json -InputObject $out.ToArray() -Depth 5 -Compress
[IO.File]::WriteAllText("$SITE\teachers-data.js", $hdr + $body + ";`n", (New-Object Text.UTF8Encoding $false))

$shdr = @"
/* 공부의 온도 — 선생님 검색 색인 (자동 생성)
   { 선생님id: '시군구 읍면동 + 지도 가능 학교 + 소개글' } — 전부 소문자
   teachers.html 에서 defer 로 로드되며, 로드 완료 시 목록을 다시 그린다 */
window.TSEARCH=
"@
[IO.File]::WriteAllText("$SITE\teachers-search.js", $shdr + ($idx|ConvertTo-Json -Depth 3 -Compress) + ";`n", (New-Object Text.UTF8Encoding $false))

# 상세 생성용 중간 파일 (사이트에는 안 올림)
[IO.File]::WriteAllText("$env:TEMP\td_detail.json", ($detail|ConvertTo-Json -Depth 5 -Compress), (New-Object Text.UTF8Encoding $false))

"teachers-data.js  : {0:N0} bytes / {1}명" -f (Get-Item "$SITE\teachers-data.js").Length, $out.Count
"teachers-search.js: {0:N0} bytes" -f (Get-Item "$SITE\teachers-search.js").Length
