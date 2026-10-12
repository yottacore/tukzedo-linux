/***************************************************************************
* Copyright (c) 2013 Reza Fatahilah Shah <rshah0385@kireihana.com>
* Copyright (c) 2013 Abdurrahman AVCI <abdurrahmanavci@gmail.com>
*
* Permission is hereby granted, free of charge, to any person
* obtaining a copy of this software and associated documentation
* files (the "Software"), to deal in the Software without restriction,
* including without limitation the rights to use, copy, modify, merge,
* publish, distribute, sublicense, and/or sell copies of the Software,
* and to permit persons to whom the Software is furnished to do so,
* subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included
* in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
* OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
* OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
* ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
* OR OTHER DEALINGS IN THE SOFTWARE.
*
*
* Tukzedo: Elarun with a dropdown of users in place of the typed user name,
* a dark top bar with the clock and flat power buttons, and a centered form.
* Images come from the installed Elarun theme, in '../elarun/'.
***************************************************************************/

import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    width: 640
    height: 480

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int sessionIndex: session.index

    // The user dropdown gives only an index, so keep the names in model order.
    property var userNames: []
    Repeater {
        model: userModel
        delegate: Item {
            visible: false
            Component.onCompleted: { var names = userNames; names[index] = model.name; userNames = names }
        }
    }

    TextConstants { id: textConstants }

    // Flat icon button for the top bar, using the Breeze dark icons.
    component PowerButton: Rectangle {
        id: btn
        property string icon
        signal clicked()
        width: 32; height: 32; radius: 6
        color: area.containsMouse || activeFocus ? "#33ffffff" : "transparent"
        Image {
            anchors.centerIn: parent
            width: 22; height: 22
            sourceSize.width: 22; sourceSize.height: 22
            source: "file:///usr/share/icons/breeze-dark/actions/22/" + btn.icon + ".svg"
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { btn.clicked(); event.accepted = true }
        }
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
        }
        function onInformationMessage(message) {
        }
        function onLoginFailed() {
            pw_entry.text = ""
        }
    }

    Background {
        anchors.fill: parent
        source: Qt.resolvedUrl(config.background)
        fillMode: Image.PreserveAspectCrop
        onStatusChanged: {
            var defaultBackground = Qt.resolvedUrl(config.defaultBackground)
            if (status == Image.Error && source != defaultBackground) {
                source = defaultBackground
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        //visible: primaryScreen

        Rectangle {
            width: 416; height: 262
            color: "#00000000"

            anchors.centerIn: parent

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("../elarun/images/rectangle.png")
            }

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("../elarun/images/rectangle_overlay.png")
                opacity: 0.1
            }

            Item {
                anchors.margins: 20
                anchors.fill: parent

                Text {
                    height: 50
                    anchors.top: parent.top
                    anchors.left: parent.left; anchors.right: parent.right

                    color: "#123a4d"
                    opacity: 0.85

                    text: sddm.hostName

                    font.bold: true
                    font.pixelSize: 18
                }

                // The form and the login arrow center as one group.
                Row {
                    anchors.centerIn: parent
                    spacing: 14

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Row {
                            z: 1    // the open user list draws over the password row
                            spacing: 6
                            Image { source: Qt.resolvedUrl("../elarun/images/user_icon.png"); anchors.verticalCenter: parent.verticalCenter }

                            ComboBox {
                                id: user_entry

                                width: 180; height: 30
                                anchors.verticalCenter: parent.verticalCenter;

                                arrowIcon: Qt.resolvedUrl("../elarun/angle-down.png")

                                model: userModel
                                index: userModel.lastIndex

                                font.pixelSize: 14

                                onValueChanged: pw_entry.focus = true

                                KeyNavigation.backtab: power_button; KeyNavigation.tab: pw_entry
                            }
                        }

                        Row {
                            spacing: 6
                            Image { source: Qt.resolvedUrl("../elarun/images/lock.png"); anchors.verticalCenter: parent.verticalCenter }

                            PasswordBox {
                                id: pw_entry
                                width: 180; height: 30
                                anchors.verticalCenter: parent.verticalCenter;

                                tooltipBG: "CornflowerBlue"

                                font.pixelSize: 14

                                KeyNavigation.backtab: user_entry; KeyNavigation.tab: login_button

                                Keys.onPressed: function (event) {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        sddm.login(userNames[user_entry.index], pw_entry.text, sessionIndex)
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                    }

                    ImageButton {
                        id: login_button
                        anchors.verticalCenter: parent.verticalCenter

                        source: Qt.resolvedUrl("../elarun/images/login_normal.png")

                        onClicked: sddm.login(userNames[user_entry.index], pw_entry.text, sessionIndex)

                        KeyNavigation.backtab: pw_entry; KeyNavigation.tab: session
                    }
                }
            }
        }
    }

    Rectangle {
        id: actionBar
        anchors.top: parent.top;
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width; height: 40
        color: "#e6141417"

        Row {
            anchors.left: parent.left
            anchors.margins: 5
            height: parent.height
            spacing: 5

            Text {
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter

                text: textConstants.session
                color: "#e4e4e7"
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }

            ComboBox {
                id: session
                width: 245
                anchors.verticalCenter: parent.verticalCenter

                arrowIcon: Qt.resolvedUrl("../elarun/angle-down.png")

                model: sessionModel
                index: sessionModel.lastIndex

                color: "#2a2a2f"; menuColor: "#2a2a2f"; textColor: "#e4e4e7"
                borderColor: "#45454c"; hoverColor: "#3d7fd9"; focusColor: "#3d7fd9"
                arrowColor: "#9a9aa0"

                font.pixelSize: 14

                KeyNavigation.backtab: login_button; KeyNavigation.tab: layoutBox
            }

            Text {
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter

                visible: layoutBox.visible

                text: textConstants.layout
                color: "#e4e4e7"
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }

            LayoutBox {
                id: layoutBox
                width: 90
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 14

                visible: keyboard.enabled && keyboard.layouts.length > 0

                color: "#2a2a2f"; menuColor: "#2a2a2f"; textColor: "#e4e4e7"
                borderColor: "#45454c"; hoverColor: "#3d7fd9"; focusColor: "#3d7fd9"
                arrowColor: "#9a9aa0"

                arrowIcon: Qt.resolvedUrl("../elarun/angle-down.png")

                KeyNavigation.backtab: session; KeyNavigation.tab: suspend_button
            }
        }

        Text {
            id: dateTime
            anchors.centerIn: parent
            color: "#e4e4e7"
            font.pixelSize: 15

            function update() { text = Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy    h:mm AP") }
            Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: dateTime.update() }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            PowerButton {
                id: suspend_button
                icon: "system-suspend"; visible: sddm.canSuspend
                onClicked: sddm.suspend()
                KeyNavigation.backtab: layoutBox; KeyNavigation.tab: reboot_button
            }
            PowerButton {
                id: reboot_button
                icon: "system-reboot"; visible: sddm.canReboot
                onClicked: sddm.reboot()
                KeyNavigation.backtab: suspend_button; KeyNavigation.tab: power_button
            }
            PowerButton {
                id: power_button
                icon: "system-shutdown"; visible: sddm.canPowerOff
                onClicked: sddm.powerOff()
                KeyNavigation.backtab: reboot_button; KeyNavigation.tab: user_entry
            }
        }
    }

    Component.onCompleted: {
        pw_entry.focus = true
    }
}
