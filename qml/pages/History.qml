/**
 * Copyright (C) 2018 Willem-Jan de Hoog
 *
 * License: MIT
 */


import QtQuick 2.2
import Sailfish.Silica 1.0

import "../components"
import "../Spotify.js" as Spotify
import "../Util.js" as Util

Page {
    id: historyPage
    objectName: "HistoryPage"

    property bool showBusy: false

    property int currentIndex: -1

    allowedOrientations: Orientation.All

    ListModel {
        id: searchModel
    }

    SilicaListView {
        id: listView
        model: searchModel

        width: parent.width
        anchors.top: parent.top
        anchors.bottom: navPanel.top
        clip: navPanel.expanded

        header: Column {
            id: lvColumn

            width: parent.width - 2*Theme.paddingMedium
            x: Theme.paddingMedium
            anchors.bottomMargin: Theme.paddingLarge
            spacing: Theme.paddingLarge

            PageHeader {
                id: pHeader
                width: parent.width
                title: qsTr("History")
                MenuButton {}
            }

            //LoadPullMenus {}
            //LoadPushMenus {}
            PullDownMenu {
                MenuItem {
                    text: qsTr("Clear History")
                    onClicked: app.clearHistory()
                }
            }

        }

        delegate: ListItem {
            id: listItem
            width: parent.width - 2*Theme.paddingMedium
            x: Theme.paddingMedium
            //height: searchResultListItem.height
            contentHeight: Theme.itemSizeLarge

            SearchResultListItem {
                id: searchResultListItem
                dataModel: model
            }

            menu: SearchResultContextMenu {}

            onClicked: {
                switch(type) {
                case 0:
                    app.pushPage(Util.HutspotPage.Album, {album: album})
                    break;
                case 1:
                    app.pushPage(Util.HutspotPage.Artist, {currentArtist: artist})
                    break;
                case 2:
                    app.pushPage(Util.HutspotPage.Playlist, {playlist: playlist})
                    break;
                }
            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: listView.count === 0
            text: qsTr("Nothing found")
            hintText: qsTr("Pull down to reload")
        }

    }

    NavigationPanel {
        id: navPanel
    }

    Connections {
        target: app
        onHistoryModified: {
            if(added >= 0 && removed === -1)          // a new one
                loadFirstOne()
            else if(added >= 0)                       // a moved one
                searchModel.move(removed, added, 1)
            else if(added === -1 && removed >= 0)     // a removed one
                searchModel.remove(removed)
            else if(added === -1 && removed === -1)   // new history
                refresh()
        }
    }

    function reload() {
        searchModel.clear()

        for(var p=0;p<parsed.length;p++) {
            for(var i=0;i<retrieved.length;i++) {
                if(parsed[p].id === retrieved[i].data.id) {
                    switch(retrieved[i].type) {
                    case 0:
                        searchModel.append({type: 0,
                                            name: retrieved[i].data.name,
                                            album: retrieved[i].data})
                        break
                    case 1:
                        searchModel.append({type: 1,
                                            name: retrieved[i].data.name,
                                            artist: retrieved[i].data})
                        break
                    case 2:
                        searchModel.append({type: 2,
                                            name: retrieved[i].data.name,
                                            playlist: retrieved[i].data})
                        break
                    }
                    break
                }
            }
        }
    }

    function checkReload() {
        retrievedCount++
        if(retrievedCount === app.history.length || retrievedCount === numberToRetrieve)
            reload()
    }

    property var retrieved: []
    property var parsed: []
    property int retrievedCount: 0
    property int numberToRetrieve: 0

    function refresh() {
        var i;
        showBusy = true
        retrieved = []
        retrievedCount = 0
        numberToRetrieve = 20
        parsed = []
        _refresh(app.history.length)
    }

    function loadFirstOne() {
        retrieved.unshift({})
        parsed.unshift({})
        numberToRetrieve = 1
        _refresh(1)
    }

    function _refresh(count) {
        for(var i=0;i<count && i < numberToRetrieve;i++) {
            var p = Util.parseSpotifyUri(app.history[i])
            parsed[i] = p
            if(p.type === undefined)
                continue
            switch(p.type) {
            case Util.SpotifyItemType.Album:
                Spotify.getAlbum([p.id], function(error, data) {
                    if(data) {
                        retrieved.push({type: 0, data: data})
                    } else
                        console.log("No Data for getAlbum " + p.id)
                    checkReload()
                })
                break
            case Util.SpotifyItemType.Artist:
                Spotify.getArtist([p.id], function(error, data) {
                    if(data) {
                        retrieved.push({type: 1, data: data})
                    } else
                        console.log("No Data for getArtist " + p.id)
                    checkReload()
                })
                break
            case Util.SpotifyItemType.Playlist:
                Spotify.getPlaylist(app.id, p.id, function(error, data) {
                    if(data) {
                        retrieved.push({type: 2, data: data})
                    } else
                        console.log("No Data for getPlaylist" + p.id)
                    checkReload()
                })
                break
            }
        }
    }

    property alias cursorHelper: cursorHelper

    CursorHelper {
        id: cursorHelper

        onLoadNext: refresh()
        onLoadPrevious: refresh()
    }

    Connections {
        target: app
        onLoggedInChanged: {
            if(app.loggedIn)
                refresh()
        }
        onHasValidTokenChanged: refresh()
    }

    Component.onCompleted: {
        if(app.hasValidToken)
            refresh()
    }

}
