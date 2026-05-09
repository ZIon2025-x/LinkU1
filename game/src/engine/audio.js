// Web Audio synthesizer — no external assets.
class AudioEngine {
  constructor() {
    this.ctx = null;
    this.muted = false;
    this.ambientNodes = [];
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
  startRain(intensity = 0.3) {
    if (!this.ctx || this.muted) return;
    this.stopAmbient();
    const buf = this.ctx.createBuffer(1, this.ctx.sampleRate * 2, this.ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * 0.5;
    const s = this.ctx.createBufferSource(); s.buffer = buf; s.loop = true;
    const f = this.ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 1200;
    const g = this.ctx.createGain(); g.gain.value = intensity * 0.12;
    s.connect(f); f.connect(g); g.connect(this.ctx.destination); s.start();
    this.ambientNodes = [s, f, g];
  }
  startQuiet() {
    if (!this.ctx || this.muted) return;
    this.stopAmbient();
    const o = this.ctx.createOscillator(); o.frequency.value = 60; o.type = 'sine';
    const g = this.ctx.createGain(); g.gain.value = 0.012;
    o.connect(g); g.connect(this.ctx.destination); o.start();
    this.ambientNodes = [o, g];
  }
  stopAmbient() {
    this.ambientNodes.forEach(n => {
      try { if (n.stop) n.stop(); n.disconnect && n.disconnect(); } catch (e) { /* ignore */ }
    });
    this.ambientNodes = [];
  }
}

export const audio = new AudioEngine();
