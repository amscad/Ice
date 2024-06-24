//
//  MenuBarItemImageCache.swift
//  Ice
//

import Bridging
import Cocoa
import Combine
import OSLog

@MainActor
class MenuBarItemImageCache: ObservableObject {
    /// The cached item images.
    @Published private(set) var images = [MenuBarItemInfo: CGImage]()

    /// The screen of the cached item images.
    private(set) var screen: NSScreen?

    private weak var appState: AppState?

    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
    }

    func performSetup() {
        configureCancellables()
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        if let appState {
            Publishers.Merge(
                // update when the active space or screen parameters change
                Publishers.Merge(
                    NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification),
                    NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
                )
                .mapToVoid(),

                // update when the average menu bar color or cached items change
                Publishers.Merge(
                    appState.menuBarManager.$averageColor.removeDuplicates().mapToVoid(),
                    appState.itemManager.$cachedMenuBarItems.removeDuplicates().mapToVoid()
                )
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else {
                    return
                }
                Task {
                    await self.updateCache()
                }
            }
            .store(in: &c)
        }

        Timer.publish(every: 3, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                Task {
                    await self.updateCache()
                }
            }
            .store(in: &c)

        cancellables = c
    }

    func isEmpty(for section: MenuBarSection.Name) -> Bool {
        let keys = Set(images.keys)
        let items = appState?.itemManager.cachedMenuBarItems[section] ?? []
        for item in items where keys.contains(item.info) {
            return false
        }
        return true
    }

    func createImages(for section: MenuBarSection.Name, screen: NSScreen) async -> [MenuBarItemInfo: CGImage] {
        actor TempCache {
            private(set) var images = [MenuBarItemInfo: CGImage]()

            func cache(image: CGImage, with info: MenuBarItemInfo) {
                images[info] = image
            }
        }

        guard
            let appState,
            let items = appState.itemManager.cachedMenuBarItems[section]
        else {
            return [:]
        }

        let tempCache = TempCache()
        let backingScaleFactor = screen.backingScaleFactor

        let cacheTask = Task.detached {
            let windowIDs = items.map { $0.windowID }

            guard
                let compositeImage = Bridging.captureWindows(windowIDs, option: .boundsIgnoreFraming),
                !compositeImage.isTransparent(maxAlpha: 0.9)
            else {
                return
            }

            if CGFloat(compositeImage.width) == items.reduce(into: 0, { $0 += $1.frame.width }) * backingScaleFactor {
                var start: CGFloat = 0

                for item in items {
                    let width = item.frame.width * backingScaleFactor
                    let height = item.frame.height * backingScaleFactor
                    let frame = CGRect(x: start, y: 0, width: width, height: height)

                    defer {
                        start += width
                    }

                    guard
                        let itemImage = compositeImage.cropping(to: frame),
                        !itemImage.isTransparent()
                    else {
                        continue
                    }

                    await tempCache.cache(image: itemImage, with: item.info)
                }
            } else {
                for item in items {
                    guard
                        let image = Bridging.captureWindow(item.windowID, option: .boundsIgnoreFraming),
                        !image.isTransparent()
                    else {
                        continue
                    }
                    await tempCache.cache(image: image, with: item.info)
                }
            }
        }

        await cacheTask.value
        return await tempCache.images
    }

    func updateCache() async {
        guard
            let appState,
            let screen = NSScreen.main
        else {
            return
        }
        var sectionsNeedingDisplay = [MenuBarSection.Name]()
        if
            let settingsWindow = appState.settingsWindow,
            settingsWindow.isVisible
        {
            sectionsNeedingDisplay = MenuBarSection.Name.allCases
        } else if let section = appState.menuBarManager.iceBarPanel.currentSection {
            sectionsNeedingDisplay.append(section)
        }
        for section in sectionsNeedingDisplay {
            let sectionImages = await createImages(for: section, screen: screen)
            guard !sectionImages.isEmpty else {
                Logger.imageCache.warning("Update cache failed for section \(section.logString)")
                continue
            }
            images.merge(sectionImages) { (_, new) in new }
        }
        self.screen = screen
    }
}

private extension Logger {
    static let imageCache = Logger(category: "MenuBarItemImageCache")
}
