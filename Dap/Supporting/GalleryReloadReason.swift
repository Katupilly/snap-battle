enum GalleryReloadReason: String, CaseIterable {
    case initialLoad
    case saveCompleted
    case delete
    case pullToRefresh
    case retry
    case playLatestFallback
    case boardOpen
    case fixtureInstalled
    case manual
}