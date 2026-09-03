# 공부의 온도 (firststudy.co.kr) — 프로젝트 안내

## 개요
- 초·중·고 1:1 과외 상담 유치 사이트 (정적 사이트, GitHub Pages)
- **라이브 주소:** https://firststudy.co.kr
- **GitHub 저장소:** https://github.com/x26589334-cpu/tutoring-site (기본 브랜치: **main**)
- **상담 접수:** 구글 "웹 문의" 시트의 `공부의온도` 탭 (공용 Apps Script 웹앱)
- 형제 사이트: **티칭코칭**(perfectedu.co.kr, 저장소 `gwaoe-page`) · **와와**(wawa-renewal) — 같은 회사

## 배포 방법 (수정 → 반영)
```
git add .
git commit -m "메시지"
git push
```
→ 1~2분 후 라이브 반영. 캐시로 안 보이면 Ctrl+Shift+R.

## 파일 구조
- `index.html` — 홈. 히어로 / 세 가지 방식(방문·화상·학습센터) / 상담 폼
- `teachers.html` — **선생님 찾기**. 검색 + 방식 탭 + 과목·지역·성별·유아 필터, 30명씩 "더 보기"
- `teachers-data.js` — 선생님 목록 데이터 `window.TEACHERS=[{i,n,g,c,s,gr,sd,r,tag,k}]`
  - `i`=publicId, `n`=마스킹 이름, `g`=성별, `c`=수업방식(방문/화상/방문+화상), `s`=과목[], `gr`=학년[], `sd`=시도, `r`=방문지역, `tag`=한 줄 소개, `k`=유아·아동 전문
- `teachers-search.js` — 검색 색인 `{id: '시군구 읍면동 + 학교 + 소개글'}` (defer 로드, 초기 로딩 경량화)
- `t/{publicId}.html` — 선생님 개별 페이지 **750개**
- `status.html` — 이번 달 수업 현황 (현재 내용은 예시 데이터, 자동 갱신 장치 없음)
- `style.css` 공용 스타일 / `sitemap.xml` / `robots.txt` / `CNAME`(firststudy.co.kr)
- `google-apps-script.gs` — 상담 폼 수신 Apps Script **참고용 사본** (실제 코드는 Apps Script 편집기에 있음)
- `tools/` — 재생성 스크립트 (아래 참고)

## ⚠️ 중요 규칙
- **`style.css` 를 수정하면 전 페이지의 `style.css?v=` 숫자를 올려야 반영된다.** (현재 **v2**)
  안 올리면 배포는 돼도 브라우저가 옛 캐시를 써서 "바뀐 게 없다"는 현상이 난다.
  ```bash
  V=3
  grep -rl 'style.css?v=' --include='*.html' . | while read f; do
    sed -i "s#style\.css?v=[0-9]*#style.css?v=$V#g" "$f"
  done
  grep -rho 'style\.css?v=[0-9]*' --include='*.html' . | sort | uniq -c   # 전부 같은 버전이어야 함
  ```
  `t/` 하위 750개도 함께 바뀌므로 `-r` 로 돌릴 것.
- **선생님 페이지를 추가·삭제하면 `tools/build_sitemap.ps1` 을 다시 실행**해 `sitemap.xml` 을 갱신한다.
- 커밋은 Applefist 계정으로.

## 선생님 750명 데이터
- 출처: **와와 사내 코치 데이터**를 두 저장소에서 합쳐 만든다. 원본을 직접 긁지 않는다.
  - `~/wawa-renewal/assets/js/coaches-data.js` → `tag`(한 줄 소개), `intro`(소개 전문), `schools`, `emdong`, `sigungu`
  - `~/gwaoe-page/teachers-data.js` → `i`(publicId), `n`(ㅇ 마스킹 이름), `g`(성별), `gr`(학년 범위), `k`(유아)
  - **두 파일은 인덱스 순서가 정확히 일치**한다(750 = 750, 이름 동일). 이 순서 일치를 전제로 병합한다.
- 이름은 가운데 글자 **ㅇ 마스킹**(박인옥 → 박ㅇ옥). 사진은 쓰지 않고 이니셜 사각형으로 대체.
- 소개글은 와와 쪽에서 이미 정제된 것(내부 조직 태그·외모 언급·검증 불가 성과 주장 제거)을 그대로 쓴다.

