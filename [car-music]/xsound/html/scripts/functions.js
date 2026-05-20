function sanitizeURL(url) {
    url = DOMPurify.sanitize(url);
    return url.replace(/<[^>]*>?/gm, '');
}

function getYoutubeUrlId(url) {
    let videoId = "";
    if (url.indexOf("youtube") !== -1) {
        let urlParts = url.split("?v=");
        videoId = urlParts[1].substring(0, 11);
    }

    if (url.indexOf("youtu.be") !== -1) {
        let urlParts = url.replace("//", "").split("/");
        videoId = urlParts[1].substring(0, 11);
    }
    return videoId;
}

function isYoutubeURL(url) {
    return getYoutubeUrlId(url) !== "";
}

let durationIdId = 0;

function getDurationOfMusicFromURL(url, timeStamp) {
    url = sanitizeURL(url);
    const link = getYoutubeUrlId(url);

    if (link === "") {
        let audioPlayer = new Howl({
            src: [ url ],
            loop: false,
            html5: true,
            autoplay: false,
            volume: 0.00,
            format: [ 'mp3' ],
            onload: () => {
                timeStamp(audioPlayer.duration());
                audioPlayer.unload();
                audioPlayer = null;
            },
            onloaderror: (id, error) => {
                timeStamp(null);
                audioPlayer.unload();
                audioPlayer = null;
            },
        });
    } else {
        const div_id = "duration_temp_" + (durationIdId++);
        const iframeUrl = "https://cfx-nui-xsound/html/index2.html?url=" + url;

        $("body").append("<iframe id='" + div_id + "' src='" + iframeUrl + "' allow='autoplay' style='display:none;'></iframe>");

        let attempts = 0;
        const maxAttempts = 50;

        let checkReady = setInterval(() => {
            attempts++;
            let frame = document.getElementById(div_id);
            if (frame && frame.contentWindow && frame.contentWindow.yPlayer) {
                clearInterval(checkReady);
                const duration = frame.contentWindow.yPlayer.getDuration();
                timeStamp(duration);
                $("#" + div_id).remove();
            } else if (attempts >= maxAttempts) {
                clearInterval(checkReady);
                timeStamp(null);
                $("#" + div_id).remove();
            }
        }, 100);
    }
}

function isReady(soundName) {
    const sound = soundList[soundName];
    if (sound == null) {
        return;
    }
    if (sound.loaded() == false) {
        sound.setLoaded(true);

        $.post('https://xsound/events', JSON.stringify({
            type: "onPlay",
            id: sound.getName(),
        }));

        if (sound.isAudioYoutubePlayer()) {
            sound.setYoutubePlayerReady(true);
        }

        if (sound.isDynamic()) {
            addToCache();
            updateVolumeSounds();
        } else {
            sound.setVolume(sound.getVolume())
        }
    }
}

function ended(soundName) {
    const sound = soundList[soundName];
    if (sound == null) {
        return;
    }
    if (!sound.isPlaying()) {
        if (sound.isLoop()) {
            const time = sound.getAudioCurrentTime();

            sound.setTimeStamp(0);
            sound.play();

            $.post('https://xsound/events', JSON.stringify({
                type: "resetTimeStamp",
                id: sound.getName(),
                time: time,
            }));
        }

        $.post('https://xsound/data_status', JSON.stringify({
            type: "finished",
            id: soundName
        }));
        $.post('https://xsound/events', JSON.stringify({
            type: "onEnd",
            id: sound.getName(),
        }));
    }
}

function sendMaxDurationToClient(item) {
    getDurationOfMusicFromURL(item.url, function (time) {
        if (time) {
            $.post('https://xsound/data_status', JSON.stringify({
                time: time,
                type: "maxDuration",
                id: item.name,
            }));
        }
    });
}