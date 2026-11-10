(function() {
    if (window.__castBrowserInjected) return;
    window.__castBrowserInjected = true;

    function sendBridgeMessage(payload) {
        try {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.castBrowserBridge) {
                window.webkit.messageHandlers.castBrowserBridge.postMessage(payload);
            }
        } catch(e) {}
    }

    function notifyStream(url, source) {
        if (!url || typeof url !== 'string') return;
        if (url.startsWith('blob:') || url.startsWith('data:')) return;

        // Resolve relative URLs to absolute
        try {
            const absoluteUrl = new URL(url, window.location.href).href;
            sendBridgeMessage({
                type: 'STREAM_CANDIDATE',
                url: absoluteUrl,
                source: source,
                title: document.title || '',
                pageUrl: window.location.href
            });
        } catch(e) {}
    }

    function notifySubtitle(url, label, lang) {
        if (!url || typeof url !== 'string') return;
        if (url.startsWith('blob:') || url.startsWith('data:')) return;

        try {
            const absoluteUrl = new URL(url, window.location.href).href;
            sendBridgeMessage({
                type: 'SUBTITLE_CANDIDATE',
                url: absoluteUrl,
                label: label || 'Subtitle',
                language: lang || '',
                pageUrl: window.location.href
            });
        } catch(e) {}
    }

    function scanTracks() {
        try {
            const tracks = document.querySelectorAll('track');
            for (const t of tracks) {
                if (t.src) {
                    notifySubtitle(t.src, t.label || t.getAttribute('label') || 'Subtitle', t.srclang || t.getAttribute('srclang') || '');
                }
            }
        } catch(e) {}
    }

    // 1. Hook HTMLMediaElement.prototype.src
    try {
        const originalSrc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src');
        if (originalSrc && originalSrc.set) {
            Object.defineProperty(HTMLMediaElement.prototype, 'src', {
                set: function(val) {
                    notifyStream(val, 'media_src');
                    return originalSrc.set.call(this, val);
                },
                get: originalSrc.get,
                configurable: true
            });
        }
    } catch(e) {}

    // 2. Hook window.fetch
    try {
        const originalFetch = window.fetch;
        if (originalFetch) {
            window.fetch = function(input, init) {
                const url = (typeof input === 'string') ? input : (input && input.url ? input.url : '');
                if (url && typeof url === 'string') {
                    const lower = url.toLowerCase();
                    if (lower.includes('.m3u8') || lower.includes('.mpd') || lower.includes('.mp4') || lower.includes('videoplayback') || lower.includes('/manifest')) {
                        notifyStream(url, 'fetch');
                    } else if (lower.includes('.vtt') || lower.includes('.srt') || lower.includes('.ass') || lower.includes('.ssa')) {
                        notifySubtitle(url, 'Detected Subtitle', '');
                    }
                }
                return originalFetch.apply(this, arguments);
            };
        }
    } catch(e) {}

    // 3. Hook XMLHttpRequest.prototype.open
    try {
        const originalOpen = XMLHttpRequest.prototype.open;
        if (originalOpen) {
            XMLHttpRequest.prototype.open = function(method, url) {
                if (url && typeof url === 'string') {
                    const lower = url.toLowerCase();
                    if (lower.includes('.m3u8') || lower.includes('.mpd') || lower.includes('.mp4') || lower.includes('videoplayback') || lower.includes('/manifest')) {
                        notifyStream(url, 'xhr');
                    } else if (lower.includes('.vtt') || lower.includes('.srt') || lower.includes('.ass') || lower.includes('.ssa')) {
                        notifySubtitle(url, 'Detected Subtitle', '');
                    }
                }
                return originalOpen.apply(this, arguments);
            };
        }
    } catch(e) {}

    // 4. MutationObserver for dynamically inserted video, source, and track tags
    try {
        const observer = new MutationObserver(function(mutations) {
            for (const mutation of mutations) {
                for (const node of mutation.addedNodes) {
                    if (node.tagName === 'VIDEO') {
                        if (node.src) notifyStream(node.src, 'video_node');
                        const tracks = node.querySelectorAll('track');
                        for (const t of tracks) {
                            if (t.src) notifySubtitle(t.src, t.label, t.srclang);
                        }
                    } else if (node.tagName === 'SOURCE' && node.src) {
                        notifyStream(node.src, 'source_node');
                    } else if (node.tagName === 'TRACK' && node.src) {
                        notifySubtitle(node.src, node.label, node.srclang);
                    }
                }
            }
        });
        observer.observe(document.documentElement || document, { childList: true, subtree: true });
    } catch(e) {}

    // Initial scan of any pre-existing elements
    scanTracks();
    try {
        const existingVideos = document.querySelectorAll('video');
        for (const v of existingVideos) {
            if (v.src) notifyStream(v.src, 'video_node_init');
            const sources = v.querySelectorAll('source');
            for (const s of sources) {
                if (s.src) notifyStream(s.src, 'source_node_init');
            }
        }
    } catch(e) {}

    // 5. Periodic Playback Progress Tracking & Subtitle Refresh
    setInterval(function() {
        scanTracks();
        try {
            const videos = document.querySelectorAll('video');
            for (const v of videos) {
                if (!v.paused && v.duration > 0 && v.currentTime > 5) {
                    sendBridgeMessage({
                        type: 'PLAYBACK_PROGRESS',
                        currentTime: Math.floor(v.currentTime),
                        duration: Math.floor(v.duration),
                        url: v.currentSrc || v.src || window.location.href,
                        title: document.title || '',
                        pageUrl: window.location.href
                    });
                    break;
                }
            }
        } catch(e) {}
    }, 5000);
})();
