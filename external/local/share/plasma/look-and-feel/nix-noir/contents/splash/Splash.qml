/*
    Nix Noir splash — the calling card.
    One line. That's the whole thing.

    Layout invariant: this must render pixel-identical to the final
    frame of /usr/share/plymouth/themes/nix-noir/nix-noir.script.
    Both sides use literal pixels (Hack 28pt @ 96dpi -> 37px) and a
    literal 24px gap. First frame is fully opaque (no fade-in) so
    the --retain-splash handoff is pixel-stable, not a fade-through-black.
*/

import QtQuick

Rectangle {
    id: root
    color: "#11111b"

    property int stage

    readonly property color text: "#cdd6f4"
    readonly property color pink: "#f5c2e7"

    Row {
        id: greeting
        anchors.centerIn: parent
        spacing: 24
        opacity: 1

        Text {
            text: "\u276f"
            color: root.pink
            font.family: "Hack"
            font.pixelSize: 37
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "you're home."
            color: root.text
            font.family: "Hack"
            font.pixelSize: 37
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
