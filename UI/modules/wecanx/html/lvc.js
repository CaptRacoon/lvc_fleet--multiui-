/*
---------------------------------------------------
LVC Fleet - WECANX UI module
Assets are fully local to UI/modules/wecanx/.

Supported visual states:
  switch_1 / switch_2 / switch_3 / switch_4
  siren_off / siren_on / siren_hf / siren_t1 / siren_t2 / siren_t3
  siren_wail / siren_yelp -> lights the MANUAL button
---------------------------------------------------
*/

var time_folder = "day/";
var audioPlayer = null;
var soundID = 0;
var scale = 0.60;
var pos1 = 0, pos2 = 0, pos3 = 0, pos4 = 0;

var currentStates = {
    switchMode: "switch_1",
    sirenMode: "siren_off",
    horn: false,
    manual: false,
    tkd: false,
    scene: false,
    cruise: false,
    rumbler: false,
    pier: false,
    blackout: false,
    leftalley: false,
    rightalley: false
};

function getModuleRootUrl() {
    try {
        return new URL("../", window.location.href).href;
    } catch (e) {
        return "../";
    }
}

const LVC_MODULE_ROOT = getModuleRootUrl();
const LVC_CACHE_QUERY = (function () {
    try {
        const v = new URLSearchParams(window.location.search).get("v");
        return v ? "?v=" + encodeURIComponent(v) : "";
    } catch (e) {
        return "";
    }
})();

function safePath(path) {
    return String(path || "").replace(/^\/+/, "");
}

function lvcTexture(path) {
    return LVC_MODULE_ROOT + "textures/" + safePath(path) + LVC_CACHE_QUERY;
}

function lvcSoundCandidate(path) {
    return LVC_MODULE_ROOT + "sounds/" + safePath(path) + LVC_CACHE_QUERY;
}

function setTexture(element, path) {
    if (element) {
        element.src = lvcTexture(path);
    }
}

function setModuleBackground(element, path) {
    if (element) {
        element.style.backgroundImage = 'url("' + lvcTexture(path) + '")';
    }
}

function setButton(element, name, enabled) {
    if (!element || !name) return;
    setTexture(element, time_folder + name + (enabled ? "_on" : "_off") + ".png");
}

const elements = {
    sirenbox: document.getElementById("sirenbox"),
    switch: document.getElementById("switch"),
    siren: document.getElementById("siren"),
    horn: document.getElementById("horn"),
    manual: document.getElementById("manual"),
    tkd: document.getElementById("tkd"),
    scene: document.getElementById("scene"),
    cruise: document.getElementById("cruise"),
    rumbler: document.getElementById("rumbler"),
    pier: document.getElementById("pier"),
    blackout: document.getElementById("blackout"),
    leftalley: document.getElementById("leftalley"),
    rightalley: document.getElementById("rightalley")
};

const backup = {
    left: (elements.sirenbox && elements.sirenbox.style.left) || "0%",
    top: (elements.sirenbox && elements.sirenbox.style.top) || "68%"
};

function normalizeSwitchMode(state) {
    if (state === true) return "switch_3";
    if (state === false || state === null || state === undefined) return "switch_1";

    var value = String(state).toLowerCase().trim().replace(/\s+/g, "_");

    if (value === "" || value === "0" || value === "off" || value === "false" || value === "switch_1") return "switch_1";
    if (value === "stage" || value === "stage_1" || value === "switch_2") return "switch_2";
    if (value === "1" || value === "on" || value === "true" || value === "lights" || value === "switch_3") return "switch_3";
    if (value === "2" || value === "siren" || value === "sirens" || value === "lights_siren" || value === "lights_sirens" || value === "switch_4") return "switch_4";

    return "switch_1";
}

function applySwitchState(state) {
    var mode = normalizeSwitchMode(state);
    currentStates.switchMode = mode;
    setTexture(elements.switch, time_folder + mode + ".png");
}

