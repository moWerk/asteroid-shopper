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
import Nemo.Configuration 1.0
import org.asteroid.utils 1.0
import org.asteroid.controls 1.0
import org.asteroid.shopper 1.0

Application {
    id: root
    anchors.fill: parent

    centerColor: "#0E7B81"
    outerColor: "#090B0C"

    signal listLoaded()
    signal deleteConfirmed()

    // ----------------------------------------------------------------
    // User lists config
    // ----------------------------------------------------------------
    ConfigurationValue {
        id: userListsConfig
        key: "/asteroid/apps/shopper/lists"
        defaultValue: "[]"
    }

    ConfigurationValue {
        id: lastListConfig
        key: "/asteroid/apps/shopper/lastList"
        defaultValue: "default"
    }

    // ----------------------------------------------------------------
    // Categories config — empty string means use built-in defaults
    // ----------------------------------------------------------------
    ConfigurationValue {
        id: categoriesConfig
        key: "/asteroid/apps/shopper/categories"
        defaultValue: ""
    }

    readonly property var defaultCategories: [
        //% "Produce"
        { name: qsTrId("id-cat-produce"),    color: "#7BC67E", sortOrder: 0 },
        //% "Dairy"
        { name: qsTrId("id-cat-dairy"),      color: "#F5E642", sortOrder: 1 },
        //% "Meat & Fish"
        { name: qsTrId("id-cat-meat-fish"),  color: "#E07A5F", sortOrder: 2 },
        //% "Bakery"
        { name: qsTrId("id-cat-bakery"),     color: "#C4A35A", sortOrder: 3 },
        //% "Frozen"
        { name: qsTrId("id-cat-frozen"),     color: "#8ECAE6", sortOrder: 4 },
        //% "Pantry"
        { name: qsTrId("id-cat-pantry"),     color: "#B0B0B0", sortOrder: 5 },
        //% "Drinks"
        { name: qsTrId("id-cat-drinks"),     color: "#6A9EC4", sortOrder: 6 },
        //% "Household"
        { name: qsTrId("id-cat-household"),  color: "#9B72CF", sortOrder: 7 },
        //% "Snacks"
        { name: qsTrId("id-cat-snacks"),     color: "#E8A838", sortOrder: 8 },
        //% "Baby & Pet"
        { name: qsTrId("id-cat-baby-pet"),   color: "#F4A8C0", sortOrder: 9 }
    ]

    property bool defaultExists: false
    property bool hasUserLists: JSON.parse(userListsConfig.value).length > 0 || !defaultExists

    // ----------------------------------------------------------------
    // List config helpers
    // ----------------------------------------------------------------
    function getUserLists() { return JSON.parse(userListsConfig.value) }
    function setUserLists(arr) { userListsConfig.value = JSON.stringify(arr) }

    // ----------------------------------------------------------------
    // Category helpers
    // ----------------------------------------------------------------
    function getCategories() {
        var val = categoriesConfig.value
        if (!val || val === "") return defaultCategories.slice()
            return JSON.parse(val)
    }

    function setCategories(arr) {
        categoriesConfig.value = JSON.stringify(arr)
    }

    function getCategoryColor(name) {
        if (!name || name === "") return ""
            var cats = getCategories()
            for (var i = 0; i < cats.length; i++) {
                if (cats[i].name === name) return cats[i].color
            }
            return ""
    }

    function getCategoryNames() {
        var cats = getCategories()
        cats.sort(function(a, b) { return a.sortOrder - b.sortOrder })
        return cats.map(function(c) { return c.name })
    }

    function renameCategoryInItems(oldName, newName) {
        for (var i = 0; i < shoppingModel.count; i++) {
            if (shoppingModel.get(i).category === oldName)
                shoppingModel.setProperty(i, "category", newName)
        }
    }

    function moveCategoryToPosition(categoryName, newPosition) {
        var cats = getCategories()
        cats.sort(function(a, b) { return a.sortOrder - b.sortOrder })
        var idx = -1
        for (var i = 0; i < cats.length; i++) {
            if (cats[i].name === categoryName) { idx = i; break }
        }
        if (idx < 0) return
            var cat = cats.splice(idx, 1)[0]
            cats.splice(Math.max(0, Math.min(newPosition - 1, cats.length)), 0, cat)
            cats.forEach(function(c, i) { c.sortOrder = i })
            setCategories(cats)
    }

    // ----------------------------------------------------------------
    // Data models
    // ----------------------------------------------------------------
    ListModel { id: shoppingModel }
    ListModel { id: listsModel }
    ListModel { id: flatModel }

    // ----------------------------------------------------------------
    // App state
    // ----------------------------------------------------------------
    QtObject {
        id: appState
        property bool anyChecked: false
        property int uncheckedCount: 0
        property int totalCount: 0
        property string currentListName: "default"
        property bool isLoading: false
    }

    QtObject {
        id: appStyle
        readonly property int    rowHeight:           Dims.l(17)
        readonly property int    categoryHeaderHeight: Dims.l(13)
        readonly property int    footerRowHeight:      Dims.l(26)
        readonly property int    footerDividerHeight:  Dims.l(13)
        readonly property int    iconSize:             Dims.l(11)
        readonly property int    bodyFontSize:         Dims.l(8)
        readonly property int    secondaryFontSize:    Dims.l(6)
        readonly property string separatorColor:       "#20ffffff"
        readonly property string pressColor:           "#33ffffff"
        readonly property string labelColor:           "#ffffff"
        readonly property string dimLabelColor:        "#80ffffff"
        readonly property string accentColor:          "#119DA4"
    }

    Component.onCompleted: {
        loadListsModel()
        var last = lastListConfig.value
        var known = getUserLists()
        if (last !== "default" && known.indexOf(last) < 0) last = "default"
            appState.currentListName = last
            loadShoppingList()
    }

    // ----------------------------------------------------------------
    // File line parser — handles both legacy and category-prefixed lines
    // Format: ±CategoryName:itemName  or  ±itemName  (legacy)
    // ----------------------------------------------------------------
    function parseLine(line) {
        var trimmed = line.trim()
        if (trimmed.length === 0) return null
            var isChecked = trimmed.charAt(0) === '+'
            var rest = (trimmed.charAt(0) === '+' || trimmed.charAt(0) === '-')
            ? trimmed.substring(1) : trimmed
            var colonIdx = rest.indexOf(':')
            var category = ""
            var name = rest
            if (colonIdx >= 0) {
                category = rest.substring(0, colonIdx).trim()
                name = rest.substring(colonIdx + 1).trim()
            }
            if (name.length === 0) return null
                return { name: name, checked: isChecked, category: category }
    }

    function countItems(listName) {
        var content = FileHelper.readFile(listName)
        if (!content) return 0
            return content.split('\n').filter(function(l) { return l.trim() !== '' }).length
    }

    function countCheckedItems(listName) {
        var content = FileHelper.readFile(listName)
        if (!content) return 0
            return content.split('\n').filter(function(l) { return l.trim().charAt(0) === '+' }).length
    }

    // ----------------------------------------------------------------
    // List management
    // ----------------------------------------------------------------
    function loadListsModel() {
        defaultExists = FileHelper.exists("default") && countItems("default") > 0
        listsModel.clear()
        var arr = getUserLists()
        arr.forEach(function(n) {
            listsModel.append({ name: n, itemCount: countItems(n), checkedCount: countCheckedItems(n) })
        })
        if (defaultExists)
            listsModel.append({ name: "default", itemCount: countItems("default"), checkedCount: countCheckedItems("default") })
    }

    function loadShoppingList() {
        appState.isLoading = true
        shoppingModel.clear()
        var content = FileHelper.readFile(appState.currentListName)
        if (content) {
            var lines = content.split('\n')
            lines.forEach(function(line) {
                var parsed = parseLine(line)
                if (parsed) shoppingModel.append(parsed)
            })
        }
        buildFlatModel()
        appState.isLoading = false
        root.listLoaded()
    }

    function saveShoppingList() {
        var data = ""
        for (var i = 0; i < shoppingModel.count; i++) {
            var item = shoppingModel.get(i)
            var prefix = item.checked ? "+" : "-"
            data += (item.category && item.category !== "")
            ? prefix + item.category + ":" + item.name + "\n"
            : prefix + item.name + "\n"
        }
        FileHelper.writeFile(appState.currentListName, data)
    }

    function updateItemInPlace(sourceIndex, newName, newCategory) {
        shoppingModel.setProperty(sourceIndex, "name",     newName)
        shoppingModel.setProperty(sourceIndex, "category", newCategory)
        for (var i = 0; i < flatModel.count; i++) {
            if (flatModel.get(i).sourceIndex === sourceIndex) {
                flatModel.setProperty(i, "name",          newName)
                flatModel.setProperty(i, "category",      newCategory)
                flatModel.setProperty(i, "categoryColor", getCategoryColor(newCategory))
                break
            }
        }
        saveShoppingList()
    }

    // ----------------------------------------------------------------
    // Flat display model builder
    //
    // Layout order:
    //   1. Category groups (sorted by sortOrder)
    //      — header row per category if it has ≥1 item
    //      — items alphabetically within group, checked state in place
    //   2. Uncategorized items (no header, plain rows, alpha sorted)
    //
    // flatModel roles: type, name, checked, category, categoryColor,
    //                  sortNum, sourceIndex, allChecked
    // ----------------------------------------------------------------
    function buildFlatModel() {
        flatModel.clear()
        var cats = getCategories()
        cats.sort(function(a, b) { return a.sortOrder - b.sortOrder })

        for (var ci = 0; ci < cats.length; ci++) {
            var cat = cats[ci]
            var items = []
            for (var ii = 0; ii < shoppingModel.count; ii++) {
                var sm = shoppingModel.get(ii)
                if (sm.category === cat.name)
                    items.push({ name: sm.name, checked: sm.checked, sourceIndex: ii })
            }
            if (items.length === 0) continue
                items.sort(function(a, b) { return a.name.localeCompare(b.name) })
                var allChecked = items.every(function(it) { return it.checked })
                flatModel.append({ type: "categoryHeader", name: cat.name,
                    sortNum: cat.sortOrder + 1, checked: false, category: cat.name,
                    categoryColor: cat.color, sourceIndex: -1, allChecked: allChecked })
                for (var ai = 0; ai < items.length; ai++) {
                    flatModel.append({ type: "item", name: items[ai].name, checked: items[ai].checked,
                        category: cat.name, categoryColor: cat.color,
                        sourceIndex: items[ai].sourceIndex, allChecked: false })
                }
        }

        var uncatItems = []
        for (var ui = 0; ui < shoppingModel.count; ui++) {
            var um = shoppingModel.get(ui)
            if (!um.category || um.category === "")
                uncatItems.push({ name: um.name, checked: um.checked, sourceIndex: ui })
        }
        uncatItems.sort(function(a, b) { return a.name.localeCompare(b.name) })
        for (var uu = 0; uu < uncatItems.length; uu++) {
            flatModel.append({ type: "item", name: uncatItems[uu].name, checked: uncatItems[uu].checked,
                category: "", categoryColor: "", sourceIndex: uncatItems[uu].sourceIndex, allChecked: false })
        }

        saveShoppingList()
        updateAnyChecked()
    }

    function uncheckAll() {
        for (var i = 0; i < shoppingModel.count; i++) shoppingModel.setProperty(i, "checked", false)
            buildFlatModel()
    }

    function checkAll() {
        for (var i = 0; i < shoppingModel.count; i++) shoppingModel.setProperty(i, "checked", true)
            buildFlatModel()
    }

    function updateAnyChecked() {
        var unchecked = 0
        var total = shoppingModel.count
        for (var i = 0; i < total; i++) {
            if (!shoppingModel.get(i).checked) unchecked++
        }
        appState.totalCount     = total
        appState.uncheckedCount = unchecked
        appState.anyChecked     = unchecked < total && total > 0
        updateCurrentListCount()
    }

    function updateCurrentListCount() {
        var checked = 0
        for (var j = 0; j < shoppingModel.count; j++) {
            if (shoppingModel.get(j).checked) checked++
        }
        for (var i = 0; i < listsModel.count; i++) {
            if (listsModel.get(i).name === appState.currentListName) {
                listsModel.setProperty(i, "itemCount",    shoppingModel.count)
                listsModel.setProperty(i, "checkedCount", checked)
                return
            }
        }
    }

    function switchToList(listName) {
        shoppingModel.clear()
        flatModel.clear()
        appState.currentListName = listName
        lastListConfig.value = listName
        loadShoppingList()
    }

    function createList(listName) {
        var trimmed = listName.trim()
        if (trimmed === "" || trimmed === "default") return
            var arr = getUserLists()
            if (arr.indexOf(trimmed) >= 0) return
                arr.push(trimmed)
                setUserLists(arr)
                FileHelper.writeFile(trimmed, "")
                loadListsModel()
                switchToList(trimmed)
    }

    function deleteList(listName) {
        if (listName === "default") {
            FileHelper.writeFile("default", "")
            defaultExists = false
            if (appState.currentListName === "default") {
                var remaining = getUserLists()
                switchToList(remaining.length > 0 ? remaining[0] : "default")
            }
        } else {
            var arr = getUserLists()
            arr = arr.filter(function(n) { return n !== listName })
            setUserLists(arr)
            FileHelper.writeFile(listName, "")
            if (appState.currentListName === listName) {
                var remaining2 = getUserLists()
                switchToList(remaining2.length > 0 ? remaining2[0] : "default")
            }
        }
        loadListsModel()
    }

    function renameList(oldName, newName) {
        var trimmed = newName.trim()
        if (oldName === trimmed || trimmed === "" || oldName === "default" || trimmed === "default") return
            var arr = getUserLists()
            if (arr.indexOf(trimmed) >= 0) return
                var content = FileHelper.readFile(oldName)
                FileHelper.writeFile(trimmed, content)
                FileHelper.writeFile(oldName, "")
                var idx = arr.indexOf(oldName)
                if (idx >= 0) arr[idx] = trimmed
                    setUserLists(arr)
                    loadListsModel()
                    if (appState.currentListName === oldName) appState.currentListName = trimmed
    }

    function moveItemToList(sourceIndex, targetListName, itemName, itemCategory) {
        var line = "-"
        if (itemCategory && itemCategory !== "") line += itemCategory + ":"
            line += itemName
            var existing = FileHelper.readFile(targetListName)
            FileHelper.writeFile(targetListName, existing + line + "\n")
            shoppingModel.remove(sourceIndex)
            buildFlatModel()
            loadListsModel()
            root.listLoaded()
    }

    // ----------------------------------------------------------------
    // Navigation
    // ----------------------------------------------------------------
    LayerStack {
        id: layerStack
        anchors.fill: parent
        firstPage: shoppingListPageComponent
    }

    Component { id: shoppingListPageComponent;  ShoppingListPage   { } }
    Component { id: allListsPageComponent;       AllListsPage       { } }
    Component { id: editDialogComponent;         EditDialog         { } }
    Component { id: categoryEditDialogComponent; CategoryEditDialog { } }

    // ----------------------------------------------------------------
    // Delete remorse timer — started from EditDialog
    // ----------------------------------------------------------------
    RemorseTimer {
        id: deleteRemorseTimer
        duration: 3000
        gaugeSegmentAmount: 6
        gaugeStartDegree: -130
        gaugeEndFromStartDegree: 265
        //% "Tap to cancel"
        cancelText: qsTrId("id-tap-to-cancel")

        property string deleteMode: "item"
        property int deleteItemIndex: -1
        property string deleteTargetName: ""

        onTriggered: {
            if (deleteMode === "list") {
                deleteList(deleteTargetName)
            } else {
                shoppingModel.remove(deleteItemIndex)
                buildFlatModel()
            }
            root.deleteConfirmed()
        }
    }
}
