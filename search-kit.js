/* ============================================================
   search-kit.js — 사이트 공용 검색 부품  (v1, 2026-09-08)

   하는 일 두 가지
     1) 띄어쓰기를 무시하고 찾기   "부산동래구" = "부산 동래구"
     2) 검색 결과 아래 연관 검색어 칩 띄우기

   ※ 이 파일은 여러 저장소에 같은 내용으로 복사돼 있습니다.
      고칠 때는 사이트관리/사이트대장.md 의 "공용 검색 부품" 절을 보고
      쓰는 사이트를 전부 같이 갱신하세요. 한 곳만 고치면 갈라집니다.

   쓰는 법 (요약)
     var hay = SearchKit.indexer(function(r){return r.i}, function(r){return r.n+' '+r.addr});
     if(!SearchKit.match(hay(row), 검색어)) return false;                 // 1번 기능
     SearchKit.chips(엘리먼트, SearchKit.related(결과배열, 검색어, [필드]), 콜백);  // 2번 기능
   ============================================================ */
(function (w, d) {
  'use strict';

  /* ---------- 1. 글자 다듬기 ---------- */

  /* 소문자 + 학교 정식명칭을 약칭으로 통일 + 공백 하나로 */
  function norm(s) {
    return String(s == null ? '' : s).toLowerCase()
      .replace(/여자중학교/g, '여중').replace(/여자고등학교/g, '여고').replace(/여자초등학교/g, '여초')
      .replace(/초등학교/g, '초').replace(/중학교/g, '중').replace(/고등학교/g, '고')
      .replace(/\s+/g, ' ').trim();
  }

  /* 공백까지 전부 없앤 형태 */
  function nospace(s) { return norm(s).replace(/ /g, ''); }

  /* 검색 대상 문자열 한 벌 → { s: 공백 있는 것, ns: 공백 없앤 것 } */
  function hay(str) {
    var s = norm(str);
    return { s: s, ns: s.replace(/ /g, '') };
  }

  /* ---------- 2. 매칭 ---------- */

  /* 검색어의 낱말이 전부 들어 있으면 통과.
     낱말 하나하나를 "공백 있는 원문" 또는 "공백 없앤 원문" 어느 쪽에서든 찾는다.
       "분당 불곡중"  → 낱말 2개가 원문에 다 있음            ✔
       "분당불곡중"   → 낱말 1개가 공백 없앤 원문에 있음      ✔
       "부산동래구"   → 데이터가 "부산 동래구" 여도 잡힘      ✔ */
  function match(h, q) {
    if (!q) return true;
    var nq = norm(q);
    if (!nq) return true;
    return nq.split(' ').filter(Boolean).every(function (t) {
      if (h.s.indexOf(t) >= 0 || h.ns.indexOf(t) >= 0) return true;
      /* 그래도 없으면, 붙여 친 낱말을 쪼개서 다시 찾는다.
         "분당불곡중" → "분당" + "불곡중" 처럼 데이터에서 떨어져 있어도 잡히게. */
      return t.length >= 4 && splitOk(h, t, 3);
    });
  }

  /* 붙여 친 말 s 를 최대 parts 조각까지 쪼개, 조각이 전부 들어 있으면 통과.
     조각은 2글자 이상만 인정한다(한 글자는 아무 데나 걸려서 엉뚱한 결과가 난다). */
  function splitOk(h, s, parts) {
    if (s.length < 2) return false;
    if (h.ns.indexOf(s) >= 0) return true;
    if (parts <= 1) return false;
    var max = Math.min(s.length - 2, 8);
    for (var i = 2; i <= max; i++) {
      if (h.ns.indexOf(s.slice(0, i)) >= 0 && splitOk(h, s.slice(i), parts - 1)) return true;
    }
    return false;
  }

  /* 레코드마다 검색 문자열을 만들어 캐시해 두는 도우미.
     keyFn(r) = 레코드 고유값, textFn(r) = 검색 대상 문자열
     검색 색인이 늦게 도착하는 사이트는 도착 후 .clear() 를 부르면 된다. */
  function indexer(keyFn, textFn) {
    var cache = new Map();
    function get(r) {
      var k = keyFn(r), h = cache.get(k);
      if (!h) { h = hay(textFn(r)); cache.set(k, h); }
      return h;
    }
    get.clear = function () { cache.clear(); };
    return get;
  }

  /* ---------- 3. 연관 검색어 ---------- */

  /* 값 하나를 쪼갠다: 배열이면 그대로, 문자열이면 구분자로 자른다 */
  function values(v) {
    if (v == null) return [];
    if (Array.isArray(v)) return v;
    return String(v).split(/[|,·/]/);
  }

  /* 결과 목록에서 자주 나오는 낱말을 뽑아 연관 검색어를 만든다.
       rows   = 지금 화면에 걸린 결과 배열
       q      = 지금 검색어 (빈 값이면 "많이 찾는" 목록이 된다)
       fields = 뽑아낼 필드. 문자열('region') 또는 함수(r=>r.a+' '+r.b)
       opt.limit = 최대 개수(기본 6), opt.minLen/maxLen = 낱말 길이 제한
     반환값은 { term: 검색창에 넣을 말, label: 화면에 보일 말 } 배열 */
  function related(rows, q, fields, opt) {
    opt = opt || {};
    var limit = opt.limit || 6;
    var minLen = opt.minLen || 2, maxLen = opt.maxLen || 12;
    var nq = norm(q), qToks = nq.split(' ').filter(Boolean);

    var count = Object.create(null);   /* 낱말 → 몇 건에 나오나 */
    var keep  = Object.create(null);   /* 낱말 → 화면에 쓸 표기 */
    var owner = Object.create(null);   /* 낱말 → 어느 갈래(필드)에서 왔나 */
    var inField = fields.map(function () { return Object.create(null); });

    rows.forEach(function (r) {
      fields.forEach(function (f, fi) {
        var seen = Object.create(null);
        values(typeof f === 'function' ? f(r) : r[f]).forEach(function (raw) {
          var v = String(raw).trim();
          if (v.length < minLen || v.length > maxLen) return;
          var nv = norm(v);
          if (!nv) return;
          inField[fi][nv.replace(/ /g, '')] = 1;
          if (seen[nv]) return;                 /* 한 건 안에서 중복은 1로 */
          seen[nv] = 1;
          count[nv] = (count[nv] || 0) + 1;
          if (!keep[nv]) { keep[nv] = v; owner[nv] = fi; }
        });
      });
    });

    var total = rows.length;

    /* 갈래별 낱말 목록 (긴 것부터 — "부산 동래구"를 "부산"보다 먼저 떼어내려고) */
    var fieldWords = inField.map(function (m) {
      return Object.keys(m).filter(function (v) { return v.length >= 2; })
        .sort(function (a, b) { return b.length - a.length; });
    });

    /* 아는 낱말 전체 (붙여 친 검색어를 쪼개는 데 쓴다) */
    var allWords = [];
    fieldWords.forEach(function (ws) { allWords = allWords.concat(ws); });
    allWords = allWords.filter(function (v, i, a) { return a.indexOf(v) === i; })
      .sort(function (a, b) { return b.length - a.length; });

    /* 붙여 친 낱말을 아는 낱말 기준으로 쪼갠다. "분당불곡중" → ["분당","불곡중"] */
    function pieces(t, depth) {
      var s = t.replace(/ /g, '');
      if (depth <= 0 || s.length < 4) return [s];
      for (var j = 0; j < allWords.length; j++) {
        var v = allWords[j];
        if (v.length >= s.length) continue;
        var at = s.indexOf(v);
        if (at < 0) continue;
        var head = s.slice(0, at), tail = s.slice(at + v.length);
        return (head ? pieces(head, depth - 1) : []).concat([v], tail ? pieces(tail, depth - 1) : []);
      }
      return [s];
    }
    var qParts = [];
    qToks.forEach(function (t) { qParts = qParts.concat(pieces(t, 2)); });
    qToks = qParts;
    var qNs = qToks.map(function (t) { return t.replace(/ /g, ''); });

    /* 연관어 후보 고르기 — 검색어를 쪼갠 뒤라야 "부산동래구"에서 "부산"이 걸러진다 */
    var cands = Object.keys(count).filter(function (nv) {
      var nvNs = nv.replace(/ /g, '');
      /* 이미 검색어에 있는 말은 뺀다 (띄어쓰기 무시하고 비교) */
      for (var i = 0; i < qNs.length; i++) {
        if (nvNs.indexOf(qNs[i]) >= 0 || qNs[i].indexOf(nvNs) >= 0) return false;
      }
      /* 결과 전부가 가진 값은 더 좁혀 주지 못하므로 뺀다 */
      if (total >= 3 && count[nv] === total) return false;
      return true;
    }).sort(function (a, b) { return count[b] - count[a] || a.length - b.length; });

    /* 검색어에서 같은 갈래의 말을 떼어낸다.
       "분당 수학" + 영어 → "분당 수학 영어"(어색)가 아니라 "분당 영어"
       "목동영어"  + 국어 → 붙여 친 말에서도 "영어"를 떼어 "목동 국어" */
    function reshape(fi) {
      var words = fieldWords[fi], stripped = false, toks = [];
      qToks.forEach(function (t) {
        var tns = t.replace(/ /g, '');
        if (inField[fi][tns]) { stripped = true; return; }   /* 낱말 통째가 같은 갈래 */
        for (var j = 0; j < words.length; j++) {
          var v = words[j];
          if (tns.length > v.length && tns.indexOf(v) >= 0) {
            tns = tns.replace(v, ''); stripped = true; break;
          }
        }
        if (tns) toks.push(tns === t.replace(/ /g, '') ? t : tns);
      });
      return { toks: toks, stripped: stripped };
    }

    var out = [], used = Object.create(null);
    for (var i = 0; i < cands.length && out.length < limit; i++) {
      var nv = cands[i], fi = owner[nv];
      var rs = reshape(fi), toks = rs.toks;
      /* 결과가 한두 건뿐이면 더 좁혀 봐야 소용없다 → 마지막 낱말을 바꿔 다른 선택지를 준다 */
      if (!rs.stripped && total <= 2 && toks.length >= 2) toks = toks.slice(0, -1);
      toks = toks.concat([keep[nv]]);
      var term = toks.join(' ').trim();
      var k = norm(term);
      if (!k || k === nq || used[k]) continue;
      used[k] = 1;
      out.push({ term: term, label: term });
    }
    return out;
  }

  /* 많이 찾는 말 — 검색어 없이 자주 나오는 값만 뽑는다 (마지막 대비책) */
  function popular(rows, fields, opt) { return related(rows, '', fields, opt); }

  /* 결과가 0건일 때 대안을 제안한다.
       all = 전체 데이터, hayFn = 레코드→hay, q = 검색어, fields = 연관어 뽑을 필드 */
  function suggest(all, hayFn, q, fields, opt) {
    opt = opt || {};
    var nq = norm(q);
    var toks = nq.split(' ').filter(Boolean);
    if (!toks.length) return [];

    function hits(r, t) {
      var h = hayFn(r);
      return h.s.indexOf(t) >= 0 || h.ns.indexOf(t) >= 0 || (t.length >= 4 && splitOk(h, t, 3));
    }

    /* ① 낱말 중 하나라도 걸리는 것 */
    var loose = all.filter(function (r) { return toks.some(function (t) { return hits(r, t); }); });
    var base = '';
    if (loose.length) {
      base = toks.filter(function (t) {
        return loose.some(function (r) { return hits(r, t); });
      }).join(' ');
    } else {
      /* ② 그래도 없으면 붙여 친 말을 앞에서부터 잘라 가며 걸리는 조각을 찾는다 */
      var joined = toks.join('');
      for (var len = Math.min(joined.length - 1, 8); len >= 2 && !loose.length; len--) {
        var head = joined.slice(0, len);
        loose = all.filter(function (r) { return hayFn(r).ns.indexOf(head) >= 0; });
        if (loose.length) base = head;
      }
    }

    /* ③ 끝내 없으면 많이 찾는 말이라도 보여 준다 */
    if (!loose.length) return popular(all, fields, opt);

    var out = related(loose, base, fields, opt);
    if (base && norm(base) !== nq) out.unshift({ term: base, label: base });
    return out.slice(0, opt.limit || 6);
  }

  /* ---------- 4. 칩 그리기 ---------- */

  var CSS = '.sk-rel{display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin:14px 0 4px;font-size:.9rem;line-height:1.5}'
    + '.sk-rel[hidden]{display:none}'
    + '.sk-rel-label{font-weight:700;opacity:.6;margin-right:2px;white-space:nowrap}'
    + '.sk-chip{font:inherit;font-size:.92em;cursor:pointer;padding:6px 13px;border-radius:999px;'
    + 'border:1px solid currentColor;background:transparent;color:inherit;opacity:.72;'
    + 'transition:opacity .15s,background-color .15s;-webkit-appearance:none;appearance:none}'
    + '.sk-chip:hover{opacity:1;background:rgba(127,127,127,.12)}'
    + '.sk-chip:focus-visible{outline:2px solid currentColor;outline-offset:2px;opacity:1}'
    + '@media (prefers-reduced-motion:reduce){.sk-chip{transition:none}}';

  var cssDone = false;
  function injectCSS() {
    if (cssDone) return;
    cssDone = true;
    var st = d.createElement('style');
    st.setAttribute('data-search-kit', '1');
    st.textContent = CSS;
    d.head.appendChild(st);
  }

  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  /* 칩을 그린다.
       el    = 담을 요소, items = related()/suggest() 결과
       onPick(term) = 칩을 눌렀을 때 (보통 검색창에 넣고 다시 그리기)
       label = 앞에 붙일 말 (기본 "연관 검색어") */
  function chips(el, items, onPick, label) {
    if (!el) return;
    injectCSS();
    if (!items || !items.length) { el.hidden = true; el.innerHTML = ''; return; }
    el.className = 'sk-rel';
    el.hidden = false;
    el.innerHTML = '<span class="sk-rel-label">' + esc(label || '연관 검색어') + '</span>'
      + items.map(function (it) {
        return '<button type="button" class="sk-chip" data-term="' + esc(it.term) + '">' + esc(it.label) + '</button>';
      }).join('');
    if (!el.__skBound) {
      el.__skBound = true;
      el.addEventListener('click', function (e) {
        var b = e.target.closest('.sk-chip');
        if (b && typeof el.__skPick === 'function') el.__skPick(b.getAttribute('data-term'));
      });
    }
    el.__skPick = onPick;
  }

  w.SearchKit = {
    norm: norm, nospace: nospace, hay: hay, match: match,
    indexer: indexer, related: related, popular: popular, suggest: suggest,
    chips: chips, style: injectCSS, esc: esc
  };
})(window, document);
