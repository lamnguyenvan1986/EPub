// Cầu nối giữa Dart (dart:js_interop) và piper_worker.js. Dart gọi window.libriPiper.*,
// mọi hàm trả Promise. Worker chỉ được tạo khi dùng giọng offline lần đầu.
(function () {
  const workerUrl = new URL('piper_worker.js', document.currentScript.src).href;
  let worker = null;
  let nextId = 0;
  const pending = new Map();

  function getWorker() {
    if (!worker) {
      worker = new Worker(workerUrl);
      worker.onmessage = (event) => {
        const msg = event.data;
        const entry = pending.get(msg.id);
        if (!entry) return;
        if (msg.progress !== undefined) {
          if (entry.onProgress) entry.onProgress(msg.progress);
          return;
        }
        pending.delete(msg.id);
        if (msg.ok) entry.resolve(msg.value);
        else entry.reject(new Error(msg.error));
      };
      worker.onerror = (event) => {
        // Lỗi nạp worker (thiếu file vendor...): báo cho mọi lệnh đang chờ
        const error = new Error(event.message || 'Không chạy được giọng offline trên trình duyệt này.');
        for (const entry of pending.values()) entry.reject(error);
        pending.clear();
        worker = null;
      };
    }
    return worker;
  }

  function call(message, onProgress) {
    return new Promise((resolve, reject) => {
      const id = nextId++;
      pending.set(id, { resolve, reject, onProgress });
      getWorker().postMessage(Object.assign({ id }, message));
    });
  }

  window.libriPiper = {
    isSupported: () =>
      typeof Worker !== 'undefined' && typeof WebAssembly !== 'undefined' && 'caches' in window,
    isInstalled: (urls) => call({ type: 'isInstalled', urls: Array.from(urls) }),
    download: (urls, onProgress) => call({ type: 'download', urls: Array.from(urls) }, onProgress),
    remove: (urls) => call({ type: 'delete', urls: Array.from(urls) }),
    load: (modelUrl, configUrl) => call({ type: 'load', modelUrl, configUrl }),
    // Trả ArrayBuffer chứa file WAV
    synthesize: (text) => call({ type: 'synthesize', text }),
  };
})();