function normalizeSirenMode(state) {
    if (state && typeof state === "object") {
        if (state.handsfree === true || state.hf === true) return "siren_hf";
        if (state.mode !== undefined) return normalizeSirenMode(state.mode);
        if (state.tone !== undefined) return normalizeSirenMode(state.tone);
        if (state.siren !== undefined) return normalizeSirenMode(state.siren);
    }

    if (state === true) return "siren_on";
    if (state === false || state === null || state === undefined) return "siren_off";

    var value = String(state).toLowerCase().trim().replace(/\s+/g, "_");

    if (value === "" || value === "0" || value === "false" || value === "off" || value === "siren_off") return "siren_off";
    if (value === "on" || value === "true" || value === "siren_on") return "siren_on";
    if (value === "hf" || value === "handsfree" || value === "hands_free" || value === "handfree" || value === "siren_hf") return "siren_hf";
    if (value === "wail" || value === "manual_wail" || value === "main_wail" || value === "siren_wail") return "siren_wail";
    if (value === "yelp" || value === "manual_yelp" || value === "aux_yelp" || value === "siren_yelp") return "siren_yelp";
    if (value === "1" || value === "t1" || value === "tone1" || value === "tone_1" || value === "siren_t1") return "siren_t1";
    if (value === "2" || value === "t2" || value === "tone2" || value === "tone_2" || value === "siren_t2") return "siren_t2";
    if (value === "3" || value === "t3" || value === "tone3" || value === "tone_3" || value === "siren_t3") return "siren_t3";

    var numericTone = Number(value.replace(/[^0-9]/g, ""));
    if (!isNaN(numericTone)) {
        if (numericTone <= 1) return "siren_t1";
        if (numericTone === 2) return "siren_t2";
        return "siren_t3";
    }

    return "siren_t2";
}

function applySirenState(state) {
    var mode = normalizeSirenMode(state);
    currentStates.sirenMode = mode;

    if (mode === "siren_wail" || mode === "siren_yelp") {
        currentStates.manual = true;
        currentStates.horn = false;
        setButton(elements.manual, "manual", true);
        setButton(elements.horn, "horn", false);
        setTexture(elements.siren, time_folder + "siren_off.png");
        return;
    }

    currentStates.manual = false;
    setButton(elements.manual, "manual", false);
    setTexture(elements.siren, time_folder + mode + ".png");
}

function applyHornState(state) {
    currentStates.horn = !!state;
    setButton(elements.horn, "horn", currentStates.horn);
}

function applyManualState(state) {
    currentStates.manual = !!state;
    setButton(elements.manual, "manual", currentStates.manual);
}

function applyTakedownState(state) {
    currentStates.tkd = !!state;
    setButton(elements.tkd, "tkd", currentStates.tkd);
}

function applySceneState(state) {
    currentStates.scene = !!state;
    setButton(elements.scene, "scene", currentStates.scene);
}

function applyCruiseState(state) {
    currentStates.cruise = !!state;
    setButton(elements.cruise, "cruise", currentStates.cruise);
}

function applyRumblerState(state) {
    currentStates.rumbler = !!state;
    setButton(elements.rumbler, "rumbler", currentStates.rumbler);
}

function applyPierState(state) {
    currentStates.pier = !!state;
    setButton(elements.pier, "pier", currentStates.pier);
}

function applyBlackoutState(state) {
    currentStates.blackout = !!state;
    setButton(elements.blackout, "blackout", currentStates.blackout);
}

function applyLeftAlleyState(state) {
    currentStates.leftalley = !!state;
    setButton(elements.leftalley, "leftalley", currentStates.leftalley);
}

function applyRightAlleyState(state) {
    currentStates.rightalley = !!state;
    setButton(elements.rightalley, "rightalley", currentStates.rightalley);
}

function replayStates() {
    setModuleBackground(elements.sirenbox, time_folder + "background.png");
    applySwitchState(currentStates.switchMode);
    applySirenState(currentStates.sirenMode);
    applyHornState(currentStates.horn);
    applyManualState(currentStates.manual);
    applyTakedownState(currentStates.tkd);
    applySceneState(currentStates.scene);
    applyCruiseState(currentStates.cruise);
    applyRumblerState(currentStates.rumbler);
    applyPierState(currentStates.pier);
    applyBlackoutState(currentStates.blackout);
    applyLeftAlleyState(currentStates.leftalley);
    applyRightAlleyState(currentStates.rightalley);
}

function normalizeAudioFileName(file) {
    file = safePath(file);

    if (file === "key_lock") {
        file = "Key_Lock";
    }

    return file.replace(/\.(ogg|wav)$/i, "");
}

function buildSoundCandidates(file) {
    var cleanFile = normalizeAudioFileName(file);
    var baseName = cleanFile.split("/").pop();
    var stems = [cleanFile];

    if (baseName && baseName !== cleanFile) {
        stems.push(baseName);
    }

    var candidates = [];

    function addCandidate(path) {
        if (path && candidates.indexOf(path) === -1) {
            candidates.push(path);
        }
    }

    stems.forEach(function (stem) {
        addCandidate(stem + ".ogg");
        addCandidate(stem + ".wav");
    });

    return candidates;
}

