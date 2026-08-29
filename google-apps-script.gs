/* =========================================================================
   구글 "웹 문의" 시트 공용 Apps Script — 사이트별 탭 저장 (참고용 사본)
   -------------------------------------------------------------------------
   과외(perfectedu)·키즈튜터·픽포스·데일리카네기·공부의온도 폼이 모두 이 웹앱 하나로 보냅니다.
   폼이 sheet=탭이름 을 함께 보내면 해당 탭에, 없거나 허용 목록에 없으면 기본 탭("과외")에 저장.
   키즈튜터 폼(form.js)은 sheet=키즈튜터, _form=키즈튜터-무료체험신청 등을 보냅니다.

   ▶ 수정 반영 방법 (URL 유지)
   Apps Script 편집기에서 코드 교체 → 저장 → [배포] → [배포 관리]
   → 기존 배포 연필(수정) → 버전: 새 버전 → [배포]
   ========================================================================= */

var SHEET_ID   = "1UUS6le8gJTsuvaSDi31ZzuQjA214YD32xJFVgYx9cno";
var SHEET_NAME = "과외"; // sheet 값이 없거나 허용 목록에 없을 때 기본 탭

// 사이트별 탭 (새 사이트 추가 시 여기에 한 줄 추가)
var ALLOWED_TABS = {
  "과외": true,         // 티칭코칭(perfectedu)
  "견적": true,         // 픽포스
  "데일리카네기": true, // 데일리카네기 입학 상담
  "키즈튜터": true,     // 키즈튜터(kidstutor.co.kr) 무료 체험·상담
  "공부의온도": true    // 공부의 온도(firststudy.co.kr) 무료 상담 신청
};

function doPost(e) {
  try {
    var ss = SpreadsheetApp.openById(SHEET_ID);
    var p  = (e && e.parameter) ? e.parameter : {};
    var tab = (p.sheet && ALLOWED_TABS[p.sheet]) ? p.sheet : SHEET_NAME;
    var sh = ss.getSheetByName(tab) || ss.insertSheet(tab);
    var when = p._time || new Date().toLocaleString("ko-KR");
    var kind = p._form || "";
    var headers;
    if (sh.getLastRow() === 0) {
      headers = ["접수시각", "구분"];
      for (var k in p) { if (k.charAt(0) === "_" || k === "sheet") continue; headers.push(k); }
      sh.appendRow(headers);
    } else {
      headers = sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0];
      for (var k2 in p) {
        if (k2.charAt(0) === "_" || k2 === "sheet") continue;
        if (headers.indexOf(k2) === -1) { headers.push(k2); sh.getRange(1, headers.length).setValue(k2); }
      }
    }
    var row = [];
    for (var i = 0; i < headers.length; i++) {
      var h = headers[i];
      row.push(h === "접수시각" ? when : h === "구분" ? kind : (p[h] != null ? p[h] : ""));
    }
    sh.appendRow(row);
    return ContentService.createTextOutput("ok");
  } catch (err) {
    return ContentService.createTextOutput("error: " + err);
  }
}
