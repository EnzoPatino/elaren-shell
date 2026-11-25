import QtQuick
import QtMultimedia
import "../../services"

// Fondo animado de Background.qml: video sin sonido y en bucle. Arranca al
// cargarse y se pausa en modo gaming. Va en un archivo aparte (cargado con un
// Loader) para que, si falta QtMultimedia, solo falle el video.
Item {
    id: vw

    property string source
    property bool ready: false
    property bool failed: false

    MediaPlayer {
        id: player
        source: vw.source
        loops: MediaPlayer.Infinite
        videoOutput: output
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia && !Wallpaper.animatedPaused) play();
            if (mediaStatus === MediaPlayer.BufferedMedia || mediaStatus === MediaPlayer.LoadedMedia) vw.ready = true;
            if (mediaStatus === MediaPlayer.InvalidMedia) vw.failed = true;
        }
        onErrorOccurred: (error, message) => {
            console.warn("wallpaper: no se pudo reproducir", vw.source, message);
            vw.failed = true;
        }
    }

    Connections {
        target: Wallpaper
        function onAnimatedPausedChanged(): void {
            if (Wallpaper.animatedPaused) player.pause();
            else player.play();
        }
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