### 재생성 방법
```powershell
# PowerShell 5.1 은 BOM 없는 .ps1 을 CP949 로 읽어 한글이 깨진다.
# tools/ 안의 스크립트는 UTF-8 BOM 으로 저장돼 있으니 그대로 실행하면 된다.
.\tools\build_data.ps1      # 와와 + 티칭코칭 → teachers-data.js, teachers-search.js
.\tools\gen_teachers.ps1    # → t/*.html 750개
.\tools\build_sitemap.ps1   # → sitemap.xml
```
`build_data.ps1` 은 `~/wawa-renewal` 과 `~/gwaoe-page` 가 로컬에 clone 돼 있어야 동작한다.
중간 파일 `%TEMP%\td_detail.json`(소개 전문·학교 목록)을 `gen_teachers.ps1` 이 읽으므로 **순서대로** 실행할 것.

**PowerShell 함정**: 변수명은 대소문자를 구분하지 않는다. `$w=$W[$n]` 처럼 쓰면 원본 배열 `$W` 가 첫 원소로 덮여 루프가 1회만 돈다. 루프 변수는 `$cw`/`$ct` 처럼 다른 이름을 쓸 것.

## 티칭코칭과 일부러 다르게 한 점
같은 회사 사이트라 데이터는 공유하지만, **화면이 겹치면 두 사이트가 서로 잡아먹는다.** 아래는 의도적 차별화이므로 되돌리지 말 것.

| | 티칭코칭 (perfectedu) | 공부의 온도 (firststudy) |
|---|---|---|
| 1차 축 | 과목·지역 | **수업 방식**(방문/화상) — 브랜드 3색으로 구분 |
| 카드 | 이니셜 원 + 과목 칩 + 지역 | **한 줄 소개(tag)를 헤드라인**으로 세움 |
| 목록 | 24명씩 페이지네이션 | 30명씩 **"더 보기"** |
| 상세 URL | `teacher-{id}.html` (루트) | `t/{id}.html` (폴더 분리) |
| 상세 하단 | 학교 링크 중심 | **"이런 선생님도 있어요"** 3명 추천 |
| 톤 | 정보형 | 크림색·고운돋움, 학부모 대화체 |

브랜드 색 토큰: 방문=`--visit`(애프리콧) / 화상=`--online`(스카이) / 학습센터=`--center`(민트).
선생님 카드 왼쪽 색 띠와 배지가 이 토큰을 따른다.

## 선생님 → 상담 연결
선생님 상세의 CTA 는 `index.html?t={publicId}&n={이름}#contact` 로 이동한다.
홈에서 이 파라미터를 읽어 폼 위에 "OOO 선생님을 보고 오셨네요" 안내를 띄우고,
접수 데이터에 `희망선생님` 항목을 함께 보낸다.
공용 Apps Script 는 **새 항목이 오면 시트 헤더에 자동으로 컬럼을 추가**하므로 서버 쪽 수정은 필요 없다.

## 아직 안 한 것 / 다음 후보
- `status.html` 수업 현황이 **예시 데이터**다. 실제 수업으로 교체하거나, 구글 시트에 `수업현황` 탭을 만들어 읽어오게 하면 커밋 없이 갱신할 수 있다. (페이지에는 "매주 월요일 업데이트"라고 적혀 있지만 자동 갱신 장치는 없다.)
- 데일리 콘텐츠(블로그·지역 페이지·RSS)는 아직 없다. 티칭코칭이 이미 그 키워드를 잡고 있으므로, 같은 글을 쓰면 자기잠식이 된다. 하려면 **방식(방문 vs 화상) 선택 고민** 쪽 키워드로 축을 달리 잡을 것.
- 구글 서치콘솔 / 네이버 서치어드바이저에 `sitemap.xml` 재제출 (선생님 750페이지 색인)

## 다른 PC 에서 이어서 하기
1. `git clone https://github.com/x26589334-cpu/tutoring-site.git`
2. 선생님 데이터를 재생성하려면 `wawa-renewal`, `gwaoe-page` 도 같이 clone
3. 그 폴더에서 Claude Code 실행 → "공부의 온도(firststudy) 이어서 작업해줘"
