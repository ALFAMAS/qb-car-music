// NUI fetch helper -----------------------------------------------------------

function nuiPost(data) {
    return fetch('https://qb-car-music/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).catch(function() {});
}

// Button / input wire-up -----------------------------------------------------

document.getElementById('shutdownbutton').addEventListener('click', function() {
    nuiPost({ action: 'exit' });
});

document.getElementById('volumedown').addEventListener('click', function() {
    nuiPost({ action: 'volumedown' });
});

document.getElementById('volumeup').addEventListener('click', function() {
    nuiPost({ action: 'volumeup' });
});

document.getElementById('play').addEventListener('click', function() {
    nuiPost({ action: 'play' });
});

document.getElementById('pause').addEventListener('click', function() {
    nuiPost({ action: 'pause' });
});

document.getElementById('loop').addEventListener('click', function() {
    nuiPost({ action: 'loop' });
});

document.getElementById('back').addEventListener('click', function() {
    nuiPost({ action: 'back' });
});

document.getElementById('forward').addEventListener('click', function() {
    nuiPost({ action: 'forward' });
});

document.getElementById('queuenext').addEventListener('click', function() {
    nuiPost({ action: 'playNext' });
});

// Volume slider --------------------------------------------------------------

var sliderDragging = false;

document.getElementById('volslider').addEventListener('mousedown', function() {
    sliderDragging = true;
});

document.addEventListener('mouseup', function() {
    if (!sliderDragging) return;
    sliderDragging = false;
    var value = parseInt(document.getElementById('volslider').value, 10) / 100;
    nuiPost({ action: 'setvol', value: value });
});

document.getElementById('volslider').addEventListener('input', function() {
    // Live label update while dragging, server call on mouseup
    var pct = this.value;
    document.getElementById('testrecv').innerHTML = '<b>Volume:</b> ' + pct + '%';
});

// PLAY button ----------------------------------------------------------------

document.getElementById('inputok').addEventListener('click', function() {
    var url = document.getElementById('linkinput').value.trim();
    if (!url) {
        showValidation('Please enter a URL.');
        return;
    }
    hideValidation();
    nuiPost({ action: 'seturl', link: url });
    resolveTrackName(url);
    document.getElementById('linkinput').value = '';
});

// Queue: add via shift+enter or a dedicated button ---------------------------

document.getElementById('linkinput').addEventListener('keydown', function(e) {
    if (e.key === 'Enter') {
        if (e.shiftKey) {
            var url = this.value.trim();
            if (!url) { showValidation('Please enter a URL.'); return; }
            hideValidation();
            nuiPost({ action: 'addToQueue', link: url });
            this.value = '';
        } else {
            document.getElementById('inputok').click();
        }
    }
});

// Validation message helpers -------------------------------------------------

function showValidation(msg) {
    var el = document.getElementById('validation-msg');
    el.textContent = msg;
    el.style.display = 'block';
    clearTimeout(el._timer);
    el._timer = setTimeout(hideValidation, 3000);
}

function hideValidation() {
    var el = document.getElementById('validation-msg');
    el.style.display = 'none';
}

// Message handler ------------------------------------------------------------

window.addEventListener('message', function(event) {
    var data = event.data;
    switch (data.action) {
        case 'showRadio':
            document.getElementById('main').style.display = 'block';
            showTime();
            break;

        case 'hideRadio':
            document.getElementById('main').style.display = 'none';
            break;

        case 'changetextv':
            document.getElementById('testrecv').innerHTML = data.text;
            if (data.volume !== undefined && !sliderDragging) {
                document.getElementById('volslider').value = Math.round(data.volume * 100);
            }
            break;

        case 'changetextl':
            document.getElementById('testrecl').innerHTML = data.text;
            break;

        case 'changevidname':
            resolveTrackName(data.text);
            break;

        case 'TimeVid':
            updateTimeDisplay(data.total, data.played);
            break;

        case 'validationError':
            showValidation(data.text);
            break;

        case 'updateQueue':
            renderQueue(data.queue);
            break;
    }
});

// Time display ---------------------------------------------------------------

function updateTimeDisplay(totaltime, timeplayed) {
    var el = document.getElementById('testtime');
    if (totaltime !== undefined && timeplayed !== undefined) {
        if (timeplayed > totaltime) timeplayed = timeplayed - 1;
        el.textContent = secondsToHms(timeplayed) + ' / ' + secondsToHms(totaltime);
    } else {
        el.textContent = '0:00 / 0:00';
    }
}

function secondsToHms(d) {
    d = Number(d);
    var h = Math.floor(d / 3600);
    var m = Math.floor(d % 3600 / 60);
    var s = Math.floor(d % 3600 % 60);
    var hDisplay = h > 0 ? h + ':' : '';
    var mDisplay = m > 0 ? m + ':' : '0:';
    var sDisplay = s < 10 ? '0' + s : '' + s;
    return hDisplay + mDisplay + sDisplay;
}

// Track name resolution (noembed API → filename fallback) --------------------

function resolveTrackName(url) {
    var trackEl = document.getElementById('trackname');
    if (!url) {
        setTrackName('Nothing');
        return;
    }
    fetch('https://noembed.com/embed?url=' + encodeURIComponent(url))
        .then(function(r) { return r.json(); })
        .then(function(data) {
            setTrackName(data.title || extractFilename(url) || 'Unknown');
        })
        .catch(function() {
            setTrackName(extractFilename(url) || 'Unknown');
        });
}

function setTrackName(name) {
    var el = document.getElementById('trackname');
    el.textContent = name;
    // Restart the CSS marquee animation so it begins from the right edge
    el.style.animation = 'none';
    void el.offsetWidth; // force reflow
    el.style.animation = '';
}

function extractFilename(url) {
    if (!url) return '';
    var m = url.toString().match(/.*\/(.+?)\./);
    return (m && m.length > 1) ? capitalize(m[1]) : '';
}

function capitalize(s) {
    return typeof s === 'string' ? s.charAt(0).toUpperCase() + s.slice(1) : '';
}

// Queue render ---------------------------------------------------------------

function renderQueue(queue) {
    var listEl  = document.getElementById('queuelist');
    var nextBtn = document.getElementById('queuenext');
    if (!queue || queue.length === 0) {
        listEl.innerHTML = '';
        nextBtn.style.display = 'none';
        return;
    }
    nextBtn.style.display = 'inline-block';
    listEl.innerHTML = queue.map(function(url, i) {
        return '<div class="queue-item">' + (i + 1) + '. ' + escapeHtml(url) + '</div>';
    }).join('');
}

function escapeHtml(str) {
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Clock ----------------------------------------------------------------------

var colonVisible = false;

function showTime() {
    var date = new Date();
    var h = date.getHours();
    var m = date.getMinutes();
    var session = ' AM';
    if (h === 0) h = 12;
    if (h > 12)  { h -= 12; session = ' PM'; }
    var hStr = h < 10 ? '0' + h : '' + h;
    var mStr = m < 10 ? '0' + m : '' + m;
    var sep  = colonVisible ? ':' : ' ';
    colonVisible = !colonVisible;
    var el = document.getElementById('MyClockDisplay');
    el.textContent = hStr + sep + mStr + session;
    if (document.getElementById('main').style.display !== 'none') {
        setTimeout(showTime, 1000);
    }
}

// ESC to close ---------------------------------------------------------------

document.addEventListener('keyup', function(e) {
    if (e.key === 'Escape') {
        nuiPost({ action: 'exit' });
    }
});

// Responsive scale -----------------------------------------------------------

function applyScale() {
    var scale = Math.min(1, window.innerWidth / 900, window.innerHeight / 520);
    document.documentElement.style.setProperty('--ui-scale', scale);
}

window.addEventListener('resize', applyScale);
applyScale();

// Init -----------------------------------------------------------------------

document.getElementById('main').style.display = 'none';
