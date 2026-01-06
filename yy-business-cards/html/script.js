const panel = document.getElementById('bc-panel');
const placement = document.getElementById('bc-placement');
const closeBtn = document.getElementById('bc-close');
const photoInput = document.getElementById('bc-photo-url');
const saveBtn = document.getElementById('bc-save-photo');
const previewImg = document.getElementById('bc-photo-preview');
const previewPlaceholder = document.getElementById('bc-photo-placeholder');
const previewBox = document.querySelector('.preview');
const amountInput = document.getElementById('bc-amount');
const printBtn = document.getElementById('bc-print');
const statusEl = document.getElementById('bc-status');
const cardPreview = document.getElementById('bc-card');
const cardImage = document.getElementById('bc-card-image');

let currentPrinterId = null;
let maxAmount = 50;
const defaultPhotoState = { scale: 1, offsetX: 0, offsetY: 0, offsetXRatio: 0, offsetYRatio: 0 };
const zoomSettings = { min: 1, max: 2.5, step: 0.1 };
let photoState = { ...defaultPhotoState };
let dragState = { active: false, startX: 0, startY: 0, originX: 0, originY: 0 };

function postNui(eventName, payload) {
    fetch(`https://${GetParentResourceName()}/${eventName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {})
    });
}

function setStatus(text) {
    if (statusEl) statusEl.textContent = text;
}

function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
}

function getBounds(element) {
    if (!element) {
        return { width: 0, height: 0 };
    }
    return {
        width: element.clientWidth || 0,
        height: element.clientHeight || 0
    };
}

function clampStateToBounds(state, bounds) {
    const width = bounds?.width || 0;
    const height = bounds?.height || 0;
    const scale = clamp(state.scale, zoomSettings.min, zoomSettings.max);
    if (width <= 0 || height <= 0) {
        return { scale, offsetX: 0, offsetY: 0, offsetXRatio: 0, offsetYRatio: 0 };
    }
    const maxRatio = Math.max(0, (scale - 1) * 0.5);
    const offsetXRatio = clamp(state.offsetXRatio ?? 0, -maxRatio, maxRatio);
    const offsetYRatio = clamp(state.offsetYRatio ?? 0, -maxRatio, maxRatio);
    return {
        scale,
        offsetXRatio,
        offsetYRatio,
        offsetX: offsetXRatio * width,
        offsetY: offsetYRatio * height
    };
}

function normalizePhotoState(state, bounds) {
    if (!state) return { ...defaultPhotoState };
    let parsed = state;
    if (typeof state === 'string') {
        try {
            parsed = JSON.parse(state);
        } catch (err) {
            parsed = null;
        }
    }
    const scale = Number(parsed?.scale);
    const offsetX = Number(parsed?.offsetX);
    const offsetY = Number(parsed?.offsetY);
    let offsetXRatio = Number(parsed?.offsetXRatio);
    let offsetYRatio = Number(parsed?.offsetYRatio);
    if ((!Number.isFinite(offsetXRatio) || !Number.isFinite(offsetYRatio)) && bounds) {
        const width = bounds.width || 0;
        const height = bounds.height || 0;
        if (width > 0 && height > 0) {
            offsetXRatio = Number.isFinite(offsetX) ? offsetX / width : 0;
            offsetYRatio = Number.isFinite(offsetY) ? offsetY / height : 0;
        }
    }
    return {
        scale: Number.isFinite(scale) ? scale : defaultPhotoState.scale,
        offsetX: Number.isFinite(offsetX) ? offsetX : defaultPhotoState.offsetX,
        offsetY: Number.isFinite(offsetY) ? offsetY : defaultPhotoState.offsetY,
        offsetXRatio: Number.isFinite(offsetXRatio) ? offsetXRatio : defaultPhotoState.offsetXRatio,
        offsetYRatio: Number.isFinite(offsetYRatio) ? offsetYRatio : defaultPhotoState.offsetYRatio
    };
}

function applyPreviewTransform() {
    if (!previewImg) return;
    const bounds = getBounds(previewBox);
    const normalized = normalizePhotoState(photoState, bounds);
    const clamped = clampStateToBounds(normalized, bounds);
    photoState = clamped;
    previewImg.style.transform = `translate(${clamped.offsetX}px, ${clamped.offsetY}px) scale(${clamped.scale})`;
}

function applyCardTransform(state) {
    if (!cardImage) return;
    const bounds = getBounds(cardPreview);
    const normalized = normalizePhotoState(state, bounds);
    const clamped = clampStateToBounds(normalized, bounds);
    cardImage.style.transform = `translate(${clamped.offsetX}px, ${clamped.offsetY}px) scale(${clamped.scale})`;
}

function setPreview(url, state) {
    if (!url) {
        previewImg.style.display = 'none';
        previewImg.src = '';
        previewPlaceholder.style.display = 'block';
        if (previewBox) previewBox.classList.remove('has-image');
        photoState = { ...defaultPhotoState };
        applyPreviewTransform();
        return;
    }
    previewImg.src = url;
    previewImg.style.display = 'block';
    previewPlaceholder.style.display = 'none';
    if (previewBox) previewBox.classList.add('has-image');
    if (state) {
        photoState = normalizePhotoState(state);
    }
    applyPreviewTransform();
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') {
        panel.classList.remove('hidden');
        currentPrinterId = data.printerId || null;
        maxAmount = data.maxAmount || 50;
        amountInput.max = String(maxAmount);
        const img = data.imageUrl || '';
        photoInput.value = img;
        photoState = normalizePhotoState(data.photoState, getBounds(previewBox));
        setPreview(img, photoState);
        setStatus('Ready');
    } else if (data.action === 'close') {
        panel.classList.add('hidden');
        currentPrinterId = null;
    } else if (data.action === 'photoSaved') {
        setPreview(data.imageUrl || '', photoState);
        setStatus('Photo saved.');
    } else if (data.action === 'showCard') {
        if (cardImage) cardImage.src = data.imageUrl || '';
        if (cardPreview) {
            if (data.width) cardPreview.style.width = `${data.width}px`;
            if (data.height) cardPreview.style.height = `${data.height}px`;
        }
        if (cardPreview) cardPreview.classList.remove('hidden');
        requestAnimationFrame(() => {
            applyCardTransform(data.photoState);
        });
    } else if (data.action === 'hideCard') {
        if (cardPreview) cardPreview.classList.add('hidden');
    } else if (data.action === 'showPlacementHelp') {
        placement.classList.remove('hidden');
    } else if (data.action === 'hidePlacementHelp') {
        placement.classList.add('hidden');
    }
});

closeBtn.addEventListener('click', () => {
    postNui('bc_close', {});
});

saveBtn.addEventListener('click', () => {
    const url = photoInput.value.trim();
    if (!url) {
        setStatus('Enter a photo link.');
        return;
    }
    applyPreviewTransform();
    postNui('bc_save_photo', { printerId: currentPrinterId, url, photoState: { ...photoState } });
});

printBtn.addEventListener('click', () => {
    const amount = Number(amountInput.value) || 1;
    if (amount < 1) {
        setStatus('Enter a valid amount.');
        return;
    }
    applyPreviewTransform();
    postNui('bc_print_cards', { printerId: currentPrinterId, amount, photoState: { ...photoState } });
});

if (previewBox) {
    previewBox.addEventListener('mousedown', (event) => {
        if (previewImg.style.display === 'none') return;
        applyPreviewTransform();
        dragState.active = true;
        dragState.startX = event.clientX;
        dragState.startY = event.clientY;
        dragState.originX = photoState.offsetXRatio || 0;
        dragState.originY = photoState.offsetYRatio || 0;
        previewBox.classList.add('dragging');
    });

    window.addEventListener('mousemove', (event) => {
        if (!dragState.active) return;
        const bounds = getBounds(previewBox);
        const width = bounds.width || 1;
        const height = bounds.height || 1;
        photoState.offsetXRatio = dragState.originX + ((event.clientX - dragState.startX) / width);
        photoState.offsetYRatio = dragState.originY + ((event.clientY - dragState.startY) / height);
        applyPreviewTransform();
    });

    window.addEventListener('mouseup', () => {
        if (!dragState.active) return;
        dragState.active = false;
        previewBox.classList.remove('dragging');
    });

    previewBox.addEventListener('wheel', (event) => {
        if (previewImg.style.display === 'none') return;
        event.preventDefault();
        const direction = event.deltaY < 0 ? 1 : -1;
        const nextScale = clamp(photoState.scale + (direction * zoomSettings.step), zoomSettings.min, zoomSettings.max);
        photoState.scale = nextScale;
        applyPreviewTransform();
    }, { passive: false });
}
