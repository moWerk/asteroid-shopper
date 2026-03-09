/*
 * Copyright (C) 2026 - Timo Könnecke <github.com/moWerk>
 *
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.9
import QtQuick.Layouts 1.15
import org.asteroid.utils 1.0
import org.asteroid.controls 1.0

Item {
    id: shoppingListPage
    width: root.width
    height: root.height

    property bool overscrollRebuildPending: false

    Timer {
        id: reloadTimer
        interval: 400
        repeat: false
        onTriggered: {
            loadShoppingList()
            refreshAnim.restart()
        }
    }

    // ----------------------------------------------------------------
    // Restore scroll to top after list switch
    // ----------------------------------------------------------------
    Connections {
        target: root
        function onListLoaded() {
            Qt.callLater(function() { listView.positionViewAtBeginning() })
        }
    }

    // ----------------------------------------------------------------
    // Right-edge swipe hint — navigate to All Lists
    // ----------------------------------------------------------------
    Indicator {
        id: rightIndicator
        edge: Qt.RightEdge
        Component.onCompleted: animate()
    }

    Icon {
        id: refreshIndicator
        name: "ios-refresh-circle-outline"
        width:  Dims.l(30)
        height: Dims.l(30)
        anchors {
            top: listHeader.bottom
            horizontalCenter: parent.horizontalCenter
        }
        opacity: 0.0

        SequentialAnimation {
            id: refreshAnim
            running: false
            NumberAnimation { target: refreshIndicator; property: "opacity"; to: 1.0; duration: 150; easing.type: Easing.InOutQuad }
            PauseAnimation  { duration: 300 }
            NumberAnimation { target: refreshIndicator; property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.InOutQuad }
        }
    }

    // ----------------------------------------------------------------
    // Main list — fills page entirely; PageHeader paints on top via
    // declaration order. header: spacer pushes first item below header.
    // ----------------------------------------------------------------
    ListView {
        id: listView
        anchors.fill: parent
        model: flatModel
        clip: true

        header: Item {
            width: listView.width
            height: listHeader.height
        }

        onVerticalOvershootChanged: {
            if (verticalOvershoot < -Dims.l(30) && !shoppingListPage.overscrollRebuildPending) {
                shoppingListPage.overscrollRebuildPending = true
                reloadTimer.restart()
            }
            if (verticalOvershoot === 0) shoppingListPage.overscrollRebuildPending = false
        }

        delegate: Item {
            id: delegateRoot
            width: listView.width
            height: model.type === "categoryHeader" ? appStyle.categoryHeaderHeight : appStyle.rowHeight

            // ---- Category colour band ----
            Rectangle {
                anchors.fill: parent
                visible: model.categoryColor !== ""
                color: model.categoryColor !== "" ? model.categoryColor : "transparent"
                opacity: model.type === "categoryHeader" ? (model.allChecked ? 0.4 : 0.8) : (model.checked ? 0.3 : 0.5)

                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                }
            }

            // ---- Category header content ----
            Label {
                visible: model.type === "categoryHeader"
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    leftMargin: Dims.l(17)
                }
                text: "#" + model.sortNum + " " + model.name
                font {
                    pixelSize: appStyle.secondaryFontSize
                    family:    "Noto Sans Condensed"
                    styleName: "Bold"
                    letterSpacing: Dims.l(0.8)
                }
                color: appStyle.labelColor
            }

            // ---- Item content ----
            RowLayout {
                visible: model.type === "item"
                anchors.fill: parent
                spacing: 0
                opacity: model.checked ? 0.6 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                }

                Icon {
                    name: model.checked ? "ios-checkmark-circle-outline" : "ios-circle-outline"
                    Layout.preferredWidth:  appStyle.iconSize
                    Layout.preferredHeight: appStyle.iconSize
                    Layout.leftMargin: Dims.l(16)
                }

                Label {
                    text: model.name
                    font {
                        pixelSize: appStyle.bodyFontSize
                        strikeout: model.checked
                        family:    "Noto Sans Condensed"
                        styleName: "Medium"
                    }
                    color: appStyle.labelColor
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.leftMargin: Dims.l(2)
                    Layout.rightMargin: Dims.l(4)
                }
            }

            // ---- Row separator (items only) ----
            RowSeparator { visible: model.type === "item" }

            // ---- Press highlight ----
            Rectangle {
                anchors.fill: parent
                color: delegateMouseArea.containsPress ? appStyle.pressColor : "transparent"
                Behavior on color {
                    ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
            }

            // ---- Interaction ----
            MouseArea {
                id: delegateMouseArea
                anchors.fill: parent

                onClicked: {
                    if (model.type !== "item") return
                        var wasChecked = model.checked
                        shoppingModel.setProperty(model.sourceIndex, "checked", !wasChecked)
                        flatModel.setProperty(index, "checked", !wasChecked)

                        // Live-update the category header's allChecked role
                        if (model.category !== "") {
                            for (var h = index - 1; h >= 0; h--) {
                                var hr = flatModel.get(h)
                                if (hr.type === "categoryHeader" && hr.category === model.category) {
                                    var allDone = true
                                    for (var s = h + 1; s < flatModel.count; s++) {
                                        var sr = flatModel.get(s)
                                        if (sr.type === "categoryHeader") break
                                            if (!sr.checked) { allDone = false; break }
                                    }
                                    flatModel.setProperty(h, "allChecked", allDone)
                                    break
                                }
                            }
                        }

                        saveShoppingList()
                        updateAnyChecked()
                }

                onPressAndHold: {
                    if (model.type === "item") {
                        layerStack.push(editDialogComponent, {
                            pop:          function() { layerStack.pop() },
                                        editIndex:    model.sourceIndex,
                                        editText:     model.name,
                                        editCategory: model.category,
                                        isListEdit:   false
                        })
                    } else if (model.type === "categoryHeader") {
                        layerStack.push(categoryEditDialogComponent, {
                            pop:          function() { layerStack.pop() },
                                        categoryName: model.category
                        })
                    }
                }
            }
        }

        // ----------------------------------------------------------------
        // Footer
        // ----------------------------------------------------------------
        footer: Item {
            width: listView.width
            height: appStyle.footerDividerHeight
            + Dims.l(52)
            + appStyle.footerRowHeight
            + (hasUserLists ? appStyle.footerRowHeight : 0)
            + (hasUserLists ? Dims.l(10) : 0)
            + (appState.currentListName === "default"
            ? warningLabel.height + (DeviceSpecs.hasRoundScreen ? Dims.l(24) : Dims.l(12))
            : 0)

            // ── Footer divider ────────────────────────────────────────
            Item {
                id: footerDivider
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: appStyle.footerDividerHeight

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1
                    color: appStyle.separatorColor
                }
            }

            // ── Add Item row ──────────────────────────────────────────
            Item {
                id: addRow
                anchors { top: footerDivider.bottom; left: parent.left; right: parent.right }
                height: appStyle.footerRowHeight

                Icon {
                    id: addIcon
                    name: "ios-add-circle-outline"
                    width:  appStyle.iconSize
                    height: appStyle.iconSize
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: Dims.l(3)
                    }
                }
                Label {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: addIcon.bottom
                        topMargin: Dims.l(1)
                    }
                    //% "Add Item"
                    text: qsTrId("id-add-item")
                    font.pixelSize: appStyle.secondaryFontSize
                    font.bold: true
                    color: appStyle.dimLabelColor
                }

                HighlightBar {
                    onClicked: {
                        layerStack.push(editDialogComponent, {
                            pop:          function() { layerStack.pop() },
                                        editIndex:    -1,
                                        editText:     "",
                                        editCategory: "",
                                        isListEdit:   false
                        })
                    }
                }
            }

            Rectangle {
                id: footerSep1
                anchors { top: addRow.bottom; left: parent.left; right: parent.right }
                height: 1
                color: appStyle.separatorColor
            }

            // ── Check / Uncheck All row ───────────────────────────────
            Item {
                id: checkRow
                anchors { top: footerSep1.bottom; left: parent.left; right: parent.right }
                height: appStyle.footerRowHeight

                Icon {
                    id: checkAllIcon
                    name: appState.anyChecked ? "ios-refresh-circle-outline" : "ios-checkmark-circle-outline"
                    width:  appStyle.iconSize
                    height: appStyle.iconSize
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: Dims.l(3)
                    }
                }
                Label {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: checkAllIcon.bottom
                        topMargin: Dims.l(1)
                    }
                    //% "Uncheck All Items"
                    text: appState.anyChecked ? qsTrId("id-uncheck-all")
                    //% "Check All Items"
                    : qsTrId("id-check-all")
                    font.pixelSize: appStyle.secondaryFontSize
                    font.bold: true
                    color: appStyle.dimLabelColor
                }

                HighlightBar {
                    onClicked: appState.anyChecked ? uncheckAll() : checkAll()
                }
            }

            Rectangle {
                id: footerSep2
                anchors { top: checkRow.bottom; left: parent.left; right: parent.right }
                height: 1
                color: appStyle.separatorColor
            }

            // ── Edit List row ─────────────────────────────────────────
            Item {
                id: editRow
                anchors { top: footerSep2.bottom; left: parent.left; right: parent.right }
                height: appStyle.footerRowHeight

                Icon {
                    id: editListIcon
                    name: "ios-brush-outline"
                    width:  appStyle.iconSize
                    height: appStyle.iconSize
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: Dims.l(3)
                    }
                }
                Label {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: editListIcon.bottom
                        topMargin: Dims.l(1)
                    }
                    //% "Edit List"
                    text: qsTrId("id-edit-list")
                    font.pixelSize: appStyle.secondaryFontSize
                    font.bold: true
                    color: appStyle.dimLabelColor
                }

                HighlightBar {
                    onClicked: {
                        layerStack.push(editDialogComponent, {
                            pop:        function() { layerStack.pop() },
                                        editIndex:  0,
                                        editText:   appState.currentListName,
                                        isListEdit: true
                        })
                    }
                }
            }

            Rectangle {
                id: footerSepEdit
                visible: hasUserLists
                anchors { top: editRow.bottom; left: parent.left; right: parent.right }
                height: hasUserLists ? 1 : 0
                color: appStyle.separatorColor
            }

            // ── All My Hauls row ──────────────────────────────────────
            Item {
                id: allListsRow
                visible: hasUserLists
                anchors { top: footerSepEdit.bottom; left: parent.left; right: parent.right }
                height: hasUserLists ? appStyle.footerRowHeight : 0

                Icon {
                    id: allListsIcon
                    name: "ios-list-box-outline"
                    width:  appStyle.iconSize
                    height: appStyle.iconSize
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: Dims.l(3)
                    }
                }
                Label {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: allListsIcon.bottom
                        topMargin: Dims.l(1)
                    }
                    //% "All My Hauls"
                    text: qsTrId("id-show-all-lists")
                    font.pixelSize: appStyle.secondaryFontSize
                    font.bold: true
                    color: appStyle.dimLabelColor
                }

                HighlightBar {
                    onClicked: layerStack.push(allListsPageComponent, {
                        pop: function() { layerStack.pop() }
                    })
                }
            }

            Item {
                id: spacerAfterLists
                anchors { top: allListsRow.bottom; left: parent.left; right: parent.right }
                height: hasUserLists ? Dims.l(10) : 0
            }

            Rectangle {
                id: footerSep3
                visible: hasUserLists
                anchors { top: spacerAfterLists.bottom; left: parent.left; right: parent.right }
                height: hasUserLists ? 1 : 0
                color: appStyle.separatorColor
            }

            Label {
                id: warningLabel
                visible: appState.currentListName === "default"
                anchors {
                    top: hasUserLists ? footerSep3.bottom : footerSepEdit.bottom
                    topMargin: Dims.l(5)
                    left: parent.left
                    right: parent.right
                    leftMargin:  DeviceSpecs.hasRoundScreen ? Dims.l(14) : Dims.l(8)
                    rightMargin: DeviceSpecs.hasRoundScreen ? Dims.l(14) : Dims.l(8)
                }
                //% "This is a demo list meant for exploring the app. It will be reset on reinstall and should be deleted once you have created your own list."
                text: qsTrId("id-default-list-warning")
                font.pixelSize: appStyle.secondaryFontSize
                color: appStyle.labelColor
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ---- PageHeader last — natural paint order keeps it on top ----
    PageHeader {
        id: listHeader
        text: appState.currentListName === "default"
        ? qsTrId("id-default")
        : appState.currentListName
    }
}
