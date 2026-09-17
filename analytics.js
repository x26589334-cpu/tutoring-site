// Google Analytics 4 (GA4) — 전 페이지 공용. 측정 ID 를 바꿀 땐 이 파일만 고친다.
(function () {
  var GA_ID = 'G-LE1CVC83WT';
  var s = document.createElement('script');
  s.async = true;
  s.src = 'https://www.googletagmanager.com/gtag/js?id=' + GA_ID;
  document.head.appendChild(s);
  window.dataLayer = window.dataLayer || [];
  function gtag(){ dataLayer.push(arguments); }
  window.gtag = gtag;
  gtag('js', new Date());
  gtag('config', GA_ID);
})();