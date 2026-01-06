const panel = document.getElementById('bc-panel');
const placement = document.getElementById('bc-placement');
const closeBtn = document.getElementById('bc-close');
const photoInput = document.getElementById('bc-photo-url');
const saveBtn = document.getElementById('bc-save-photo');
const sideToggle = document.getElementById('bc-side-toggle');
const sideFrontBtn = document.getElementById('bc-side-front');
const sideBackBtn = document.getElementById('bc-side-back');
const previewImg = document.getElementById('bc-photo-preview');
const previewPlaceholder = document.getElementById('bc-photo-placeholder');
const previewBox = document.querySelector('.preview');
const amountInput = document.getElementById('bc-amount');
const printBtn = document.getElementById('bc-print');
const statusEl = document.getElementById('bc-status');
const cardPreview = document.getElementById('bc-card');
const cardFrontImage = document.getElementById('bc-card-front');
const cardBackImage = document.getElementById('bc-card-back');
const cardControls = document.getElementById('bc-card-controls');
const cardFlipBtn = document.getElementById('bc-card-flip');
const cardCloseBtn = document.getElementById('bc-card-close');

let currentPrinterId = null;
let maxAmount = 50;
const defaultPhotoState = { scale: 1, offsetX: 0, offsetY: 0, offsetXRatio: 0, offsetYRatio: 0 };
const zoomSettings = { min: 1, max: 2.5, step: 0.1 };
let enableBackSide = true;
let activeSide = 'front';
let cardSide = 'front';
const photoUrls = { front: '', back: '' };
const photoStates = { front: { ...defaultPhotoState }, back: { ...defaultPhotoState } };
const cardData = {
    front: { url: '', state: { ...defaultPhotoState } },
    back: { url: '', state: { ...defaultPhotoState } }
};
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
    const currentState = photoStates[activeSide] || { ...defaultPhotoState };
    const normalized = normalizePhotoState(currentState, bounds);
    const clamped = clampStateToBounds(normalized, bounds);
    photoStates[activeSide] = clamped;
    previewImg.style.transform = `translate(${clamped.offsetX}px, ${clamped.offsetY}px) scale(${clamped.scale})`;
}

function applyCardTransform(imageEl, state) {
    if (!imageEl) return;
    const bounds = getBounds(cardPreview);
    const normalized = normalizePhotoState(state, bounds);
    const clamped = clampStateToBounds(normalized, bounds);
    imageEl.style.transform = `translate(${clamped.offsetX}px, ${clamped.offsetY}px) scale(${clamped.scale})`;
}

function setPreviewForSide(side) {
    const url = photoUrls[side] || '';
    if (!url) {
        previewImg.style.display = 'none';
        previewImg.src = '';
        previewPlaceholder.style.display = 'block';
        if (previewBox) previewBox.classList.remove('has-image');
        photoStates[side] = { ...defaultPhotoState };
        applyPreviewTransform();
        return;
    }
    previewImg.src = url;
    previewImg.style.display = 'block';
    previewPlaceholder.style.display = 'none';
    if (previewBox) previewBox.classList.add('has-image');
    photoStates[side] = normalizePhotoState(photoStates[side], getBounds(previewBox));
    applyPreviewTransform();
}

function setSideMode(enableBack) {
    enableBackSide = !!enableBack;
    if (sideToggle) sideToggle.classList.toggle('hidden', !enableBackSide);
    if (sideBackBtn) {
        sideBackBtn.disabled = !enableBackSide;
        sideBackBtn.classList.toggle('hidden', !enableBackSide);
    }
    if (cardControls) cardControls.classList.toggle('hidden', !enableBackSide);
    if (cardFlipBtn) cardFlipBtn.classList.toggle('hidden', !enableBackSide);
    if (!enableBackSide) {
        activeSide = 'front';
        if (cardBackImage) cardBackImage.classList.add('hidden');
        if (cardFlipBtn) cardFlipBtn.disabled = true;
    }
}

function setActiveSide(side) {
    if (side !== 'front' && side !== 'back') return;
    if (!enableBackSide && side === 'back') return;
    applyPreviewTransform();
    activeSide = side;
    if (sideFrontBtn) sideFrontBtn.classList.toggle('active', side === 'front');
    if (sideBackBtn) sideBackBtn.classList.toggle('active', side === 'back');
    if (photoInput) photoInput.value = photoUrls[side] || '';
    setPreviewForSide(side);
}

