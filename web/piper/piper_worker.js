// Worker chạy giọng Piper trên web: espeak-ng (piper_phonemize, WASM) đổi text thành
// phoneme, onnxruntime-web chạy model VITS. Chạy trong worker để UI không bị đứng.
// File thư viện nằm ở vendor/, do tool/fetch_piper_web.sh tải về lúc build.
importScripts('vendor/ort.wasm.min.js', 'vendor/piper_phonemize.js');

// GitHub Pages không bật cross-origin isolation nên không dùng được nhiều luồng
ort.env.wasm.numThreads = 1;
ort.env.wasm.wasmPaths = new URL('vendor/', self.location.href).href;

const CACHE_NAME = 'libri-piper-voices';

let session = null;
let sessionKey = null;
let modelConfig = null;
let phonemizerFiles = null;

function post(id, ok, value) {
  if (ok) {
    self.postMessage({ id, ok: true, value }, value instanceof ArrayBuffer ? [value] : []);
  } else {
    self.postMessage({ id, ok: false, error: String(value && value.message ? value.message : value) });
  }
}

async function isInstalled(urls) {
  const cache = await caches.open(CACHE_NAME);
  for (const url of urls) {
    if (!(await cache.match(url))) return false;
  }
  return true;
}

// Tải file về Cache Storage, báo tiến độ theo tổng số byte của mọi file
async function download(id, urls) {
  const cache = await caches.open(CACHE_NAME);
  const blobs = [];
  let total = 0;
  const loaded = urls.map(() => 0);
  const responses = [];
  for (const url of urls) {
    const res = await fetch(url);
    if (!res.ok) throw new Error('Tải giọng thất bại (mã ' + res.status + ').');
    total += +(res.headers.get('Content-Length') || 0);
    responses.push(res);
  }
  for (let i = 0; i < responses.length; i++) {
    const reader = responses[i].body.getReader();
    const chunks = [];
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      loaded[i] += value.length;
      if (total > 0) {
        self.postMessage({ id, progress: loaded.reduce((a, b) => a + b, 0) / total });
      }
    }
    blobs.push(new Blob(chunks));
  }
  for (let i = 0; i < urls.length; i++) {
    await cache.put(urls[i], new Response(blobs[i]));
  }
}

async function remove(urls) {
  const cache = await caches.open(CACHE_NAME);
  for (const url of urls) await cache.delete(url);
  if (session && urls.includes(sessionKey)) {
    await session.release();
    session = null;
    sessionKey = null;
  }
}

async function load(modelUrl, configUrl) {
  if (session && sessionKey === modelUrl) return;
  const cache = await caches.open(CACHE_NAME);
  const modelRes = await cache.match(modelUrl);
  const configRes = await cache.match(configUrl);
  if (!modelRes || !configRes) throw new Error('Chưa tải giọng offline.');
  modelConfig = await configRes.json();
  const buffer = await modelRes.arrayBuffer();
  if (session) await session.release();
  session = await ort.InferenceSession.create(buffer, { executionProviders: ['wasm'] });
  sessionKey = modelUrl;
}

// Giữ bytes của piper_phonemize.wasm/.data để mỗi lần tạo module không phải tải lại
async function phonemizerAssets() {
  if (!phonemizerFiles) {
    const base = new URL('vendor/', self.location.href).href;
    const [wasm, data] = await Promise.all([
      fetch(base + 'piper_phonemize.wasm').then((r) => r.arrayBuffer()),
      fetch(base + 'piper_phonemize.data').then((r) => r.arrayBuffer()),
    ]);
    phonemizerFiles = { wasm, data };
  }
  return phonemizerFiles;
}

let phonemizer = null;
let phonemizerOutput = '';

function createPhonemizer() {
  return phonemizerAssets().then(({ wasm, data }) =>
    createPiperPhonemize({
      wasmBinary: wasm,
      getPreloadedPackage: () => data.slice(0),
      print: (line) => {
        phonemizerOutput += line;
      },
      printErr: (line) => console.warn('piper_phonemize:', line),
      locateFile: (name) => name,
    }));
}

function runPhonemizer(module, text) {
  phonemizerOutput = '';
  module.callMain([
    '-l', modelConfig.espeak.voice,
    '--input', JSON.stringify([{ text }]),
    '--espeak_data', '/espeak-ng-data',
  ]);
  return JSON.parse(phonemizerOutput).phoneme_ids;
}

// Dùng lại một module cho nhiều câu; nếu module hỏng sau lần chạy trước thì tạo lại
// (bytes wasm/data đã có sẵn trong bộ nhớ nên nhanh)
async function phonemize(text) {
  if (phonemizer) {
    try {
      return runPhonemizer(await phonemizer, text);
    } catch (e) {
      console.warn('piper_phonemize: tạo lại module', e);
    }
  }
  phonemizer = createPhonemizer();
  try {
    return runPhonemizer(await phonemizer, text);
  } catch (e) {
    phonemizer = null;
    throw e;
  }
}

function toWav(samples, sampleRate) {
  const view = new DataView(new ArrayBuffer(44 + samples.length * 2));
  const writeString = (offset, s) => {
    for (let i = 0; i < s.length; i++) view.setUint8(offset + i, s.charCodeAt(i));
  };
  writeString(0, 'RIFF');
  view.setUint32(4, 36 + samples.length * 2, true);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  writeString(36, 'data');
  view.setUint32(40, samples.length * 2, true);
  for (let i = 0; i < samples.length; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    view.setInt16(44 + i * 2, v < 0 ? v * 32768 : v * 32767, true);
  }
  return view.buffer;
}

async function synthesize(text) {
  if (!session) throw new Error('Chưa nạp giọng offline.');
  const ids = await phonemize(text.trim());
  const inf = modelConfig.inference;
  const feeds = {
    input: new ort.Tensor('int64', BigInt64Array.from(ids.map(BigInt)), [1, ids.length]),
    input_lengths: new ort.Tensor('int64', BigInt64Array.from([BigInt(ids.length)]), [1]),
    scales: new ort.Tensor('float32', Float32Array.from([inf.noise_scale, inf.length_scale, inf.noise_w]), [3]),
  };
  if (modelConfig.num_speakers > 1) {
    feeds.sid = new ort.Tensor('int64', BigInt64Array.from([0n]), [1]);
  }
  const result = await session.run(feeds);
  return toWav(result.output.data, modelConfig.audio.sample_rate);
}

// Xử lý lần lượt từng lệnh: onnxruntime không cho chạy hai session.run cùng lúc
let queue = Promise.resolve();
self.onmessage = (event) => {
  const msg = event.data;
  queue = queue.then(async () => {
    try {
      switch (msg.type) {
        case 'isInstalled':
          post(msg.id, true, await isInstalled(msg.urls));
          break;
        case 'download':
          await download(msg.id, msg.urls);
          post(msg.id, true, null);
          break;
        case 'delete':
          await remove(msg.urls);
          post(msg.id, true, null);
          break;
        case 'load':
          await load(msg.modelUrl, msg.configUrl);
          post(msg.id, true, null);
          break;
        case 'synthesize':
          post(msg.id, true, await synthesize(msg.text));
          break;
        default:
          post(msg.id, false, 'Lệnh không hợp lệ: ' + msg.type);
      }
    } catch (e) {
      post(msg.id, false, e);
    }
  });
};
