// Petits utilitaires d'interface
const U = (() => {
  function el(tag, attrs = {}, ...kids) {
    const n = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v == null || v === false) continue;
      if (k === 'class') n.className = v;
      else if (k === 'html') n.innerHTML = v;
      else if (k.startsWith('on') && typeof v === 'function') n.addEventListener(k.slice(2), v);
      else if (k === 'style' && typeof v === 'object') Object.assign(n.style, v);
      else n.setAttribute(k, v === true ? '' : v);
    }
    for (const k of kids.flat(Infinity)) {
      if (k == null || k === false) continue;
      n.appendChild(typeof k === 'string' || typeof k === 'number' ? document.createTextNode(String(k)) : k);
    }
    return n;
  }
  const SVGNS = 'http://www.w3.org/2000/svg';
  function svg(tag, attrs = {}, ...kids) {
    const n = document.createElementNS(SVGNS, tag);
    for (const [k, v] of Object.entries(attrs || {})) if (v != null) n.setAttribute(k, v);
    for (const k of kids.flat(Infinity)) {
      if (k == null || k === false) continue;
      n.appendChild(typeof k === 'string' || typeof k === 'number' ? document.createTextNode(String(k)) : k);
    }
    return n;
  }
  function clear(n) { while (n.firstChild) n.removeChild(n.firstChild); return n; }
  function esc(s) { return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]); }

  function toast(msg, kind = 'info') {
    const t = el('div', { class: `toast toast-${kind}` }, msg);
    document.body.appendChild(t);
    setTimeout(() => t.classList.add('show'), 10);
    setTimeout(() => { t.classList.remove('show'); setTimeout(() => t.remove(), 300); }, 2600);
  }

  // Fenêtre modale. content : Node. buttons : [{label, value, primary}]
  function modal(title, content, buttons = [{ label: 'Fermer', value: null }]) {
    return new Promise((resolve) => {
      const close = (v) => { back.remove(); resolve(v); };
      const box = el('div', { class: 'modal', role: 'dialog', 'aria-modal': 'true' },
        el('div', { class: 'modal-head' }, el('h3', {}, title),
          el('button', { class: 'icon-btn', 'aria-label': 'Fermer', onclick: () => close(null) }, '✕')),
        el('div', { class: 'modal-body' }, content),
        el('div', { class: 'modal-foot' }, buttons.map((b) =>
          el('button', { class: b.primary ? 'btn primary' : 'btn', onclick: () => close(typeof b.value === 'function' ? b.value() : b.value) }, b.label))));
      const back = el('div', { class: 'modal-back', onclick: (e) => { if (e.target === back) close(null); } }, box);
      document.body.appendChild(back);
      const first = box.querySelector('input,select,textarea');
      if (first) setTimeout(() => first.focus(), 50);
    });
  }

  function store(key, val) {
    try { localStorage.setItem('gll.' + key, JSON.stringify(val)); } catch (e) { /* stockage indisponible */ }
  }
  function load(key, def) {
    try { const v = localStorage.getItem('gll.' + key); return v == null ? def : JSON.parse(v); } catch (e) { return def; }
  }
  const clone = (o) => JSON.parse(JSON.stringify(o));

  // Durées : "3s", "500ms", "1.5 s", "2min" → ms
  function parseDuration(s) {
    const m = /^\s*(\d+(?:[.,]\d+)?)\s*(ms|s|min)?\s*$/i.exec(String(s ?? ''));
    if (!m) return null;
    const v = parseFloat(m[1].replace(',', '.'));
    const u = (m[2] || 's').toLowerCase();
    return Math.round(u === 'ms' ? v : u === 'min' ? v * 60000 : v * 1000);
  }
  function fmtDuration(ms) {
    if (ms == null) return '';
    if (ms >= 60000 && ms % 60000 === 0) return ms / 60000 + 'min';
    if (ms >= 1000) return (ms / 1000).toString().replace('.', ',') + 's';
    return ms + 'ms';
  }

  return { el, svg, clear, esc, toast, modal, store, load, clone, parseDuration, fmtDuration };
})();
