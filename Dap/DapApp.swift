//
//  DapApp.swift
//  Dap
//
//  Created by Pedro Kosciuk Lima on 14/07/26.
//

import SwiftUI

@main
struct DapApp: App {
    @State private var navigation = AppNavigationModel()
    @State private var gallery = GalleryViewModel()
    @State private var pedalboards = PedalboardsViewModel()
    @State private var thumbnailLoader = ThumbnailLoader()

    var body: some Scene {
        WindowGroup {
            ContentView(
                navigation: navigation,
                gallery: gallery,
                pedalboards: pedalboards,
                thumbnailLoader: thumbnailLoader
            )
            .environment(navigation)
            .environment(gallery)
            .overlay(alignment: .bottom) {
                RootChromeOverlay(navigation: navigation, gallery: gallery)
            }
        }
    }
}

private struct RootChromeOverlay: View {
    let navigation: AppNavigationModel
    let gallery: GalleryViewModel

    var body: some View {
        let presentation = RootChromePresentation(
            rootNavigation: navigation.rootNavigation,
            galleryBottomChromeMode: GalleryBottomChromeMode(
                isSelecting: gallery.isSelecting,
                selectedCount: gallery.selectedIDs.count
            )
        )
        if presentation.shouldShowTab {
            CustomBottomNavigation(
                selectedTab: navigation.rootNavigation.selectedDestination,
                selectTab: { navigation.selectedDestination = $0.appDestination },
                capture: navigation.beginCapture,
                isAccessibilityHidden: false,
                isCaptureVisible: presentation.shouldShowCapture
            )
        } else {
            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)
        }
    }
}
