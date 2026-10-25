const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const html = fs.readFileSync(path.join(__dirname, '../../main/resources/static/proof-session.html'), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const elements = new Map();
function element(id) {
  if (!elements.has(id)) elements.set(id, {
    id, hidden: false, disabled: false, textContent: '', value: '', children: [],
    classList: { contains: () => false },
    append(...items) { this.children.push(...items); },
    replaceChildren(...items) { this.children = items; },
    removeAttribute(name) { delete this[name]; },
    videoWidth: 720, videoHeight: 1280,
    play: async () => {}, getContext: () => ({ drawImage() {} }),
    toDataURL: () => 'data:image/jpeg;base64,approved-image',
  });
  return elements.get(id);
}
const calls = [];
const timeouts = [];
let stopped = 0;
const context = vm.createContext({
  console, Date, Math, Number, String, Error, Promise, Uint8Array, TextEncoder,
  navigator: { mediaDevices: { getUserMedia: async () => ({
    getTracks: () => [{ stop: () => stopped++ }],
  }) } },
  document: { getElementById: element, querySelectorAll: () => [], addEventListener() {} },
  window: { scrollTo() {} },
  localStorage: { getItem: () => null, setItem() {} },
  setInterval() {}, clearTimeout() {},
  setTimeout(fn, ms) { timeouts.push({ fn, ms }); return timeouts.length; },
  fetch: async (url, options) => {
    calls.push({ url, options });
    return { ok: true, json: async () => url.includes('/capture?')
      ? { captureId: 22, token: 'ticket-token' } : { id: 22 } };
  },
});
vm.runInContext(script, context);
const evaluate = code => vm.runInContext(code, context);
const settle = async () => {
  for (let i = 0; i < 10; i++) await new Promise(setImmediate);
  assert.equal(evaluate('photoPromise !== null'), true, 'Camera must be ready for confirmation');
};
const watchdog = setTimeout(() => { console.error('Photo flow did not finish'); process.exit(1); }, 5000);

(async () => {
  evaluate("proof={id:1};memberId=1;currentView='sessionView';notice('بداية موفقة',true)");
  assert.equal(timeouts.at(-1).ms, 4000);
  timeouts.at(-1).fn();
  assert.equal(element('notice').hidden, true);

  const cancelled = evaluate("capture('PHOTO','إثبات النشاط')");
  await settle();
  element('shutter').onclick();
  assert.equal(element('preview').hidden, false);
  assert.equal(calls.length, 0, 'Taking a picture must not upload it');
  element('retake').onclick();
  assert.equal(element('preview').hidden, true);
  assert.equal(calls.length, 0, 'Retaking must not upload');
  element('cancelPhoto').onclick();
  assert.equal(await cancelled, null);
  assert.equal(calls.length, 0, 'Cancelling must not create a ticket or upload');

  const approved = evaluate("capture('PHOTO','إثبات النشاط')");
  await settle();
  element('shutter').onclick();
  assert.equal(calls.length, 0);
  element('confirmPhoto').onclick();
  const result = await approved;
  assert.equal(result.id, 22);
  assert.equal(calls.length, 2, 'Only approval creates a ticket and uploads');
  assert.equal(JSON.parse(calls[1].options.body).imageData, result.image);
  assert.equal(stopped, 2, 'Camera tracks stop on both cancel and approval');
  assert.equal(evaluate('currentView'), 'sessionView');

  evaluate("selectActivity({title:'نشاط جديد',weekId:2,goalTaskId:null,proofMethod:'TIMER'})");
  assert.equal(evaluate('activity.weekId'), 2);
  assert.equal(evaluate('currentView'), 'startView');
  assert.equal(element('durationFields').hidden, false);
  console.log('PASS: transient notice, preview, retake, cancel, approval-only upload, camera cleanup, and activity selection');
})().catch(e => { console.error(e); process.exitCode = 1; }).finally(() => clearTimeout(watchdog));
