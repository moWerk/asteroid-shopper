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
import org.asteroid.utils 1.0
import org.asteroid.controls 1.0

Item {
    id: allListsPage
    width: root.width
    height: root.height

    property var pop: function() {}

    // ----------------------------------------------------------------
    // Left-edge swipe hint — navigate back
    // ----------------------------------------------------------------
    Indicator {
        id: leftIndicator
        edge: Qt.LeftEdge
        Component.onCompleted: animate()
    }

    // ----------------------------------------------------------------
    // Lists ListView — fills page, PageHeader paints on top
    // ----------------------------------------------------------------
    ListView {
        id: listsView
        anchors.fill: parent
        model: listsModel
        clip: true

        header: Item {
            width: listsView.width
            height: listsHeader.height
        }

        delegate: Item {
            id: listDelegateRoot
            width: listsView.width
            height: appStyle.rowHeight

            property bool isDefault: model.name === "default"
            property bool isCurrent: model.name === appState.currentListName

            // Active list background
            Rectangle {
                anchors.fill: parent
                color: appStyle.accentColor
                opacity: 0.2
                visible: isCurrent
            }

            // Progress meter — behind text, covers most of row width
            ValueMeter {
                anchors {
                    verticalCenter: parent.verticalCenter
                    left:  parent.left
                    leftMargin:  Dims.l(9)
                    right: parent.right
                    rightMargin: Dims.l(9)
                }
                height:           appStyle.categoryHeaderHeight
                valueLowerBound:  0
                valueUpperBound:  Math.max(model.itemCount, 1)
                value:            model.checkedCount
                enableAnimations: false
                fillColor:        "#CC8ED081"
            }

            // List name
            Label {
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    leftMargin: Dims.l(16)
                    right: countLabel.left
                    rightMargin: Dims.l(3)
                }
                //% "Starter Pack"
                text: isDefault ? qsTrId("id-default") : model.name
                font {
                    pixelSize: appStyle.bodyFontSize
                    family:    "Noto Sans Condensed"
                    styleName: "Medium"
                }
                color: appStyle.labelColor
                elide: Text.ElideRight
            }

            // Item count
            Label {
                id: countLabel
                anchors {
                    verticalCenter: parent.verticalCenter
                    right: parent.right
                    rightMargin: Dims.l(16)
                }
                text: model.checkedCount + "/" + model.itemCount
                font {
                    pixelSize: appStyle.secondaryFontSize
                    family:    "Noto Sans Condensed"
                }
                color: "#aaffffff"
            }

            // Row separator
            RowSeparator { pinToBottom: true }

            // Press highlight
            Rectangle {
                anchors.fill: parent
                color: listMouseArea.containsPress ? appStyle.pressColor : "transparent"
                Behavior on color {
                    ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
            }

            MouseArea {
                id: listMouseArea
                anchors.fill: parent

                onClicked: {
                    switchToList(model.name)
                        pop()
                }

                onPressAndHold: {
                    layerStack.push(editDialogComponent, {
                        pop:        function() { layerStack.pop() },
                                    editIndex:  index,
                                    editText:   model.name,
                                    isListEdit: true
                    })
                }
            }
        }

        // ----------------------------------------------------------------
        // Footer — New List button
        // ----------------------------------------------------------------
        footer: Item {
            width: listsView.width
            height: appStyle.footerRowHeight

            Icon {
                id: newListIcon
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
                    top: newListIcon.bottom
                    topMargin: Dims.l(1)
                }
                //% "Fresh Haul"
                text: qsTrId("id-new-list")
                font.pixelSize: appStyle.secondaryFontSize
                font.bold: true
                color: appStyle.dimLabelColor
            }

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                color: appStyle.separatorColor
            }

            HighlightBar {
                onClicked: {
                    layerStack.push(editDialogComponent, {
                        pop:        function() { layerStack.pop() },
                                    editIndex:  -1,
                                    editText:   "",
                                    isListEdit: true
                    })
                }
            }
        }
    }

    // ---- PageHeader last — natural paint order keeps it on top ----
    PageHeader {
        id: listsHeader
        //% "My Hauls"
        text: qsTrId("id-my-lists")
    }
}
