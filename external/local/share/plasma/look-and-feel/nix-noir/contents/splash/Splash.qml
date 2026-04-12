/*
    Nix Noir splash — the calling card.
    One line. That's the whole thing.
*/

import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "#000000"

    property int stage

    readonly property color text: "#cdd6f4"
    readonly property color pink: "#f5c2e7"

    onStageChanged: {
        if (stage === 2) {
            introAnimation.running = true;
        }
    }

    Row {
        id: greeting
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing
        opacity: 0

        Text {
            text: "\u276f"
            color: root.pink
            font.family: "Hack"
            font.pixelSize: Kirigami.Units.gridUnit * 2.25
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "you're home."
            color: root.text
            font.family: "Hack"
            font.pixelSize: Kirigami.Units.gridUnit * 2.25
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    OpacityAnimator {
        id: introAnimation
        running: false
        target: greeting
        from: 0
        to: 1
        duration: Kirigami.Units.longDuration
        easing.type: Easing.InOutQuad
    }
}
