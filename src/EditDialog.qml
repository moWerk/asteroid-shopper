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
    id: editDialog
    width: root.width
    height: root.height

    // ----------------------------------------------------------------
    // Properties injected at push time
    // ----------------------------------------------------------------
    property var    pop:          function() {}
    property int    editIndex:    -1
    property string editText:     ""
    property string editCategory: ""
    property bool   isListEdit:   false

    // ----------------------------------------------------------------
    // Dialog-level state — survives delegate scope
    // ----------------------------------------------------------------
    property string draftName:        editText
    property string selectedCategory: editCategory === "" ? "None" : editCategory
    property string selectedList:     appState.currentListName
    property var    categoryOptions:  []
    property var    listOptions:      []

    // ----------------------------------------------------------------
    // Page set — computed once, drives ListView model and PageDots
    // ----------------------------------------------------------------
    property var pages: {
        if (isListEdit) {
            return ["textField", "delete"]
        } else if (editIndex < 0) {
            return ["textField", "category"]
        } else {
            var p = ["textField", "category"]
            if (listOptions.length >= 2) p.push("moveList")
                p.push("delete")
                return p
        }
    }

    Component.onCompleted: {
        var names = getCategoryNames()
        names.unshift("None")
        categoryOptions = names

        var lists = getUserLists().slice()
        if (appState.currentListName === "default") {
            if (lists.indexOf("default") < 0) lists.unshift("default")
        } else {
            lists = lists.filter(function(n) { return n !== "default" })
        }
        listOptions = lists
    }

    // ----------------------------------------------------------------
    // Page header — text reflects current page, reuses existing IDs
    // ----------------------------------------------------------------
    PageHeader {
        id: dialogHeader
        text: {
            if (pages.length === 0) return ""
                var page = pages[pageView.currentIndex] || ""
                if (page === "textField") {
                    if (isListEdit)
                        //% "Edit List"
                        return editIndex >= 0 ? qsTrId("id-edit-list")
                        //% "Fresh Haul"
                        : qsTrId("id-new-list")
                        //% "Edit Item"
                        return editIndex >= 0 ? qsTrId("id-edit-item")
                        //% "Add Item"
                        : qsTrId("id-add-item")
                }
                //% "Category"
                if (page === "category") return qsTrId("id-category")
                    //% "Move to Haul"
                    if (page === "moveList") return qsTrId("id-move-to-haul")
                        //% "Delete List"
                        if (page === "delete") return isListEdit ? qsTrId("id-delete-list")
                            //% "Delete Item"
                            : qsTrId("id-delete-item")
                            return ""
        }
    }

    // ----------------------------------------------------------------
    // Horizontal snapping page view
    // ----------------------------------------------------------------
    ListView {
        id: pageView
        anchors {
            top: dialogHeader.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        model: pages
        orientation:        ListView.Horizontal
        snapMode:           ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        boundsBehavior:     Flickable.DragAndOvershootBounds
        clip: true

        delegate: Item {
            id: pageDelegate
            width:  pageView.width
            height: pageView.height

            property string pageType: modelData

            // ── TextField page ────────────────────────────────────────
            TextField {
                id: delegateTextField
                visible: pageType === "textField"
                anchors {
                    bottom: parent.verticalCenter
                    bottomMargin: Dims.l(18)
                    horizontalCenter: parent.horizontalCenter
                }
                width: Dims.l(74)
                previewText: isListEdit
                //% "List name"
                ? qsTrId("id-list-name")
                //% "Item name"
                : qsTrId("id-item-name")
                text: editDialog.draftName
                onTextChanged: editDialog.draftName = text
                Component.onCompleted: {
                    if (editDialog.editText === "" && pageType === "textField")
                        Qt.callLater(function() { delegateTextField.forceActiveFocus() })
                }
            }

            // ── Category cycler page ──────────────────────────────────
            Item {
                visible: pageType === "category"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter:   parent.verticalCenter
                    verticalCenterOffset: -Dims.l(12)
                }
                width:  pageView.width
                height: Dims.l(24)

                Rectangle {
                    anchors.fill: parent
                    color: editDialog.selectedCategory !== "None"
                    ? getCategoryColor(editDialog.selectedCategory)
                    : "transparent"
                    opacity: 0.5
                }

                OptionCycler {
                    anchors.fill: parent
                    //% "Tap to change category"
                    title: qsTrId("id-tap-to-change-category")
                    valueArray:   editDialog.categoryOptions
                    currentValue: editDialog.selectedCategory
                    onValueChanged: editDialog.selectedCategory = value
                }
            }

            // ── Move-to-list cycler page ──────────────────────────────
            Item {
                visible: pageType === "moveList"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter:   parent.verticalCenter
                    verticalCenterOffset: -Dims.l(12)
                }
                width:  pageView.width
                height: Dims.l(24)

                OptionCycler {
                    anchors.fill: parent
                    //% "Tap to select target"
                    title: qsTrId("id-tap-to-select-target")
                    valueArray:   editDialog.listOptions
                    currentValue: editDialog.selectedList
                    onValueChanged: editDialog.selectedList = value
                }
            }

            // ── Delete page ───────────────────────────────────────────
            Item {
                visible: pageType === "delete"
                anchors.fill: parent

                Icon {
                    name:  "ios-trash-outline"
                    color: "#FF3B30"
                    anchors {
                        verticalCenter: parent.verticalCenter
                        verticalCenterOffset: -Dims.l(10)
                        horizontalCenter: parent.horizontalCenter
                    }
                    width:  Dims.l(40)
                    height: Dims.l(40)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        deleteRemorseTimer.deleteMode       = isListEdit ? "list" : "item"
                        deleteRemorseTimer.deleteItemIndex  = editIndex
                        deleteRemorseTimer.deleteTargetName = editText
                        deleteRemorseTimer.action = (isListEdit
                        ? qsTrId("id-delete-list")
                        : qsTrId("id-delete-item")) + "\n" + editDialog.draftName.trim()
                        deleteRemorseTimer.countdownSeconds = 0
                        deleteRemorseTimer.start()
                    }
                }
            }

            // ── Cancel / Confirm buttons — all pages except delete ────
            Item {
                visible: pageType !== "delete"
                anchors {
                    bottom:           parent.bottom
                    bottomMargin:     Dims.l(14)
                    horizontalCenter: parent.horizontalCenter
                }
                width:  pageView.width
                height: Dims.l(18)

                IconButton {
                    iconName: "ios-close-circle-outline"
                    anchors {
                        right:        parent.horizontalCenter
                        rightMargin:  Dims.l(4)
                        verticalCenter: parent.verticalCenter
                    }
                    onClicked: pop()
                }

                IconButton {
                    iconName: "ios-checkmark-circle-outline"
                    anchors {
                        left:       parent.horizontalCenter
                        leftMargin: Dims.l(4)
                        verticalCenter: parent.verticalCenter
                    }
                    onClicked: {
                        var trimmed = editDialog.draftName.trim()
                        if (trimmed.length === 0) { pop(); return }

                        var newCategory = editDialog.selectedCategory === "None"
                        ? "" : editDialog.selectedCategory

                        pop()

                        if (isListEdit) {
                            if (editIndex >= 0) renameList(editText, trimmed)
                                else                createList(trimmed)
                        } else if (editIndex >= 0 && editDialog.selectedList !== appState.currentListName) {
                            moveItemToList(editIndex, editDialog.selectedList, trimmed, newCategory)
                        } else if (editIndex >= 0) {
                            updateItemInPlace(editIndex, trimmed, newCategory)
                        } else {
                            shoppingModel.append({ name: trimmed, checked: false, category: newCategory })
                            buildFlatModel()
                        }
                    }
                }
            }
        }
    }

    PageDot {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     Dims.h(4)
        height:                   Dims.h(3)
        dotNumber:                pages.length
        currentIndex:             pageView.currentIndex
    }

    // ----------------------------------------------------------------
    // Close dialog when delete remorse timer confirms
    // ----------------------------------------------------------------
    Connections {
        target: root
        function onDeleteConfirmed() { pop() }
    }

    // ----------------------------------------------------------------
    // HandWritingKeyboard — always last, activates on TextField focus
    // ----------------------------------------------------------------
    HandWritingKeyboard {
        anchors.fill: parent
    }
}