function playSound(file, volume) {
    if (audioPlayer != null) {
        audioPlayer.pause();
        audioPlayer = null;
    }

    soundID++;
    var thisSound = soundID;
    var candidates = buildSoundCandidates(file);
    var index = 0;

    function tryPlay() {
        if (thisSound !== soundID) return;

        if (index >= candidates.length) {
            audioPlayer = null;
            return;
        }

        var player = new Audio(lvcSoundCandidate(candidates[index]));
        index++;

        audioPlayer = player;
        audioPlayer.volume = Math.max(0.0, Math.min(1.0, Number(volume) || 0.0));

        function tryNext() {
            if (thisSound !== soundID || audioPlayer !== player) return;
            tryPlay();
        }

        player.onerror = tryNext;

        var didPlayPromise = player.play();
        if (didPlayPromise !== undefined) {
            didPlayPromise.catch(tryNext);
        }
    }

    tryPlay();
}

replayStates();

window.addEventListener("message", function (event) {
    var data = event.data || {};
    var type = data._type;

    if (type == "audio") {
        playSound(data.file, data.volume);
        return;
    }

    if (type == "hud:setItemState") {
        var item = data.item;
        var state = data.state;

        switch (item) {
            case "hud":
                if (elements.sirenbox) {
                    elements.sirenbox.style.display = state == true ? "inline" : "none";
                }
                break;

            case "switch":
                applySwitchState(state);
                break;

            case "siren":
            case "siren_mode":
            case "siren_tone":
                applySirenState(state);
                break;

            case "siren_hf":
            case "handsfree":
            case "hands_free":
                if (state == true) {
                    applySirenState("siren_hf");
                } else if (currentStates.sirenMode === "siren_hf") {
                    applySirenState("siren_off");
                }
                break;

            case "horn":
                applyHornState(state);
                break;

            case "manual":
                applyManualState(state);
                break;

            case "tkd":
            case "takedown":
                applyTakedownState(state);
                break;

            case "scene":
                applySceneState(state);
                break;

            case "cruise":
            case "cruise_control":
                applyCruiseState(state);
                break;

            case "rumbler":
            case "howlr":
            case "howler":
                applyRumblerState(state);
                break;

            case "pier":
                applyPierState(state);
                break;

            case "blackout":
                applyBlackoutState(state);
                break;

            case "leftalley":
            case "left_alley":
                applyLeftAlleyState(state);
                break;

            case "rightalley":
            case "right_alley":
                applyRightAlleyState(state);
                break;

            case "time":
                time_folder = (state === "night") ? "night/" : "day/";
                replayStates();
                break;

            case "lock":
            case "ta":
            case "ta_pattern":
                // No dedicated visual for these in this WECANX asset set.
                break;

            default:
                break;
        }
        return;
    }

    if (type == "hud:setHudScale") {
        scale = data.scale;
        if (elements.sirenbox) {
            elements.sirenbox.style.transform = "scale(" + scale + ")";
        }
    } else if (type == "hud:getHudScale") {
        sendData("hud:sendHudScale", scale);
    } else if (type == "hud:setHudPosition") {
        try {
            elements.sirenbox.style.left = data.pos.left;
            elements.sirenbox.style.top = data.pos.top;
        } catch (error) {}
    } else if (type == "hud:resetPosition") {
        if (elements.sirenbox) {
            elements.sirenbox.style.left = backup.left;
            elements.sirenbox.style.top = backup.top;
        }
    }
});

function sendData(name, data) {
    $.post("https://lvc_fleet/" + name, JSON.stringify(data), function (datab) {
        if (datab != "ok") {
            console.log(datab);
        }
    });
}

$(document).keyup(function (event) {
    // Esc, Tab, Space
    if (event.keyCode == 27 || event.keyCode == 9 || event.keyCode == 32) {
        sendData("hud:setHudPositon", { left: elements.sirenbox.style.left, top: elements.sirenbox.style.top });
        sendData("hud:setMoveState", false);
    }
});

$(document).contextmenu(function () {
    sendData("hud:setHudPositon", { left: elements.sirenbox.style.left, top: elements.sirenbox.style.top });
    sendData("hud:setMoveState", false);
});

if (elements.sirenbox) {
    elements.sirenbox.onmousedown = dragMouseDown;
}

function dragMouseDown(e) {
    e = e || window.event;
    e.preventDefault();
    pos3 = e.clientX;
    pos4 = e.clientY;
    document.onmouseup = closeDragElement;
    document.onmousemove = elementDrag;
}

function elementDrag(e) {
    e = e || window.event;
    e.preventDefault();
    pos1 = pos3 - e.clientX;
    pos2 = pos4 - e.clientY;
    pos3 = e.clientX;
    pos4 = e.clientY;
    elements.sirenbox.style.top = (elements.sirenbox.offsetTop - pos2) + "px";
    elements.sirenbox.style.left = (elements.sirenbox.offsetLeft - pos1) + "px";
}

function closeDragElement() {
    document.onmouseup = null;
    document.onmousemove = null;
}
