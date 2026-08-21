//
//  Environment.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2017/08/10.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

struct Environment {

    // MARK: - Properties
    let clipService: ClipService
    let hotKeyService: HotKeyService
    let dataCleanService: DataCleanService
    let pasteService: PasteService
    let excludeAppService: ExcludeAppService
    let accessibilityService: AccessibilityService
    let menuManager: MenuManager
    let pythonService: PythonExecutionService
    let finderService: FinderService
    let imageExportService: ClipImageExportService

    let defaults: UserDefaults

    // MARK: - Initialize
    init(clipService: ClipService = ClipService(),
         hotKeyService: HotKeyService = HotKeyService(),
         dataCleanService: DataCleanService = DataCleanService(),
         pasteService: PasteService = PasteService(),
         excludeAppService: ExcludeAppService = ExcludeAppService(applications: []),
         accessibilityService: AccessibilityService = AccessibilityService(),
         menuManager: MenuManager = MenuManager(),
         pythonService: PythonExecutionService = PythonExecutionService(),
         finderService: FinderService = FinderService(),
         imageExportService: ClipImageExportService = ClipImageExportService(),
         defaults: UserDefaults = .standard) {

        self.clipService = clipService
        self.hotKeyService = hotKeyService
        self.dataCleanService = dataCleanService
        self.pasteService = pasteService
        self.excludeAppService = excludeAppService
        self.accessibilityService = accessibilityService
        self.menuManager = menuManager
        self.pythonService = pythonService
        self.finderService = finderService
        self.imageExportService = imageExportService
        self.defaults = defaults
    }

}
