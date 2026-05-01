/*
    LVC Fleet UI module loader
    Loads the selected HUD from UI/modules/<module>/html/index.html.
    Each UI module keeps its own html, textures, and sounds folder.
*/

const DEFAULT_MODULE = "default";
const frame = document.getElementById("lvc-module-frame");

let activeModule = DEFAULT_MODULE;
let frameReady = false;
let queuedMessages = [];
let moduleLoadToken = 0;
const cachedMessages = {};

function sanitizeModuleName(name) {
    if (typeof name !== "string") return DEFAULT_MODULE;

    name = name.toLowerCase().trim();

    // Prevent ../ path traversal. Module folder names should be simple: default, ui2, cencom, etc.
    if (!/^[a-z0-9_-]+$/.test(name)) return DEFAULT_MODULE;

    return name;
}

function modulePath(name) {
    const cleanName = sanitizeModuleName(name);
    // Cache buster is intentional. FiveM CEF can keep old images/scripts around during UI swaps.
    return "../modules/" + cleanName + "/html/index.html?module=" + encodeURIComponent(cleanName) + "&v=" + moduleLoadToken;
}

function sendToModule(data) {
    if (!frame || !frame.contentWindow || !frameReady) {
        queuedMessages.push(data);
        return;
    }

    frame.contentWindow.postMessage(data, "*");
}

function cacheHudMessage(data) {
    if (!data || !data._type) return;

    if (data._type === "hud:setItemState") {
        cachedMessages["item:" + data.item] = data;
    } else if (data._type === "hud:setHudScale") {
        cachedMessages.scale = data;
    } else if (data._type === "hud:setHudPosition") {
        cachedMessages.position = data;
    } else if (data._type === "hud:setHudState") {
        cachedMessages.hudState = data;
    }
}

function replayCachedHudState() {
    // Important: replay time/TA pattern first so the image folder is correct before button states are applied.
    const orderedKeys = ["item:time", "item:ta_pattern", "position", "scale", "hudState"];

    orderedKeys.forEach((key) => {
        if (cachedMessages[key]) sendToModule(cachedMessages[key]);
    });

    Object.keys(cachedMessages).forEach((key) => {
        if (!orderedKeys.includes(key)) sendToModule(cachedMessages[key]);
    });
}

function flushQueue() {
    const queue = queuedMessages;
    queuedMessages = [];

    queue.forEach((data) => sendToModule(data));
}

function loadModule(name) {
    activeModule = sanitizeModuleName(name);
    frameReady = false;
    queuedMessages = [];
    moduleLoadToken = Date.now();

    // Force-unload previous iframe first. This prevents old UI elements/scripts from staying drawn over the new UI.
    frame.src = "about:blank";
    setTimeout(function () {
        frame.src = modulePath(activeModule);
    }, 0);
}

frame.addEventListener("load", function () {
    if (!frame || frame.src === "about:blank") return;

    frameReady = true;
    replayCachedHudState();
    flushQueue();
});

window.addEventListener("message", function (event) {
    const data = event.data || {};

    if (data._type === "ui:setModule") {
        loadModule(data.module || data.name || DEFAULT_MODULE);
        return;
    }

    if (data._type !== "audio") {
        cacheHudMessage(data);
    }

    sendToModule(data);
});
