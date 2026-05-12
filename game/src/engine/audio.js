// Audio engine.
//
// SFX (click/ding/warning/success/fail/message) 用 Web Audio 合成 — 这些短音效
// 用 oscillator + gain 完美胜任。
//
// AMBIENT (背景氛围) 用真实音频文件 (assets/audio/ambient-*.{mp3,wav,flac,ogg})
// 通过 HTMLAudioElement 播放。procedural 合成无法做出可信的"中餐馆 sizzle"
// 等场景声 — 只能合成抽象电子音 — 所以 ambient 一律走文件。
//
// 每地点 gain 独立可调（见底部 LOCATION_AMBIENT_GAIN_MAP），用户反馈
// "library 太轻 / pub 太吵" 后改这张表即可，不动其它代码。
import { AMBIENT_URLS } from './audioRegistry.js';

// 总开关 —— 把整体 ambient 压到 SFX 之下。SFX 用 0.04-0.07 gain，
// MASTER * per-location 的最终值不要超过 0.7 否则盖过 click/message
const MASTER_AMBIENT_GAIN = 0.45;

// 每地点的相对增益。1.0 = MASTER 原样。用户反馈某 ambient 太吵就调低。
// 例：用户说 "pub 太吵" → pub: 0.5 ；"library 听不到" → library: 1.5
const LOCATION_AMBIENT_GAIN_MAP = {
  library: 1.0,
  mei:     1.0,
  pub:     1.0,
  park:    1.0,
  soho:    1.0,
  tesco:   1.0,
  station: 1.0,
  tate:    1.0,
  uni:     1.0,
  flat:    1.0,
  rain:    0.6,  // 雨声经验上要压一档别盖过对话
};

class AudioEngine {
  constructor() {
    this.ctx = null;
    this.muted = false;
    this.ambientNodes = [];
    this._currentAmbientId = null;
    // 缓存已创建的 HTMLAudioElement —— 避免切回同一地点时重新下载
    this._ambientCache = {};
  }
  init() {
    if (this.ctx) return;
    try {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    } catch (e) { /* unavailable */ }
  }
  setMuted(m) { this.muted = m; if (m) this.stopAmbient(); }
  click() {
    if (!this.ctx || this.muted) return;
    const o = this.ctx.createOscillator(), g = this.ctx.createGain();
    o.frequency.value = 800; o.type = 'sine';
    g.gain.setValueAtTime(0.04, this.ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.04);
    o.connect(g); g.connect(this.ctx.destination); o.start(); o.stop(this.ctx.currentTime + 0.04);
  }
  ding() {
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;
    [880, 1320].forEach((f, i) => {
      const o = this.ctx.createOscillator(), g = this.ctx.createGain();
      o.frequency.value = f; o.type = 'sine';
      g.gain.setValueAtTime(0.05, t + i * 0.08);
      g.gain.exponentialRampToValueAtTime(0.001, t + i * 0.08 + 0.15);
      o.connect(g); g.connect(this.ctx.destination); o.start(t + i * 0.08); o.stop(t + i * 0.08 + 0.15);
    });
  }
  warning() {
    if (!this.ctx || this.muted) return;
    const o = this.ctx.createOscillator(), g = this.ctx.createGain();
    o.frequency.setValueAtTime(440, this.ctx.currentTime);
    o.frequency.setValueAtTime(330, this.ctx.currentTime + 0.15);
    o.type = 'square';
    g.gain.setValueAtTime(0.04, this.ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.4);
    o.connect(g); g.connect(this.ctx.destination); o.start(); o.stop(this.ctx.currentTime + 0.4);
  }
  success() {
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;
    [523, 659, 784].forEach((f, i) => {
      const o = this.ctx.createOscillator(), g = this.ctx.createGain();
      o.frequency.value = f; o.type = 'triangle';
      g.gain.setValueAtTime(0.05, t + i * 0.08);
      g.gain.exponentialRampToValueAtTime(0.001, t + i * 0.08 + 0.2);
      o.connect(g); g.connect(this.ctx.destination); o.start(t + i * 0.08); o.stop(t + i * 0.08 + 0.2);
    });
  }
  fail() {
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;
    [392, 311].forEach((f, i) => {
      const o = this.ctx.createOscillator(), g = this.ctx.createGain();
      o.frequency.value = f; o.type = 'triangle';
      g.gain.setValueAtTime(0.05, t + i * 0.12);
      g.gain.exponentialRampToValueAtTime(0.001, t + i * 0.12 + 0.25);
      o.connect(g); g.connect(this.ctx.destination); o.start(t + i * 0.12); o.stop(t + i * 0.12 + 0.25);
    });
  }
  message() {
    if (!this.ctx || this.muted) return;
    const o = this.ctx.createOscillator(), g = this.ctx.createGain();
    o.frequency.value = 1200; o.type = 'sine';
    g.gain.setValueAtTime(0.04, this.ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.1);
    o.connect(g); g.connect(this.ctx.destination); o.start(); o.stop(this.ctx.currentTime + 0.1);
  }
  // ────────────────────────────────────────────────────────
  // Ambient · 走文件，每个 location 独立 gain
  // ────────────────────────────────────────────────────────
  _playFileAmbient(ambientId) {
    if (this._currentAmbientId === ambientId) {
      // 同一个 ambient 已经在播 —— 不打断 + 不重 fetch
      return;
    }
    this.stopAmbient();
    const url = AMBIENT_URLS[ambientId];
    if (!url) {
      this.startQuiet();
      return;
    }
    // 用缓存：第一次创建时才 new Audio()，之后切回直接复用
    let el = this._ambientCache[ambientId];
    if (!el) {
      el = new Audio(url);
      el.loop = true;
      el.preload = 'auto';
      this._ambientCache[ambientId] = el;
    }
    const perLoc = LOCATION_AMBIENT_GAIN_MAP[ambientId] ?? 1.0;
    el.volume = Math.max(0, Math.min(1, MASTER_AMBIENT_GAIN * perLoc));
    el.play().catch(() => { /* autoplay block — 下次 click 后会过 */ });
    this._currentAmbientId = ambientId;
    this.ambientNodes.push({
      _isHtmlAudio: true,
      stop: () => { try { el.pause(); } catch (e) {} },
      // 不调 disconnect / 不清 src —— 留 cache 给下次复用
      disconnect: () => {},
    });
  }

  // 单纯的低频 sine drone — 仅在没有对应音频文件时 fallback 用
  startQuiet() {
    if (!this.ctx || this.muted) return;
    this.stopAmbient();
    const o = this.ctx.createOscillator(); o.frequency.value = 60; o.type = 'sine';
    const g = this.ctx.createGain(); g.gain.value = 0.012;
    o.connect(g); g.connect(this.ctx.destination); o.start();
    this.ambientNodes.push(o, g);
    this._currentAmbientId = '_quiet';
  }

  // 雨声 — 走文件版（assets/audio/ambient-rain.wav）
  startRain(_intensity) {
    this._playFileAmbient('rain');
  }

  // 入口：按 location id 切 ambient (走文件)
  playLocationAmbient(locId) {
    if (this.muted) return;
    this._playFileAmbient(locId || 'flat');
  }

  stopAmbient() {
    this.ambientNodes.forEach(n => {
      try { if (n.stop) n.stop(); n.disconnect && n.disconnect(); } catch (e) { /* ignore */ }
    });
    this.ambientNodes = [];
    this._currentAmbientId = null;
  }
}

export const audio = new AudioEngine();
