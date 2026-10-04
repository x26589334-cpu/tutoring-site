/* 학교 × 과목 페이지 생성 (2026-10-04) — school/{약칭}-{과목}과외.html
   실행: ELECTRON_RUN_AS_NODE=1 Code.exe tools/build_subjects.js   (저장소 루트에서. build_incheon.ps1 을 먼저 돌린 뒤에)
   - 틀(머리말·메뉴·푸터)은 이미 만들어진 학교 페이지에서 그대로 가져온다 → 디자인이 바뀌어도 따라간다
   - 본문은 tools/subjects.js (지역 과외 생성기와 같은 내용. 과목·학교급마다 다르다)
   - 초등은 국어·영어·수학만, 중·고는 5과목. 학교별 시험 범위·출제 경향은 쓰지 않는다(지어내기 금지) */
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..'), SITE = 'https://firststudy.co.kr';
const { SUBJ, subjectsFor, C } = require('./subjects');
const esc = s => String(s == null ? '' : s).replace(/[<>&"]/g, c => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;' }[c]));
const enc = s => encodeURIComponent(s);
const load = (f, marker) => { const t = fs.readFileSync(path.join(ROOT, f), 'utf8'); const i = t.indexOf(marker) + marker.length; return JSON.parse(t.slice(i, t.lastIndexOf(']') + 1)); };
const SCH = load('incheon-schools.js', 'window.INC_SCHOOLS=');
const TEACH = load('teachers-data.js', 'window.TEACHERS=');
const LEVEL = { '초': '초등학교', '중': '중학교', '고': '고등학교' };
const GORD = ['초1', '초2', '초3', '초4', '초5', '초6', '중1', '중2', '중3', '고1', '고2', '고3'];
const covers = (gr, lv) => (gr || []).some(g => {
  const m = String(g).match(/(초|중|고)(\d)\s*~\s*(초|중|고)(\d)/); if (!m) return String(g).includes(lv);
  const a = GORD.indexOf(m[1] + m[2]), b = GORD.indexOf(m[3] + m[4]), lo = GORD.indexOf(lv + '1'), hi = GORD.indexOf(lv === '초' ? '초6' : lv + '3');
  return a <= hi && b >= lo;
});
const josa = (w, a, b) => { const c = w.charCodeAt(w.length - 1); return w + ((c >= 0xAC00 && c <= 0xD7A3 && (c - 0xAC00) % 28 !== 0) ? a : b); };

let made = 0;
for (const s of SCH) {
  const n = s.n, a = s.a, gu = s.g, lv = s.t;
  const tplFile = path.join(ROOT, 'school', n + '.html');
  if (!fs.existsSync(tplFile)) continue;
  const tpl = fs.readFileSync(tplFile, 'utf8');
  const headEnd = tpl.indexOf('<section class="cd-hero">'), footStart = tpl.indexOf('<footer>');
  if (headEnd < 0 || footStart < 0) continue;
  for (const sub of subjectsFor(lv)) {
    const K = C[sub], file = `${a}-${sub}과외`, url = `${SITE}/school/${enc(file)}.html`;
    const isElem = lv === '초', examWord = isElem ? '단원평가' : '중간고사·기말고사';
    const title = `${a} ${sub}과외 | 인천 ${gu} ${n} ${sub} 내신·${isElem ? '단원평가' : '시험'} 대비 1:1 — 인천과외`;
    const desc = `${a}(${n}) ${sub}과외. 인천 ${gu} ${a} 학생의 ${sub} ${examWord}·수행평가·서술형을 방문수업·화상수업으로 1:1 준비합니다.`;
    /* 이 구를 방문하는 선생님 먼저, 그다음 화상 — 학교마다 다른 사람이 보이게 시작 위치를 민다 */
    const pool = TEACH.filter(t => !t.k && (t.s || []).includes(sub) && covers(t.gr, lv));
    const local = pool.filter(t => t.c !== '화상' && String(t.r || '').includes('인천') && String(t.r || '').includes(gu));
    const online = pool.filter(t => t.c !== '방문');
    let h = 0; for (const ch of file) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
    const rot = online.length ? online.slice(h % online.length).concat(online.slice(0, h % online.length)) : [];
    const seen = new Set(); const show = local.slice(0, 2).concat(rot).filter(t => !seen.has(t.i) && seen.add(t.i)).slice(0, 4);
    const faq = [...K.faq,
      [`${a} 학생만 신청할 수 있나요?`, `아닙니다. 이 페이지는 ${n} 학생이 찾기 쉽게 만든 안내이고, 인천 ${gu}의 다른 학교 학생도 같은 방식으로 수업합니다.`],
      ['방문수업과 화상수업 중 무엇이 맞나요?', '집중이 어려운 학생이나 저학년은 방문수업이, 이동 시간을 줄이고 선생님 선택 폭을 넓히고 싶으면 화상수업이 맞습니다. 방문 가능 여부는 동네와 시간대에 따라 달라 상담 때 확인해 드립니다.'],
      ['상담은 무료인가요?', '네. 학년과 과목, 지금 어려운 부분을 알려 주시면 맞는 선생님과 수업 방식을 함께 골라 드립니다.']];
    const ld = { '@context': 'https://schema.org', '@graph': [
      { '@type': 'BreadcrumbList', itemListElement: [
        { '@type': 'ListItem', position: 1, name: '인천과외', item: SITE + '/' },
        { '@type': 'ListItem', position: 2, name: '학교별 과외', item: SITE + '/schools.html' },
        { '@type': 'ListItem', position: 3, name: `${a} 과외`, item: `${SITE}/school/${enc(n)}.html` },
        { '@type': 'ListItem', position: 4, name: `${a} ${sub}과외`, item: url }] },
      { '@type': 'FAQPage', mainEntity: faq.map(([q, x]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: x } })) }] };
    const head = tpl.slice(0, headEnd)
      .replace(/<title>[\s\S]*?<\/title>/, () => `<title>${esc(title)}</title>`)
      .replace(/(<meta name="description" content=")[^"]*/, (m, p) => p + esc(desc))
      .replace(/(<link rel="canonical" href=")[^"]*/, (m, p) => p + url)
      .replace(/(<meta property="og:title" content=")[^"]*/, (m, p) => p + esc(title))
      .replace(/(<meta property="og:description" content=")[^"]*/, (m, p) => p + esc(desc))
      .replace(/(<meta property="og:url" content=")[^"]*/, (m, p) => p + url)
      .replace(/<script type="application\/ld\+json">[\s\S]*?<\/script>/, () => `<script type="application/ld+json">${JSON.stringify(ld)}</script>`);
    const kw = [`${a} ${sub}과외`, `${n} ${sub}과외`, `${a} ${sub} 내신`, `${a} ${sub} 시험대비`, `인천 ${gu} ${sub}과외`, `${a} 과외`];
    const others = subjectsFor(lv).filter(x => x !== sub).map(x => `          <a href="${enc(`${a}-${x}과외`)}.html">${esc(a)} ${x}과외</a>`).join('\n');
    const teacherHtml = show.length ? `
<section style="background:var(--bg-soft)">
  <div class="wrap">
    <h2 class="sec-title" style="text-align:center">${esc(a)} ${sub}과외 선생님</h2>
    <p class="sec-desc" style="text-align:center">${LEVEL[lv]} ${josa(sub, '을', '를')} 가르치는 선생님 가운데 일부입니다. 전체는 <a href="../teachers.html" style="color:#B96A48;text-decoration:underline">선생님 찾기</a>에서 과목·학년으로 골라 보실 수 있습니다.</p>
    <div class="t-grid" style="margin-top:22px">
${show.map(t => { const w = t.c === '화상' ? 'online' : 'visit'; return `        <a class="t-card w-${w}" href="../t/${t.i}.html">
          <span class="t-badge w-${w}">${esc(t.c)}과외</span>
          <p class="t-tag">${esc(t.tag || (t.s || []).join('·'))}</p>
          <p class="t-name"><b>${esc(t.n)}</b> 선생님</p>
          <p class="t-where">📚 ${esc((t.s || []).join('·'))} · ${esc((t.gr || []).join(', '))}</p>
        </a>`; }).join('\n')}
    </div>
  </div>
</section>
` : '';
    const body = `<section class="cd-hero">
  <div class="wrap">
    <p class="sc-crumb"><a href="../index.html">인천과외</a> › <a href="../schools.html">학교별 과외</a> › <a href="${enc(n)}.html">${esc(a)}</a> › ${sub}</p>
    <p class="eyebrow">인천 ${esc(gu)} · ${esc(n)}</p>
    <h1>${esc(a)} ${sub}과외<br><em>${sub} ${examWord} 1:1 준비</em></h1>
    <p class="cd-lead">${esc(K.lead[lv](a))}</p>
    <div class="sc-kw">${kw.map(k => `<span>${esc(k)}</span>`).join('')}</div>
  </div>
</section>

<section style="padding-top:10px">
  <div class="wrap">
    <div class="cd-box">
      <h2>${esc(a)} ${sub}, 학년별로 이렇게 봅니다</h2>
      <ul class="bl-list" style="margin:6px 0 0">
${K.grades[lv].map(([g, t]) => `          <li><b>${g}</b> — ${esc(t)}</li>`).join('\n')}
      </ul>
    </div>
  </div>
</section>

<section style="background:var(--bg-soft)">
  <div class="wrap">
    <div class="cd-box">
      <h2>${esc(a)} ${sub} ${isElem ? '단원평가 준비' : '내신 대비'}</h2>
      <p class="cd-note">${isElem ? `초등 ${josa(sub, '은', '는')} 점수보다 이해와 습관이 중요합니다. 단원이 끝날 때마다 아래 순서로 점검합니다.` : `${esc(a)} ${sub} 시험은 학교 수업에서 다룬 내용이 중심입니다. 시험 범위와 출제 방식은 학교와 학년마다 달라, 첫 수업에서 지난 시험지와 교과서·프린트를 함께 보고 계획을 세웁니다.`}</p>
      <ul class="bl-list" style="margin:6px 0 0">
${K.exam.map(x => { const [p, q] = x.split(' — '); return `          <li><b>${esc(p)}</b>${q ? ' — ' + esc(q) : ''}</li>`; }).join('\n')}
      </ul>
    </div>
  </div>
</section>

<section>
  <div class="wrap">
    <div class="cd-box">
      <h2>${esc(a)} ${sub} 수행평가·서술형</h2>
      <p class="cd-note">${esc(K.perf)}</p>
      <h2 style="margin-top:26px">학원 대신 ${sub} 1:1 과외를 고르는 이유</h2>
      <p class="cd-note" style="margin-bottom:0">${esc(K.why)}</p>
    </div>
  </div>
</section>
${teacherHtml}
<section>
  <div class="wrap">
    <div class="cd-box">
      <h2>자주 묻는 질문</h2>
${faq.map(([q, x]) => `      <p style="margin:14px 0 4px"><b>${esc(q)}</b></p>\n      <p class="cd-note" style="margin:0">${esc(x)}</p>`).join('\n')}
    </div>
  </div>
</section>

<section style="background:var(--bg-soft)">
  <div class="wrap" style="text-align:center">
    <h2 class="sec-title">${esc(a)} 다른 과목도 함께 준비하세요</h2>
    <div class="cd-near">
${others}
          <a href="${enc(n)}.html">${esc(a)} 과외 전체 안내</a>
    </div>
  </div>
</section>

<section id="contact">
  <div class="wrap" style="text-align:center;padding:70px 0">
    <h2 class="sec-title">${esc(a)} ${sub}과외, 무료 상담부터</h2>
    <p class="sec-desc">학년과 지금 막힌 부분을 알려주시면 ${esc(a)} 학생에게 맞는 ${sub} 선생님과 수업 방식을 함께 골라 드립니다.</p>
    <a href="../index.html#contact" class="btn btn-main" style="margin-top:26px;padding:16px 44px">무료 상담 신청하기</a>
  </div>
</section>
`;
    fs.writeFileSync(path.join(ROOT, 'school', file + '.html'), head + body + tpl.slice(footStart), 'utf8');
    made++;
  }
}
console.log('과목 페이지 ' + made + '개 생성 → school/');
