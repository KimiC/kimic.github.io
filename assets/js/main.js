/* ==========================================================================
   Kimi Chen — 个人主页交互
   纯原生 JS，无依赖。功能：主题切换 / 滚动入场 / 导航高亮 / 阅读进度 / 年份
   ========================================================================== */
(function () {
  'use strict';

  var doc = document;
  var root = doc.documentElement;

  /* ---------- 1. 主题切换 ---------- */
  var themeToggle = doc.getElementById('themeToggle');

  function currentTheme() {
    return root.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
  }

  function setTheme(theme, persist) {
    root.setAttribute('data-theme', theme);
    var meta = doc.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', theme === 'dark' ? '#0b0b0b' : '#fafafa');
    if (persist) {
      try { localStorage.setItem('theme', theme); } catch (e) {}
    }
  }

  setTheme(currentTheme(), false);

  if (themeToggle) {
    themeToggle.addEventListener('click', function () {
      setTheme(currentTheme() === 'dark' ? 'light' : 'dark', true);
    });
  }

  /* 用户没手动选择过时，跟随系统主题变化 */
  var media = window.matchMedia('(prefers-color-scheme: dark)');
  var onSystemChange = function (e) {
    var saved = null;
    try { saved = localStorage.getItem('theme'); } catch (err) {}
    if (!saved) setTheme(e.matches ? 'dark' : 'light', false);
  };
  if (media.addEventListener) media.addEventListener('change', onSystemChange);
  else if (media.addListener) media.addListener(onSystemChange);

  /* ---------- 2. 滚动入场动画 ---------- */
  var revealEls = Array.prototype.slice.call(doc.querySelectorAll('.reveal'));

  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-visible');
        io.unobserve(entry.target);
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -8% 0px' });

    revealEls.forEach(function (el, i) {
      el.style.transitionDelay = Math.min(i % 6, 5) * 70 + 'ms';
      io.observe(el);
    });
  } else {
    revealEls.forEach(function (el) { el.classList.add('is-visible'); });
  }

  /* Hero 区域的首次入场 */
  var hero = doc.querySelector('.hero');
  if (hero) {
    window.requestAnimationFrame(function () {
      window.requestAnimationFrame(function () { hero.classList.add('is-ready'); });
    });
  }

  /* ---------- 3. 页头状态 / 阅读进度 / 导航高亮 ---------- */
  var header = doc.getElementById('siteHeader');
  var progress = doc.getElementById('scrollProgress');
  var navLinks = Array.prototype.slice.call(doc.querySelectorAll('.nav a'));
  var sections = navLinks
    .map(function (a) { return doc.querySelector(a.getAttribute('href')); })
    .filter(Boolean);

  var ticking = false;

  function onScroll() {
    var y = window.scrollY || doc.documentElement.scrollTop;

    if (header) header.classList.toggle('is-scrolled', y > 8);

    if (progress) {
      var max = doc.documentElement.scrollHeight - window.innerHeight;
      progress.style.width = (max > 0 ? Math.min(y / max, 1) * 100 : 0) + '%';
    }

    var activeId = null;
    sections.forEach(function (sec) {
      if (sec.getBoundingClientRect().top <= window.innerHeight * 0.34) activeId = sec.id;
    });
    navLinks.forEach(function (a) {
      a.classList.toggle('is-active', a.getAttribute('href') === '#' + activeId);
    });

    ticking = false;
  }

  window.addEventListener('scroll', function () {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(onScroll);
  }, { passive: true });

  window.addEventListener('resize', onScroll, { passive: true });
  onScroll();

  /* ---------- 4. 页脚年份 ---------- */
  var yearEl = doc.getElementById('year');
  if (yearEl) yearEl.textContent = String(new Date().getFullYear());
})();