function setCardSide(side) {
    if (side !== 'front' && side !== 'back') return;
    if (!enableBackSide && side === 'back') return;
    cardSide = side;
    if (cardFrontImage) cardFrontImage.classList.toggle('hidden', side !== 'front');
    if (cardBackImage) cardBackImage.classList.toggle('hidden', side !== 'back');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') {
        panel.classList.remove('hidden');
        setSideMode(data.enableBack !== false);
        currentPrinterId = data.printerId || null;
        maxAmount = data.maxAmount || 50;
        amountInput.max = String(maxAmount);
        photoUrls.front = data.frontImageUrl || data.imageUrl || '';
        photoUrls.back = data.backImageUrl || '';
        photoStates.front = normalizePhotoState(data.frontPhotoState || data.photoState, getBounds(previewBox));
        photoStates.back = normalizePhotoState(data.backPhotoState, getBounds(previewBox));
        setActiveSide('front');
        setStatus('Ready');
    } else if (data.action === 'close') {
        panel.classList.add('hidden');
        currentPrinterId = null;
    } else if (data.action === 'photoSaved') {
        const side = data.side === 'back' ? 'back' : 'front';
        if (typeof data.imageUrl !== 'undefined') {
            photoUrls[side] = data.imageUrl || '';
        }
        if (side === activeSide) {
            setPreviewForSide(activeSide);
        }
        setStatus('Photo saved.');
    } else if (data.action === 'showCard') {
        if (typeof data.enableBack !== 'undefined') {
            setSideMode(data.enableBack !== false);
        }
        const frontUrl = data.frontImageUrl || data.imageUrl || '';
        const backUrl = enableBackSide ? (data.backImageUrl || data.backUrl || '') : '';
        cardData.front.url = frontUrl;
        cardData.back.url = backUrl;
        cardData.front.state = normalizePhotoState(data.frontPhotoState || data.photoState, getBounds(cardPreview));
        cardData.back.state = normalizePhotoState(data.backPhotoState, getBounds(cardPreview));
        if (cardFrontImage) cardFrontImage.src = frontUrl;
        if (cardBackImage) cardBackImage.src = backUrl;
        if (cardPreview) {
            if (data.width) cardPreview.style.width = `${data.width}px`;
            if (data.height) cardPreview.style.height = `${data.height}px`;
        }
        if (cardPreview) cardPreview.classList.remove('hidden');
        requestAnimationFrame(() => {
            setCardSide('front');
            if (cardFlipBtn) cardFlipBtn.disabled = !backUrl || !enableBackSide;
            applyCardTransform(cardFrontImage, cardData.front.state);
            if (enableBackSide) {
                applyCardTransform(cardBackImage, cardData.back.state);
            }
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

if (sideFrontBtn) {
    sideFrontBtn.addEventListener('click', () => {
        setActiveSide('front');
    });
}

if (sideBackBtn) {
    sideBackBtn.addEventListener('click', () => {
        setActiveSide('back');
    });
}

saveBtn.addEventListener('click', () => {
    const url = photoInput.value.trim();
    if (!url) {
        setStatus('Enter a photo link.');
        return;
    }
    const side = enableBackSide ? activeSide : 'front';
    photoUrls[side] = url;
    applyPreviewTransform();
    postNui('bc_save_photo', {
        printerId: currentPrinterId,
        side,
        url,
        photoState: { ...photoStates[side] }
    });
});

printBtn.addEventListener('click', () => {
    const amount = Number(amountInput.value) || 1;
    if (amount < 1) {
        setStatus('Enter a valid amount.');
        return;
    }
    applyPreviewTransform();
    const payload = {
        printerId: currentPrinterId,
        amount
    };
    if (enableBackSide) {
        payload.photoState = {
            front: { ...photoStates.front },
            back: { ...photoStates.back }
        };
    } else {
        payload.photoState = { ...photoStates.front };
    }
    postNui('bc_print_cards', payload);
});

if (cardFlipBtn) {
    cardFlipBtn.addEventListener('click', () => {
        if (!enableBackSide || !cardData.back.url) return;
        setCardSide(cardSide === 'front' ? 'back' : 'front');
    });
}

if (cardCloseBtn) {
    cardCloseBtn.addEventListener('click', () => {
        if (cardPreview) cardPreview.classList.add('hidden');
        postNui('bc_close_card', {});
    });
}

if (previewBox) {
    previewBox.addEventListener('mousedown', (event) => {
        if (previewImg.style.display === 'none') return;
        applyPreviewTransform();
        dragState.active = true;
        dragState.startX = event.clientX;
        dragState.startY = event.clientY;
        dragState.originX = (photoStates[activeSide] && photoStates[activeSide].offsetXRatio) || 0;
        dragState.originY = (photoStates[activeSide] && photoStates[activeSide].offsetYRatio) || 0;
        previewBox.classList.add('dragging');
    });

    window.addEventListener('mousemove', (event) => {
        if (!dragState.active) return;
        const bounds = getBounds(previewBox);
        const width = bounds.width || 1;
        const height = bounds.height || 1;
        if (!photoStates[activeSide]) photoStates[activeSide] = { ...defaultPhotoState };
        photoStates[activeSide].offsetXRatio = dragState.originX + ((event.clientX - dragState.startX) / width);
        photoStates[activeSide].offsetYRatio = dragState.originY + ((event.clientY - dragState.startY) / height);
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
        if (!photoStates[activeSide]) photoStates[activeSide] = { ...defaultPhotoState };
        const nextScale = clamp(photoStates[activeSide].scale + (direction * zoomSettings.step), zoomSettings.min, zoomSettings.max);
        photoStates[activeSide].scale = nextScale;
        applyPreviewTransform();
    }, { passive: false });
}
